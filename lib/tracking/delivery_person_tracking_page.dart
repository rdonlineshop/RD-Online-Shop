import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../order_data.dart';

class DeliveryPersonTrackingPage
    extends StatefulWidget {
  final String orderId;
  final String driverName;
  final String driverPhone;

  const DeliveryPersonTrackingPage({
    super.key,
    required this.orderId,
    required this.driverName,
    required this.driverPhone,
  });

  @override
  State<DeliveryPersonTrackingPage>
      createState() =>
          _DeliveryPersonTrackingPageState();
}

class _DeliveryPersonTrackingPageState
    extends State<DeliveryPersonTrackingPage> {
  StreamSubscription<Position>?
      _positionSubscription;

  bool _isTracking = false;
  bool _isLoading = false;

  double? _latitude;
  double? _longitude;

  String _statusText =
      'Live tracking has not started.';

  String _lastUpdated = '';

  // =========================================================
  // SHOW MESSAGE
  // =========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================================================
  // LOCATION PERMISSION
  // =========================================================

  Future<bool> _checkPermission() async {
    final bool serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showMessage(
        'Please turn on GPS / Location.',
      );

      return false;
    }

    LocationPermission permission =
        await Geolocator
            .checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator
              .requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      _showMessage(
        'Location permission denied.',
      );

      return false;
    }

    if (permission ==
        LocationPermission
            .deniedForever) {
      _showMessage(
        'Location permission permanently denied. Please enable it from Settings.',
      );

      return false;
    }

    return true;
  }

  // =========================================================
  // SAVE LOCATION
  // =========================================================

  Future<void> _saveDriverLocation(
    Position position,
  ) async {
    final String orderId =
        widget.orderId.trim();

    if (orderId.isEmpty) {
      return;
    }

    final double latitude =
        position.latitude;

    final double longitude =
        position.longitude;

    await updateDriverLocation(
      orderId: orderId,
      latitude: latitude,
      longitude: longitude,
      driverName:
          widget.driverName.trim(),
      driverPhone:
          widget.driverPhone.trim(),
    );

    await updateTrackingStatus(
      orderId,
      'Out for Delivery',
    );

    if (!mounted) {
      return;
    }

    final DateTime now =
        DateTime.now();

    String two(
      int value,
    ) {
      return value
          .toString()
          .padLeft(
            2,
            '0',
          );
    }

    setState(() {
      _latitude = latitude;
      _longitude = longitude;

      _statusText =
          'Live location is being shared.';

      _lastUpdated =
          '${two(now.day)}/'
          '${two(now.month)}/'
          '${now.year} '
          '${two(now.hour)}:'
          '${two(now.minute)}:'
          '${two(now.second)}';
    });
  }

  // =========================================================
  // START TRACKING
  // =========================================================

  Future<void> _startTracking() async {
    if (_isTracking ||
        _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final bool allowed =
        await _checkPermission();

    if (!allowed) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      final Position firstPosition =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      await _saveDriverLocation(
        firstPosition,
      );

      const LocationSettings
          locationSettings =
          LocationSettings(
        accuracy:
            LocationAccuracy.high,
        distanceFilter: 5,
      );

      await _positionSubscription
          ?.cancel();

      _positionSubscription =
          Geolocator
              .getPositionStream(
        locationSettings:
            locationSettings,
      ).listen(
        (
          Position position,
        ) async {
          try {
            await _saveDriverLocation(
              position,
            );
          } catch (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _statusText =
                  'Could not update live location.';
            });
          }
        },
        onError: (
          Object error,
        ) {
          if (!mounted) {
            return;
          }

          setState(() {
            _statusText =
                'Location tracking error.';
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isTracking = true;
        _isLoading = false;

        _statusText =
            'Live location is being shared.';
      });

      _showMessage(
        'Live delivery tracking started.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _statusText =
            'Could not start live tracking.';
      });

      _showMessage(
        'Could not start live tracking.',
      );
    }
  }

  // =========================================================
  // STOP TRACKING
  // =========================================================

  Future<void> _stopTracking() async {
    await _positionSubscription
        ?.cancel();

    _positionSubscription = null;

    if (widget.orderId
        .trim()
        .isNotEmpty) {
      await updateTrackingStatus(
        widget.orderId,
        'Delivery Tracking Stopped',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isTracking = false;

      _statusText =
          'Live tracking stopped.';
    });

    _showMessage(
      'Live delivery tracking stopped.',
    );
  }

  // =========================================================
  // MARK DELIVERED
  // =========================================================

  Future<void> _markDelivered() async {
    final String orderId =
        widget.orderId.trim();

    if (orderId.isEmpty) {
      return;
    }

    final bool? confirm =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text(
            'Mark as Delivered',
          ),
          content:
              const Text(
            'Has this order been delivered to the customer?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon:
                  const Icon(
                Icons.check_circle,
              ),
              label:
                  const Text(
                'Delivered',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _positionSubscription
        ?.cancel();

    _positionSubscription = null;

    await updateOrderStatus(
      orderId,
      'Delivered',
    );

    await updateTrackingStatus(
      orderId,
      'Delivered',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isTracking = false;

      _statusText =
          'Order delivered.';
    });

    _showMessage(
      'Order marked as delivered.',
    );
  }

  // =========================================================
  // LOCATION CARD
  // =========================================================

  Widget _locationCard() {
    final bool hasLocation =
        _latitude != null &&
            _longitude != null;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                CircleAvatar(
                  child: Icon(
                    Icons.local_shipping,
                  ),
                ),
                SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Text(
                    'Delivery Person Live GPS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              'Order ID: ${widget.orderId}',
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              'Delivery Person: ${widget.driverName}',
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              'Phone: ${widget.driverPhone}',
            ),

            const Divider(
              height: 28,
            ),

            Row(
              children: <Widget>[
                Icon(
                  _isTracking
                      ? Icons.gps_fixed
                      : Icons.gps_off,
                  color:
                      _isTracking
                          ? Colors.green
                          : Colors.orange,
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color:
                          _isTracking
                              ? Colors.green
                              : Colors
                                  .blueGrey,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (hasLocation)
              ...<Widget>[
                const SizedBox(
                  height: 14,
                ),

                Text(
                  'Latitude: '
                  '${_latitude!.toStringAsFixed(6)}',
                ),

                Text(
                  'Longitude: '
                  '${_longitude!.toStringAsFixed(6)}',
                ),

                if (_lastUpdated
                    .isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 5,
                    ),
                    child: Text(
                      'Last updated: $_lastUpdated',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey
                                .shade700,
                      ),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: !_isTracking,
      onPopInvokedWithResult: (
        bool didPop,
        dynamic result,
      ) {
        if (didPop) {
          return;
        }

        _showMessage(
          'Stop live tracking before leaving this page.',
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Delivery Tracking',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),

        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 700,
            ),
            child:
                ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: <Widget>[
                _locationCard(),

                const SizedBox(
                  height: 16,
                ),

                if (!_isTracking)
                  SizedBox(
                    height: 55,
                    child:
                        FilledButton.icon(
                      onPressed:
                          _isLoading
                              ? null
                              : _startTracking,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .location_searching,
                            ),
                      label: Text(
                        _isLoading
                            ? 'Starting...'
                            : 'Start Live Tracking',
                      ),
                    ),
                  ),

                if (_isTracking)
                  SizedBox(
                    height: 55,
                    child:
                        FilledButton.icon(
                      onPressed:
                          _stopTracking,
                      icon:
                          const Icon(
                        Icons.stop_circle,
                      ),
                      label:
                          const Text(
                        'Stop Live Tracking',
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 12,
                ),

                SizedBox(
                  height: 55,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _markDelivered,
                    icon: const Icon(
                      Icons
                          .check_circle_outline,
                    ),
                    label:
                        const Text(
                      'Mark Order Delivered',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    child:
                        const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: <Widget>[
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          '1. Tap Start Live Tracking.',
                        ),
                        Text(
                          '2. Keep GPS enabled while delivering.',
                        ),
                        Text(
                          '3. The customer Track Order map will receive updated driver location.',
                        ),
                        Text(
                          '4. Stop tracking or mark the order Delivered after delivery.',
                        ),
                      ],
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

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _positionSubscription?.cancel();

    super.dispose();
  }
}