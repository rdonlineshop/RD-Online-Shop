import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
