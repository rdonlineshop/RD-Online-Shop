import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  String _deliveryPersonName = '';
  String _deliveryPersonPhone = '';
  String _deliveryPersonId = '';

  @override
  void initState() {
    super.initState();
    _loadDeliveryPerson();
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

        _isLoading = false;
      });
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

    await verificationRef.set(
      verification,
      SetOptions(merge: false),
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

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    if (!mounted) {
      return;
    }

    Navigator.pop(
      context,
    );
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

                            const Chip(
                              label: Text(
                                'Online',
                              ),
                            ),
                          ],
                        ),
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
