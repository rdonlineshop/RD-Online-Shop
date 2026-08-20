import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../order_data.dart';

class DeliveryPersonTrackingPage extends StatefulWidget {
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
  State<DeliveryPersonTrackingPage> createState() =>
      _DeliveryPersonTrackingPageState();
}

class _DeliveryPersonTrackingPageState
    extends State<DeliveryPersonTrackingPage> {
  StreamSubscription<Position>? _positionSubscription;

  bool _isTracking = false;
  bool _isLoading = false;
  bool _isVerifyingOtp = false;
  bool _orderDelivered = false;

  double? _latitude;
  double? _longitude;

  String _statusText =
      'Live tracking has not started.';

  String _lastUpdated = '';

  @override
  void initState() {
    super.initState();

    _prepareDeliveryConfirmation();
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================================================
  // PREPARE DELIVERY OTP
  // =========================================================

  Future<void> _prepareDeliveryConfirmation() async {
    final String orderId =
        widget.orderId.trim();

    if (orderId.isEmpty) {
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>>
          orderReference =
          FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId);

      final DocumentSnapshot<Map<String, dynamic>>
          snapshot =
          await orderReference.get();

      if (!snapshot.exists) {
        return;
      }

      final Map<String, dynamic> data =
          snapshot.data() ??
              <String, dynamic>{};

      final String status =
          data['status']
                  ?.toString()
                  .trim() ??
              '';

      final String existingOtp =
          data['deliveryOtp']
                  ?.toString()
                  .trim() ??
              '';

      if (status == 'Delivered') {
        if (!mounted) {
          return;
        }

        setState(() {
          _orderDelivered = true;
          _statusText =
              'Order already delivered.';
        });

        return;
      }

      if (existingOtp.isEmpty) {
        final int otp =
            100000 +
                Random.secure()
                    .nextInt(900000);

        await orderReference.set(
          <String, dynamic>{
            'deliveryOtp':
                otp.toString(),
            'deliveryOtpCreatedAt':
                DateTime.now()
                    .toIso8601String(),
            'deliveryOtpVerified':
                false,
            'deliveryOtpVerifiedAt':
                null,
            'deliveryConfirmationMethod':
                '',
          },
          SetOptions(
            merge: true,
          ),
        );
      }
    } catch (error) {
      // OTP preparation failure should
      // not stop live GPS tracking.
    }
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
        LocationPermission.deniedForever) {
      _showMessage(
        'Location permission permanently denied. '
        'Please enable it from Settings.',
      );

      return false;
    }

    return true;
  }

  // =========================================================
  // SAVE DRIVER LOCATION
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
        _isLoading ||
        _orderDelivered) {
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
    } catch (_) {
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
  // READ CUSTOMER LATITUDE
  // =========================================================

  double? _customerLatitude(
    Map<String, dynamic> order,
  ) {
    final dynamic value =
        order['customerLat'] ??
            order['latitude'];

    if (value is num) {
      return value.toDouble();
    }

    if (value != null) {
      return double.tryParse(
        value.toString(),
      );
    }

    return null;
  }

  // =========================================================
  // READ CUSTOMER LONGITUDE
  // =========================================================

  double? _customerLongitude(
    Map<String, dynamic> order,
  ) {
    final dynamic value =
        order['customerLng'] ??
            order['longitude'];

    if (value is num) {
      return value.toDouble();
    }

    if (value != null) {
      return double.tryParse(
        value.toString(),
      );
    }

    return null;
  }

  // =========================================================
  // CHECK DRIVER IS NEAR CUSTOMER
  //
  // 250 meters limit for delivery confirmation.
  // =========================================================

  Future<bool> _checkCustomerProximity(
    Map<String, dynamic> order,
  ) async {
    final double? customerLat =
        _customerLatitude(order);

    final double? customerLng =
        _customerLongitude(order);

    if (customerLat == null ||
        customerLng == null) {
      _showMessage(
        'Customer GPS location is not available.',
      );

      return false;
    }

    double? driverLat =
        _latitude;

    double? driverLng =
        _longitude;

    if (driverLat == null ||
        driverLng == null) {
      final bool permission =
          await _checkPermission();

      if (!permission) {
        return false;
      }

      try {
        final Position position =
            await Geolocator
                .getCurrentPosition(
          locationSettings:
              const LocationSettings(
            accuracy:
                LocationAccuracy.high,
          ),
        );

        driverLat =
            position.latitude;

        driverLng =
            position.longitude;

        await _saveDriverLocation(
          position,
        );
      } catch (_) {
        _showMessage(
          'Could not get your current GPS location.',
        );

        return false;
      }
    }

    final double distanceMeters =
        Geolocator.distanceBetween(
      driverLat,
      driverLng,
      customerLat,
      customerLng,
    );

    if (distanceMeters > 250) {
      _showMessage(
        'You are still about '
        '${distanceMeters.round()} meters '
        'away from the customer. '
        'Delivery can only be confirmed near the customer.',
      );

      return false;
    }

    return true;
  }

  // =========================================================
  // DELIVERY OTP DIALOG
  // =========================================================

  Future<String?> _askForOtp() async {
    final TextEditingController controller =
        TextEditingController();

    final String? result =
        await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Customer Delivery OTP',
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Ask the customer for the 6-digit '
                'Delivery OTP shown in their My Orders page.',
              ),

              const SizedBox(
                height: 16,
              ),

              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    TextInputType.number,
                maxLength: 6,
                decoration:
                    const InputDecoration(
                  labelText:
                      '6-digit OTP',
                  hintText:
                      '123456',
                  prefixIcon:
                      Icon(
                    Icons.password,
                  ),
                  border:
                      OutlineInputBorder(),
                  counterText:
                      '',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),

            FilledButton.icon(
              onPressed: () {
                final String otp =
                    controller.text.trim();

                if (otp.length != 6 ||
                    int.tryParse(otp) ==
                        null) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  otp,
                );
              },
              icon: const Icon(
                Icons.verified,
              ),
              label: const Text(
                'Verify',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  // =========================================================
  // CUSTOMER QR SCANNER
  // =========================================================

  Future<void> _scanQrAndDeliver() async {
    if (_isVerifyingOtp ||
        _orderDelivered) {
      return;
    }

    final String? scannedOtp =
        await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (
          BuildContext context,
        ) {
          return const _DeliveryQrScannerPage();
        },
      ),
    );

    if (!mounted ||
        scannedOtp == null ||
        scannedOtp.trim().isEmpty) {
      return;
    }

    await _verifyOtpAndDeliver(
      scannedOtp: scannedOtp.trim(),
    );
  }

  // =========================================================
  // VERIFY OTP AND MARK DELIVERED
  // =========================================================

  Future<void> _verifyOtpAndDeliver({
    String? scannedOtp,
  }) async {
    if (_isVerifyingOtp ||
        _orderDelivered) {
      return;
    }

    final String orderId =
        widget.orderId.trim();

    if (orderId.isEmpty) {
      _showMessage(
        'Order ID is missing.',
      );

      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>>
          orderReference =
          FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId);

      final DocumentSnapshot<Map<String, dynamic>>
          snapshot =
          await orderReference.get();

      if (!snapshot.exists) {
        _showMessage(
          'Order was not found.',
        );

        return;
      }

      final Map<String, dynamic> order =
          snapshot.data() ??
              <String, dynamic>{};

      final String status =
          order['status']
                  ?.toString()
                  .trim() ??
              '';

      if (status == 'Delivered') {
        if (mounted) {
          setState(() {
            _orderDelivered = true;
          });
        }

        _showMessage(
          'This order is already delivered.',
        );

        return;
      }

      // =====================================================
      // DRIVER ID SECURITY CHECK
      // =====================================================

      final String savedDriverId =
          order['driverId']
                  ?.toString()
                  .trim() ??
              '';

      final String currentDriverId =
          FirebaseAuth
                  .instance
                  .currentUser
                  ?.uid ??
              '';

      if (savedDriverId.isNotEmpty &&
          currentDriverId.isNotEmpty &&
          savedDriverId !=
              currentDriverId) {
        _showMessage(
          'This order is assigned to another delivery person.',
        );

        return;
      }

      // =====================================================
      // DRIVER MUST BE NEAR CUSTOMER
      // =====================================================

      final bool nearCustomer =
          await _checkCustomerProximity(
        order,
      );

      if (!nearCustomer) {
        return;
      }

      // =====================================================
      // ASK CUSTOMER OTP
      // =====================================================

      final String? enteredOtp =
          scannedOtp ??
              await _askForOtp();

      if (enteredOtp == null) {
        return;
      }

      final DocumentSnapshot<
              Map<String, dynamic>>
          latestSnapshot =
          await orderReference.get();

      final Map<String, dynamic>
          latestOrder =
          latestSnapshot.data() ??
              <String, dynamic>{};

      final String savedOtp =
          latestOrder['deliveryOtp']
                  ?.toString()
                  .trim() ??
              '';

      if (savedOtp.isEmpty) {
        _showMessage(
          'Delivery OTP has not been generated.',
        );

        await _prepareDeliveryConfirmation();

        return;
      }

      if (enteredOtp !=
          savedOtp) {
        _showMessage(
          'Incorrect Delivery OTP.',
        );

        return;
      }

      // =====================================================
      // OTP CORRECT
      // =====================================================

      await _positionSubscription
          ?.cancel();

      _positionSubscription =
          null;

      final String now =
          DateTime.now()
              .toIso8601String();

      await orderReference.set(
        <String, dynamic>{
          'status':
              'Delivered',

          'trackingStatus':
              'Delivered',

          'deliveryOtpVerified':
              true,

          'deliveryOtpVerifiedAt':
              now,

          'deliveryConfirmationMethod':
              scannedOtp == null
                  ? 'OTP'
                  : 'QR',

          'deliveredAt':
              now,

          'deliveredByDriverId':
              currentDriverId,

          'deliveredByDriverName':
              widget.driverName.trim(),

          'deliveredByDriverPhone':
              widget.driverPhone.trim(),

          'deliveryConfirmedLat':
              _latitude,

          'deliveryConfirmedLng':
              _longitude,

          // Remove OTP after successful verification.
          'deliveryOtp':
              FieldValue.delete(),
        },
        SetOptions(
          merge: true,
        ),
      );

      // Keep local/order-data system synced too.
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

        _orderDelivered = true;

        _statusText =
            'Delivery confirmed successfully.';
      });

      await showDialog<void>(
        context: context,
        builder: (
          BuildContext dialogContext,
        ) {
          return AlertDialog(
            icon: const Icon(
              Icons.verified,
              color:
                  Colors.green,
              size: 50,
            ),
            title: const Text(
              'Delivery Confirmed',
            ),
            content: const Text(
              'Customer delivery verification succeeded. '
              'This order is now marked as Delivered.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );
    } catch (error) {
      _showMessage(
        'Could not confirm delivery: '
        '${error.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp =
              false;
        });
      }
    }
  }

  // =========================================================
  // LOCATION CARD
  // =========================================================

  Widget _locationCard() {
    final double? latitude =
        _latitude;

    final double? longitude =
        _longitude;

    final bool hasLocation =
        latitude != null &&
            longitude != null;

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
                  _orderDelivered
                      ? Icons.verified
                      : _isTracking
                          ? Icons.gps_fixed
                          : Icons.gps_off,
                  color:
                      _orderDelivered
                          ? Colors.green
                          : _isTracking
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
                          _orderDelivered ||
                                  _isTracking
                              ? Colors.green
                              : Colors.blueGrey,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (hasLocation) ...<Widget>[
              const SizedBox(
                height: 14,
              ),

              Text(
                'Latitude: '
                '${latitude.toStringAsFixed(6)}',
              ),

              Text(
                'Longitude: '
                '${longitude.toStringAsFixed(6)}',
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
  // OTP INFORMATION CARD
  // =========================================================

  Widget _otpInfoCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.security,
                  color:
                      Colors.green,
                ),

                SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: Text(
                    'Secure Delivery Confirmation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'The order cannot be marked Delivered '
              'without the customer\'s 6-digit Delivery OTP.',
            ),

            const SizedBox(
              height: 7,
            ),

            const Text(
              'The delivery person must also be near '
              'the customer GPS location.',
              style: TextStyle(
                color:
                    Colors.blueGrey,
              ),
            ),
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
      canPop:
          !_isTracking,
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

            child: ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: <Widget>[
                _locationCard(),

                const SizedBox(
                  height: 16,
                ),

                if (!_orderDelivered &&
                    !_isTracking)
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

                if (!_orderDelivered &&
                    _isTracking)
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
                  child: FilledButton.icon(
                    onPressed:
                        _orderDelivered ||
                                _isVerifyingOtp
                            ? null
                            : _scanQrAndDeliver,
                    icon: const Icon(
                      Icons.qr_code_scanner,
                    ),
                    label: const Text(
                      'Scan Customer QR',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // =================================================
                // OLD DIRECT DELIVERED BUTTON REMOVED
                // OTP REQUIRED NOW
                // =================================================

                SizedBox(
                  height: 55,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _orderDelivered ||
                                _isVerifyingOtp
                            ? null
                            : () {
                                _verifyOtpAndDeliver();
                              },
                    icon: _isVerifyingOtp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : Icon(
                            _orderDelivered
                                ? Icons.verified
                                : Icons
                                    .password,
                          ),
                    label: Text(
                      _orderDelivered
                          ? 'Order Delivered'
                          : _isVerifyingOtp
                              ? 'Verifying...'
                              : 'Confirm Delivery with OTP',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                _otpInfoCard(),

                const SizedBox(
                  height: 16,
                ),

                const Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: <Widget>[
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        SizedBox(
                          height: 8,
                        ),

                        Text(
                          '1. Start Live Tracking.',
                        ),

                        Text(
                          '2. Travel to the customer delivery location.',
                        ),

                        Text(
                          '3. Ask the customer for their 6-digit Delivery OTP.',
                        ),

                        Text(
                          '4. Tap Confirm Delivery with OTP.',
                        ),

                        Text(
                          '5. Enter the correct customer OTP.',
                        ),

                        Text(
                          '6. Only then will the order become Delivered.',
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
    _positionSubscription
        ?.cancel();

    super.dispose();
  }
}

class _DeliveryQrScannerPage extends StatefulWidget {
  const _DeliveryQrScannerPage();

  @override
  State<_DeliveryQrScannerPage> createState() =>
      _DeliveryQrScannerPageState();
}

class _DeliveryQrScannerPageState
    extends State<_DeliveryQrScannerPage> {
  final MobileScannerController _scannerController =
      MobileScannerController();

  bool _resultReturned = false;

  void _handleDetection(
    BarcodeCapture capture,
  ) {
    if (_resultReturned ||
        capture.barcodes.isEmpty) {
      return;
    }

    final String value =
        capture.barcodes.first.rawValue
                ?.trim() ??
            '';

    if (value.length != 6 ||
        int.tryParse(value) == null) {
      return;
    }

    _resultReturned = true;

    Navigator.of(context).pop<String>(
      value,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan Customer QR',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Torch',
            onPressed: () {
              _scannerController
                  .toggleTorch();
            },
            icon: const Icon(
              Icons.flashlight_on,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Ask the customer to show the Secure Delivery QR, then place it inside the frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
