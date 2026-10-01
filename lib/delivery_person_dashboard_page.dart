import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'tracking/delivery_person_tracking_page.dart';

class DeliveryPersonDashboardPage extends StatefulWidget {
  const DeliveryPersonDashboardPage({
    super.key,
  });

  @override
  State<DeliveryPersonDashboardPage> createState() =>
      _DeliveryPersonDashboardPageState();
}

class _DeliveryPersonDashboardPageState
    extends State<DeliveryPersonDashboardPage> {
  bool _isLoading = true;
  bool _isOnline = false;
  bool _updatingAvailability = false;
  bool _updatingAvailabilityLocation = false;

  Timer? _availabilityLocationTimer;
  double? _currentLatitude;
  double? _currentLongitude;

  String _deliveryPersonName = '';
  String _deliveryPersonPhone = '';
  String _deliveryPersonId = '';

  Map<String, dynamic> _deliveryPersonData =
      <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadDeliveryPerson();

    _availabilityLocationTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (_isOnline) {
          unawaited(
            _refreshAvailabilityLocation(),
          );
        }
      },
    );
  }

  // =========================================================
  // LOAD DELIVERY PERSON
  // =========================================================

  Future<void> _loadDeliveryPerson() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('delivery_persons')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> data =
          doc.data() ?? <String, dynamic>{};

      if (!mounted) {
        return;
      }

      setState(() {
        _deliveryPersonId = user.uid;

        _deliveryPersonName =
            data['name']?.toString().trim() ?? '';

        _deliveryPersonPhone =
            data['phone']?.toString().trim() ?? '';

        _deliveryPersonData =
            Map<String, dynamic>.from(data);

        _isOnline =
            data['isOnline'] == true;

        _isLoading = false;
      });

      await _publishDeliveryPresence(
        online: _isOnline,
      );

      if (_isOnline) {
        await _refreshAvailabilityLocation();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deliveryPersonId = user.uid;
        _isLoading = false;
      });
    }
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
  // SAFE DOUBLE
  // =========================================================

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    final String text =
        value.toString().trim();

    if (text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return double.tryParse(text);
  }

  // =========================================================
  // CUSTOMER NAME
  // =========================================================

  String _customerName(
    Map<String, dynamic> order,
  ) {
    final List<dynamic> names = <dynamic>[
      order['customerName'],
      order['name'],
      order['fullName'],
      order['customer'],
    ];

    for (final dynamic value in names) {
      final String name =
          value?.toString().trim() ?? '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Unknown Customer';
  }

  // =========================================================
  // CUSTOMER PHONE
  // =========================================================

  String _customerPhone(
    Map<String, dynamic> order,
  ) {
    final List<dynamic> phones = <dynamic>[
      order['phone'],
      order['customerPhone'],
      order['mobile'],
    ];

    for (final dynamic value in phones) {
      final String phone =
          value?.toString().trim() ?? '';

      if (phone.isNotEmpty) {
        return phone;
      }
    }

    return '';
  }

  // =========================================================
  // CUSTOMER ADDRESS
  // =========================================================

  String _customerAddress(
    Map<String, dynamic> order,
  ) {
    final List<dynamic> addresses = <dynamic>[
      order['customerAddress'],
      order['address'],
      order['deliveryAddress'],
    ];

    for (final dynamic value in addresses) {
      final String address =
          value?.toString().trim() ?? '';

      if (address.isNotEmpty &&
          address.toLowerCase() != 'null') {
        return address;
      }
    }

    return 'Address not available';
  }

  // =========================================================
  // CUSTOMER LATITUDE
  // =========================================================

  double? _customerLatitude(
    Map<String, dynamic> order,
  ) {
    final double? direct = _toDouble(
      order['customerLat'] ??
          order['latitude'] ??
          order['deliveryLatitude'],
    );

    if (direct != null) {
      return direct;
    }

    final dynamic location =
        order['customerLocation'];

    if (location is GeoPoint) {
      return location.latitude;
    }

    if (location is Map) {
      return _toDouble(
        location['latitude'] ??
            location['lat'],
      );
    }

    return null;
  }

  // =========================================================
  // CUSTOMER LONGITUDE
  // =========================================================

  double? _customerLongitude(
    Map<String, dynamic> order,
  ) {
    final double? direct = _toDouble(
      order['customerLng'] ??
          order['longitude'] ??
          order['deliveryLongitude'],
    );

    if (direct != null) {
      return direct;
    }

    final dynamic location =
        order['customerLocation'];

    if (location is GeoPoint) {
      return location.longitude;
    }

    if (location is Map) {
      return _toDouble(
        location['longitude'] ??
            location['lng'],
      );
    }

    return null;
  }

  // =========================================================
  // SELLER / SHOP ID
  // =========================================================

  String _orderSellerId(
    Map<String, dynamic> order,
  ) {
    final String direct =
        order['pickupSellerId']?.toString().trim() ?? '';

    if (direct.isNotEmpty) {
      return direct;
    }

    final String topSeller =
        order['sellerId']?.toString().trim() ?? '';

    if (topSeller.isNotEmpty) {
      return topSeller;
    }

    final dynamic sellerIds = order['sellerIds'];

    if (sellerIds is List) {
      for (final dynamic value in sellerIds) {
        final String id = value?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          return id;
        }
      }
    }

    final dynamic items = order['items'];

    if (items is List) {
      for (final dynamic item in items) {
        if (item is Map) {
          final String id =
              item['sellerId']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            return id;
          }
        }
      }
    }

    return '';
  }

  // =========================================================
  // SELLER / SHOP LOCATION
  // =========================================================

  Future<Map<String, dynamic>> _sellerShopData(
    Map<String, dynamic> order,
  ) async {
    double? latitude = _toDouble(
      order['pickupSellerLat'] ??
          order['sellerShopLat'] ??
          order['shopLat'],
    );

    double? longitude = _toDouble(
      order['pickupSellerLng'] ??
          order['sellerShopLng'] ??
          order['shopLng'],
    );

    String name =
        order['pickupSellerName']?.toString().trim() ?? '';

    String address =
        order['pickupSellerAddress']?.toString().trim() ?? '';

    if (latitude == null || longitude == null) {
      final dynamic shopLocation = order['pickupSellerLocation'];

      if (shopLocation is GeoPoint) {
        latitude ??= shopLocation.latitude;
        longitude ??= shopLocation.longitude;
      }
    }

    if (latitude != null && longitude != null) {
      return <String, dynamic>{
        'name': name.isEmpty ? 'Seller Shop' : name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
    }

    final String sellerId = _orderSellerId(order);

    if (sellerId.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> sellerSnapshot =
          await FirebaseFirestore.instance
              .collection('sellers')
              .doc(sellerId)
              .get();

      final Map<String, dynamic> seller =
          sellerSnapshot.data() ?? <String, dynamic>{};

      name = seller['shopName']?.toString().trim() ?? name;
      address =
          seller['address']?.toString().trim() ??
              seller['shopAddress']?.toString().trim() ??
              address;

      latitude ??= _toDouble(
        seller['shopLat'] ??
            seller['shopLatitude'] ??
            seller['latitude'] ??
            seller['lat'],
      );

      longitude ??= _toDouble(
        seller['shopLng'] ??
            seller['shopLongitude'] ??
            seller['longitude'] ??
            seller['lng'],
      );

      final dynamic shopLocation = seller['shopLocation'];

      if (shopLocation is GeoPoint) {
        latitude ??= shopLocation.latitude;
        longitude ??= shopLocation.longitude;
      }
    } catch (_) {
      return <String, dynamic>{};
    }

    if (latitude == null || longitude == null) {
      return <String, dynamic>{
        'name': name.isEmpty ? 'Seller Shop' : name,
        'address': address,
      };
    }

    return <String, dynamic>{
      'name': name.isEmpty ? 'Seller Shop' : name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Future<void> _openSellerDirections(
    double latitude,
    double longitude,
  ) async {
    final Uri uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{
        'api': '1',
        'destination': '$latitude,$longitude',
        'travelmode': 'driving',
      },
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage(
          'Map could not be opened.',
        );
      }
    } catch (_) {
      _showMessage(
        'Map could not be opened.',
      );
    }
  }

  Widget _sellerLocationCard(
    Map<String, dynamic> order,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _sellerShopData(order),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.orange.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.orange.shade200,
              ),
            ),
            child: const Row(
              children: <Widget>[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Loading Seller Shop Location...'),
                ),
              ],
            ),
          );
        }

        final Map<String, dynamic> data =
            snapshot.data ?? <String, dynamic>{};

        final String name =
            data['name']?.toString().trim() ?? 'Seller Shop';
        final String address =
            data['address']?.toString().trim() ?? '';
        final double? latitude = _toDouble(data['latitude']);
        final double? longitude = _toDouble(data['longitude']);
        final bool hasLocation =
            latitude != null && longitude != null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.orange.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.orange.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(
                      Icons.store,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seller Shop Pickup Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),

              if (address.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(address)),
                  ],
                ),
              ],

              if (hasLocation) ...<Widget>[
                const SizedBox(height: 7),
                Text(
                  'Latitude: ${latitude.toStringAsFixed(6)}',
                ),
                Text(
                  'Longitude: ${longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      _openSellerDirections(
                        latitude,
                        longitude,
                      );
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text(
                      'Track Seller Shop Location',
                    ),
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Seller shop GPS location is not available.',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // CALL CUSTOMER
  // =========================================================

  Future<void> _callPhone(
    String phone,
  ) async {
    final String cleanPhone = phone
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');

    if (cleanPhone.isEmpty) {
      _showMessage(
        'Phone number is not available.',
      );
      return;
    }

    try {
      final bool opened = await launchUrl(
        Uri(
          scheme: 'tel',
          path: cleanPhone,
        ),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage(
          'Phone app could not be opened.',
        );
      }
    } catch (_) {
      _showMessage(
        'Phone app could not be opened.',
      );
    }
  }

  // =========================================================
  // SMS
  // =========================================================

  Future<void> _sendSms(
    String phone,
  ) async {
    final String cleanPhone = phone
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');

    if (cleanPhone.isEmpty) {
      _showMessage(
        'Phone number is not available.',
      );
      return;
    }

    try {
      final bool opened = await launchUrl(
        Uri(
          scheme: 'sms',
          path: cleanPhone,
        ),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage(
          'SMS app could not be opened.',
        );
      }
    } catch (_) {
      _showMessage(
        'SMS app could not be opened.',
      );
    }
  }

  // =========================================================
  // OPEN CUSTOMER LOCATION
  // =========================================================

  Future<void> _openMap(
    double latitude,
    double longitude,
  ) async {
    final Uri uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': '$latitude,$longitude',
      },
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage(
          'Map could not be opened.',
        );
      }
    } catch (_) {
      _showMessage(
        'Map could not be opened.',
      );
    }
  }

  // =========================================================
  // CURRENT DRIVER ORDERS
  //
  // NEW ORDER:
  // driverId == logged in Firebase UID
  //
  // Firestore security requires a server-side UID query.
  // =========================================================

  Stream<List<Map<String, dynamic>>>
      _assignedOrdersStream() {
    final String driverId =
        _deliveryPersonId.trim();

    if (driverId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(
        <Map<String, dynamic>>[],
      );
    }

    return FirebaseFirestore.instance
        .collection('orders')
        .where(
          'driverId',
          isEqualTo: driverId,
        )
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<Map<String, dynamic>> orders =
            snapshot.docs
                .map<Map<String, dynamic>>(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      <String, dynamic>{
                    ...doc.data(),
                    'id': doc.id,
                  },
                )
                .toList();

      orders.sort(
        (
          Map<String, dynamic> first,
          Map<String, dynamic> second,
        ) {
          final DateTime? firstDate =
              DateTime.tryParse(
            first['orderDateTime']
                    ?.toString() ??
                '',
          );

          final DateTime? secondDate =
              DateTime.tryParse(
            second['orderDateTime']
                    ?.toString() ??
                '',
          );

          if (firstDate == null &&
              secondDate == null) {
            return 0;
          }

          if (firstDate == null) {
            return 1;
          }

          if (secondDate == null) {
            return -1;
          }

          return secondDate.compareTo(
            firstDate,
          );
        },
      );

        return orders;
      },
    );
  }

  // =========================================================
  // START LIVE TRACKING
  // =========================================================

  Future<void> _openTracking(
    Map<String, dynamic> order,
  ) async {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      _showMessage(
        'Order ID is missing.',
      );
      return;
    }

    final String savedDriverId =
        order['driverId']
                ?.toString()
                .trim() ??
            '';

    // New orders must belong to this logged-in driver.
    if (savedDriverId.isNotEmpty &&
        savedDriverId !=
            _deliveryPersonId) {
      _showMessage(
        'This order is assigned to another delivery person.',
      );
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DeliveryPersonTrackingPage(
          orderId: orderId,
          driverName:
              _deliveryPersonName,
          driverPhone:
              _deliveryPersonPhone,
        ),
      ),
    );
  }

  // =========================================================
  // CUSTOMER LOCATION CARD
  // =========================================================

  Widget _customerLocationCard(
    Map<String, dynamic> order,
  ) {
    final String address =
        _customerAddress(order);

    final double? latitude =
        _customerLatitude(order);

    final double? longitude =
        _customerLongitude(order);

    final String source =
        order['customerLocationSource']
                ?.toString()
                .trim() ??
            '';

    final bool hasLocation =
        latitude != null &&
            longitude != null;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              Colors.green.shade200,
        ),
        color:
            Colors.green.withValues(
          alpha: 0.06,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor:
                    Colors.green,
                child: Icon(
                  Icons.home,
                  color:
                      Colors.white,
                ),
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  'Customer Delivery Location',
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
            height: 12,
          ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.location_on_outlined,
                size: 20,
              ),
              const SizedBox(
                width: 7,
              ),
              Expanded(
                child: Text(
                  address,
                ),
              ),
            ],
          ),

          if (source.isNotEmpty) ...<Widget>[
            const SizedBox(
              height: 6,
            ),
            Text(
              'Location Source: $source',
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.grey.shade700,
              ),
            ),
          ],

          if (hasLocation) ...<Widget>[
            const SizedBox(
              height: 10,
            ),

            Text(
              'Latitude: '
              '${latitude.toStringAsFixed(6)}',
            ),

            Text(
              'Longitude: '
              '${longitude.toStringAsFixed(6)}',
            ),

            const SizedBox(
              height: 12,
            ),

            SizedBox(
              width: double.infinity,
              height: 48,
              child:
                  FilledButton.icon(
                onPressed: () {
                  _openMap(
                    latitude,
                    longitude,
                  );
                },
                icon: const Icon(
                  Icons.navigation,
                ),
                label: const Text(
                  'Open Customer Location',
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(
              height: 10,
            ),

            const Text(
              'Customer GPS location is not available.',
              style: TextStyle(
                color: Colors.orange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // SELLER HANDOVER / PICKUP VERIFICATION
  // =========================================================

  String _generatePickupCode() {
    final Random random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _generatePickupToken() {
    const String alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final Random random = Random.secure();

    return List<String>.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  Map<String, dynamic> _preparePickupVerificationData(
    Map<String, dynamic> order,
  ) {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      throw StateError('Order ID is missing.');
    }

    if (_deliveryPersonId.trim().isEmpty) {
      throw StateError('Delivery person login is required.');
    }

    if (order['pickupConfirmed'] == true) {
      throw StateError('Pickup is already confirmed.');
    }

    final String savedDriverId =
        order['driverId']?.toString().trim() ?? '';

    if (savedDriverId != _deliveryPersonId) {
      throw StateError(
        'This order is not assigned to the current delivery person.',
      );
    }

    final String pickupCode = _generatePickupCode();
    final String qrToken = _generatePickupToken();
    final String qrPayload =
        'NRD_PICKUP|$orderId|$_deliveryPersonId|$qrToken';
    final String now = DateTime.now().toIso8601String();

    return <String, dynamic>{
      'orderId': orderId,
      'driverId': _deliveryPersonId,
      'pickupCode': pickupCode,
      'qrPayload': qrPayload,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  Future<Map<String, dynamic>> _getOrCreatePickupVerification(
    Map<String, dynamic> order,
  ) async {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      throw StateError('Order ID is missing.');
    }

    if (_deliveryPersonId.trim().isEmpty) {
      throw StateError('Delivery person login is required.');
    }

    if (order['pickupConfirmed'] == true) {
      throw StateError('Pickup is already confirmed.');
    }

    final String savedDriverId =
        order['driverId']?.toString().trim() ?? '';

    if (savedDriverId != _deliveryPersonId) {
      throw StateError(
        'This order is not assigned to the current delivery person.',
      );
    }

    final DocumentReference<Map<String, dynamic>> verificationRef =
        FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .collection('pickup_private')
            .doc('verification');

    final DocumentSnapshot<Map<String, dynamic>> existing =
        await verificationRef.get();

    final Map<String, dynamic>? existingData = existing.data();

    if (existing.exists && existingData != null) {
      final String existingDriverId =
          existingData['driverId']?.toString().trim() ?? '';
      final String existingCode =
          existingData['pickupCode']?.toString().trim() ?? '';
      final String existingQr =
          existingData['qrPayload']?.toString().trim() ?? '';
      final bool isActive = existingData['isActive'] == true;

      if (existingDriverId == _deliveryPersonId &&
          RegExp(r'^\d{6}$').hasMatch(existingCode) &&
          existingQr.startsWith('NRD_PICKUP|') &&
          isActive) {
        return existingData;
      }
    }

    final Map<String, dynamic> verification =
        _preparePickupVerificationData(order);

    await verificationRef
        .set(
          verification,
          SetOptions(merge: false),
        )
        .timeout(
          const Duration(seconds: 10),
        );

    return verification;
  }

  Widget _pickupVerificationInline(
    Map<String, dynamic> order,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getOrCreatePickupVerification(order),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Preparing pickup QR & code...',
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          String message = snapshot.error
                  ?.toString()
                  .replaceFirst('Bad state: ', '')
                  .replaceFirst('Exception: ', '') ??
              'Could not prepare pickup QR & code.';

          if (snapshot.error is FirebaseException &&
              (snapshot.error! as FirebaseException).code ==
                  'permission-denied') {
            message =
                'Pickup QR permission was denied. Deploy the latest Firestore rules and retry.';
          }

          return Column(
            children: <Widget>[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          );
        }

        final Map<String, dynamic> verification = snapshot.data!;
        final String pickupCode =
            verification['pickupCode']?.toString().trim() ?? '';
        final String qrPayload =
            verification['qrPayload']?.toString().trim() ?? '';

        if (pickupCode.isEmpty || qrPayload.isEmpty) {
          return const Text(
            'Pickup QR or code is not available.',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w700,
            ),
          );
        }

        return Column(
          children: <Widget>[
            const SizedBox(height: 12),
            const Text(
              'SHOW THIS TO THE SELLER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'PICKUP CODE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              pickupCode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 7,
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.verified_rounded,
                  color: Colors.green,
                  size: 20,
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Seller can scan the QR or enter the 6-digit code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // ORDER CARD
  // =========================================================

  Widget _orderCard(
    Map<String, dynamic> order,
  ) {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    final String status =
        order['status']
                ?.toString()
                .trim() ??
            'Pending';

    final String trackingStatus =
        order['trackingStatus']
                ?.toString()
                .trim() ??
            'Delivery Person Assigned';

    final String customerName =
        _customerName(order);

    final String customerPhone =
        _customerPhone(order);

    final String amount =
        order['amount']
                ?.toString()
                .trim() ??
            '0';

    final String payment =
        order['payment']
                ?.toString()
                .trim() ??
            '';

    final String savedDriverId =
        order['driverId']
                ?.toString()
                .trim() ??
            '';

    final bool secureAssignment =
        savedDriverId.isNotEmpty;

    final bool pickupConfirmed =
        order['pickupConfirmed'] == true;

    final String pickupConfirmedAt =
        order['pickupConfirmedAt']
                ?.toString()
                .trim() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  child: Icon(
                    Icons.local_shipping,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Order #$orderId',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        trackingStatus,
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                Chip(
                  label: Text(
                    status,
                  ),
                ),
              ],
            ),

            if (secureAssignment) ...<Widget>[
              const SizedBox(
                height: 8,
              ),
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.verified_user,
                    size: 17,
                    color: Colors.green,
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Text(
                    'Secure Driver ID Assignment',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(
              height: 26,
            ),

            const Text(
              'Customer Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Row(
              children: <Widget>[
                const Icon(
                  Icons.person_outline,
                  size: 20,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    customerName,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 5,
            ),

            Row(
              children: <Widget>[
                const Icon(
                  Icons.phone_outlined,
                  size: 20,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    customerPhone.isEmpty
                        ? 'Phone not available'
                        : customerPhone,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Row(
              children: <Widget>[
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        customerPhone.isEmpty
                            ? null
                            : () {
                                _callPhone(
                                  customerPhone,
                                );
                              },
                    icon: const Icon(
                      Icons.call,
                    ),
                    label: const Text(
                      'Call Customer',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        customerPhone.isEmpty
                            ? null
                            : () {
                                _sendSms(
                                  customerPhone,
                                );
                              },
                    icon: const Icon(
                      Icons.sms,
                    ),
                    label: const Text(
                      'SMS',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            _sellerLocationCard(
              order,
            ),

            const SizedBox(
              height: 14,
            ),

            _customerLocationCard(
              order,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              'Amount: Rs. $amount',
              style: const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            if (payment.isNotEmpty)
              Text(
                'Payment: $payment',
              ),

            const SizedBox(
              height: 14,
            ),

            if (status != 'Delivered')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pickupConfirmed
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pickupConfirmed
                        ? Colors.green.withValues(alpha: 0.35)
                        : Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          pickupConfirmed
                              ? Icons.inventory_2_rounded
                              : Icons.qr_code_2_rounded,
                          color: pickupConfirmed
                              ? Colors.green
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pickupConfirmed
                                ? 'Parcel Pickup Confirmed'
                                : 'Seller Handover Verification',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pickupConfirmed
                          ? 'The seller confirmed that this parcel was handed to you.'
                          : 'At the shop, show your pickup QR or 6-digit code to the seller.',
                    ),
                    if (pickupConfirmed &&
                        pickupConfirmedAt.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Confirmed: $pickupConfirmedAt',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (!pickupConfirmed) ...<Widget>[
                      _pickupVerificationInline(order),
                    ],
                  ],
                ),
              ),

            const SizedBox(
              height: 14,
            ),

            SizedBox(
              width: double.infinity,
              height: 54,
              child:
                  FilledButton.icon(
                onPressed:
                    status == 'Delivered'
                        ? null
                        : () {
                            _openTracking(
                              order,
                            );
                          },
                icon: const Icon(
                  Icons.location_searching,
                ),
                label: Text(
                  status == 'Delivered'
                      ? 'Order Delivered'
                      : 'Start / Continue Live Tracking',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DELIVERY AVAILABILITY PRESENCE / GPS
  // =========================================================

  Future<void> _publishDeliveryPresence({
    required bool online,
  }) async {
    final String driverId =
        _deliveryPersonId.trim();

    if (driverId.isEmpty) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    final Map<String, dynamic> presence =
        <String, dynamic>{
      'driverId': driverId,
      'name': _deliveryPersonName.trim(),
      'phone': _deliveryPersonPhone.trim(),
      'email': user?.email?.trim() ?? '',
      'isOnline': online,
      'updatedAt': FieldValue.serverTimestamp(),
      'locationUpdatedAt': online &&
              _currentLatitude != null &&
              _currentLongitude != null
          ? FieldValue.serverTimestamp()
          : null,
      'latitude':
          online ? _currentLatitude : null,
      'longitude':
          online ? _currentLongitude : null,
    };

    await FirebaseFirestore.instance
        .collection('delivery_presence')
        .doc(driverId)
        .set(
          presence,
          SetOptions(merge: true),
        );
  }

  Future<void> _refreshAvailabilityLocation({
    bool showErrors = false,
  }) async {
    if (!_isOnline ||
        _updatingAvailabilityLocation ||
        _deliveryPersonId.trim().isEmpty) {
      return;
    }

    _updatingAvailabilityLocation = true;

    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (showErrors) {
          _showMessage(
            'Turn on device Location/GPS to receive nearby Krishi orders.',
          );
        }
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        if (showErrors) {
          _showMessage(
            'Location permission is required for nearby Krishi orders.',
          );
        }
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLatitude =
            position.latitude;
        _currentLongitude =
            position.longitude;
      });

      await _publishDeliveryPresence(
        online: true,
      );
    } catch (error) {
      if (showErrors) {
        _showMessage(
          'Could not update delivery location: $error',
        );
      }
    } finally {
      _updatingAvailabilityLocation = false;
    }
  }

  Future<void> _openNearbyKrishiOrders() async {
    if (!_isOnline) {
      _showMessage(
        'Go Online first to view nearby Krishi orders.',
      );
      return;
    }

    await _refreshAvailabilityLocation(
      showErrors: true,
    );

    if (!mounted) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _NearbyKrishiOrdersPage(
          driverId: _deliveryPersonId,
          driverName: _deliveryPersonName,
          driverPhone: _deliveryPersonPhone,
          initialLatitude:
              _currentLatitude,
          initialLongitude:
              _currentLongitude,
        ),
      ),
    );

    if (mounted && _isOnline) {
      await _refreshAvailabilityLocation();
    }
  }

  // =========================================================
  // ONLINE / OFFLINE
  // =========================================================

  Future<void> _setOnlineStatus(
    bool value,
  ) async {
    if (_updatingAvailability ||
        _deliveryPersonId.trim().isEmpty) {
      return;
    }

    setState(() {
      _updatingAvailability = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('delivery_persons')
          .doc(_deliveryPersonId)
          .set(
        <String, dynamic>{
          'isOnline': value,
          'updatedAt':
              DateTime.now().toIso8601String(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = value;
        _deliveryPersonData =
            <String, dynamic>{
          ..._deliveryPersonData,
          'isOnline': value,
        };
      });

      await _publishDeliveryPresence(
        online: value,
      );

      if (value) {
        await _refreshAvailabilityLocation(
          showErrors: true,
        );
      }

      _showMessage(
        value
            ? 'You are now Online and available for delivery work.'
            : 'You are now Offline.',
      );
    } catch (error) {
      _showMessage(
        'Could not update Online / Offline status: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingAvailability = false;
        });
      }
    }
  }

  // =========================================================
  // DELIVERY EARNINGS
  // =========================================================

  Future<void> _openDeliveryEarnings() async {
    final String driverId = _deliveryPersonId.trim();

    if (driverId.isEmpty) {
      _showMessage('Delivery person login is required.');
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _DeliveryEarningsPage(
          driverId: driverId,
          driverName: _deliveryPersonName.trim(),
        ),
      ),
    );
  }

  // =========================================================
  // EDIT PROFILE
  // =========================================================

  Future<void> _openEditProfile() async {
    if (_deliveryPersonId.trim().isEmpty ||
        _isLoading) {
      return;
    }

    final bool? requiresReapproval =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            DeliveryPersonEditProfilePage(
          deliveryPersonId:
              _deliveryPersonId,
          initialData:
              Map<String, dynamic>.from(
            _deliveryPersonData,
          ),
        ),
      ),
    );

    if (!mounted ||
        requiresReapproval == null) {
      return;
    }

    await _loadDeliveryPerson();

    if (!mounted) {
      return;
    }

    if (requiresReapproval) {
      await showDialog<void>(
        context: context,
        builder: (
          BuildContext dialogContext,
        ) {
          return AlertDialog(
            title: const Text(
              'Admin Verification Required',
            ),
            content: const Text(
              'Your vehicle or driving licence details were changed. '
              'For security, the account has been moved back to Pending Approval. '
              'Admin must verify the updated documents before delivery work can continue.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        await _logout();
      }
    } else {
      _showMessage(
        'Delivery Person profile updated.',
      );
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection(
              'delivery_persons',
            )
            .doc(
              user.uid,
            )
            .set(
          <String, dynamic>{
            'isOnline': false,
            'updatedAt':
                DateTime.now()
                    .toIso8601String(),
          },
          SetOptions(
            merge: true,
          ),
        );
      } catch (_) {
        // Continue logout.
      }
    }

    try {
      await _publishDeliveryPresence(
        online: false,
      );
    } catch (_) {
      // Continue logout.
    }

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    if (!mounted) {
      return;
    }

    Navigator.pop(
      context,
    );
  }

  @override
  void dispose() {
    _availabilityLocationTimer?.cancel();
    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Dashboard',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit Profile',
            onPressed:
                _isLoading
                    ? null
                    : _openEditProfile,
            icon: const Icon(
              Icons.edit_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed:
                _isLoading
                    ? null
                    : _logout,
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _deliveryPersonId.isEmpty
              ? const Center(
                  child: Text(
                    'Delivery person login required.',
                  ),
                )
              : Column(
                  children: <Widget>[
                    Padding(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      child: Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          14,
                        ),
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                          color:
                              Colors.blue
                                  .withValues(
                            alpha: 0.08,
                          ),
                        ),
                        child: Row(
                          children:
                              <Widget>[
                            const CircleAvatar(
                              child: Icon(
                                Icons
                                    .delivery_dining,
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children:
                                    <Widget>[
                                  Text(
                                    _deliveryPersonName
                                            .isEmpty
                                        ? 'Delivery Person'
                                        : _deliveryPersonName,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          17,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  if (_deliveryPersonPhone
                                      .isNotEmpty)
                                    Text(
                                      _deliveryPersonPhone,
                                    ),

                                  Text(
                                    'ID: $_deliveryPersonId',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        TextStyle(
                                      fontSize: 11,
                                      color:
                                          Colors.grey
                                              .shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children:
                                  <Widget>[
                                Switch(
                                  value:
                                      _isOnline,
                                  onChanged:
                                      _updatingAvailability
                                          ? null
                                          : _setOnlineStatus,
                                ),
                                Text(
                                  _updatingAvailability
                                      ? 'Updating...'
                                      : _isOnline
                                          ? 'Online'
                                          : 'Offline',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        12,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    color:
                                        _isOnline
                                            ? Colors
                                                .green
                                            : Colors
                                                .grey
                                                .shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        14,
                        0,
                        14,
                        12,
                      ),
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _isOnline
                                  ? _openNearbyKrishiOrders
                                  : null,
                              icon: const Icon(
                                Icons.agriculture_rounded,
                              ),
                              label: Text(
                                _isOnline
                                    ? 'Nearby Krishi Delivery Orders'
                                    : 'Go Online for Nearby Krishi Orders',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _openDeliveryEarnings,
                              icon: const Icon(
                                Icons.account_balance_wallet_rounded,
                              ),
                              label: const Text(
                                'Delivery Earnings',
                              ),
                            ),
                          ),
                          if (_isOnline) ...<Widget>[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  _currentLatitude != null &&
                                          _currentLongitude != null
                                      ? Icons.gps_fixed
                                      : Icons.gps_not_fixed,
                                  size: 16,
                                  color: _currentLatitude != null &&
                                          _currentLongitude != null
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 5),
                                TextButton(
                                  onPressed:
                                      _updatingAvailabilityLocation
                                          ? null
                                          : () {
                                              _refreshAvailabilityLocation(
                                                showErrors: true,
                                              );
                                            },
                                  child: Text(
                                    _updatingAvailabilityLocation
                                        ? 'Updating GPS...'
                                        : 'Refresh delivery GPS',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    Expanded(
                      child: StreamBuilder<
                          List<
                              Map<String,
                                  dynamic>>>(
                        stream:
                            _assignedOrdersStream(),
                        builder: (
                          BuildContext context,
                          AsyncSnapshot<
                                  List<
                                      Map<String,
                                          dynamic>>>
                              snapshot,
                        ) {
                          if (snapshot
                                  .connectionState ==
                              ConnectionState
                                  .waiting) {
                            return const Center(
                              child:
                                  CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(
                                  20,
                                ),
                                child: Text(
                                  'Could not load assigned orders.\n'
                                  '${snapshot.error}',
                                  textAlign:
                                      TextAlign.center,
                                ),
                              ),
                            );
                          }

                          final List<
                                  Map<String,
                                      dynamic>>
                              orders =
                              snapshot.data ??
                                  <Map<String,
                                      dynamic>>[];

                          if (orders.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children:
                                    <Widget>[
                                  Icon(
                                    Icons
                                        .local_shipping_outlined,
                                    size: 75,
                                    color:
                                        Colors.grey,
                                  ),
                                  SizedBox(
                                    height: 12,
                                  ),
                                  Text(
                                    'No Assigned Orders',
                                    style:
                                        TextStyle(
                                      fontSize: 19,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    'Orders assigned to this Delivery ID will appear here.',
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              14,
                              0,
                              14,
                              14,
                            ),
                            itemCount:
                                orders.length,
                            itemBuilder: (
                              BuildContext context,
                              int index,
                            ) {
                              return _orderCard(
                                orders[index],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}


class _DeliveryIncomeEntry {
  const _DeliveryIncomeEntry({
    required this.id,
    required this.data,
    required this.deliveredAt,
    required this.deliveryFee,
    required this.payoutStatus,
  });

  final String id;
  final Map<String, dynamic> data;
  final DateTime deliveredAt;
  final double deliveryFee;
  final String payoutStatus;
}

class _DeliveryIncomeSummary {
  const _DeliveryIncomeSummary({
    required this.amount,
    required this.deliveries,
  });

  final double amount;
  final int deliveries;
}

class _DeliveryEarningsPage extends StatelessWidget {
  const _DeliveryEarningsPage({
    required this.driverId,
    required this.driverName,
  });

  final String driverId;
  final String driverName;

  double? _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text.replaceAll(',', ''));
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    final DateTime? parsed = DateTime.tryParse(
      value?.toString().trim() ?? '',
    );

    return parsed?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _deliveredTime(Map<String, dynamic> order) {
    for (final String key in <String>[
      'deliveredAt',
      'deliveryCompletedAt',
      'completedAt',
      'updatedAt',
      'orderDateTime',
    ]) {
      final DateTime value = _date(order[key]);
      if (value.millisecondsSinceEpoch > 0) {
        return value;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isDelivered(Map<String, dynamic> order) {
    final String status =
        order['status']?.toString().trim().toLowerCase() ?? '';
    final String trackingStatus =
        order['trackingStatus']?.toString().trim().toLowerCase() ?? '';
    final String deliveredAt =
        order['deliveredAt']?.toString().trim() ?? '';

    return status == 'delivered' ||
        trackingStatus == 'delivered' ||
        deliveredAt.isNotEmpty;
  }

  double _deliveryFee(Map<String, dynamic> order) {
    return _number(order['delivery']) ??
        _number(order['deliveryFee']) ??
        _number(order['deliveryCharge']) ??
        _number(order['shippingFee']) ??
        0.0;
  }

  String _payoutStatus(Map<String, dynamic> order) {
    final List<dynamic> values = <dynamic>[
      order['deliveryPayoutStatus'],
      order['driverPayoutStatus'],
      order['deliveryPaymentStatus'],
      order['payoutStatus'],
    ];

    for (final dynamic value in values) {
      final String status = value?.toString().trim().toLowerCase() ?? '';
      if (status.isEmpty) {
        continue;
      }

      if (status == 'paid' ||
          status == 'settled' ||
          status == 'completed') {
        return 'Paid';
      }

      if (status == 'pending' ||
          status == 'ready' ||
          status == 'ready to pay' ||
          status == 'unpaid') {
        return 'Pending';
      }
    }

    // Existing orders do not currently write a delivery payout field.
    // Treat delivered fee as pending until an admin/payment flow marks it paid.
    return 'Pending';
  }

  List<_DeliveryIncomeEntry> _entries(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<_DeliveryIncomeEntry> entries = <_DeliveryIncomeEntry>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> order = document.data();

      if (!_isDelivered(order)) {
        continue;
      }

      entries.add(
        _DeliveryIncomeEntry(
          id: document.id,
          data: order,
          deliveredAt: _deliveredTime(order),
          deliveryFee: _deliveryFee(order),
          payoutStatus: _payoutStatus(order),
        ),
      );
    }

    entries.sort(
      (_DeliveryIncomeEntry first, _DeliveryIncomeEntry second) =>
          second.deliveredAt.compareTo(first.deliveredAt),
    );

    return entries;
  }

  _DeliveryIncomeSummary _summary(
    Iterable<_DeliveryIncomeEntry> entries,
  ) {
    double amount = 0;
    int deliveries = 0;

    for (final _DeliveryIncomeEntry entry in entries) {
      amount += entry.deliveryFee;
      deliveries += 1;
    }

    return _DeliveryIncomeSummary(
      amount: amount,
      deliveries: deliveries,
    );
  }

  String _dateText(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) {
      return '-';
    }

    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
  }

  Widget _statCard(
    String title,
    double amount,
    int deliveries,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '$deliveries deliveries',
            style: const TextStyle(fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(
    String label,
    double amount, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(_DeliveryIncomeEntry entry) {
    final String marketplace =
        entry.data['marketplace']?.toString().trim() ?? '';
    final String customer =
        entry.data['customerName']?.toString().trim() ??
            entry.data['name']?.toString().trim() ??
            '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    marketplace.isEmpty ? 'Delivery' : marketplace,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _dateText(entry.deliveredAt),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Order ID: ${entry.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
            if (customer.isNotEmpty) ...<Widget>[
              const SizedBox(height: 3),
              Text('Customer: $customer'),
            ],
            const Divider(height: 22),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Delivery Fee'),
                ),
                Text(
                  'Rs. ${entry.deliveryFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Payout Status'),
                ),
                Chip(
                  label: Text(entry.payoutStatus),
                  avatar: Icon(
                    entry.payoutStatus == 'Paid'
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cleanDriverId = driverId.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Earnings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: cleanDriverId.isEmpty
            ? const Center(
                child: Text('Delivery Person ID is not available.'),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('driverId', isEqualTo: cleanDriverId)
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load Delivery Earnings.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final List<_DeliveryIncomeEntry> entries =
                      _entries(snapshot.data!);

                  final DateTime now = DateTime.now();
                  final DateTime startOfToday =
                      DateTime(now.year, now.month, now.day);
                  final DateTime startOfWeek = startOfToday.subtract(
                    Duration(
                      days: startOfToday.weekday - DateTime.monday,
                    ),
                  );
                  final DateTime startOfMonth =
                      DateTime(now.year, now.month);

                  final _DeliveryIncomeSummary today = _summary(
                    entries.where(
                      (_DeliveryIncomeEntry entry) =>
                          !entry.deliveredAt.isBefore(startOfToday),
                    ),
                  );
                  final _DeliveryIncomeSummary week = _summary(
                    entries.where(
                      (_DeliveryIncomeEntry entry) =>
                          !entry.deliveredAt.isBefore(startOfWeek),
                    ),
                  );
                  final _DeliveryIncomeSummary month = _summary(
                    entries.where(
                      (_DeliveryIncomeEntry entry) =>
                          !entry.deliveredAt.isBefore(startOfMonth),
                    ),
                  );
                  final _DeliveryIncomeSummary total = _summary(entries);
                  final _DeliveryIncomeSummary pending = _summary(
                    entries.where(
                      (_DeliveryIncomeEntry entry) =>
                          entry.payoutStatus != 'Paid',
                    ),
                  );
                  final _DeliveryIncomeSummary paid = _summary(
                    entries.where(
                      (_DeliveryIncomeEntry entry) =>
                          entry.payoutStatus == 'Paid',
                    ),
                  );

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const CircleAvatar(
                                        radius: 24,
                                        child: Icon(
                                          Icons.account_balance_wallet_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            const Text(
                                              'Delivery Earnings',
                                              style: TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              driverName.isEmpty
                                                  ? 'Delivery Person'
                                                  : driverName,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Only the order Delivery Fee is counted here. Product/order total is not counted as Delivery Person income.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F8FA),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        _moneyRow(
                                          'Total Delivery Earnings',
                                          total.amount,
                                          bold: true,
                                        ),
                                        _moneyRow(
                                          'Pending Payout',
                                          pending.amount,
                                        ),
                                        _moneyRow(
                                          'Paid Earnings',
                                          paid.amount,
                                        ),
                                        const Divider(height: 20),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Completed deliveries: ${total.deliveries}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _statCard(
                                          'Today',
                                          today.amount,
                                          today.deliveries,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _statCard(
                                          'This Week',
                                          week.amount,
                                          week.deliveries,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _statCard(
                                          'This Month',
                                          month.amount,
                                          month.deliveries,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _statCard(
                                          'All Time',
                                          total.amount,
                                          total.deliveries,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Completed Delivery History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (entries.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No completed deliveries yet. Earnings will appear after an assigned order is marked Delivered.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ...entries.map(_historyCard),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}


class _NearbyKrishiOrdersPage
    extends StatefulWidget {
  const _NearbyKrishiOrdersPage({
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  final String driverId;
  final String driverName;
  final String driverPhone;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<_NearbyKrishiOrdersPage> createState() =>
      _NearbyKrishiOrdersPageState();
}

class _NearbyKrishiOrdersPageState
    extends State<_NearbyKrishiOrdersPage> {
  double? _latitude;
  double? _longitude;
  bool _refreshingLocation = false;
  String? _busyOrderId;
  Timer? _locationTimer;

  void _showNearbyMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _refreshLocation();

    _locationTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        unawaited(
          _refreshLocation(),
        );
      },
    );
  }

  double? _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    double radians(double degree) =>
        degree * pi / 180.0;

    final double dLat =
        radians(lat2 - lat1);
    final double dLon =
        radians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(radians(lat1)) *
                cos(radians(lat2)) *
                sin(dLon / 2) *
                sin(dLon / 2);

    final double c =
        2 * atan2(
          sqrt(a),
          sqrt(1 - a),
        );

    return earthRadiusKm * c;
  }

  double? _driverToFarmKm(
    Map<String, dynamic> pool,
  ) {
    final double? farmLat =
        _toDouble(pool['farmLat']);
    final double? farmLng =
        _toDouble(pool['farmLng']);

    if (_latitude == null ||
        _longitude == null ||
        farmLat == null ||
        farmLng == null) {
      return null;
    }

    return _distanceKm(
      _latitude!,
      _longitude!,
      farmLat,
      farmLng,
    );
  }

  DateTime? _timestampDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value?.toString() ?? '',
    );
  }

  bool _reservationExpired(
    Map<String, dynamic> pool,
  ) {
    final DateTime? expiry =
        _timestampDate(
      pool['reservationExpiresAt'],
    );

    return expiry == null ||
        !expiry.isAfter(
          DateTime.now(),
        );
  }

  String _distanceText(
    double? km,
  ) {
    if (km == null) {
      return 'GPS unavailable';
    }

    if (km < 1) {
      return '${(km * 1000).round()} m';
    }

    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _refreshLocation() async {
    if (_refreshingLocation) {
      return;
    }

    setState(() {
      _refreshingLocation = true;
    });

    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Turn on Location/GPS to sort Krishi orders by distance.',
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required for nearby Krishi orders.',
              ),
            ),
          );
        }
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude =
            position.latitude;
        _longitude =
            position.longitude;
      });

      await FirebaseFirestore.instance
          .collection('delivery_presence')
          .doc(widget.driverId)
          .set(
        <String, dynamic>{
          'driverId': widget.driverId,
          'name': widget.driverName.trim(),
          'phone': widget.driverPhone.trim(),
          'email': FirebaseAuth
                  .instance.currentUser?.email
                  ?.trim() ??
              '',
          'isOnline': true,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Could not refresh GPS: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingLocation = false;
        });
      }
    }
  }

  Stream<List<Map<String, dynamic>>>
      _poolStream() {
    return FirebaseFirestore.instance
        .collection(
          'krishi_delivery_pool',
        )
        .where(
          'active',
          isEqualTo: true,
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<Map<String, dynamic>>
            orders = snapshot.docs
                .map(
                  (
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        doc,
                  ) =>
                      <String, dynamic>{
                    ...doc.data(),
                    'poolId': doc.id,
                  },
                )
                .where(
                  (
                    Map<String, dynamic>
                        item,
                  ) =>
                      item['readyForPickup'] ==
                      true,
                )
                .toList();

        orders.sort(
          (
            Map<String, dynamic> a,
            Map<String, dynamic> b,
          ) {
            final double? aDistance =
                _driverToFarmKm(a);
            final double? bDistance =
                _driverToFarmKm(b);

            if (aDistance == null &&
                bDistance == null) {
              return 0;
            }

            if (aDistance == null) {
              return 1;
            }

            if (bDistance == null) {
              return -1;
            }

            return aDistance
                .compareTo(bDistance);
          },
        );

        return orders;
      },
    );
  }

  String _generateReservationKey() {
    const String alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789';

    final Random random =
        Random.secure();

    return List<String>.generate(
      40,
      (_) => alphabet[
        random.nextInt(
          alphabet.length,
        )
      ],
    ).join();
  }

  Future<void> _reserveOrder(
    Map<String, dynamic> pool,
  ) async {
    final String orderId =
        pool['orderId']?.toString().trim() ??
            pool['poolId']?.toString().trim() ??
            '';

    if (orderId.isEmpty || _busyOrderId != null) {
      return;
    }

    setState(() {
      _busyOrderId = orderId;
    });

    final DocumentReference<Map<String, dynamic>> poolRef =
        FirebaseFirestore.instance
            .collection('krishi_delivery_pool')
            .doc(orderId);
    final DocumentReference<Map<String, dynamic>> requestRef =
        poolRef
            .collection('pickup_requests')
            .doc(widget.driverId);

    try {
      final DocumentSnapshot<Map<String, dynamic>> poolSnapshot =
          await poolRef.get();
      final Map<String, dynamic> latestPool =
          poolSnapshot.data() ?? <String, dynamic>{};

      if (!poolSnapshot.exists ||
          latestPool['active'] != true ||
          latestPool['readyForPickup'] != true ||
          latestPool['state'] != 'available') {
        throw StateError(
          'This Krishi pickup is no longer available for a new request.',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> existing =
          await requestRef.get();
      final Map<String, dynamic> existingData =
          existing.data() ?? <String, dynamic>{};

      if (existing.exists &&
          existingData['status'] == 'pending_driver' &&
          existingData['requestedBy'] == 'seller') {
        throw StateError(
          'This farm already sent you a pickup request. Use Accept Farm Request below.',
        );
      }

      if (existing.exists) {
        await requestRef.delete();
      }

      await requestRef.set(
        <String, dynamic>{
          'orderId': orderId,
          'sellerId': latestPool['sellerId']?.toString().trim() ?? '',
          'driverId': widget.driverId,
          'driverName': widget.driverName.trim(),
          'driverPhone': widget.driverPhone.trim(),
          'driverEmail':
              FirebaseAuth.instance.currentUser?.email?.trim() ?? '',
          'requestedBy': 'driver',
          'status': 'pending_seller',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pickup request sent to the farm. Wait for seller approval before using QR/code.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showNearbyMessage(
          error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyOrderId = null;
        });
      }
    }
  }

  Future<void> _acceptFarmPickupRequest(
    Map<String, dynamic> pool,
  ) async {
    final String orderId =
        pool['orderId']?.toString().trim() ??
            pool['poolId']?.toString().trim() ??
            '';

    if (orderId.isEmpty || _busyOrderId != null) {
      return;
    }

    setState(() {
      _busyOrderId = orderId;
    });

    final DocumentReference<Map<String, dynamic>> poolRef =
        FirebaseFirestore.instance
            .collection('krishi_delivery_pool')
            .doc(orderId);
    final DocumentReference<Map<String, dynamic>> requestRef =
        poolRef
            .collection('pickup_requests')
            .doc(widget.driverId);

    final String reservationKey = _generateReservationKey();
    final Timestamp expiresAt = Timestamp.fromDate(
      DateTime.now().add(
        const Duration(hours: 2),
      ),
    );

    try {
      await FirebaseFirestore.instance.runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> poolSnapshot =
              await transaction.get(poolRef);
          final DocumentSnapshot<Map<String, dynamic>> requestSnapshot =
              await transaction.get(requestRef);

          final Map<String, dynamic> latestPool =
              poolSnapshot.data() ?? <String, dynamic>{};
          final Map<String, dynamic> request =
              requestSnapshot.data() ?? <String, dynamic>{};

          if (!poolSnapshot.exists ||
              latestPool['active'] != true ||
              latestPool['state'] != 'available') {
            throw StateError('This order is no longer available.');
          }

          if (!requestSnapshot.exists ||
              request['requestedBy'] != 'seller' ||
              request['status'] != 'pending_driver') {
            throw StateError('The farm pickup request is no longer pending.');
          }

          transaction.update(
            requestRef,
            <String, dynamic>{
              'status': 'accepted',
              'respondedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );

          transaction.update(
            poolRef,
            <String, dynamic>{
              'state': 'reserved',
              'reservationKey': reservationKey,
              'reservedDriverId': widget.driverId,
              'reservedDriverName': widget.driverName.trim(),
              'reservedDriverPhone': widget.driverPhone.trim(),
              'reservedDriverEmail':
                  FirebaseAuth.instance.currentUser?.email?.trim() ?? '',
              'reservedAt': FieldValue.serverTimestamp(),
              'reservationExpiresAt': expiresAt,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );

      final DocumentSnapshot<Map<String, dynamic>> fresh =
          await poolRef.get();
      final Map<String, dynamic> reservedPool = <String, dynamic>{
        ...?fresh.data(),
        'poolId': orderId,
      };

      await _getOrCreatePickupVerification(
        reservedPool,
      );

      if (mounted) {
        _showNearbyMessage(
          'Farm request accepted. QR/code is ready for physical parcel handover.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showNearbyMessage(
          'Could not accept farm request: ${error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyOrderId = null;
        });
      }
    }
  }

  Future<void> _declineFarmPickupRequest(
    Map<String, dynamic> pool,
  ) async {
    final String orderId =
        pool['orderId']?.toString().trim() ??
            pool['poolId']?.toString().trim() ??
            '';

    if (orderId.isEmpty || _busyOrderId != null) {
      return;
    }

    setState(() {
      _busyOrderId = orderId;
    });

    try {
      await FirebaseFirestore.instance
          .collection('krishi_delivery_pool')
          .doc(orderId)
          .collection('pickup_requests')
          .doc(widget.driverId)
          .update(
        <String, dynamic>{
          'status': 'rejected',
          'respondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (error) {
      if (mounted) {
        _showNearbyMessage('Could not decline farm request: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyOrderId = null;
        });
      }
    }
  }

  Future<void> _cancelPickupRequest(
    Map<String, dynamic> pool,
  ) async {
    final String orderId =
        pool['orderId']?.toString().trim() ??
            pool['poolId']?.toString().trim() ??
            '';

    if (orderId.isEmpty || _busyOrderId != null) {
      return;
    }

    setState(() {
      _busyOrderId = orderId;
    });

    try {
      await FirebaseFirestore.instance
          .collection('krishi_delivery_pool')
          .doc(orderId)
          .collection('pickup_requests')
          .doc(widget.driverId)
          .update(
        <String, dynamic>{
          'status': 'cancelled',
          'respondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (error) {
      if (mounted) {
        _showNearbyMessage('Could not cancel pickup request: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyOrderId = null;
        });
      }
    }
  }

  Future<void> _releaseReservation(
    Map<String, dynamic> pool,
  ) async {
    final String orderId =
        pool['orderId']?.toString().trim() ??
            pool['poolId']?.toString().trim() ??
            '';

    if (orderId.isEmpty || _busyOrderId != null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Release this reservation?'),
          content: const Text(
            'The order will become available to nearby delivery persons again. No pickup is recorded.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep Reservation'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Release'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busyOrderId = orderId;
    });

    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance
            .collection('krishi_delivery_pool')
            .doc(orderId);

    try {
      // Remove the old private proof while this driver still owns the active
      // reservation. A future reservation will receive a fresh proof.
      try {
        await ref
            .collection('pickup_private')
            .doc('verification')
            .delete()
            .timeout(
              const Duration(seconds: 6),
            );
      } catch (_) {
        // Missing/expired proof is harmless; releasing the parent reservation
        // is still the important operation.
      }

      await FirebaseFirestore.instance
          .runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw StateError('This reservation no longer exists.');
          }

          final Map<String, dynamic> data =
              snapshot.data() ?? <String, dynamic>{};
          final String reservedDriverId =
              data['reservedDriverId']?.toString().trim() ?? '';

          if (data['state'] != 'reserved' ||
              reservedDriverId != widget.driverId) {
            throw StateError(
              'This pickup is no longer reserved by you.',
            );
          }

          transaction.update(
            ref,
            <String, dynamic>{
              'state': 'available',
              'reservationKey': '',
              'reservedDriverId': '',
              'reservedDriverName': '',
              'reservedDriverPhone': '',
              'reservedDriverEmail': '',
              'reservedAt': null,
              'reservationExpiresAt': null,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      ).timeout(
        const Duration(seconds: 12),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reservation released. The order is available again.',
            ),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Release timed out. Check internet and try again.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not release reservation: ${error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyOrderId = null;
        });
      }
    }
  }

  String _generatePickupCode() {
    final Random random =
        Random.secure();

    return (100000 +
            random.nextInt(900000))
        .toString();
  }

  String _generatePickupToken() {
    const String alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789';

    final Random random =
        Random.secure();

    return List<String>.generate(
      32,
      (_) => alphabet[
        random.nextInt(
          alphabet.length,
        )
      ],
    ).join();
  }

  Future<Map<String, dynamic>>
      _getOrCreatePickupVerification(
    Map<String, dynamic> pool,
  ) async {
    final String orderId =
        pool['orderId']?.toString().trim() ??
            pool['poolId']
                ?.toString()
                .trim() ??
            '';

    final String reservedDriverId =
        pool['reservedDriverId']
                ?.toString()
                .trim() ??
            '';

    final String reservationKey =
        pool['reservationKey']
                ?.toString()
                .trim() ??
            '';

    if (orderId.isEmpty ||
        reservedDriverId !=
            widget.driverId ||
        reservationKey.isEmpty ||
        _reservationExpired(pool)) {
      throw StateError(
        'Reserve this order first. The reservation must still be active.',
      );
    }

    final DocumentReference<
            Map<String, dynamic>>
        verificationRef =
        FirebaseFirestore.instance
            .collection(
              'krishi_delivery_pool',
            )
            .doc(orderId)
            .collection(
              'pickup_private',
            )
            .doc('verification');

    final DocumentSnapshot<
            Map<String, dynamic>>
        existing =
        await verificationRef.get().timeout(
          const Duration(seconds: 10),
        );

    final Map<String, dynamic>?
        existingData =
        existing.data();

    if (existing.exists &&
        existingData != null &&
        existingData['driverId']
                ?.toString()
                .trim() ==
            widget.driverId &&
        existingData['reservationKey']
                ?.toString()
                .trim() ==
            reservationKey &&
        existingData['isActive'] ==
            true) {
      final String code =
          existingData['pickupCode']
                  ?.toString()
                  .trim() ??
              '';

      final String qr =
          existingData['qrPayload']
                  ?.toString()
                  .trim() ??
              '';

      if (RegExp(r'^\d{6}$')
              .hasMatch(code) &&
          qr.startsWith(
            'NRD_PICKUP|',
          )) {
        return existingData;
      }
    }

    final String code =
        _generatePickupCode();
    final String token =
        _generatePickupToken();
    final String qrPayload =
        'NRD_PICKUP|$orderId|'
        '${widget.driverId}|$token';
    final String now =
        DateTime.now()
            .toIso8601String();

    final Map<String, dynamic>
        verification =
        <String, dynamic>{
      'orderId': orderId,
      'driverId':
          widget.driverId,
      'reservationKey':
          reservationKey,
      'pickupCode': code,
      'qrPayload': qrPayload,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    };

    await verificationRef.set(
      verification,
      SetOptions(merge: false),
    );

    return verification;
  }

  Future<void> _showPickupProof(
    Map<String, dynamic> pool,
  ) async {
    final Future<Map<String, dynamic>> proofFuture =
        _getOrCreatePickupVerification(pool);

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Farm Pickup Verification',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SizedBox(
            width: 330,
            child: FutureBuilder<Map<String, dynamic>>(
              future: proofFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<Map<String, dynamic>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text(
                          'Preparing pickup QR & 6-digit code...',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  String message = snapshot.error
                          ?.toString()
                          .replaceFirst('Bad state: ', '')
                          .replaceFirst('Exception: ', '') ??
                      'Could not prepare pickup QR/code.';

                  if (snapshot.error is TimeoutException) {
                    message =
                        'Pickup QR/code timed out. Check internet and try again.';
                  } else if (snapshot.error is FirebaseException &&
                      (snapshot.error! as FirebaseException).code ==
                          'permission-denied') {
                    message =
                        'Pickup QR/code permission was denied. Deploy the latest Firestore rules and retry.';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final Map<String, dynamic> verification = snapshot.data!;
                final String code =
                    verification['pickupCode']?.toString().trim() ?? '';
                final String qr =
                    verification['qrPayload']?.toString().trim() ?? '';

                if (!RegExp(r'^\d{6}$').hasMatch(code) || qr.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Pickup QR or code is not available. Close and retry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Show this QR or 6-digit code to the Krishi seller only when you are physically collecting the parcel.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.white,
                        child: QrImageView(
                          data: qr,
                          version: QrVersions.auto,
                          size: 210,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'PICKUP CODE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        code,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'The order becomes your real delivery only after the seller verifies this proof and hands over the parcel.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFarmDirections(
    double latitude,
    double longitude,
  ) async {
    final Map<String, String> query =
        <String, String>{
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    };

    if (_latitude != null &&
        _longitude != null) {
      query['origin'] =
          '$_latitude,$_longitude';
    }

    final Uri uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      query,
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showNearbyMessage(
          'Farm pickup navigation could not be opened.',
        );
      }
    } catch (_) {
      _showNearbyMessage(
        'Farm pickup navigation could not be opened.',
      );
    }
  }

  Future<void> _openFullKrishiRoute(
    double farmLat,
    double farmLng,
    double customerLat,
    double customerLng,
  ) async {
    final Map<String, String> query =
        <String, String>{
      'api': '1',
      'destination': '$customerLat,$customerLng',
      'waypoints': '$farmLat,$farmLng',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    };

    if (_latitude != null &&
        _longitude != null) {
      query['origin'] =
          '$_latitude,$_longitude';
    }

    final Uri uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      query,
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showNearbyMessage(
          'Full Krishi delivery route could not be opened.',
        );
      }
    } catch (_) {
      _showNearbyMessage(
        'Full Krishi delivery route could not be opened.',
      );
    }
  }

  Future<void> _callFarm(
    String phone,
  ) async {
    final String clean =
        phone
            .replaceAll(' ', '')
            .replaceAll('-', '')
            .trim();

    if (clean.isEmpty) {
      return;
    }

    await launchUrl(
      Uri(
        scheme: 'tel',
        path: clean,
      ),
      mode:
          LaunchMode.externalApplication,
    );
  }

  Widget _poolCard(
    Map<String, dynamic> pool,
  ) {
    final String orderId =
        pool['orderId']?.toString().trim() ??
            pool['poolId']
                ?.toString()
                .trim() ??
            '';

    final String farmName =
        pool['farmName']
                ?.toString()
                .trim() ??
            'Krishi Farm';

    final String farmAddress =
        pool['farmAddress']
                ?.toString()
                .trim() ??
            '';

    final String farmPhone =
        pool['farmPhone']
                ?.toString()
                .trim() ??
            '';

    final double? farmLat =
        _toDouble(pool['farmLat']);
    final double? farmLng =
        _toDouble(pool['farmLng']);
    final double? customerLat =
        _toDouble(pool['customerLat']);
    final double? customerLng =
        _toDouble(pool['customerLng']);

    final double? youToFarm =
        _driverToFarmKm(pool);

    final double? farmToCustomer =
        _toDouble(
      pool['farmToCustomerKm'],
    );

    final double? totalRoute =
        youToFarm != null &&
                farmToCustomer != null
            ? youToFarm +
                farmToCustomer
            : null;

    final String state =
        pool['state']
                ?.toString()
                .trim() ??
            'available';

    final String reservedDriverId =
        pool['reservedDriverId']
                ?.toString()
                .trim() ??
            '';

    final bool expired =
        state == 'reserved' &&
            _reservationExpired(pool);

    final bool reservedByMe =
        state == 'reserved' &&
            reservedDriverId ==
                widget.driverId &&
            !expired;

    final bool reservedByOther =
        state == 'reserved' &&
            reservedDriverId.isNotEmpty &&
            reservedDriverId !=
                widget.driverId &&
            !expired;

    final int itemCount =
        (pool['itemCount'] as num?)
                ?.toInt() ??
            0;

    final String amount =
        pool['orderAmount']
                ?.toString()
                .trim() ??
            '';

    final bool busy =
        _busyOrderId == orderId;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor:
                      Colors.green,
                  child: Icon(
                    Icons.agriculture,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      Text(
                        farmName,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      Text(
                        'Order #$orderId',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey
                              .shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    reservedByMe
                        ? 'RESERVED BY YOU'
                        : reservedByOther
                            ? 'RESERVED'
                            : expired
                                ? 'AVAILABLE AGAIN'
                                : 'AVAILABLE',
                  ),
                ),
              ],
            ),
            if (farmAddress.isNotEmpty) ...<Widget>[
              const SizedBox(
                height: 8,
              ),
              Text(
                farmAddress,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(
              height: 12,
            ),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.green
                    .withValues(
                  alpha: 0.07,
                ),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: <Widget>[
                  Text(
                    'You → Farm: ${_distanceText(youToFarm)}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    'Farm → Customer: ${_distanceText(farmToCustomer)}',
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    'Estimated route: ${_distanceText(totalRoute)}',
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Items: $itemCount'
              '${amount.isEmpty ? '' : ' • Order amount: Rs. $amount'}',
            ),
            const SizedBox(
              height: 10,
            ),
            if (farmLat != null &&
                farmLng != null &&
                customerLat != null &&
                customerLng != null) ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    _openFullKrishiRoute(
                      farmLat,
                      farmLng,
                      customerLat,
                      customerLng,
                    );
                  },
                  icon: const Icon(
                    Icons.route_rounded,
                  ),
                  label: const Text(
                    'Track Full Route: You → Farm → Customer',
                  ),
                ),
              ),
              const SizedBox(
                height: 8,
              ),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        farmLat == null ||
                                farmLng ==
                                    null
                            ? null
                            : () {
                                _openFarmDirections(
                                  farmLat,
                                  farmLng,
                                );
                              },
                    icon:
                        const Icon(
                      Icons.navigation,
                    ),
                    label:
                        const Text(
                      'Track Farm Pickup',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        farmPhone.isEmpty
                            ? null
                            : () {
                                _callFarm(
                                  farmPhone,
                                );
                              },
                    icon:
                        const Icon(
                      Icons.call,
                    ),
                    label:
                        const Text(
                      'Call Farm',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            if (reservedByMe) ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          _showPickupProof(
                            pool,
                          );
                        },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text(
                    'Show Pickup QR / Code at Farm',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          _releaseReservation(pool);
                        },
                  icon: const Icon(Icons.undo),
                  label: const Text('Release Reservation'),
                ),
              ),
            ] else if (reservedByOther) ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.lock_outline),
                  label: Text(
                    'Reserved by another delivery person',
                  ),
                ),
              ),
            ] else ...<Widget>[
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('krishi_delivery_pool')
                    .doc(orderId)
                    .collection('pickup_requests')
                    .doc(widget.driverId)
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                      requestSnapshot,
                ) {
                  final Map<String, dynamic> request =
                      requestSnapshot.data?.data() ?? <String, dynamic>{};
                  final String requestStatus =
                      request['status']?.toString().trim() ?? '';
                  final String requestedBy =
                      request['requestedBy']?.toString().trim() ?? '';

                  if (requestStatus == 'pending_seller' &&
                      requestedBy == 'driver') {
                    return Column(
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(
                              Icons.hourglass_top_rounded,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Waiting for Farm Seller Approval',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () {
                                    _cancelPickupRequest(pool);
                                  },
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Cancel Pickup Request'),
                          ),
                        ),
                      ],
                    );
                  }

                  if (requestStatus == 'pending_driver' &&
                      requestedBy == 'seller') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Farm Seller requested you to pick up this order.',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () {
                                        _acceptFarmPickupRequest(pool);
                                      },
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Accept Farm Request'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () {
                                        _declineFarmPickupRequest(pool);
                                      },
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Decline'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              _reserveOrder(pool);
                            },
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        expired
                            ? 'Request Pickup Again'
                            : 'Request Pickup from Farm',
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Customer GPS route is visible for planning. Customer phone and text address stay private until the farm verifies pickup.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nearby Krishi Orders',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip:
                'Refresh GPS',
            onPressed:
                _refreshingLocation
                    ? null
                    : _refreshLocation,
            icon: const Icon(
              Icons.gps_fixed,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            margin:
                const EdgeInsets.all(
              12,
            ),
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color: Colors.green
                  .withValues(
                alpha: 0.08,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: const Text(
              'New Krishi customer orders appear here automatically. Nearest farm orders appear first. There is no fixed limit on how many pickups you may reserve, but every parcel must be verified separately by that farm before it becomes an active delivery.',
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<
                List<
                    Map<String,
                        dynamic>>>(
              stream:
                  _poolStream(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        List<
                            Map<String,
                                dynamic>>>
                    snapshot,
              ) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        20,
                      ),
                      child: Text(
                        'Could not load nearby Krishi orders.\n${snapshot.error}',
                        textAlign:
                            TextAlign
                                .center,
                      ),
                    ),
                  );
                }

                final List<
                        Map<String,
                            dynamic>>
                    orders =
                    snapshot.data ??
                        <Map<String,
                            dynamic>>[];

                if (orders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children:
                          <Widget>[
                        Icon(
                          Icons
                              .agriculture_outlined,
                          size: 72,
                          color:
                              Colors.grey,
                        ),
                        SizedBox(
                          height: 12,
                        ),
                        Text(
                          'No Krishi pickup orders are ready nearby.',
                          style:
                              TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh:
                      _refreshLocation,
                  child:
                      ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      16,
                    ),
                    itemCount:
                        orders.length,
                    itemBuilder: (
                      BuildContext context,
                      int index,
                    ) {
                      return _poolCard(
                        orders[index],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryPersonEditProfilePage extends StatefulWidget {
  const DeliveryPersonEditProfilePage({
    required this.deliveryPersonId,
    required this.initialData,
    super.key,
  });

  final String deliveryPersonId;
  final Map<String, dynamic> initialData;

  @override
  State<DeliveryPersonEditProfilePage> createState() =>
      _DeliveryPersonEditProfilePageState();
}

class _DeliveryPersonEditProfilePageState
    extends State<DeliveryPersonEditProfilePage> {
  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset =
      'rd_online_shop_products';

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController
      _vehicleNumberController;
  late final TextEditingController
      _licenseNumberController;
  late final TextEditingController
      _licenseExpiryController;

  late String _photoUrl;
  late String _licenseFrontUrl;
  late String _licenseBackUrl;

  bool _saving = false;
  bool _uploadingImage = false;

  String _value(
    Map<String, dynamic> data,
    String key,
  ) {
    return data[key]?.toString().trim() ?? '';
  }

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic> data =
        widget.initialData;

    _nameController =
        TextEditingController(
      text: _value(data, 'name'),
    );

    _phoneController =
        TextEditingController(
      text: _value(data, 'phone'),
    );

    _vehicleNumberController =
        TextEditingController(
      text: _value(data, 'vehicleNumber'),
    );

    _licenseNumberController =
        TextEditingController(
      text:
          _value(data, 'drivingLicenseNumber'),
    );

    _licenseExpiryController =
        TextEditingController(
      text:
          _value(data, 'drivingLicenseExpiry'),
    );

    _photoUrl =
        _value(data, 'photoUrl');
    _licenseFrontUrl =
        _value(data, 'drivingLicenseFrontUrl');
    _licenseBackUrl =
        _value(data, 'drivingLicenseBackUrl');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleNumberController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    super.dispose();
  }

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

  Future<String> _uploadImage(
    XFile image,
  ) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );

    final http.StreamedResponse response =
        await request.send();

    final String body =
        await response.stream.bytesToString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Image upload failed: $body',
      );
    }

    final dynamic decoded =
        jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid image upload response.',
      );
    }

    final String url =
        decoded['secure_url']
                ?.toString()
                .trim() ??
            '';

    if (url.isEmpty) {
      throw Exception(
        'Image URL was not received.',
      );
    }

    return url;
  }

  Future<void> _pickImage({
    required String type,
  }) async {
    if (_uploadingImage || _saving) {
      return;
    }

    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _uploadingImage = true;
    });

    try {
      final String url =
          await _uploadImage(image);

      if (!mounted) {
        return;
      }

      setState(() {
        switch (type) {
          case 'profile':
            _photoUrl = url;
            break;
          case 'front':
            _licenseFrontUrl = url;
            break;
          case 'back':
            _licenseBackUrl = url;
            break;
        }
      });

      _showMessage(
        'Photo uploaded successfully.',
      );
    } catch (error) {
      _showMessage(
        'Photo upload failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _selectLicenseExpiry() async {
    DateTime initialDate =
        DateTime.now().add(
      const Duration(days: 365),
    );

    final DateTime? parsed =
        DateTime.tryParse(
      _licenseExpiryController.text.trim(),
    );

    if (parsed != null) {
      initialDate = parsed;
    }

    final DateTime firstDate =
        DateTime.now();

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(
        firstDate.year + 20,
      ),
    );

    if (selected == null) {
      return;
    }

    _licenseExpiryController.text =
        '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
  }

  bool get _sensitiveDocumentsChanged {
    final Map<String, dynamic> original =
        widget.initialData;

    return _vehicleNumberController.text
                .trim() !=
            _value(
              original,
              'vehicleNumber',
            ) ||
        _licenseNumberController.text
                .trim() !=
            _value(
              original,
              'drivingLicenseNumber',
            ) ||
        _licenseExpiryController.text
                .trim() !=
            _value(
              original,
              'drivingLicenseExpiry',
            ) ||
        _licenseFrontUrl !=
            _value(
              original,
              'drivingLicenseFrontUrl',
            ) ||
        _licenseBackUrl !=
            _value(
              original,
              'drivingLicenseBackUrl',
            );
  }

  Future<void> _save() async {
    final FormState? form =
        _formKey.currentState;

    if (form == null ||
        !form.validate() ||
        _saving ||
        _uploadingImage) {
      return;
    }

    if (_photoUrl.isEmpty) {
      _showMessage(
        'Please upload a profile photo.',
      );
      return;
    }

    if (_licenseFrontUrl.isEmpty ||
        _licenseBackUrl.isEmpty) {
      _showMessage(
        'Please upload both front and back of the driving licence.',
      );
      return;
    }

    final bool requiresReapproval =
        _sensitiveDocumentsChanged;

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> update =
          <String, dynamic>{
        'name':
            _nameController.text.trim(),
        'phone':
            _phoneController.text.trim(),
        'vehicleNumber':
            _vehicleNumberController.text.trim(),
        'drivingLicenseNumber':
            _licenseNumberController.text.trim(),
        'drivingLicenseExpiry':
            _licenseExpiryController.text.trim(),
        'photoUrl': _photoUrl,
        'drivingLicenseFrontUrl':
            _licenseFrontUrl,
        'drivingLicenseBackUrl':
            _licenseBackUrl,
        'updatedAt':
            DateTime.now().toIso8601String(),
      };

      if (requiresReapproval) {
        update.addAll(
          <String, dynamic>{
            'drivingLicenseVerified': false,
            'drivingLicenseVerifiedAt': null,
            'isApproved': false,
            'isOnline': false,
            'approvalStatus': 'pending',
            'documentReviewRequestedAt':
                FieldValue.serverTimestamp(),
          },
        );
      }

      await FirebaseFirestore.instance
          .collection('delivery_persons')
          .doc(widget.deliveryPersonId)
          .set(
        update,
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop<bool>(
        context,
        requiresReapproval,
      );
    } catch (error) {
      _showMessage(
        'Could not save profile: $error',
      );

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _photoCard({
    required String title,
    required String url,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 170,
            child: url.isEmpty
                ? Center(
                    child: Icon(
                      icon,
                      size: 58,
                      color:
                          Colors.grey.shade500,
                    ),
                  )
                : ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace?
                            stackTrace,
                      ) {
                        return const Center(
                          child: Icon(
                            Icons
                                .broken_image_outlined,
                            size: 56,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed:
                _uploadingImage
                    ? null
                    : onTap,
            icon: const Icon(
              Icons.photo_library_outlined,
            ),
            label: Text(
              url.isEmpty
                  ? 'Choose Photo'
                  : 'Change Photo',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Delivery Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller:
                  _nameController,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText: 'Full Name',
                prefixIcon:
                    Icon(Icons.person),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please enter full name';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller:
                  _phoneController,
              keyboardType:
                  TextInputType.phone,
              decoration:
                  const InputDecoration(
                labelText:
                    'Phone Number',
                prefixIcon:
                    Icon(Icons.phone),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  (String? value) {
                final String phone =
                    value?.trim() ?? '';

                if (phone.isEmpty) {
                  return 'Please enter phone number';
                }

                if (phone.length < 7) {
                  return 'Please enter a valid phone number';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller:
                  _vehicleNumberController,
              textCapitalization:
                  TextCapitalization.characters,
              decoration:
                  const InputDecoration(
                labelText:
                    'Vehicle Number',
                prefixIcon:
                    Icon(Icons.local_shipping),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please enter vehicle number';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller:
                  _licenseNumberController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Driving Licence Number',
                prefixIcon:
                    Icon(Icons.badge_outlined),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please enter driving licence number';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller:
                  _licenseExpiryController,
              readOnly: true,
              onTap:
                  _selectLicenseExpiry,
              decoration:
                  InputDecoration(
                labelText:
                    'Licence Expiry Date',
                prefixIcon:
                    const Icon(
                  Icons.event,
                ),
                suffixIcon:
                    IconButton(
                  onPressed:
                      _selectLicenseExpiry,
                  icon: const Icon(
                    Icons
                        .calendar_month,
                  ),
                ),
                border:
                    const OutlineInputBorder(),
              ),
              validator:
                  (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please select licence expiry date';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            _photoCard(
              title: 'Profile Photo',
              url: _photoUrl,
              icon:
                  Icons.person_outline,
              onTap: () =>
                  _pickImage(
                type: 'profile',
              ),
            ),
            const SizedBox(height: 12),
            _photoCard(
              title:
                  'Driving Licence Front',
              url:
                  _licenseFrontUrl,
              icon:
                  Icons.badge_outlined,
              onTap: () =>
                  _pickImage(
                type: 'front',
              ),
            ),
            const SizedBox(height: 12),
            _photoCard(
              title:
                  'Driving Licence Back',
              url:
                  _licenseBackUrl,
              icon:
                  Icons.badge_outlined,
              onTap: () =>
                  _pickImage(
                type: 'back',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors
                    .orange
                    .withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: const Text(
                'Changing vehicle or driving licence details sends the account back for Admin verification. '
                'Name, phone or profile-photo changes do not require licence re-verification.',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    _saving ||
                            _uploadingImage
                        ? null
                        : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _uploadingImage
                          ? 'Uploading Photo...'
                          : 'Save Changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

