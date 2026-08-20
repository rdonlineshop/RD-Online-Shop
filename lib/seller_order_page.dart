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

  String selectedFilter = 'All';

  final List<String> statuses = <String>[
    'Pending',
    'Confirmed',
    'Processing',
    'Shipped',
    'Delivered',
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
    await loadOrders();

    if (!mounted) {
      return;
    }

    setState(() {});
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

    return orderHistory.where(
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
                return person['isActive'] !=
                    false;
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
                  (
                String? value,
              ) {
                if (value ==
                        null ||
                    value ==
                        currentStatus) {
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