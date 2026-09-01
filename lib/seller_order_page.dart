import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_data.dart';
import 'tracking/delivery_person_tracking_page.dart';

class SellerOrderPage extends StatefulWidget {
  const SellerOrderPage({super.key});

  @override
  State<SellerOrderPage> createState() =>
      _SellerOrderPageState();
}

class _SellerOrderPageState extends State<SellerOrderPage> {
  final TextEditingController searchController =
      TextEditingController();

  List<Map<String, dynamic>> _sellerOrders =
      <Map<String, dynamic>>[];

  String selectedFilter = 'All';

  final List<String> statuses = <String>[
    'Pending',
    'Confirmed',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled',
    'Returned',
  ];

  @override
  void initState() {
    super.initState();

    searchController.addListener(
      _refreshPage,
    );

    _loadOrders();
  }

  // =========================================================
  // LOAD ORDERS
  // =========================================================

  Future<void> _loadOrders() async {
    final String sellerId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (sellerId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _sellerOrders = <Map<String, dynamic>>[];
        });
      }
      return;
    }

    final List<Map<String, dynamic>> orders =
        await sellerOrdersStream(sellerId).first;

    if (!mounted) {
      return;
    }

    setState(() {
      _sellerOrders = orders;
    });
  }

  void _refreshPage() {
    if (!mounted) {
      return;
    }

    setState(() {});
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
        text.toLowerCase() ==
            'null') {
      return null;
    }

    return double.tryParse(
      text,
    );
  }

  // =========================================================
  // CUSTOMER LOCATION
  // =========================================================

  double? _customerLatitude(
    Map<String, dynamic> order,
  ) {
    final double? direct =
        _toDouble(
      order['customerLat'] ??
          order['latitude'] ??
          order['deliveryLatitude'],
    );

    if (direct != null) {
      return direct;
    }

    final dynamic customerLocation =
        order['customerLocation'];

    if (customerLocation is GeoPoint) {
      return customerLocation.latitude;
    }

    if (customerLocation is Map) {
      return _toDouble(
        customerLocation['latitude'] ??
            customerLocation['lat'],
      );
    }

    return null;
  }

  double? _customerLongitude(
    Map<String, dynamic> order,
  ) {
    final double? direct =
        _toDouble(
      order['customerLng'] ??
          order['longitude'] ??
          order['deliveryLongitude'],
    );

    if (direct != null) {
      return direct;
    }

    final dynamic customerLocation =
        order['customerLocation'];

    if (customerLocation is GeoPoint) {
      return customerLocation.longitude;
    }

    if (customerLocation is Map) {
      return _toDouble(
        customerLocation['longitude'] ??
            customerLocation['lng'],
      );
    }

    return null;
  }

  String _customerAddress(
    Map<String, dynamic> order,
  ) {
    final List<dynamic> addresses =
        <dynamic>[
      order['customerAddress'],
      order['address'],
      order['deliveryAddress'],
    ];

    for (final dynamic value
        in addresses) {
      final String address =
          value
                  ?.toString()
                  .trim() ??
              '';

      if (address.isNotEmpty &&
          address.toLowerCase() !=
              'null') {
        return address;
      }
    }

    return 'Address not available';
  }

  String _customerName(
    Map<String, dynamic> order,
  ) {
    final List<dynamic> names =
        <dynamic>[
      order['customerName'],
      order['name'],
      order['fullName'],
      order['customer'],
    ];

    for (final dynamic value
        in names) {
      final String name =
          value
                  ?.toString()
                  .trim() ??
              '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Unknown Customer';
  }

  String _customerPhone(
    Map<String, dynamic> order,
  ) {
    final List<dynamic> phones =
        <dynamic>[
      order['phone'],
      order['customerPhone'],
      order['mobile'],
    ];

    for (final dynamic value
        in phones) {
      final String phone =
          value
                  ?.toString()
                  .trim() ??
              '';

      if (phone.isNotEmpty) {
        return phone;
      }
    }

    return '';
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

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  // =========================================================
  // CALL
  // =========================================================

  Future<void> _callPhone(
    String phone,
  ) async {
    final String cleanPhone =
        phone
            .trim()
            .replaceAll(
              ' ',
              '',
            )
            .replaceAll(
              '-',
              '',
            );

    if (cleanPhone.isEmpty) {
      _showMessage(
        'Phone number is not available.',
      );

      return;
    }

    try {
      final Uri uri =
          Uri(
        scheme: 'tel',
        path: cleanPhone,
      );

      final bool opened =
          await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
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
    final String cleanPhone =
        phone
            .trim()
            .replaceAll(
              ' ',
              '',
            )
            .replaceAll(
              '-',
              '',
            );

    if (cleanPhone.isEmpty) {
      _showMessage(
        'Phone number is not available.',
      );

      return;
    }

    try {
      final Uri uri =
          Uri(
        scheme: 'sms',
        path: cleanPhone,
      );

      final bool opened =
          await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
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
  // OPEN MAP
  // =========================================================

  Future<void> _openMap(
    double latitude,
    double longitude,
  ) async {
    final Uri uri =
        Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query':
            '$latitude,$longitude',
      },
    );

    try {
      final bool opened =
          await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
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
  // SHOW PRODUCT IMAGE
  // =========================================================

  void _showProductImage(
    String imageUrl,
  ) {
    if (imageUrl.trim().isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 60,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // PRODUCT IMAGE
  // =========================================================

  String _productImage(
    Map<dynamic, dynamic> item,
  ) {
    final List<dynamic> directImages =
        <dynamic>[
      item['image'],
      item['imagePath'],
      item['imageUrl'],
      item['photoUrl'],
      item['thumbnailUrl'],
    ];

    for (final dynamic value
        in directImages) {
      final String image =
          value
                  ?.toString()
                  .trim() ??
              '';

      if (image.isNotEmpty &&
          image.toLowerCase() !=
              'null') {
        return image;
      }
    }

    final List<dynamic> imageLists =
        <dynamic>[
      item['imagePaths'],
      item['imageUrls'],
      item['images'],
      item['photoUrls'],
      item['photos'],
    ];

    for (final dynamic value
        in imageLists) {
      if (value is List) {
        for (final dynamic photo
            in value) {
          final String image =
              photo
                      ?.toString()
                      .trim() ??
                  '';

          if (image.isNotEmpty &&
              image.toLowerCase() !=
                  'null') {
            return image;
          }
        }
      }
    }

    return '';
  }

  // =========================================================
  // SELLER IDS
  // =========================================================

  Set<String> _orderSellerIds(
    Map<String, dynamic> order,
  ) {
    final Set<String> ids =
        <String>{};

    final dynamic savedSellerIds =
        order['sellerIds'];

    if (savedSellerIds is List) {
      for (final dynamic value
          in savedSellerIds) {
        final String id =
            value
                    ?.toString()
                    .trim() ??
                '';

        if (id.isNotEmpty) {
          ids.add(
            id,
          );
        }
      }
    }

    final dynamic items =
        order['items'];

    if (items is List) {
      for (final dynamic item
          in items) {
        if (item is Map) {
          final String sellerId =
              item['sellerId']
                      ?.toString()
                      .trim() ??
                  '';

          if (sellerId.isNotEmpty) {
            ids.add(
              sellerId,
            );
          }
        }
      }
    }

    final String topSellerId =
        order['sellerId']
                ?.toString()
                .trim() ??
            '';

    if (topSellerId.isNotEmpty) {
      ids.add(
        topSellerId,
      );
    }

    return ids;
  }

  bool _isCurrentSellerOrder(
    Map<String, dynamic> order,
  ) {
    final String sellerId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    return sellerId.isNotEmpty &&
        _orderSellerIds(order).contains(sellerId);
  }

  // =========================================================
  // CURRENT SELLER ORDERS ONLY
  // =========================================================

  List<Map<String, dynamic>>
      _filteredOrders() {
    final String sellerId =
        FirebaseAuth
                .instance
                .currentUser
                ?.uid ??
            '';

    if (sellerId.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final String search =
        searchController.text
            .trim()
            .toLowerCase();

    return _sellerOrders.where(
      (
        Map<String, dynamic> order,
      ) {
        final Set<String> sellerIds =
            _orderSellerIds(
          order,
        );

        final bool sellerMatch =
            sellerIds.contains(
          sellerId,
        );

        final String status =
            order['status']
                    ?.toString()
                    .trim() ??
                'Pending';

        final bool statusMatch =
            selectedFilter == 'All' ||
                status ==
                    selectedFilter;

        final bool searchMatch =
            search.isEmpty ||
                order
                    .toString()
                    .toLowerCase()
                    .contains(
                      search,
                    );

        return sellerMatch &&
            statusMatch &&
            searchMatch;
      },
    ).toList();
  }

  // =========================================================
  // CHANGE ORDER STATUS
  // =========================================================

  Future<void> _changeStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    if (!_isCurrentSellerOrder(order)) {
      _showMessage(
        'You can only update your own order.',
      );
      return;
    }

    final String currentStatus =
        order['status']?.toString().trim() ?? 'Pending';

    if (currentStatus == 'Cancelled' ||
        currentStatus == 'Returned') {
      _showMessage(
        'This order is already closed and cannot be changed here.',
      );
      return;
    }

    if (newStatus == 'Cancelled' ||
        newStatus == 'Returned') {
      _showMessage(
        'Use the customer Cancel / Return request review section for this action.',
      );
      return;
    }

    final String orderId =
        order['id']
                ?.toString()
                .trim() ??
            '';

    if (orderId.isEmpty) {
      _showMessage(
        'Order ID is missing.',
      );

      return;
    }

    await updateOrderStatus(
      orderId,
      newStatus,
    );

    if (!mounted) {
      return;
    }

    await _loadOrders();

    if (!mounted) {
      return;
    }

    _showMessage(
      'Order status changed to $newStatus',
    );
  }

  // =========================================================
  // LOAD REGISTERED DELIVERY PERSONS
  // =========================================================

  Future<List<Map<String, dynamic>>>
      _loadDeliveryPersons() async {
    final QuerySnapshot<
            Map<String, dynamic>>
        snapshot =
        await FirebaseFirestore.instance
            .collection(
              'delivery_persons',
            )
            .where(
              'isApproved',
              isEqualTo: true,
            )
            .where(
              'isActive',
              isEqualTo: true,
            )
            .get();

    final List<Map<String, dynamic>>
        persons =
        snapshot.docs
            .map(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    doc,
              ) {
                return <String, dynamic>{
                  ...doc.data(),
                  'driverId': doc.id,
                };
              },
            )
            .where(
              (
                Map<String, dynamic>
                    person,
              ) {
                return person['isActive'] == true &&
                    person['isApproved'] == true;
              },
            )
            .toList();

    persons.sort(
      (
        Map<String, dynamic> a,
        Map<String, dynamic> b,
      ) {
        final String aName =
            a['name']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final String bName =
            b['name']
                    ?.toString()
                    .toLowerCase() ??
                '';

        return aName.compareTo(
          bName,
        );
      },
    );

    return persons;
  }

  // =========================================================
  // ASSIGN REGISTERED DELIVERY PERSON
  // =========================================================

  Future<void> _assignDeliveryPerson(
    Map<String, dynamic> order,
  ) async {
    if (!_isCurrentSellerOrder(order)) {
      _showMessage(
        'You can only manage delivery for your own order.',
      );
      return;
    }

    final String orderId =
        order['id']
                ?.toString()
                .trim() ??
            '';

    if (orderId.isEmpty) {
      _showMessage(
        'Order ID is missing.',
      );

      return;
    }

    try {
      final List<
              Map<String, dynamic>>
          deliveryPersons =
          await _loadDeliveryPersons();

      if (!mounted) {
        return;
      }

      if (deliveryPersons.isEmpty) {
        _showMessage(
          'No registered delivery persons found.',
        );

        return;
      }

      final String currentDriverId =
          order['driverId']
                  ?.toString()
                  .trim() ??
              '';

      Map<String, dynamic>?
          currentPerson;

      for (final Map<String, dynamic>
          person in deliveryPersons) {
        final String id =
            person['driverId']
                    ?.toString()
                    .trim() ??
                '';

        if (id ==
            currentDriverId) {
          currentPerson =
              person;
          break;
        }
      }

      final Map<String, dynamic>?
          selectedPerson =
          await showDialog<
              Map<String, dynamic>>(
        context: context,
        barrierDismissible:
            false,
        builder: (
          BuildContext dialogContext,
        ) {
          Map<String, dynamic>?
              tempSelected =
              currentPerson;

          return StatefulBuilder(
            builder: (
              BuildContext context,
              StateSetter
                  setDialogState,
            ) {
              final String?
                  initialId =
                  tempSelected?[
                          'driverId']
                      ?.toString();

              return AlertDialog(
                title: const Text(
                  'Assign Delivery Person',
                ),
                content: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      const Text(
                        'Select a registered delivery person',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      DropdownButtonFormField<
                          String>(
                        initialValue:
                            initialId,
                        isExpanded:
                            true,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Delivery Person',
                          prefixIcon:
                              Icon(
                            Icons
                                .local_shipping,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        items:
                            deliveryPersons
                                .map(
                          (
                            Map<String,
                                    dynamic>
                                person,
                          ) {
                            final String
                                id =
                                person['driverId']
                                        ?.toString()
                                        .trim() ??
                                    '';

                            final String
                                name =
                                person['name']
                                        ?.toString()
                                        .trim() ??
                                    'Delivery Person';

                            final String
                                phone =
                                person['phone']
                                        ?.toString()
                                        .trim() ??
                                    '';

                            return DropdownMenuItem<
                                String>(
                              value: id,
                              child: Text(
                                phone.isEmpty
                                    ? name
                                    : '$name - $phone',
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            );
                          },
                        ).toList(),
                        onChanged: (
                          String? value,
                        ) {
                          if (value ==
                              null) {
                            return;
                          }

                          for (final Map<
                                  String,
                                  dynamic>
                              person
                              in deliveryPersons) {
                            final String
                                personId =
                                person['driverId']
                                        ?.toString()
                                        .trim() ??
                                    '';

                            if (personId ==
                                value) {
                              setDialogState(
                                () {
                                  tempSelected =
                                      person;
                                },
                              );

                              break;
                            }
                          }
                        },
                      ),

                      if (tempSelected !=
                          null) ...<Widget>[
                        const SizedBox(
                          height: 16,
                        ),

                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(
                            12,
                          ),
                          decoration:
                              BoxDecoration(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                            color: Colors
                                .blue
                                .withValues(
                              alpha:
                                  0.08,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children:
                                <Widget>[
                              Text(
                                'Name: '
                                '${tempSelected?['name'] ?? ''}',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                              const SizedBox(
                                height:
                                    4,
                              ),
                              Text(
                                'Phone: '
                                '${tempSelected?['phone'] ?? ''}',
                              ),
                              const SizedBox(
                                height:
                                    4,
                              ),
                              Text(
                                'Email: '
                                '${tempSelected?['email'] ?? ''}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                      );
                    },
                    child:
                        const Text(
                      'Cancel',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        tempSelected ==
                                null
                            ? null
                            : () {
                                Navigator.pop(
                                  dialogContext,
                                  tempSelected,
                                );
                              },
                    icon:
                        const Icon(
                      Icons.check,
                    ),
                    label:
                        const Text(
                      'Assign',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (selectedPerson ==
          null) {
        return;
      }

      final String driverId =
          selectedPerson['driverId']
                  ?.toString()
                  .trim() ??
              '';

      final String driverName =
          selectedPerson['name']
                  ?.toString()
                  .trim() ??
              '';

      final String driverPhone =
          selectedPerson['phone']
                  ?.toString()
                  .trim() ??
              '';

      final String driverEmail =
          selectedPerson['email']
                  ?.toString()
                  .trim() ??
              '';

      if (driverId.isEmpty) {
        _showMessage(
          'Delivery person ID is missing.',
        );

        return;
      }

      if (driverName.isEmpty) {
        _showMessage(
          'Delivery person name is missing.',
        );

        return;
      }

      final String now =
          DateTime.now()
              .toIso8601String();

      final Map<String, dynamic>
          trackingData =
          <String, dynamic>{
        'driverId':
            driverId,
        'driverName':
            driverName,
        'driverPhone':
            driverPhone,
        'driverEmail':
            driverEmail,

        'trackingEnabled':
            true,

        'trackingStatus':
            'Delivery Person Assigned',

        'deliveryAssignedAt':
            now,

        // New driver should start with
        // fresh GPS values.
        'driverLat':
            null,
        'driverLng':
            null,
        'driverLocationUpdatedAt':
            null,
      };

      await updateOrderTrackingFields(
        orderId,
        trackingData,
      );

      if (!mounted) {
        return;
      }

      await _loadOrders();

      if (!mounted) {
        return;
      }

      _showMessage(
        '$driverName assigned successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not assign delivery person: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // =========================================================
  // OPEN LIVE TRACKING PAGE
  // =========================================================

  Future<void> _openDeliveryTracking(
    Map<String, dynamic> order,
  ) async {
    final String orderId =
        order['id']
                ?.toString()
                .trim() ??
            '';

    final String driverId =
        order['driverId']
                ?.toString()
                .trim() ??
            '';

    final String driverName =
        order['driverName']
                ?.toString()
                .trim() ??
            '';

    final String driverPhone =
        order['driverPhone']
                ?.toString()
                .trim() ??
            '';

    if (orderId.isEmpty) {
      _showMessage(
        'Order ID is missing.',
      );

      return;
    }

    if (driverId.isEmpty ||
        driverName.isEmpty) {
      _showMessage(
        'Please assign a registered delivery person first.',
      );

      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DeliveryPersonTrackingPage(
          orderId:
              orderId,
          driverName:
              driverName,
          driverPhone:
              driverPhone,
        ),
      ),
    );

    await _loadOrders();
  }

  // =========================================================
  // PRODUCT DETAILS
  // =========================================================

  Widget _productDetails(
    dynamic items,
  ) {
    if (items is! List ||
        items.isEmpty) {
      return const Text(
        'Products: No product details',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Products',
          style: TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        ...items.map<Widget>(
          (
            dynamic rawItem,
          ) {
            if (rawItem is! Map) {
              return const SizedBox
                  .shrink();
            }

            final String name =
                rawItem['productName']
                        ?.toString()
                        .trim() ??
                    rawItem['name']
                        ?.toString()
                        .trim() ??
                    'Unknown Product';

            final String price =
                rawItem['price']
                        ?.toString()
                        .trim() ??
                    '0';

            final String quantity =
                rawItem['quantity']
                        ?.toString()
                        .trim() ??
                    '1';

            final String color =
                rawItem['selectedColor']
                        ?.toString()
                        .trim() ??
                    '';

            final String size =
                rawItem['selectedSize']
                        ?.toString()
                        .trim() ??
                    '';

            final String image =
                _productImage(
              rawItem,
            );

            final bool networkImage =
                image.startsWith(
                  'http://',
                ) ||
                image.startsWith(
                  'https://',
                );

            final bool assetImage =
                image.startsWith(
              'assets/',
            );

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children:
                      <Widget>[
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                      child: Container(
                        width:
                            70,
                        height:
                            70,
                        color: Colors
                            .grey
                            .shade100,
                        child:
                            networkImage
                                ? GestureDetector(
                                    onTap:
                                        () {
                                      _showProductImage(
                                        image,
                                      );
                                    },
                                    child:
                                        Image.network(
                                      image,
                                      fit:
                                          BoxFit.cover,
                                      errorBuilder:
                                          (
                                        BuildContext
                                            context,
                                        Object
                                            error,
                                        StackTrace?
                                            stackTrace,
                                      ) {
                                        return const Icon(
                                          Icons
                                              .image_not_supported,
                                        );
                                      },
                                    ),
                                  )
                                : assetImage
                                    ? Image.asset(
                                        image,
                                        fit: BoxFit
                                            .cover,
                                        errorBuilder:
                                            (
                                          BuildContext
                                              context,
                                          Object
                                              error,
                                          StackTrace?
                                              stackTrace,
                                        ) {
                                          return const Icon(
                                            Icons
                                                .image_not_supported,
                                          );
                                        },
                                      )
                                    : const Icon(
                                        Icons
                                            .inventory_2_outlined,
                                        size:
                                            34,
                                      ),
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
                            name,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          Text(
                            'Qty: $quantity',
                          ),
                          Text(
                            'Price: $price',
                          ),
                          if (color
                              .isNotEmpty)
                            Text(
                              'Color: $color',
                            ),
                          if (size
                              .isNotEmpty)
                            Text(
                              'Size: $size',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // =========================================================
  // CUSTOMER LOCATION CARD
  // =========================================================

  Widget _customerLocationCard(
    Map<String, dynamic> order,
  ) {
    final double? latitude =
        _customerLatitude(
      order,
    );

    final double? longitude =
        _customerLongitude(
      order,
    );

    final String address =
        _customerAddress(
      order,
    );

    final String source =
        order['customerLocationSource']
                ?.toString()
                .trim() ??
            '';

    final bool hasLocation =
        latitude != null &&
            longitude != null;

    return Card(
      margin:
          EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.location_on,
                  color:
                      Colors.red,
                ),
                SizedBox(
                  width:
                      8,
                ),
                Expanded(
                  child: Text(
                    'Customer Delivery Location',
                    style:
                        TextStyle(
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
                  10,
            ),

            Text(
              address,
            ),

            if (source.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets
                        .only(
                  top:
                      5,
                ),
                child:
                    Text(
                  'Location Source: $source',
                ),
              ),

            if (hasLocation) ...<Widget>[
              const SizedBox(
                height:
                    10,
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton
                        .icon(
                  onPressed:
                      () {
                    _openMap(
                      latitude,
                      longitude,
                    );
                  },
                  icon:
                      const Icon(
                    Icons.map,
                  ),
                  label:
                      const Text(
                    'Open Customer Location',
                  ),
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(
                height:
                    8,
              ),
              const Text(
                'Customer GPS location is not available.',
                style:
                    TextStyle(
                  color:
                      Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DELIVERY PERSON CARD
  // =========================================================

  Widget _deliveryPersonCard(
    Map<String, dynamic> order,
  ) {
    final String driverId =
        order['driverId']
                ?.toString()
                .trim() ??
            '';

    final String driverName =
        order['driverName']
                ?.toString()
                .trim() ??
            '';

    final String driverPhone =
        order['driverPhone']
                ?.toString()
                .trim() ??
            '';

    final String driverEmail =
        order['driverEmail']
                ?.toString()
                .trim() ??
            '';

    final double? driverLat =
        _toDouble(
      order['driverLat'],
    );

    final double? driverLng =
        _toDouble(
      order['driverLng'],
    );

    final String trackingStatus =
        order['trackingStatus']
                ?.toString()
                .trim() ??
            '';

    final String lastUpdated =
        order['driverLocationUpdatedAt']
                ?.toString()
                .trim() ??
            '';

    final bool assigned =
        driverId.isNotEmpty ||
            driverName.isNotEmpty;

    final bool hasLiveLocation =
        driverLat != null &&
            driverLng != null;

    return Card(
      margin:
          EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons
                      .local_shipping,
                  color:
                      Colors.blue,
                ),
                SizedBox(
                  width:
                      8,
                ),
                Expanded(
                  child:
                      Text(
                    'Delivery Person',
                    style:
                        TextStyle(
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
                  10,
            ),

            if (!assigned)
              const Text(
                'No delivery person assigned yet.',
                style:
                    TextStyle(
                  color:
                      Colors.orange,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),

            if (assigned) ...<Widget>[
              Text(
                'Name: $driverName',
              ),

              if (driverPhone.isNotEmpty)
                Text(
                  'Phone: $driverPhone',
                ),

              if (driverEmail.isNotEmpty)
                Text(
                  'Email: $driverEmail',
                ),

              if (driverId.isNotEmpty)
                Text(
                  'Driver ID: $driverId',
                  maxLines:
                      1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    fontSize:
                        11,
                    color:
                        Colors.grey
                            .shade600,
                  ),
                ),

              if (trackingStatus
                  .isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    top:
                        5,
                  ),
                  child:
                      Text(
                    'Tracking: $trackingStatus',
                  ),
                ),

              const SizedBox(
                height:
                    10,
              ),

              Row(
                children: <Widget>[
                  Expanded(
                    child:
                        OutlinedButton
                            .icon(
                      onPressed:
                          driverPhone
                                  .isEmpty
                              ? null
                              : () {
                                  _callPhone(
                                    driverPhone,
                                  );
                                },
                      icon:
                          const Icon(
                        Icons.call,
                      ),
                      label:
                          const Text(
                        'Call',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width:
                        10,
                  ),

                  Expanded(
                    child:
                        OutlinedButton
                            .icon(
                      onPressed:
                          driverPhone
                                  .isEmpty
                              ? null
                              : () {
                                  _sendSms(
                                    driverPhone,
                                  );
                                },
                      icon:
                          const Icon(
                        Icons.sms,
                      ),
                      label:
                          const Text(
                        'SMS',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    10,
              ),

              SizedBox(
                width:
                    double.infinity,
                height:
                    52,
                child:
                    FilledButton
                        .icon(
                  onPressed:
                      () {
                    _openDeliveryTracking(
                      order,
                    );
                  },
                  icon:
                      const Icon(
                    Icons
                        .location_searching,
                  ),
                  label:
                      Text(
                    hasLiveLocation
                        ? 'Continue Live Tracking'
                        : 'Start Live Tracking',
                  ),
                ),
              ),

              if (hasLiveLocation) ...<Widget>[
                const SizedBox(
                  height:
                      10,
                ),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .all(
                    10,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.green
                            .withValues(
                      alpha:
                          0.10,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                  ),
                  child:
                      const Row(
                    children:
                        <Widget>[
                      Icon(
                        Icons
                            .gps_fixed,
                        color:
                            Colors.green,
                      ),
                      SizedBox(
                        width:
                            8,
                      ),
                      Text(
                        'Live location available',
                        style:
                            TextStyle(
                          color:
                              Colors.green,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (lastUpdated
                    .isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top:
                          5,
                    ),
                    child:
                        Text(
                      'Last updated: $lastUpdated',
                    ),
                  ),

                const SizedBox(
                  height:
                      8,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton
                          .icon(
                    onPressed:
                        () {
                      _openMap(
                        driverLat,
                        driverLng,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.map,
                    ),
                    label:
                        const Text(
                      'Open Live Location',
                    ),
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(
                  height:
                      8,
                ),
                const Text(
                  'Live location has not started yet.',
                  style:
                      TextStyle(
                    color:
                        Colors.blueGrey,
                  ),
                ),
              ],
            ],

            const SizedBox(
              height:
                  12,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton
                      .icon(
                onPressed:
                    () {
                  _assignDeliveryPerson(
                    order,
                  );
                },
                icon:
                    Icon(
                  assigned
                      ? Icons.edit
                      : Icons
                          .person_add,
                ),
                label:
                    Text(
                  assigned
                      ? 'Change Delivery Person'
                      : 'Assign Delivery Person',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // STATUS FILTER
  // =========================================================

  Widget _statusFilter() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      child: Row(
        children: <String>[
          'All',
          ...statuses,
        ].map(
          (
            String status,
          ) {
            final bool selected =
                selectedFilter ==
                    status;

            return Padding(
              padding:
                  const EdgeInsets
                      .only(
                right:
                    8,
              ),
              child:
                  ChoiceChip(
                label:
                    Text(
                  status,
                ),
                selected:
                    selected,
                onSelected:
                    (_) {
                  setState(
                    () {
                      selectedFilter =
                          status;
                    },
                  );
                },
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // =========================================================
  // CUSTOMER CANCEL / RETURN REQUEST REVIEW
  // =========================================================

  String _requestText(
    Map<String, dynamic> order,
    String key,
  ) {
    return order[key]?.toString().trim() ?? '';
  }

  bool _paymentWasPaid(
    Map<String, dynamic> order,
  ) {
    final String status =
        _requestText(
      order,
      'paymentStatus',
    ).toLowerCase();

    return status == 'paid' ||
        status == 'success' ||
        status == 'successful' ||
        status == 'completed';
  }

  bool _isCashOnDelivery(
    Map<String, dynamic> order,
  ) {
    final String payment =
        _requestText(
      order,
      'payment',
    ).toLowerCase();

    return payment == 'cod' ||
        payment.contains('cash on delivery');
  }

  Color _customerRequestColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending review':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'not required':
        return Colors.blueGrey;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _reviewCustomerRequest({
    required Map<String, dynamic> order,
    required bool isReturn,
    required bool approve,
    required String sellerNote,
  }) async {
    if (!_isCurrentSellerOrder(order)) {
      _showMessage(
        'You can only review requests for your own order.',
      );
      return;
    }

    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      _showMessage(
        'Order ID is missing.',
      );
      return;
    }

    final String sellerId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (sellerId.isEmpty) {
      _showMessage(
        'Seller login is required.',
      );
      return;
    }

    final String now =
        DateTime.now().toIso8601String();

    final double amount =
        _toDouble(order['amount']) ?? 0;

    final Map<String, dynamic> currentSettlement =
        _currentSellerSettlement(order);

    final String currentSettlementStatus =
        currentSettlement['status']?.toString().trim() ?? '';

    final double alreadyPaidToSeller =
        _toDouble(
              currentSettlement['amount'] ??
                  currentSettlement['sellerPayable'],
            ) ??
            0;

    final bool sellerWasAlreadyPaid =
        currentSettlementStatus == 'Paid' &&
            alreadyPaidToSeller > 0;

    final Map<String, dynamic> update =
        <String, dynamic>{
      'customerRequestType':
          isReturn ? 'Return' : 'Cancellation',
      'customerRequestStatus':
          approve ? 'Approved' : 'Rejected',
      'customerRequestUpdatedAt':
          now,
    };

    if (isReturn) {
      update.addAll(
        <String, dynamic>{
          'returnRequestStatus':
              approve ? 'Approved' : 'Rejected',
          'returnReviewedAt':
              now,
          'returnReviewedBySellerId':
              sellerId,
          'returnSellerNote':
              sellerNote.trim(),
        },
      );

      if (approve) {
        // A return is requested only after delivery, so a refund
        // normally needs Admin processing after seller approval.
        update.addAll(
          <String, dynamic>{
            'returnStatus':
                'Approved',
            'returnApprovedAt':
                now,
            'refundStatus':
                'Pending',
            'refundSource':
                'Return',
            'refundReason':
                'Return approved by seller',
            'refundRequestedAt':
                now,
            'refundAmount':
                amount,
          },
        );
      }
    } else {
      update.addAll(
        <String, dynamic>{
          'cancelRequestStatus':
              approve ? 'Approved' : 'Rejected',
          'cancelReviewedAt':
              now,
          'cancelReviewedBySellerId':
              sellerId,
          'cancelSellerNote':
              sellerNote.trim(),
        },
      );

      if (approve) {
        final bool refundNeeded =
            !_isCashOnDelivery(order) &&
                _paymentWasPaid(order);

        update.addAll(
          <String, dynamic>{
            'status':
                'Cancelled',
            'trackingStatus':
                'Cancelled',
            'trackingEnabled':
                false,
            'cancelledAt':
                now,
            'cancelledBy':
                'seller',
            'refundStatus':
                refundNeeded
                    ? 'Pending'
                    : 'Not Required',
            'refundSource':
                'Cancellation',
            'refundReason':
                refundNeeded
                    ? 'Cancellation approved by seller'
                    : 'No completed prepaid payment found',
            'refundRequestedAt':
                refundNeeded ? now : '',
            'refundAmount':
                refundNeeded ? amount : 0,
          },
        );
      }
    }

    if (approve && sellerWasAlreadyPaid) {
      update.addAll(
        <String, dynamic>{
          'sellerAdjustmentRequired':
              true,
          'sellerAdjustmentStatus':
              'Pending',
          'sellerAdjustmentSellerId':
              sellerId,
          'sellerAdjustmentAmount':
              alreadyPaidToSeller,
          'sellerAdjustmentReason':
              isReturn
                  ? 'Seller was already paid before the approved return.'
                  : 'Seller was already paid before the approved cancellation.',
          'sellerAdjustmentCreatedAt':
              now,
        },
      );
    }

    await updateOrderTrackingFields(
      orderId,
      update,
    );

    if (!mounted) {
      return;
    }

    await _loadOrders();

    if (!mounted) {
      return;
    }

    final String action =
        approve ? 'approved' : 'rejected';

    _showMessage(
      '${isReturn ? 'Return' : 'Cancellation'} request $action.',
    );
  }

  Future<void> _openCustomerRequestReview({
    required Map<String, dynamic> order,
    required bool isReturn,
  }) async {
    final String status =
        _requestText(
      order,
      isReturn
          ? 'returnRequestStatus'
          : 'cancelRequestStatus',
    );

    if (status != 'Pending') {
      _showMessage(
        'This request has already been reviewed.',
      );
      return;
    }

    final String reason =
        _requestText(
      order,
      isReturn
          ? 'returnRequestReason'
          : 'cancelRequestReason',
    );

    final String note =
        _requestText(
      order,
      isReturn
          ? 'returnRequestNote'
          : 'cancelRequestNote',
    );

    String sellerResponse = '';

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        BuildContext dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            Future<void> save(
              bool approve,
            ) async {
              if (isSaving) {
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await _reviewCustomerRequest(
                  order: order,
                  isReturn: isReturn,
                  approve: approve,
                  sellerNote:
                      sellerResponse,
                );

                if (!mounted ||
                    !dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );
              } catch (error) {
                if (mounted) {
                  _showMessage(
                    'Could not review request: $error',
                  );
                }
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSaving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(
                isReturn
                    ? 'Review Return Request'
                    : 'Review Cancellation Request',
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Reason: '
                      '${reason.isEmpty ? 'Not provided' : reason}',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    if (note.isNotEmpty) ...<Widget>[
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        'Customer note: $note',
                      ),
                    ],
                    const SizedBox(
                      height: 16,
                    ),
                    TextField(
                      enabled:
                          !isSaving,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (
                        String value,
                      ) {
                        sellerResponse =
                            value;
                      },
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Seller response / note (optional)',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      isReturn
                          ? 'Approve sends the return to Refund Pending for Admin processing.'
                          : 'Approve cancels the order. A completed prepaid payment will move to Refund Pending.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      isSaving
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                  child:
                      const Text('Back'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      isSaving
                          ? null
                          : () {
                              save(false);
                            },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Reject',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      isSaving
                          ? null
                          : () {
                              save(true);
                            },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline,
                        ),
                  label: const Text(
                    'Approve',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

  }

  Widget _customerRequestReviewCard(
    Map<String, dynamic> order,
  ) {
    final String cancelStatus =
        _requestText(
      order,
      'cancelRequestStatus',
    );

    final String returnStatus =
        _requestText(
      order,
      'returnRequestStatus',
    );

    final String refundStatus =
        _requestText(
      order,
      'refundStatus',
    );

    if (cancelStatus.isEmpty &&
        returnStatus.isEmpty &&
        refundStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget requestBox({
      required String title,
      required String status,
      required String reason,
      required String note,
      required bool isReturn,
    }) {
      final Color color =
          _customerRequestColor(
        status,
      );

      return Container(
        width: double.infinity,
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(
          12,
        ),
        decoration:
            BoxDecoration(
          color: color.withValues(
            alpha: 0.08,
          ),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          border: Border.all(
            color: color.withValues(
              alpha: 0.30,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label:
                      Text(status),
                  side:
                      BorderSide.none,
                  backgroundColor:
                      color.withValues(
                    alpha: 0.15,
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty)
              Text(
                'Reason: $reason',
              ),
            if (note.isNotEmpty) ...<Widget>[
              const SizedBox(
                height: 4,
              ),
              Text(
                'Customer note: $note',
              ),
            ],
            if (status == 'Pending') ...<Widget>[
              const SizedBox(
                height: 12,
              ),
              SizedBox(
                width:
                    double.infinity,
                height: 48,
                child:
                    FilledButton.icon(
                  onPressed: () {
                    _openCustomerRequestReview(
                      order: order,
                      isReturn: isReturn,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .rate_review_outlined,
                  ),
                  label: const Text(
                    'Review Request',
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final String cancelReason =
        _requestText(
      order,
      'cancelRequestReason',
    );
    final String cancelNote =
        _requestText(
      order,
      'cancelRequestNote',
    );
    final String returnReason =
        _requestText(
      order,
      'returnRequestReason',
    );
    final String returnNote =
        _requestText(
      order,
      'returnRequestNote',
    );

    final String refundAmount =
        _requestText(
      order,
      'refundAmount',
    );

    final Color refundColor =
        _customerRequestColor(
      refundStatus,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons
                      .support_agent_outlined,
                  color:
                      Colors.deepPurple,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer Cancel / Return Request',
                    style:
                        TextStyle(
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
            if (cancelStatus
                .isNotEmpty)
              requestBox(
                title:
                    'Cancellation Request',
                status:
                    cancelStatus,
                reason:
                    cancelReason,
                note:
                    cancelNote,
                isReturn:
                    false,
              ),
            if (returnStatus
                .isNotEmpty)
              requestBox(
                title:
                    'Return Request',
                status:
                    returnStatus,
                reason:
                    returnReason,
                note:
                    returnNote,
                isReturn:
                    true,
              ),
            if (refundStatus
                .isNotEmpty)
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
                      refundColor.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  border:
                      Border.all(
                    color:
                        refundColor.withValues(
                      alpha: 0.30,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons
                          .payments_outlined,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children:
                            <Widget>[
                          Text(
                            'Refund: $refundStatus',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          if (refundAmount
                              .isNotEmpty)
                            Text(
                              'Requested Amount: Rs. $refundAmount',
                            ),
                        ],
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

  // =========================================================
  // SELLER SETTLEMENT
  // =========================================================

  Map<String, dynamic> _currentSellerSettlement(
    Map<String, dynamic> order,
  ) {
    final String sellerId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (sellerId.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final dynamic rawSettlements = order['sellerSettlements'];

    if (rawSettlements is Map) {
      final dynamic rawSettlement = rawSettlements[sellerId];

      if (rawSettlement is Map) {
        return rawSettlement.map<String, dynamic>(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(
            key.toString(),
            value,
          ),
        );
      }
    }

    return <String, dynamic>{};
  }

  String _formatSettlementDate(dynamic value) {
    if (value == null) {
      return '';
    }

    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    } else {
      final String text = value.toString().trim();

      if (text.isNotEmpty) {
        dateTime = DateTime.tryParse(text);
      }
    }

    if (dateTime == null) {
      return value.toString().trim();
    }

    final DateTime local = dateTime.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  Color _settlementStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Ready to Pay':
        return Colors.blue;
      case 'On Hold':
        return Colors.redAccent;
      case 'Pending':
      default:
        return Colors.orange;
    }
  }

  Widget _sellerSettlementCard(
    Map<String, dynamic> order,
  ) {
    final Map<String, dynamic> settlement =
        _currentSellerSettlement(order);

    final String status =
        settlement['status']?.toString().trim().isNotEmpty == true
            ? settlement['status'].toString().trim()
            : 'Pending';

    final String amount =
        settlement['amount']?.toString().trim() ?? '';

    final String paymentMethod =
        settlement['paymentMethod']?.toString().trim() ?? '';

    final String referenceId =
        settlement['referenceId']?.toString().trim() ?? '';

    final String note =
        settlement['note']?.toString().trim() ?? '';

    final dynamic dateValue =
        settlement['paidAt'] ??
        settlement['updatedAt'] ??
        settlement['settledAt'] ??
        settlement['createdAt'];

    final String dateText = _formatSettlementDate(dateValue);
    final Color statusColor = _settlementStatusColor(status);

    final String adjustmentStatus =
        order['sellerAdjustmentStatus']?.toString().trim() ?? '';

    final bool adjustmentResolved =
        adjustmentStatus == 'Recovered' ||
            adjustmentStatus == 'Deducted from Next Settlement';

    final String orderStatus =
        order['status']?.toString().trim() ?? '';

    final String refundStatus =
        order['refundStatus']?.toString().trim() ?? '';

    final double paidSettlementAmount =
        _toDouble(
              settlement['amount'] ??
                  settlement['sellerPayable'],
            ) ??
            0;

    final bool sellerAlreadyPaid =
        status == 'Paid' &&
            paidSettlementAmount > 0;

    final bool adjustmentRequired =
        !adjustmentResolved &&
            (order['sellerAdjustmentRequired'] == true ||
                (sellerAlreadyPaid &&
                    (orderStatus == 'Cancelled' ||
                        orderStatus == 'Returned' ||
                        refundStatus == 'Pending' ||
                        refundStatus == 'Processing' ||
                        refundStatus == 'Refunded')));

    final bool showAdjustment =
        adjustmentRequired ||
            adjustmentResolved ||
            adjustmentStatus.isNotEmpty ||
            order['sellerAdjustmentRequired'] == true;

    final double storedAdjustmentAmount =
        _toDouble(order['sellerAdjustmentAmount']) ?? 0;

    final double adjustmentAmount =
        storedAdjustmentAmount > 0
            ? storedAdjustmentAmount
            : paidSettlementAmount;

    final String savedAdjustmentReason =
        order['sellerAdjustmentReason']?.toString().trim() ?? '';

    final String adjustmentReason =
        savedAdjustmentReason.isNotEmpty
            ? savedAdjustmentReason
            : showAdjustment
                ? 'Seller was already paid before this cancellation / return.'
                : '';

    final String adjustmentMethod =
        order['sellerAdjustmentMethod']?.toString().trim() ?? '';

    final String adjustmentReference =
        order['sellerAdjustmentReference']?.toString().trim() ?? '';

    final String adjustmentNote =
        order['sellerAdjustmentNote']?.toString().trim() ?? '';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'RD Seller Settlement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (amount.isNotEmpty)
              Text(
                'Settlement Amount: Rs. $amount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (paymentMethod.isNotEmpty)
              Text('RD Paid Via: $paymentMethod'),
            if (referenceId.isNotEmpty)
              SelectableText(
                'Transaction / Reference ID: $referenceId',
              ),
            if (dateText.isNotEmpty)
              Text('Settlement Date: $dateText'),
            if (note.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Admin Note: $note',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (showAdjustment) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (adjustmentResolved
                          ? Colors.green
                          : Colors.red)
                      .withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (adjustmentResolved
                            ? Colors.green
                            : Colors.red)
                        .withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'RD Adjustment: '
                      '${adjustmentStatus.isEmpty ? 'Pending' : adjustmentStatus}',
                      style: TextStyle(
                        color: adjustmentResolved
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (adjustmentAmount > 0)
                      Text(
                        'Adjustment Amount: Rs. '
                        '${adjustmentAmount.toStringAsFixed(0)}',
                      ),
                    if (adjustmentReason.isNotEmpty)
                      Text(
                        adjustmentReason,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    if (adjustmentMethod.isNotEmpty)
                      Text(
                        'Method: $adjustmentMethod',
                      ),
                    if (adjustmentReference.isNotEmpty)
                      SelectableText(
                        'Reference: $adjustmentReference',
                      ),
                    if (adjustmentNote.isNotEmpty)
                      Text(
                        'RD Note: $adjustmentNote',
                      ),
                    if (adjustmentResolved) ...<Widget>[
                      const SizedBox(height: 6),
                      const Text(
                        'This RD adjustment has been resolved.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (settlement.isEmpty) ...<Widget>[
              const SizedBox(height: 4),
              const Text(
                'RD has not completed this seller settlement yet.',
                style: TextStyle(
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ORDER CARD
  // =========================================================

  Widget _orderCard(
    Map<String, dynamic> order,
  ) {
    final String currentStatus =
        order['status']
                ?.toString()
                .trim() ??
            'Pending';

    final String phone =
        _customerPhone(
      order,
    );

    final String customerName =
        _customerName(
      order,
    );

    final String orderId =
        order['id']
                ?.toString()
                .trim() ??
            '';

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

    final String paymentStatus =
        order['paymentStatus']
                ?.toString()
                .trim() ??
            '';

    final String paymentDestination =
        (order['paymentReceiverName'] ??
                order['paymentDestination'] ??
                order['paymentReceiverId'])
            ?.toString()
            .trim() ??
            '';

    final String paymentReference =
        (order['paymentReferenceId'] ??
                order['paymentTransactionCode'] ??
                order['paymentTransactionUuid'] ??
                order['transactionId'] ??
                order['transactionUuid'] ??
                order['paymentReference'] ??
                order['referenceId'])
            ?.toString()
            .trim() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom:
            16,
      ),
      elevation:
          3,
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: <Widget>[
            Text(
              'Order ID: $orderId',
              style:
                  const TextStyle(
                fontSize:
                    17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            Text(
              'Customer: $customerName',
            ),

            Text(
              'Mobile: '
              '${phone.isEmpty ? 'Not available' : phone}',
            ),

            const SizedBox(
              height:
                  10,
            ),

            Row(
              children: <Widget>[
                Expanded(
                  child:
                      OutlinedButton
                          .icon(
                    onPressed:
                        phone.isEmpty
                            ? null
                            : () {
                                _callPhone(
                                  phone,
                                );
                              },
                    icon:
                        const Icon(
                      Icons.call,
                    ),
                    label:
                        const Text(
                      'Call Customer',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      10,
                ),

                Expanded(
                  child:
                      OutlinedButton
                          .icon(
                    onPressed:
                        phone.isEmpty
                            ? null
                            : () {
                                _sendSms(
                                  phone,
                                );
                              },
                    icon:
                        const Icon(
                      Icons.sms,
                    ),
                    label:
                        const Text(
                      'SMS',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
                  10,
            ),

            Text(
              'Amount: Rs. $amount',
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            if (payment.isNotEmpty)
              Text(
                'Payment: $payment',
              ),

            if (paymentStatus.isNotEmpty)
              Text(
                'Payment Status: $paymentStatus',
                style: TextStyle(
                  color: paymentStatus.toLowerCase() == 'paid'
                      ? Colors.green
                      : null,
                  fontWeight: FontWeight.bold,
                ),
              ),

            if (paymentDestination.isNotEmpty)
              Text(
                'Payment Destination: $paymentDestination',
              ),

            if (paymentReference.isNotEmpty)
              Text(
                'Transaction / Reference ID: $paymentReference',
              ),

            const SizedBox(
              height:
                  12,
            ),

            const Text(
              'Delivery Address:',
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
              _customerAddress(
                order,
              ),
            ),

            const SizedBox(
              height:
                  14,
            ),

            _customerLocationCard(
              order,
            ),

            const SizedBox(
              height:
                  16,
            ),

            _deliveryPersonCard(
              order,
            ),

            const SizedBox(
              height:
                  16,
            ),

            _productDetails(
              order['items'],
            ),

            const SizedBox(
              height:
                  16,
            ),

            _customerRequestReviewCard(
              order,
            ),

            const SizedBox(
              height:
                  16,
            ),

            _sellerSettlementCard(
              order,
            ),

            const SizedBox(
              height:
                  15,
            ),

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                10,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
                color:
                    Colors.orange
                        .withValues(
                  alpha:
                      0.15,
                ),
              ),
              child:
                  Text(
                'Current Status: $currentStatus',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            DropdownButtonFormField<
                String>(
              initialValue:
                  statuses.contains(
                currentStatus,
              )
                      ? currentStatus
                      : 'Pending',
              decoration:
                  const InputDecoration(
                labelText:
                    'Change Status',
                border:
                    OutlineInputBorder(),
              ),
              items:
                  statuses.map(
                (
                  String status,
                ) {
                  return DropdownMenuItem<
                      String>(
                    value:
                        status,
                    child:
                        Text(
                      status,
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  currentStatus == 'Cancelled' ||
                          currentStatus == 'Returned'
                      ? null
                      : (
                          String? value,
                        ) {
                          if (value == null ||
                              value == currentStatus) {
                            return;
                          }

                          _changeStatus(
                            order,
                            value,
                          );
                        },
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
    final List<
            Map<String, dynamic>>
        sellerOrders =
        _filteredOrders();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Seller Order Management',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle:
            true,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child:
                TextField(
              controller:
                  searchController,
              decoration:
                  InputDecoration(
                hintText:
                    'Search order, customer or phone...',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                suffixIcon:
                    searchController
                            .text
                            .isNotEmpty
                        ? IconButton(
                            onPressed:
                                () {
                              searchController
                                  .clear();
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          )
                        : null,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal:
                  16,
            ),
            child:
                _statusFilter(),
          ),

          const SizedBox(
            height:
                8,
          ),

          Expanded(
            child:
                sellerOrders.isEmpty
                    ? const Center(
                        child:
                            Text(
                          'No Orders Found',
                          style:
                              TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh:
                            _loadOrders,
                        child:
                            ListView.builder(
                          padding:
                              const EdgeInsets.all(
                            16,
                          ),
                          itemCount:
                              sellerOrders.length,
                          itemBuilder:
                              (
                            BuildContext context,
                            int index,
                          ) {
                            return _orderCard(
                              sellerOrders[
                                  index],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    searchController
      ..removeListener(
        _refreshPage,
      )
      ..dispose();

    super.dispose();
  }
}
