import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ride_chat_page.dart';
import 'services/ride_request_service.dart';
import 'services/ride_sos_service.dart';

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
                        context: context,
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
    required BuildContext context,
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
    final String driverPhone =
        request['driverPhone']?.toString().trim().isNotEmpty == true
            ? request['driverPhone'].toString().trim()
            : driver['phone']?.toString().trim() ?? '';
    final String customerName =
        request['customerName']?.toString().trim().isNotEmpty == true
            ? request['customerName'].toString().trim()
            : 'Customer';

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
            _fareCard(request, status),
            if (status == 'completed') ...<Widget>[
              const SizedBox(height: 14),
              _driverRatingCard(
                context: context,
                request: request,
                driverName: driverName,
              ),
            ],
            if (status == 'pending' ||
                status == 'accepted' ||
                status == 'arrived') ...<Widget>[
              const SizedBox(height: 14),
              _customerCancellationCard(
                context: context,
                request: request,
              ),
            ],
            if (status == 'cancelled') ...<Widget>[
              const SizedBox(height: 14),
              _cancellationInfoCard(request),
            ],
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
            if (status == 'accepted' ||
                status == 'arrived' ||
                status == 'in_progress') ...<Widget>[
              const SizedBox(height: 14),
              _communicationCard(
                context: context,
                driverName: driverName,
                driverPhone: driverPhone,
                customerName: customerName,
              ),
              const SizedBox(height: 14),
              _customerSosCard(
                context: context,
                request: request,
              ),
            ],
            if ((status == 'accepted' || status == 'arrived') &&
                request['tripStartOtpRequired'] == true) ...<Widget>[
              const SizedBox(height: 14),
              _tripStartOtpCard(),
            ],
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



  int? _toRating(dynamic value) {
    final int? rating = value is num
        ? value.round()
        : int.tryParse(value?.toString().trim() ?? '');

    if (rating == null || rating < 1 || rating > 5) {
      return null;
    }

    return rating;
  }

  Widget _driverRatingCard({
    required BuildContext context,
    required Map<String, dynamic> request,
    required String driverName,
  }) {
    final int? savedRating = _toRating(request['driverRating']);
    final String savedReview =
        request['driverReview']?.toString().trim() ?? '';
    final bool alreadyRated = savedRating != null;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alreadyRated
                        ? 'Your Driver Rating'
                        : 'Rate Your Driver',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alreadyRated
                  ? 'Thank you for rating $driverName.'
                  : 'How was your ride with $driverName?',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                5,
                (int index) => Icon(
                  index < (savedRating ?? 0)
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 34,
                ),
              ),
            ),
            if (alreadyRated)
              _DriverRatingPublicSync(
                rideRequestId: rideRequestId.trim(),
                driverId: driverId.trim(),
                rating: savedRating,
              ),
            if (alreadyRated && savedReview.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  savedReview,
                  style: const TextStyle(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (!alreadyRated) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _showDriverRatingDialog(
                  context: context,
                  driverName: driverName,
                ),
                icon: const Icon(Icons.star_rate_rounded),
                label: const Text(
                  'Rate Driver',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'You can submit one rating after the trip is completed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDriverRatingDialog({
    required BuildContext context,
    required String driverName,
  }) async {
    int selectedRating = 0;
    bool isSubmitting = false;
    final TextEditingController reviewController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (
              BuildContext dialogContext,
              StateSetter setDialogState,
            ) {
              Future<void> submitRating() async {
                if (isSubmitting || selectedRating < 1) {
                  return;
                }

                final String review = reviewController.text.trim();
                if (review.length > 500) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Review can be up to 500 characters.',
                      ),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isSubmitting = true;
                });

                try {
                  final String cleanRideId = rideRequestId.trim();
                  final DocumentReference<Map<String, dynamic>> rideRef =
                      FirebaseFirestore.instance
                          .collection('ride_requests')
                          .doc(cleanRideId);
                  final DocumentReference<Map<String, dynamic>> publicRatingRef =
                      FirebaseFirestore.instance
                          .collection('ride_driver_ratings')
                          .doc(cleanRideId);

                  await FirebaseFirestore.instance.runTransaction(
                    (Transaction transaction) async {
                      final DocumentSnapshot<Map<String, dynamic>> snapshot =
                          await transaction.get(rideRef);
                      final Map<String, dynamic>? data = snapshot.data();

                      if (!snapshot.exists || data == null) {
                        throw StateError('Ride not found.');
                      }

                      final String status =
                          data['status']?.toString().trim().toLowerCase() ?? '';
                      if (status != 'completed') {
                        throw StateError(
                          'The trip must be completed before rating the driver.',
                        );
                      }

                      if (_toRating(data['driverRating']) != null) {
                        throw StateError(
                          'A rating has already been submitted for this ride.',
                        );
                      }

                      final String sourceDriverId =
                          data['driverId']?.toString().trim() ?? '';
                      if (sourceDriverId.isEmpty) {
                        throw StateError('Driver information is missing.');
                      }

                      transaction.update(
                        rideRef,
                        <String, dynamic>{
                          'driverRating': selectedRating,
                          'driverReview': review,
                          'driverRatedAt': FieldValue.serverTimestamp(),
                          'driverRatingVersion': 1,
                          'updatedAt': FieldValue.serverTimestamp(),
                        },
                      );

                      transaction.set(
                        publicRatingRef,
                        <String, dynamic>{
                          'rideRequestId': cleanRideId,
                          'driverId': sourceDriverId,
                          'rating': selectedRating,
                          'createdAt': FieldValue.serverTimestamp(),
                          'ratingVersion': 1,
                        },
                      );
                    },
                  );

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);

                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you. Your driver rating was saved.'),
                    ),
                  );
                } catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  setDialogState(() {
                    isSubmitting = false;
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not save rating: $error'),
                      ),
                    );
                  }
                }
              }

              return AlertDialog(
                title: Text('Rate $driverName'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Tap the stars to rate your completed ride.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          5,
                          (int index) {
                            final int value = index + 1;
                            return IconButton(
                              tooltip: '$value star${value == 1 ? '' : 's'}',
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        selectedRating = value;
                                      });
                                    },
                              icon: Icon(
                                value <= selectedRating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 36,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: reviewController,
                        enabled: !isSubmitting,
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Review (optional)',
                          hintText: 'Write about your ride experience...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Not Now'),
                  ),
                  FilledButton.icon(
                    onPressed: isSubmitting || selectedRating < 1
                        ? null
                        : submitRating,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.star_rounded),
                    label: Text(
                      isSubmitting ? 'Submitting...' : 'Submit Rating',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      reviewController.dispose();
    }
  }

  Widget _customerSosCard({
    required BuildContext context,
    required Map<String, dynamic> request,
  }) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  child: Icon(
                    Icons.sos_rounded,
                    color: Colors.red,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Emergency Safety',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Use SOS only for a real safety, accident or medical emergency. '
              'The ride stays active unless it is separately cancelled or completed.',
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _sendCustomerSos(
                context: context,
                request: request,
              ),
              icon: const Icon(Icons.sos_rounded),
              label: const Text(
                'SOS / Emergency',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Position?> _tryGetEmergencyPosition() async {
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

       return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendCustomerSos({
    required BuildContext context,
    required Map<String, dynamic> request,
  }) async {
    final List<String> reasons = <String>[
      'Accident',
      'Medical emergency',
      'Safety threat',
      'Driver or passenger conflict',
      'Unsafe location or route',
      'Other emergency',
    ];

    String selectedReason = reasons.first;

    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext dialogContext,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              title: const Row(
                children: <Widget>[
                  Icon(Icons.sos_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text('Send SOS Alert?')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'This sends an emergency record to RD Admin with this ride '
                    'and your best available GPS location.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Emergency reason',
                      border: OutlineInputBorder(),
                    ),
                    items: reasons
                        .map(
                          (String item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedReason = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      Navigator.pop(dialogContext, selectedReason),
                  icon: const Icon(Icons.sos_rounded),
                  label: const Text('Send SOS'),
                ),
              ],
            );
          },
        );
      },
    );

    if (reason == null || !context.mounted) {
      return;
    }

    final String authUid =
        FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (authUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer login is required for SOS.')),
      );
      return;
    }

    final Position? position = await _tryGetEmergencyPosition();

    final double? fallbackLat = _toDouble(request['pickupLatitude']);
    final double? fallbackLng = _toDouble(request['pickupLongitude']);

    final double? latitude = position?.latitude ?? fallbackLat;
    final double? longitude = position?.longitude ?? fallbackLng;
    final String locationAddress = position != null
        ? 'Current customer GPS'
        : 'Pickup location fallback — live customer GPS unavailable';

    try {
      await RideSosService().createAlert(
        ride: request,
        triggeredBy: 'customer',
        triggeredByUid: authUid,
        reason: reason,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SOS sent to RD Admin. If there is immediate danger, contact local emergency services.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send SOS: $error')),
      );
    }
  }


  Widget _communicationCard({
    required BuildContext context,
    required String driverName,
    required String driverPhone,
    required String customerName,
  }) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Contact Driver',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: driverPhone.isEmpty
                        ? null
                        : () => _callPhone(context, driverPhone),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call Driver'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RideChatPage(
                            rideRequestId: rideRequestId,
                            senderRole: 'customer',
                            senderName: customerName,
                            otherPartyName: driverName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Chat'),
                  ),
                ),
              ],
            ),
            if (driverPhone.isEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'Driver phone number is not available for this ride. In-app chat still works.',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tripStartOtpCard() {
    final String cleanRideId = rideRequestId.trim();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(cleanRideId)
          .collection('private')
          .doc('customer')
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.hasError) {
          return Card(
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Trip Start OTP is temporarily unavailable: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final String otp =
            snapshot.data?.data()?['tripStartOtp']?.toString().trim() ?? '';

        return Card(
          elevation: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: Color(0xFFFFF3E0),
                      child: Icon(
                        Icons.password_rounded,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Trip Start OTP',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  otp.isEmpty ? 'Loading OTP...' : otp,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tell this 6-digit OTP to the driver only when you are ready to start the trip. The driver cannot start the new ride without entering it.',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _customerCancellationCard({
    required BuildContext context,
    required Map<String, dynamic> request,
  }) {
    final String status =
        request['status']?.toString().trim().toLowerCase() ?? 'pending';
    final double fee = (status == 'accepted' || status == 'arrived')
        ? (_toDouble(request['fareBaseFare']) ?? 0.0)
        : 0.0;
    final String currency =
        request['currency']?.toString().trim().isNotEmpty == true
            ? request['currency'].toString().trim()
            : 'Rs.';

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Need to cancel?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              fee > 0
                  ? '${status == 'arrived' ? 'The driver has arrived at pickup. ' : 'The driver has already accepted. '}'
                      'Cancellation fee: $currency ${fee.toStringAsFixed(0)}.'
                  : 'You can cancel before the trip starts.',
              style: const TextStyle(
                color: Colors.blueGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showCustomerCancellationDialog(
                context: context,
                request: request,
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text(
                'Cancel Ride',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerCancellationDialog({
    required BuildContext context,
    required Map<String, dynamic> request,
  }) async {
    final List<String> reasons = <String>[
      'Driver is taking too long',
      'Changed my plans',
      'Booked by mistake',
      'Pickup or destination changed',
      'Found another ride',
      'Other',
    ];

    String selectedReason = reasons.first;
    bool isSubmitting = false;
    final String status =
        request['status']?.toString().trim().toLowerCase() ?? 'pending';
    final double fee = (status == 'accepted' || status == 'arrived')
        ? (_toDouble(request['fareBaseFare']) ?? 0.0)
        : 0.0;
    final String currency =
        request['currency']?.toString().trim().isNotEmpty == true
            ? request['currency'].toString().trim()
            : 'Rs.';

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext dialogContext,
            StateSetter setDialogState,
          ) {
            Future<void> submit() async {
              if (isSubmitting) {
                return;
              }

              setDialogState(() {
                isSubmitting = true;
              });

              try {
                final RideCancellationResult result =
                    await RideRequestService().cancelCustomerRide(
                  rideRequestId: rideRequestId,
                  reason: selectedReason,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.fee > 0
                          ? 'Ride cancelled. Cancellation fee: '
                              '${result.currency} ${result.fee.toStringAsFixed(0)}.'
                          : 'Ride cancelled. No cancellation fee.',
                    ),
                  ),
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSubmitting = false;
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not cancel ride: $error'),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Cancel Ride?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    fee > 0
                        ? 'Cancellation fee: '
                            '$currency ${fee.toStringAsFixed(0)}.'
                        : 'No cancellation fee applies.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cancellation reason',
                      border: OutlineInputBorder(),
                    ),
                    items: reasons
                        .map(
                          (String item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (String? value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedReason = value;
                              });
                            }
                          },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Keep Ride'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting ? null : submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    isSubmitting ? 'Cancelling...' : 'Cancel Ride',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _cancellationInfoCard(
    Map<String, dynamic> request,
  ) {
    final String cancelledBy =
        request['cancelledBy']?.toString().trim() ?? '';
    final String reason =
        request['cancellationReason']?.toString().trim() ?? '';
    final double fee = _toDouble(request['cancellationFee']) ?? 0.0;
    final String currency =
        request['cancellationCurrency']?.toString().trim().isNotEmpty == true
            ? request['cancellationCurrency'].toString().trim()
            : (request['currency']?.toString().trim().isNotEmpty == true
                ? request['currency'].toString().trim()
                : 'Rs.');

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Cancellation Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            _locationRow(
              icon: Icons.person_outline_rounded,
              label: 'Cancelled by',
              value: cancelledBy.isEmpty ? 'Not available' : cancelledBy,
            ),
            const Divider(height: 22),
            _locationRow(
              icon: Icons.notes_rounded,
              label: 'Reason',
              value: reason.isEmpty ? 'Not available' : reason,
            ),
            const Divider(height: 22),
            _locationRow(
              icon: Icons.payments_outlined,
              label: 'Cancellation Fee',
              value: fee > 0
                  ? '$currency ${fee.toStringAsFixed(0)}'
                  : '$currency 0',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callPhone(
    BuildContext context,
    String phone,
  ) async {
    final String cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) {
      return;
    }

    try {
      final bool opened = await launchUrl(
        Uri(scheme: 'tel', path: cleanPhone),
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone app is available on this device.'),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open phone call: $error')),
      );
    }
  }

  Widget _fareCard(
    Map<String, dynamic> request,
    String status,
  ) {
    final String currency =
        request['currency']?.toString().trim().isNotEmpty == true
            ? request['currency'].toString().trim()
            : 'Rs.';

    final double? estimatedFare = _toDouble(request['estimatedFare']);
    final double? liveFare = _toDouble(request['liveFare']);
    final double? finalFare = _toDouble(request['finalFare']);
    final double? routeDistanceKm =
        _toDouble(request['routeDistanceKm']);
    final double? actualDistanceKm =
        _toDouble(request['actualDistanceKm']);
    final double? finalDistanceKm =
        _toDouble(request['finalDistanceKm']);
    final double? baseFare = _toDouble(request['fareBaseFare']);
    final double? perKm = _toDouble(request['farePerKm']);
    final double? minimumFare =
        _toDouble(request['fareMinimumFare']);

    final bool inProgress =
        status == 'in_progress' || status == 'started';
    final bool completed = status == 'completed';

    final String mainLabel = completed
        ? 'Final Fare'
        : inProgress
            ? 'Live Fare'
            : 'Estimated Fare';
    final double? mainFare = completed
        ? (finalFare ?? liveFare ?? estimatedFare)
        : inProgress
            ? (liveFare ?? estimatedFare)
            : estimatedFare;
    final double? shownDistance = completed
        ? (finalDistanceKm ?? actualDistanceKm ?? routeDistanceKm)
        : inProgress
            ? actualDistanceKm
            : routeDistanceKm;
    final String distanceLabel = completed
        ? 'Final Distance'
        : inProgress
            ? 'Actual Distance • LIVE'
            : 'Estimated Distance';

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: (inProgress ? Colors.blue : Colors.green)
                      .withValues(alpha: 0.12),
                  child: Icon(
                    Icons.payments_rounded,
                    color: inProgress ? Colors.blue : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        mainLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (inProgress)
                        const Text(
                          'Updates automatically from the driver GPS.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey,
                          ),
                        ),
                    ],
                  ),
                ),
                if (inProgress)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mainFare == null
                  ? 'Fare is not available yet.'
                  : '$currency ${mainFare.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (shownDistance != null) ...<Widget>[
              const SizedBox(height: 12),
              _locationRow(
                icon: Icons.route_rounded,
                label: distanceLabel,
                value: '${shownDistance.toStringAsFixed(2)} km',
              ),
            ],
            if (baseFare != null &&
                perKm != null &&
                minimumFare != null) ...<Widget>[
              const Divider(height: 24),
              _locationRow(
                icon: Icons.calculate_outlined,
                label: 'Fare Formula',
                value:
                    '$currency ${baseFare.toStringAsFixed(0)} + '
                    '$currency ${perKm.toStringAsFixed(0)}/km '
                    '(minimum $currency ${minimumFare.toStringAsFixed(0)})',
              ),
            ],
            if (!inProgress && !completed) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                "Actual distance and live fare start from 0 km when the driver presses Start Trip. The driver's travel to pickup is not charged.",
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.blueGrey,
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
            'Your driver accepted the ride and is heading to the pickup.';
        break;
      case 'arrived':
        icon = Icons.location_on_rounded;
        color = Colors.deepOrange;
        title = 'Driver Arrived at Pickup';
        message =
            'Your driver has arrived. Please meet the driver and keep your Trip Start OTP ready.';
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


class _DriverRatingPublicSync extends StatefulWidget {
  const _DriverRatingPublicSync({
    required this.rideRequestId,
    required this.driverId,
    required this.rating,
  });

  final String rideRequestId;
  final String driverId;
  final int rating;

  @override
  State<_DriverRatingPublicSync> createState() =>
      _DriverRatingPublicSyncState();
}

class _DriverRatingPublicSyncState extends State<_DriverRatingPublicSync> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    final String rideId = widget.rideRequestId.trim();
    final String driverId = widget.driverId.trim();
    if (rideId.isEmpty || driverId.isEmpty) {
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>> ref =
          FirebaseFirestore.instance
              .collection('ride_driver_ratings')
              .doc(rideId);
      final DocumentSnapshot<Map<String, dynamic>> existing = await ref.get();
      if (existing.exists) {
        return;
      }

      await ref.set(
        <String, dynamic>{
          'rideRequestId': rideId,
          'driverId': driverId,
          'rating': widget.rating,
          'createdAt': FieldValue.serverTimestamp(),
          'ratingVersion': 1,
        },
      );
    } catch (_) {
      // This is only a backward-compatible sync for ratings saved before the
      // public rating index existed. The source ride rating remains intact.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
