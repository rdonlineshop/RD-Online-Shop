import 'package:flutter/material.dart';

import 'order_data.dart';
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
        destinationLatitude:
            widget.destinationLatitude,
        destinationLongitude:
            widget.destinationLongitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sentRequestId = requestId;
      });

      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 44,
            ),
            title: const Text(
              'Ride Request Sent',
            ),
            content: Text(
              'Your ride request was sent to ${driver.name}.\n\nRequest ID: $requestId',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
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
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSending ||
                            _sentRequestId != null
                        ? null
                        : _sendRideRequest,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _sentRequestId != null
                                ? Icons.check_circle_rounded
                                : Icons.send_rounded,
                          ),
                    label: Text(
                      _isSending
                          ? 'Sending...'
                          : _sentRequestId != null
                              ? 'Ride Request Sent'
                              : 'Send Ride Request',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
              icon: Icons.payments_outlined,
              label: 'Fare',
              value: 'Calculated next',
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
