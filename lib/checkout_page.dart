import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/cart_data.dart';
import 'order_data.dart';
import 'order_history_page.dart';

class CheckoutPage extends StatefulWidget {
  final double cartSubtotal;
  final double discountAmount;
  final bool freeDeliveryCoupon;

  const CheckoutPage({
    super.key,
    required this.cartSubtotal,
    required this.discountAmount,
    required this.freeDeliveryCoupon,
  });

  @override
  State<CheckoutPage> createState() =>
      _CheckoutPageState();
}

class _CheckoutPageState
    extends State<CheckoutPage> {
  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController cityController =
      TextEditingController();

  final TextEditingController areaController =
      TextEditingController();

  final TextEditingController landmarkController =
      TextEditingController();

  Geocoding? geocoding;

  String deliveryAddress =
      'Select your delivery address';

  String selectedPayment =
      'Cash on Delivery';

  String selectedDeliveryArea =
      'Kathmandu Valley';

  String savedAddress = '';

  String locationSource = '';

  bool isLoadingLocation = false;
  bool isLoadingSavedAddress = true;
  bool isGeocodingManualAddress = false;

  double? latitude;
  double? longitude;

  double? savedLatitude;
  double? savedLongitude;

  static const Map<String, double>
      _areaCharges =
      <String, double>{
    'Kathmandu Valley': 100,
    'Major City': 150,
    'Outside Kathmandu Valley': 250,
    'Remote Area': 400,
    'Store Pickup': 0,
  };

  double get _deliveryCharge {
    if (widget.freeDeliveryCoupon ||
        selectedDeliveryArea ==
            'Store Pickup') {
      return 0;
    }

    return _areaCharges[
            selectedDeliveryArea] ??
        0;
  }

  double get _finalTotal =>
      widget.cartSubtotal -
      widget.discountAmount +
      _deliveryCharge;

  bool get _hasValidCoordinates =>
      latitude != null &&
      longitude != null;

  @override
  void initState() {
    super.initState();

    // Geocoding has no Windows implementation. Avoid crashing the page
    // while keeping address lookup available on supported platforms.
    try {
      geocoding = Geocoding();
    } catch (_) {
      geocoding = null;
    }

    _loadSavedAddress();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _getCurrentLocation();
      },
    );
  }

  // =========================================================
  // SAVED DELIVERY ADDRESS
  // =========================================================

  Future<void> _loadSavedAddress() async {
    final SharedPreferences preferences =
        await SharedPreferences
            .getInstance();

    final String? address =
        preferences.getString(
      'saved_delivery_address',
    );

    final double? lat =
        preferences.getDouble(
      'saved_delivery_latitude',
    );

    final double? lng =
        preferences.getDouble(
      'saved_delivery_longitude',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      savedAddress =
          address ?? '';

      savedLatitude =
          lat;

      savedLongitude =
          lng;

      isLoadingSavedAddress =
          false;
    });
  }

  Future<void> _saveAddress({
    required String address,
    required double? lat,
    required double? lng,
  }) async {
    final SharedPreferences preferences =
        await SharedPreferences
            .getInstance();

    await preferences.setString(
      'saved_delivery_address',
      address,
    );

    if (lat != null) {
      await preferences.setDouble(
        'saved_delivery_latitude',
        lat,
      );
    } else {
      await preferences.remove(
        'saved_delivery_latitude',
      );
    }

    if (lng != null) {
      await preferences.setDouble(
        'saved_delivery_longitude',
        lng,
      );
    } else {
      await preferences.remove(
        'saved_delivery_longitude',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      savedAddress =
          address;

      savedLatitude =
          lat;

      savedLongitude =
          lng;
    });
  }

  // =========================================================
  // MANUAL ADDRESS
  // =========================================================

  Future<void> _useManualAddress() async {
    final String city =
        cityController.text.trim();

    final String area =
        areaController.text.trim();

    final String landmark =
        landmarkController.text.trim();

    if (city.isEmpty ||
        area.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter City and Area.',
          ),
        ),
      );

      return;
    }

    final String address =
        <String>[
      area,
      city,
      if (landmark.isNotEmpty)
        landmark,
    ].join(', ');

    setState(() {
      isGeocodingManualAddress =
          true;
    });

    try {
      final Geocoding? geocoder =
          geocoding;

      if (geocoder == null) {
        throw UnsupportedError(
          'Address search is not supported on this device. Please use Current Location.',
        );
      }

      final List<Location> locations =
          await geocoder.locationFromAddress(
        address,
      );

      if (locations.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Could not find this address on map. Please use Current Location.',
            ),
          ),
        );

        return;
      }

      final Location location =
          locations.first;

      if (!mounted) {
        return;
      }

      setState(() {
        deliveryAddress =
            address;

        selectedDeliveryArea =
            _suggestAreaFromAddress(
          address,
        );

        latitude =
            location.latitude;

        longitude =
            location.longitude;

        locationSource =
            'Manual Address';
      });

      await _saveAddress(
        address:
            address,
        lat:
            location.latitude,
        lng:
            location.longitude,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Address saved with map location.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not locate address on map: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeocodingManualAddress =
              false;
        });
      }
    }
  }

  // =========================================================
  // SAVED ADDRESS
  // =========================================================

  void _useSavedAddress() {
    if (savedAddress.isEmpty) {
      return;
    }

    setState(() {
      deliveryAddress =
          savedAddress;

      selectedDeliveryArea =
          _suggestAreaFromAddress(
        savedAddress,
      );

      latitude =
          savedLatitude;

      longitude =
          savedLongitude;

      locationSource =
          'Saved Address';
    });

    if (savedLatitude == null ||
        savedLongitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'This old saved address has no map coordinates. Please use Current Location or save the address again.',
          ),
        ),
      );
    }
  }

  // =========================================================
  // DELIVERY AREA
  // =========================================================

  String _suggestAreaFromAddress(
    String address,
  ) {
    final String lowerAddress =
        address.toLowerCase();

    if (lowerAddress.contains(
          'kathmandu',
        ) ||
        lowerAddress.contains(
          'lalitpur',
        ) ||
        lowerAddress.contains(
          'bhaktapur',
        )) {
      return 'Kathmandu Valley';
    }

    if (lowerAddress.contains(
          'pokhara',
        ) ||
        lowerAddress.contains(
          'chitwan',
        ) ||
        lowerAddress.contains(
          'biratnagar',
        ) ||
        lowerAddress.contains(
          'butwal',
        ) ||
        lowerAddress.contains(
          'nepalgunj',
        )) {
      return 'Major City';
    }

    return 'Outside Kathmandu Valley';
  }

  // =========================================================
  // CURRENT GPS LOCATION
  // =========================================================

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        isLoadingLocation =
            true;
      });
    }

    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Please turn on GPS / Location.',
              ),
            ),
          );
        }

        return;
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
              LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission was denied.',
              ),
            ),
          );
        }

        return;
      }

      final Position position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      List<Placemark> placemarks =
          <Placemark>[];

      final Geocoding? geocoder =
          geocoding;

      if (geocoder != null) {
        try {
          placemarks =
              await geocoder.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
        } catch (_) {
          // GPS coordinates remain usable if reverse geocoding is unavailable.
        }
      }

      String address =
          '${position.latitude}, '
          '${position.longitude}';

      if (placemarks.isNotEmpty) {
        final Placemark place =
            placemarks.first;

        address = <String?>[
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ]
            .where(
              (String? value) =>
                  value != null &&
                  value
                      .trim()
                      .isNotEmpty,
            )
            .map(
              (String? value) =>
                  value?.trim() ?? '',
            )
            .join(', ');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        deliveryAddress =
            address;

        selectedDeliveryArea =
            _suggestAreaFromAddress(
          address,
        );

        latitude =
            position.latitude;

        longitude =
            position.longitude;

        locationSource =
            'GPS Current Location';
      });

      await _saveAddress(
        address:
            address,
        lat:
            position.latitude,
        lng:
            position.longitude,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Location error: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingLocation =
              false;
        });
      }
    }
  }

  // =========================================================
  // PLACE ORDER
  // =========================================================

  Future<void> _placeOrder() async {
    if (nameController.text
            .trim()
            .isEmpty ||
        phoneController.text
            .trim()
            .isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your name and mobile number.',
          ),
        ),
      );

      return;
    }

    if (selectedDeliveryArea !=
        'Store Pickup') {
      if (deliveryAddress ==
          'Select your delivery address') {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Please select your delivery location.',
            ),
          ),
        );

        return;
      }

      if (!_hasValidCoordinates) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Map location is missing. Please use Current Location or save the manual address again.',
            ),
          ),
        );

        return;
      }
    }

    final String orderId =
        'RD${DateTime.now().millisecondsSinceEpoch}';

    final List<Map<String, dynamic>>
        orderedItems =
        cartItems.map(
      (Map<String, dynamic> item) {
        return <String, dynamic>{
          'productId':
              item['productId']
                      ?.toString() ??
                  '',

          'sellerId':
              item['sellerId']
                      ?.toString() ??
                  '',

          'sellerShopName':
              item['sellerShopName'] ??
                  '',

          'sellerLatitude':
              item['sellerLatitude'],

          'sellerLongitude':
              item['sellerLongitude'],

          'name':
              item['name'],

          'productName':
              item['productName'] ??
                  item['name'],

          'price':
              item['price'],

          'quantity':
              item['quantity'] ?? 1,

          'image':
              item['image'],

          if (item['selectedColor'] !=
              null)
            'selectedColor':
                item[
                    'selectedColor'],

          if (item['selectedSize'] !=
              null)
            'selectedSize':
                item[
                    'selectedSize'],
        };
      },
    ).toList();

    final Set<String> uniqueSellerIds =
        orderedItems
            .map(
              (
                Map<String, dynamic>
                    item,
              ) =>
                  item['sellerId']
                          ?.toString()
                          .trim() ??
                      '',
            )
            .where(
              (String sellerId) =>
                  sellerId.isNotEmpty,
            )
            .toSet();

    final List<String> sellerIds =
        uniqueSellerIds.toList();

    final DateTime now =
        DateTime.now();

    // =======================================================
    // DELIVERY OTP
    // =======================================================

    final Random random =
        Random.secure();

    final String deliveryOtp =
        (100000 +
                random.nextInt(
                  900000,
                ))
            .toString();

    // =======================================================
    // CUSTOMER UNIQUE ID
    // =======================================================

    final String customerId =
        await getOrCreateCustomerId();

    await addOrder(
      <String, dynamic>{
        'id': orderId,

        // =====================================================
        // CUSTOMER OWNERSHIP
        // =====================================================

        'customerId':
            customerId,

        'customerName':
            nameController.text
                .trim(),

        'name':
            nameController.text
                .trim(),

        'phone':
            phoneController.text
                .trim(),

        // =====================================================
        // DELIVERY ADDRESS
        // =====================================================

        'address':
            selectedDeliveryArea ==
                    'Store Pickup'
                ? 'Store Pickup'
                : deliveryAddress,

        'deliveryArea':
            selectedDeliveryArea,

        // =====================================================
        // OLD LOCATION FIELDS
        // =====================================================

        'latitude':
            latitude?.toString(),

        'longitude':
            longitude?.toString(),

        // =====================================================
        // CUSTOMER TRACKING LOCATION
        // =====================================================

        'customerLat':
            selectedDeliveryArea ==
                    'Store Pickup'
                ? null
                : latitude,

        'customerLng':
            selectedDeliveryArea ==
                    'Store Pickup'
                ? null
                : longitude,

        'customerAddress':
            selectedDeliveryArea ==
                    'Store Pickup'
                ? 'Store Pickup'
                : deliveryAddress,

        'customerLocationSource':
            selectedDeliveryArea ==
                    'Store Pickup'
                ? 'Store Pickup'
                : locationSource,

        'customerLocationUpdatedAt':
            now.toIso8601String(),

        // =====================================================
        // SELLER OWNERSHIP
        // =====================================================

        'sellerIds':
            sellerIds,

        // =====================================================
        // PAYMENT
        // =====================================================

        'payment':
            selectedPayment,

        // =====================================================
        // PRICE
        // =====================================================

        'subtotal':
            widget.cartSubtotal
                .toStringAsFixed(
                  0,
                ),

        'discount':
            widget.discountAmount
                .toStringAsFixed(
                  0,
                ),

        'delivery':
            _deliveryCharge
                .toStringAsFixed(
                  0,
                ),

        'amount':
            _finalTotal
                .toStringAsFixed(
                  0,
                ),

        // =====================================================
        // PRODUCTS
        // =====================================================

        'items':
            orderedItems,

        // =====================================================
        // ORDER
        // =====================================================

        'orderDateTime':
            now.toIso8601String(),

        'status':
            'Pending',

        // =====================================================
        // SECURE DELIVERY VERIFICATION
        // =====================================================

        'deliveryOtp':
            deliveryOtp,

        'deliveryOtpVerified':
            false,

        'deliveryOtpCreatedAt':
            now.toIso8601String(),

        'deliveryOtpVerifiedAt':
            null,

        'deliveryVerifiedAt':
            null,

        'deliveryVerifiedBy':
            '',

        'deliveryConfirmationMethod':
            '',

        // =====================================================
        // LIVE TRACKING FOUNDATION
        // =====================================================

        'trackingEnabled':
            true,

        'trackingStatus':
            'Order Placed',

        'driverId':
            '',

        'driverName':
            '',

        'driverPhone':
            '',

        'driverEmail':
            '',

        'driverLat':
            null,

        'driverLng':
            null,

        'driverLocationUpdatedAt':
            null,

        'deliveryStartedAt':
            null,

        'deliveredAt':
            null,
      },
    );

    await clearCart();

    if (!mounted) {
      return;
    }

    showDialog<void>(
      context:
          context,
      builder:
          (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text(
            'Order Placed',
          ),
          content:
              Text(
            'Your order has been placed successfully.\n\n'
            'Order ID: $orderId\n'
            'Final amount: Rs. ${_finalTotal.toStringAsFixed(0)}\n\n'
            'Delivery Code: $deliveryOtp\n\n'
            'Keep this code private. Give it to the delivery person only after receiving your order.\n\n'
            'Delivery location has been saved for tracking.',
          ),
          actions:
              <Widget>[
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                );

                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder:
                        (_) =>
                            const OrderHistoryPage(),
                  ),
                );
              },
              child:
                  const Text(
                'View Order',
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // TOTAL ROW
  // =========================================================

  Widget _totalRow(
    String label,
    double amount, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : null,
            ),
          ),
          Text(
            label == 'Delivery' &&
                    amount == 0
                ? 'Free'
                : 'Rs. ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LOCATION STATUS
  // =========================================================

  Widget _locationStatus() {
    if (selectedDeliveryArea ==
        'Store Pickup') {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(
          12,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.blue.shade50,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
        ),
        child:
            const Row(
          children: <Widget>[
            Icon(
              Icons.store,
              color:
                  Colors.blue,
            ),
            SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                'Store Pickup selected. Customer GPS location is not required.',
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasValidCoordinates) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(
          12,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.orange.shade50,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          border:
              Border.all(
            color:
                Colors.orange.shade200,
          ),
        ),
        child:
            const Row(
          children: <Widget>[
            Icon(
              Icons.location_off,
              color:
                  Colors.orange,
            ),
            SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                'Map location not saved yet.',
              ),
            ),
          ],
        ),
      );
    }

    final double? currentLat =
        latitude;

    final double? currentLng =
        longitude;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.green.shade50,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border:
            Border.all(
          color:
              Colors.green.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.location_on,
            color:
                Colors.green,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children:
                  <Widget>[
                const Text(
                  'Map Location Saved',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                if (currentLat !=
                    null)
                  Text(
                    'Lat: ${currentLat.toStringAsFixed(6)}',
                  ),
                if (currentLng !=
                    null)
                  Text(
                    'Lng: ${currentLng.toStringAsFixed(6)}',
                  ),
                if (locationSource
                    .isNotEmpty)
                  Text(
                    'Source: $locationSource',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PAYMENT OPTION
  // =========================================================

  Widget _paymentOption(
    String title,
    IconData icon,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        top: 8,
      ),
      child:
          RadioListTile<String>(
        value:
            title,
        title:
            Text(
          title,
        ),
        secondary:
            Icon(
          icon,
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    areaController.dispose();
    landmarkController.dispose();

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
      appBar:
          AppBar(
        title:
            const Text(
          'Checkout',
        ),
        centerTitle:
            true,
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children:
              <Widget>[
            const Text(
              'Customer Information',
              style:
                  TextStyle(
                fontSize:
                    18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            TextField(
              controller:
                  nameController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Full Name',
                prefixIcon:
                    Icon(
                  Icons.person,
                ),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            TextField(
              controller:
                  phoneController,
              keyboardType:
                  TextInputType.phone,
              decoration:
                  const InputDecoration(
                labelText:
                    'Mobile Number',
                prefixIcon:
                    Icon(
                  Icons.phone,
                ),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height:
                  25,
            ),

            const Text(
              'Manual Delivery Address',
              style:
                  TextStyle(
                fontSize:
                    18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            if (!isLoadingSavedAddress &&
                savedAddress
                    .isNotEmpty) ...<Widget>[
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.green.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  border:
                      Border.all(
                    color:
                        Colors.green.shade200,
                  ),
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children:
                      <Widget>[
                    const Text(
                      'Saved Address',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height:
                          4,
                    ),
                    Text(
                      savedAddress,
                    ),
                    Align(
                      alignment:
                          Alignment.centerRight,
                      child:
                          TextButton.icon(
                        onPressed:
                            _useSavedAddress,
                        icon:
                            const Icon(
                          Icons.check_circle_outline,
                        ),
                        label:
                            const Text(
                          'Use Saved Address',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height:
                    12,
              ),
            ],

            TextField(
              controller:
                  cityController,
              decoration:
                  const InputDecoration(
                labelText:
                    'City / District',
                prefixIcon:
                    Icon(
                  Icons.location_city,
                ),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            TextField(
              controller:
                  areaController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Area / Tole',
                prefixIcon:
                    Icon(
                  Icons.place,
                ),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            TextField(
              controller:
                  landmarkController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Landmark (optional)',
                prefixIcon:
                    Icon(
                  Icons.pin_drop,
                ),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed:
                    isGeocodingManualAddress
                        ? null
                        : _useManualAddress,
                icon:
                    isGeocodingManualAddress
                        ? const SizedBox(
                            width:
                                18,
                            height:
                                18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons.save_alt,
                          ),
                label:
                    const Text(
                  'Use & Save Manual Address',
                ),
              ),
            ),

            const SizedBox(
              height:
                  25,
            ),

            const Text(
              'Delivery Location',
              style:
                  TextStyle(
                fontSize:
                    18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            DropdownButtonFormField<
                String>(
              initialValue:
                  selectedDeliveryArea,
              decoration:
                  const InputDecoration(
                labelText:
                    'Select delivery area',
                prefixIcon:
                    Icon(
                  Icons.local_shipping,
                ),
                border:
                    OutlineInputBorder(),
              ),
              items:
                  _areaCharges.entries.map(
                (
                  MapEntry<String, double>
                      entry,
                ) {
                  return DropdownMenuItem<
                      String>(
                    value:
                        entry.key,
                    child:
                        Text(
                      entry.value ==
                              0
                          ? '${entry.key} — Free'
                          : '${entry.key} — Rs. ${entry.value.toStringAsFixed(0)}',
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  (
                String? value,
              ) {
                if (value ==
                    null) {
                  return;
                }

                setState(() {
                  selectedDeliveryArea =
                      value;
                });
              },
            ),

            if (widget
                .freeDeliveryCoupon) ...<Widget>[
              const SizedBox(
                height:
                    8,
              ),
              const Text(
                'FREEDELIVERY coupon applied — delivery is free.',
                style:
                    TextStyle(
                  color:
                      Colors.green,
                ),
              ),
            ],

            const SizedBox(
              height:
                  12,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children:
                  <Widget>[
                const Expanded(
                  child:
                      Text(
                    'Delivery Address',
                    style:
                        TextStyle(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      isLoadingLocation
                          ? null
                          : _getCurrentLocation,
                  icon:
                      isLoadingLocation
                          ? const SizedBox(
                              width:
                                  18,
                              height:
                                  18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons.my_location,
                            ),
                  label:
                      const Text(
                    'Use Current Location',
                  ),
                ),
              ],
            ),

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                14,
              ),
              decoration:
                  BoxDecoration(
                border:
                    Border.all(
                  color:
                      Colors.grey.shade300,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children:
                    <Widget>[
                  const Icon(
                    Icons.location_on,
                    color:
                        Colors.red,
                  ),
                  const SizedBox(
                    width:
                        10,
                  ),
                  Expanded(
                    child:
                        Text(
                      deliveryAddress,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            _locationStatus(),

            const SizedBox(
              height:
                  25,
            ),

            const Text(
              'Payment Method',
              style:
                  TextStyle(
                fontSize:
                    18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            RadioGroup<String>(
              groupValue:
                  selectedPayment,
              onChanged:
                  (
                String? value,
              ) {
                if (value !=
                    null) {
                  setState(() {
                    selectedPayment =
                        value;
                  });
                }
              },
              child:
                  Column(
                children:
                    <Widget>[
                  _paymentOption(
                    'Cash on Delivery',
                    Icons.money,
                  ),
                  _paymentOption(
                    'eSewa',
                    Icons.account_balance_wallet,
                  ),
                  _paymentOption(
                    'Khalti',
                    Icons.wallet,
                  ),
                  _paymentOption(
                    'Bank / eBanking',
                    Icons.account_balance,
                  ),
                  _paymentOption(
                    'Mobile Banking',
                    Icons.phone_android,
                  ),
                  _paymentOption(
                    'Debit / Credit Card',
                    Icons.credit_card,
                  ),
                  _paymentOption(
                    'connectIPS',
                    Icons.payment,
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
                  16,
            ),

            Card(
              child:
                  Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children:
                      <Widget>[
                    const Text(
                      'Order Summary',
                      style:
                          TextStyle(
                        fontSize:
                            18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height:
                          10,
                    ),
                    _totalRow(
                      'Subtotal',
                      widget.cartSubtotal,
                    ),
                    if (widget
                            .discountAmount >
                        0)
                      _totalRow(
                        'Discount',
                        -widget
                            .discountAmount,
                        color:
                            Colors.red,
                      ),
                    _totalRow(
                      'Delivery',
                      _deliveryCharge,
                      color:
                          _deliveryCharge ==
                                  0
                              ? Colors.green
                              : null,
                    ),
                    const Divider(),
                    _totalRow(
                      'Final Total',
                      _finalTotal,
                      color:
                          Colors.green,
                      bold:
                          true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            SizedBox(
              width:
                  double.infinity,
              height:
                  55,
              child:
                  ElevatedButton(
                onPressed:
                    _placeOrder,
                child:
                    const Text(
                  'Place Order',
                  style:
                      TextStyle(
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
