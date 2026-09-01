import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RideCustomerTrackingPage extends StatelessWidget {
  const RideCustomerTrackingPage({
    required this.rideRequestId,
    required this.driverId,
    super.key,
  });

  final String rideRequestId;
  final String driverId;

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cleanRequestId = rideRequestId.trim();
    final String cleanDriverId = driverId.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Track Ride',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: cleanRequestId.isEmpty || cleanDriverId.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Ride tracking information is missing.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : StreamBuilder<
                DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ride_requests')
                    .doc(cleanRequestId)
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<
                          DocumentSnapshot<Map<String, dynamic>>>
                      requestSnapshot,
                ) {
                  if (requestSnapshot.hasError) {
                    return _message(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load ride',
                      message: requestSnapshot.error.toString(),
                    );
                  }

                  if (!requestSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final DocumentSnapshot<Map<String, dynamic>>
                      requestDocument = requestSnapshot.data!;

                  if (!requestDocument.exists) {
                    return _message(
                      icon: Icons.search_off_rounded,
                      title: 'Ride not found',
                      message:
                          'This ride request is no longer available.',
                    );
                  }

                  final Map<String, dynamic> request =
                      requestDocument.data() ??
                          <String, dynamic>{};

                  return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('ride_drivers')
                        .doc(cleanDriverId)
                        .snapshots(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<
                              DocumentSnapshot<
                                  Map<String, dynamic>>>
                          driverSnapshot,
                    ) {
                      final Map<String, dynamic> driver =
                          driverSnapshot.data?.data() ??
                              <String, dynamic>{};

                      return _content(
                        request: request,
                        driver: driver,
                        driverLoadError:
                            driverSnapshot.hasError
                                ? driverSnapshot.error.toString()
                                : null,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _content({
    required Map<String, dynamic> request,
    required Map<String, dynamic> driver,
    required String? driverLoadError,
  }) {
    final String status =
        request['status']?.toString().trim().toLowerCase() ??
            'pending';

    final String driverName =
        request['driverName']?.toString().trim().isNotEmpty == true
            ? request['driverName'].toString().trim()
            : driver['name']?.toString().trim().isNotEmpty == true
                ? driver['name'].toString().trim()
                : 'Ride Driver';

    final String vehicleType =
        request['vehicleType']?.toString().trim() ?? '';
    final String vehicleNumber =
        request['vehicleNumber']?.toString().trim() ?? '';

    final String pickupAddress =
        request['pickupAddress']?.toString().trim() ?? '';
    final String destinationAddress =
        request['destinationAddress']?.toString().trim() ?? '';

    final double? pickupLat =
        _toDouble(request['pickupLatitude']);
    final double? pickupLng =
        _toDouble(request['pickupLongitude']);
    final double? destinationLat =
        _toDouble(request['destinationLatitude']);
    final double? destinationLng =
        _toDouble(request['destinationLongitude']);
    final double? driverLat = _toDouble(
      driver['latitude'] ?? driver['lat'],
    );
    final double? driverLng = _toDouble(
      driver['longitude'] ?? driver['lng'],
    );

    final LatLng? pickup = pickupLat != null && pickupLng != null
        ? LatLng(pickupLat, pickupLng)
        : null;
    final LatLng? destination =
        destinationLat != null && destinationLng != null
            ? LatLng(destinationLat, destinationLng)
            : null;
    final LatLng? driverLocation =
        driverLat != null && driverLng != null
            ? LatLng(driverLat, driverLng)
            : null;

    final List<LatLng> points = <LatLng>[
      if (driverLocation != null) driverLocation,
      if (pickup != null) pickup,
      if (destination != null) destination,
    ];

    final LatLng? mapCenter = points.isNotEmpty ? points.first : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1000,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _statusCard(status),
            const SizedBox(height: 14),
            Card(
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 29,
                      child: Icon(
                        Icons.drive_eta_rounded,
                        size: 31,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            driverName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            <String>[
                              vehicleType,
                              vehicleNumber,
                            ].where((String value) => value.isNotEmpty).join(
                                  ' • ',
                                ),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: driverLocation != null
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        driverLocation != null
                            ? 'GPS READY'
                            : 'GPS WAITING',
                        style: TextStyle(
                          color: driverLocation != null
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 1.5,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 390,
                child: mapCenter == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Map location is not available yet.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: mapCenter,
                          initialZoom: 14,
                          initialCameraFit: points.length > 1
                              ? CameraFit.coordinates(
                                  coordinates: points,
                                  padding: const EdgeInsets.all(55),
                                )
                              : null,
                          minZoom: 2,
                          maxZoom: 19,
                        ),
                        children: <Widget>[
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.rd.onlineshop',
                          ),
                          MarkerLayer(
                            markers: <Marker>[
                              if (pickup != null)
                                Marker(
                                  point: pickup,
                                  width: 48,
                                  height: 48,
                                  child: const _MapPin(
                                    icon: Icons.my_location_rounded,
                                    color: Colors.blue,
                                    tooltip: 'Pickup',
                                  ),
                                ),
                              if (destination != null)
                                Marker(
                                  point: destination,
                                  width: 48,
                                  height: 48,
                                  child: const _MapPin(
                                    icon: Icons.location_on_rounded,
                                    color: Colors.red,
                                    tooltip: 'Destination',
                                  ),
                                ),
                              if (driverLocation != null)
                                Marker(
                                  point: driverLocation,
                                  width: 56,
                                  height: 56,
                                  child: const _MapPin(
                                    icon: Icons.local_taxi_rounded,
                                    color: Colors.green,
                                    tooltip: 'Driver',
                                  ),
                                ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: <SourceAttribution>[
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Trip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
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
            ),
            if (driverLoadError != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Driver live location is temporarily unavailable: $driverLoadError',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12.5,
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              Text(
                driverLocation == null
                    ? 'Waiting for the driver GPS location.'
                    : 'Driver location is connected. The marker will update whenever the driver sends a new GPS position.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String status) {
    IconData icon = Icons.schedule_rounded;
    Color color = Colors.orange;
    String title = 'Waiting for driver';
    String message = 'Your selected driver has not responded yet.';

    switch (status) {
      case 'accepted':
        icon = Icons.check_circle_rounded;
        color = Colors.green;
        title = 'Driver Accepted';
        message =
            'Your driver accepted the ride. Live tracking is ready.';
        break;
      case 'rejected':
        icon = Icons.cancel_rounded;
        color = Colors.red;
        title = 'Ride Request Rejected';
        message = 'Please choose another nearby driver.';
        break;
      case 'started':
      case 'in_progress':
        icon = Icons.route_rounded;
        color = Colors.blue;
        title = 'Trip In Progress';
        message = 'Your ride has started.';
        break;
      case 'completed':
        icon = Icons.flag_circle_rounded;
        color = Colors.green;
        title = 'Trip Completed';
        message = 'Your ride has been completed.';
        break;
      case 'cancelled':
        icon = Icons.cancel_outlined;
        color = Colors.red;
        title = 'Ride Cancelled';
        message = 'This ride was cancelled.';
        break;
    }

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                value.isEmpty ? 'Not available' : value,
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

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 70,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: color,
          size: 30,
        ),
      ),
    );
  }
}
