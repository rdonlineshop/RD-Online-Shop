import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'order_data.dart';
import 'ride_customer_tracking_page.dart';
import 'services/ride_driver_service.dart';
import 'services/ride_request_service.dart';

class RideRequestPage extends StatefulWidget {
  const RideRequestPage({
    required this.driver,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.vehicleType,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.routeDistanceKm,
    required this.routeDurationMinutes,
    required this.estimatedFare,
    required this.fareCurrency,
    required this.fareUsesRoadRoute,
    required this.fareBaseFare,
    required this.farePerKm,
    required this.fareMinimumFare,
    super.key,
  });

  final RideDriverNearby driver;
  final String pickupAddress;
  final String destinationAddress;
  final String vehicleType;

  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  final double routeDistanceKm;
  final int routeDurationMinutes;
  final double estimatedFare;
  final String fareCurrency;
  final bool fareUsesRoadRoute;
  final double fareBaseFare;
  final double farePerKm;
  final double fareMinimumFare;

  @override
  State<RideRequestPage> createState() =>
      _RideRequestPageState();
}

class _RideRequestPageState extends State<RideRequestPage> {
  final RideRequestService _rideRequestService =
      RideRequestService();

  bool _isSending = false;
  String? _sentRequestId;

  RideDriverNearby get driver => widget.driver;
  String get pickupAddress => widget.pickupAddress;
  String get destinationAddress => widget.destinationAddress;
  String get vehicleType => widget.vehicleType;

  Future<void> _sendRideRequest() async {
    if (_isSending || _sentRequestId != null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final String customerId =
          await getOrCreateCustomerId();

      final String requestId =
          await _rideRequestService.createRideRequest(
        customerId: customerId,
        driver: driver,
        vehicleType: vehicleType,
        pickupAddress: pickupAddress,
        pickupLatitude: widget.pickupLatitude,
        pickupLongitude: widget.pickupLongitude,
        destinationAddress: destinationAddress,
        destinationLatitude: widget.destinationLatitude,
        destinationLongitude: widget.destinationLongitude,
        routeDistanceKm: widget.routeDistanceKm,
        routeDurationMinutes: widget.routeDurationMinutes,
        estimatedFare: widget.estimatedFare,
        currency: widget.fareCurrency,
        fareUsesRoadRoute: widget.fareUsesRoadRoute,
        fareBaseFare: widget.fareBaseFare,
        farePerKm: widget.farePerKm,
        fareMinimumFare: widget.fareMinimumFare,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sentRequestId = requestId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ride request sent to ${driver.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send ride request: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _openTracking(String requestId) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RideCustomerTrackingPage(
          rideRequestId: requestId,
          driverId: driver.driverId,
        ),
      ),
    );
  }

  void _chooseAnotherDriver() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Ride Request',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _driverCard(),
                const SizedBox(height: 16),
                _tripCard(),
                const SizedBox(height: 16),
                _fareCard(),
                const SizedBox(height: 20),
                _requestActionSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _requestActionSection() {
    final String? requestId = _sentRequestId;

    if (requestId == null) {
      return SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: _isSending ? null : _sendRideRequest,
          icon: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                ),
          label: Text(
            _isSending
                ? 'Sending...'
                : 'Send Ride Request',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _rideRequestService.watchRideRequest(
        requestId,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.hasError) {
          return _requestStatusCard(
            color: Colors.red,
            icon: Icons.error_outline_rounded,
            title: 'Could not load ride status',
            message: snapshot.error.toString(),
            actionLabel: 'Retry',
            onAction: () {
              setState(() {});
            },
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> document =
            snapshot.data!;

        if (!document.exists) {
          return _requestStatusCard(
            color: Colors.red,
            icon: Icons.search_off_rounded,
            title: 'Ride request not found',
            message:
                'This request is no longer available.',
            actionLabel: 'Choose Another Driver',
            onAction: _chooseAnotherDriver,
          );
        }

        final Map<String, dynamic> data =
            document.data() ?? <String, dynamic>{};

        final String status =
            data['status']?.toString().trim().toLowerCase() ??
                'pending';

        switch (status) {
          case 'accepted':
            return _requestStatusCard(
              color: Colors.green,
              icon: Icons.check_circle_rounded,
              title: 'Driver Accepted ✅',
              message:
                  '${driver.name} accepted your ride request. You can now track the driver.',
              actionLabel: 'Track Driver',
              onAction: () {
                _openTracking(requestId);
              },
            );

          case 'rejected':
            return _requestStatusCard(
              color: Colors.red,
              icon: Icons.cancel_rounded,
              title: 'Driver Rejected',
              message:
                  'This driver could not accept your ride. Please choose another nearby driver.',
              actionLabel: 'Choose Another Driver',
              onAction: _chooseAnotherDriver,
            );

          case 'started':
          case 'in_progress':
            return _requestStatusCard(
              color: Colors.blue,
              icon: Icons.route_rounded,
              title: 'Trip In Progress',
              message:
                  'Your ride has started. Live tracking is available.',
              actionLabel: 'Track Ride',
              onAction: () {
                _openTracking(requestId);
              },
            );

          case 'completed':
            return _requestStatusCard(
              color: Colors.green,
              icon: Icons.flag_circle_rounded,
              title: 'Trip Completed',
              message:
                  'Your ride has been completed successfully.',
              actionLabel: 'View Ride',
              onAction: () {
                _openTracking(requestId);
              },
            );

          case 'cancelled':
            return _requestStatusCard(
              color: Colors.red,
              icon: Icons.cancel_outlined,
              title: 'Ride Cancelled',
              message: 'This ride request was cancelled.',
              actionLabel: 'Choose Another Driver',
              onAction: _chooseAnotherDriver,
            );

          case 'pending':
          default:
            return _requestStatusCard(
              color: Colors.orange,
              icon: Icons.schedule_rounded,
              title: 'Waiting for Driver',
              message:
                  'Request ID: $requestId\nWaiting for ${driver.name} to accept or reject the ride.',
            );
        }
      },
    );
  }

  Widget _requestStatusCard({
    required Color color,
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor:
                      color.withValues(alpha: 0.12),
                  child: Icon(
                    icon,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actionLabel != null &&
                onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(
                    actionLabel.contains('Track')
                        ? Icons.location_searching_rounded
                        : Icons.search_rounded,
                  ),
                  label: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _driverCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            _avatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    driver.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: <Widget>[
                      _miniInfo(
                        Icons.directions_car_rounded,
                        driver.vehicleType,
                      ),
                      if (driver.vehicleNumber.isNotEmpty)
                        _miniInfo(
                          Icons.badge_outlined,
                          driver.vehicleNumber,
                        ),
                      _miniInfo(
                        Icons.near_me_rounded,
                        '${driver.distanceKm.toStringAsFixed(1)} km',
                      ),
                      if (driver.rating > 0)
                        _miniInfo(
                          Icons.star_rounded,
                          driver.rating.toStringAsFixed(1),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Online',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Trip Details',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _locationRow(
              icon: Icons.my_location_rounded,
              label: 'Pickup',
              value: pickupAddress,
            ),
            const Divider(height: 24),
            _locationRow(
              icon: Icons.location_on_rounded,
              label: 'Destination',
              value: destinationAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fareCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Ride Summary',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _summaryRow(
              icon: Icons.directions_car_rounded,
              label: 'Vehicle',
              value: vehicleType,
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.person_rounded,
              label: 'Driver',
              value: driver.name,
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.route_rounded,
              label: 'Distance',
              value:
                  '${widget.routeDistanceKm.toStringAsFixed(1)} km${widget.fareUsesRoadRoute ? '' : ' approx.'}',
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.timer_outlined,
              label: 'Estimated time',
              value: '${widget.routeDurationMinutes} min',
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.payments_outlined,
              label: 'Estimated Fare',
              value:
                  '${widget.fareCurrency} ${widget.estimatedFare.toStringAsFixed(0)}',
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.calculate_outlined,
              label: 'Live Fare Formula',
              value:
                  '${widget.fareCurrency} ${widget.fareBaseFare.toStringAsFixed(0)} + '
                  '${widget.fareCurrency} ${widget.farePerKm.toStringAsFixed(0)}/km',
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Minimum ${widget.fareCurrency} ${widget.fareMinimumFare.toStringAsFixed(0)}. '
                'Actual fare starts updating after Start Trip.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.schedule_rounded,
              label: 'Request',
              value: 'Ride now',
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final String photoUrl = driver.photoUrl.trim();

    if (photoUrl.isEmpty) {
      return const CircleAvatar(
        radius: 30,
        child: Icon(
          Icons.person_rounded,
          size: 32,
        ),
      );
    }

    return CircleAvatar(
      radius: 30,
      backgroundImage: NetworkImage(photoUrl),
      onBackgroundImageError: (
        Object error,
        StackTrace? stackTrace,
      ) {},
    );
  }

  Widget _locationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniInfo(
    IconData icon,
    String text,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 15,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
