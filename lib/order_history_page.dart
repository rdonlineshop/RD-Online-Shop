import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_data.dart';
import 'tracking/order_tracking_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() =>
      _OrderHistoryPageState();
}

class _OrderHistoryPageState
    extends State<OrderHistoryPage> {
  bool isLoading = true;
  String currentCustomerId = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // =========================================================
  // LOAD ORDERS
  // =========================================================

  Future<void> _loadOrders() async {
    final String customerId =
        await getOrCreateCustomerId();

    await loadOrders();

    if (!mounted) {
      return;
    }

    setState(() {
      currentCustomerId = customerId;
      isLoading = false;
    });
  }

  List<Map<String, dynamic>>
      _currentCustomerOrders() {
    if (currentCustomerId.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return orderHistory.where(
      (Map<String, dynamic> order) {
        final String orderCustomerId =
            order['customerId']
                    ?.toString()
                    .trim() ??
                '';

        return orderCustomerId ==
            currentCustomerId;
      },
    ).toList();
  }

  // =========================================================
  // SAFE DOUBLE
  // =========================================================

  double _amount(
    Map<String, dynamic> order,
    String key,
  ) {
    final dynamic value = order[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '0',
        ) ??
        0;
  }

  double? _toDouble(dynamic value) {
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
  // CUSTOMER LOCATION
  // =========================================================

  double? _customerLatitude(
    Map<String, dynamic> order,
  ) {
    final double? latitude =
        _toDouble(order['customerLat']);

    if (latitude != null) {
      return latitude;
    }

    return _toDouble(order['latitude']);
  }

  double? _customerLongitude(
    Map<String, dynamic> order,
  ) {
    final double? longitude =
        _toDouble(order['customerLng']);

    if (longitude != null) {
      return longitude;
    }

    return _toDouble(order['longitude']);
  }

  String _customerAddress(
    Map<String, dynamic> order,
  ) {
    final String customerAddress =
        order['customerAddress']
                ?.toString()
                .trim() ??
            '';

    if (customerAddress.isNotEmpty) {
      return customerAddress;
    }

    final String address =
        order['address']
                ?.toString()
                .trim() ??
            '';

    if (address.isNotEmpty) {
      return address;
    }

    return 'Address not available';
  }

  // =========================================================
  // SELLER IDS
  // =========================================================

  Set<String> _sellerIds(
    Map<String, dynamic> order,
  ) {
    final Set<String> ids =
        <String>{};

    final dynamic savedIds =
        order['sellerIds'];

    if (savedIds is List) {
      for (final dynamic value in savedIds) {
        final String id =
            value?.toString().trim() ?? '';

        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }

    final dynamic items = order['items'];

    if (items is List) {
      for (final dynamic item in items) {
        if (item is Map) {
          final String id =
              item['sellerId']
                      ?.toString()
                      .trim() ??
                  '';

          if (id.isNotEmpty) {
            ids.add(id);
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
      ids.add(topSellerId);
    }

    return ids;
  }

  // =========================================================
  // LOAD SELLER INFORMATION
  // =========================================================

  Future<List<Map<String, dynamic>>>
      _loadSellerInformation(
    Map<String, dynamic> order,
  ) async {
    final Set<String> sellerIds =
        _sellerIds(order);

    final List<Map<String, dynamic>>
        sellers =
        <Map<String, dynamic>>[];

    for (final String sellerId
        in sellerIds) {
      try {
        final DocumentSnapshot<
                Map<String, dynamic>>
            document =
            await FirebaseFirestore.instance
                .collection('sellers')
                .doc(sellerId)
                .get();

        if (!document.exists) {
          continue;
        }

        final Map<String, dynamic> data =
            document.data() ??
                <String, dynamic>{};

        sellers.add(
          <String, dynamic>{
            ...data,
            'sellerId': sellerId,
          },
        );
      } catch (_) {
        // Ignore one seller read failure.
      }
    }

    return sellers;
  }

  // =========================================================
  // PHONE
  // =========================================================

  String _cleanPhone(String phone) {
    return phone
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');
  }

  Future<void> _callPhone(
    String phone,
  ) async {
    final String cleanPhone =
        _cleanPhone(phone);

    if (cleanPhone.isEmpty) {
      _showMessage(
        'Phone number is not available.',
      );

      return;
    }

    final Uri uri = Uri(
      scheme: 'tel',
      path: cleanPhone,
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
        _cleanPhone(phone);

    if (cleanPhone.isEmpty) {
      _showMessage(
        'Phone number is not available.',
      );

      return;
    }

    final Uri uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
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
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/'
      '?api=1&query=$latitude,$longitude',
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
        content: Text(message),
      ),
    );
  }

  // =========================================================
  // DETAIL ROW
  // =========================================================

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight:
                    label == 'Final Total'
                        ? FontWeight.bold
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER DATE
  // =========================================================

  String _orderDate(
    Map<String, dynamic> order,
  ) {
    final String value =
        order['orderDateTime']
                ?.toString()
                .trim() ??
            '';

    if (value.isEmpty) {
      return '-';
    }

    final DateTime? date =
        DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final DateTime local =
        date.toLocal();

    final String day =
        local.day.toString().padLeft(
              2,
              '0',
            );

    final String month =
        local.month.toString().padLeft(
              2,
              '0',
            );

    final String hour =
        local.hour.toString().padLeft(
              2,
              '0',
            );

    final String minute =
        local.minute.toString().padLeft(
              2,
              '0',
            );

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  // =========================================================
  // PRODUCT IMAGE DIALOG
  // =========================================================

  void _showProductImage(
    String imageUrl,
  ) {
    if (imageUrl.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder:
          (BuildContext dialogContext) {
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
                      Icons
                          .image_not_supported,
                      size: 70,
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
  // PRODUCT DETAILS
  // =========================================================

  Widget _productsSection(
    Map<String, dynamic> order,
  ) {
    final dynamic rawItems =
        order['items'];

    if (rawItems is! List ||
        rawItems.isEmpty) {
      return const Text(
        'Product details are not available.',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(
              Icons.shopping_bag_outlined,
            ),
            SizedBox(width: 8),
            Text(
              'Products',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        ...rawItems.map<Widget>(
          (dynamic rawItem) {
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
                    'Product';

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

            String image =
                rawItem['image']
                        ?.toString()
                        .trim() ??
                    '';

            if (image.isEmpty) {
              image =
                  rawItem['imagePath']
                          ?.toString()
                          .trim() ??
                      '';
            }

            final bool hasNetworkImage =
                image.startsWith(
                  'http://',
                ) ||
                image.startsWith(
                  'https://',
                );

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
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
                  children: <Widget>[
                    GestureDetector(
                      onTap: hasNetworkImage
                          ? () {
                              _showProductImage(
                                image,
                              );
                            }
                          : null,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(10),
                        child: Container(
                          width: 78,
                          height: 78,
                          color: Colors
                              .grey.shade100,
                          child:
                              hasNetworkImage
                                  ? Image.network(
                                      image,
                                      fit: BoxFit
                                          .cover,
                                      errorBuilder: (
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
                                          size:
                                              35,
                                        );
                                      },
                                    )
                                  : const Icon(
                                      Icons
                                          .inventory_2_outlined,
                                      size: 35,
                                    ),
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
                        children: <Widget>[
                          Text(
                            name,
                            style:
                                const TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            'Price: $price',
                          ),

                          Text(
                            'Quantity: $quantity',
                          ),

                          if (color.isNotEmpty)
                            Text(
                              'Color: $color',
                            ),

                          if (size.isNotEmpty)
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
  // SELLER CARD
  // =========================================================

  Widget _sellerSection(
    Map<String, dynamic> order,
  ) {
    return FutureBuilder<
        List<Map<String, dynamic>>>(
      future:
          _loadSellerInformation(order),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                List<Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading seller information...',
                  ),
                ],
              ),
            ),
          );
        }

        final List<Map<String, dynamic>>
            sellers =
            snapshot.data ??
                <Map<String, dynamic>>[];

        if (sellers.isEmpty) {
          return const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(14),
              child: Text(
                'Seller information is not available for this order.',
              ),
            ),
          );
        }

        return Column(
          children: sellers.map<Widget>(
            (
              Map<String, dynamic> seller,
            ) {
              final String shopName =
                  seller['shopName']
                          ?.toString()
                          .trim() ??
                      seller['sellerShopName']
                          ?.toString()
                          .trim() ??
                      'Seller Shop';

              final String ownerName =
                  seller['ownerName']
                          ?.toString()
                          .trim() ??
                      '';

              final String phone =
                  seller['phone']
                          ?.toString()
                          .trim() ??
                      '';

              final String address =
                  seller['shopAddress']
                          ?.toString()
                          .trim() ??
                      seller['address']
                          ?.toString()
                          .trim() ??
                      '';

              final double? latitude =
                  _toDouble(
                seller['shopLatitude'],
              );

              final double? longitude =
                  _toDouble(
                seller['shopLongitude'],
              );

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      Row(
                        children:
                            <Widget>[
                          CircleAvatar(
                            child:
                                const Icon(
                              Icons.store,
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
                              children:
                                  <Widget>[
                                Text(
                                  shopName,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                if (ownerName
                                    .isNotEmpty)
                                  Text(
                                    ownerName,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (address.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 8,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children:
                                <Widget>[
                              const Icon(
                                Icons
                                    .location_on_outlined,
                                size: 18,
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Expanded(
                                child:
                                    Text(
                                  address,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(
                        height: 10,
                      ),

                      Row(
                        children:
                            <Widget>[
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
                                'Call Seller',
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 8,
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

                      if (latitude != null &&
                          longitude !=
                              null) ...<Widget>[
                        const SizedBox(
                          height: 8,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          child:
                              OutlinedButton
                                  .icon(
                            onPressed: () {
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
                              'Seller Shop Location',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  // =========================================================
  // CUSTOMER DELIVERY LOCATION
  // =========================================================

  Widget _customerLocationSection(
    Map<String, dynamic> order,
  ) {
    final double? latitude =
        _customerLatitude(order);

    final double? longitude =
        _customerLongitude(order);

    final bool hasLocation =
        latitude != null &&
            longitude != null;

    final String source =
        order['customerLocationSource']
                ?.toString()
                .trim() ??
            '';

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
                  Icons.location_on,
                  color: Colors.green,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delivery Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              _customerAddress(order),
            ),

            if (source.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 5,
                ),
                child: Text(
                  'Location Source: $source',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            if (hasLocation)
              SizedBox(
                width: double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    _openMap(
                      latitude,
                      longitude,
                    );
                  },
                  icon: const Icon(
                    Icons.map_outlined,
                  ),
                  label: const Text(
                    'Open Delivery Location',
                  ),
                ),
              )
            else
              const Text(
                'Map coordinates are not available for this order.',
                style: TextStyle(
                  color: Colors.orange,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DELIVERY PERSON STATUS
  // =========================================================

  Widget _deliveryPersonSection(
    Map<String, dynamic> order,
  ) {
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

    final double? driverLat =
        _toDouble(order['driverLat']);

    final double? driverLng =
        _toDouble(order['driverLng']);

    final String trackingStatus =
        order['trackingStatus']
                ?.toString()
                .trim() ??
            'Order Placed';

    final String lastUpdated =
        order['driverLocationUpdatedAt']
                ?.toString()
                .trim() ??
            '';

    final bool hasLiveLocation =
        driverLat != null &&
            driverLng != null;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor:
                      Colors.blue.withValues(
                    alpha: 0.15,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.blue,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      Text(
                        driverName.isEmpty
                            ? 'Delivery Person'
                            : driverName,
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Text(
                        trackingStatus,
                        style: TextStyle(
                          color: Colors
                              .grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!hasLiveLocation)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 10,
                ),
                child: Text(
                  'Live delivery location has not started yet.',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                  ),
                ),
              ),

            if (hasLiveLocation) ...<Widget>[
              const SizedBox(height: 10),

              const Row(
                children: <Widget>[
                  Icon(
                    Icons
                        .my_location_outlined,
                    size: 18,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Live location available',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),

              if (lastUpdated.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 4,
                  ),
                  child: Text(
                    'Last updated: '
                    '$lastUpdated',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey.shade600,
                    ),
                  ),
                ),
            ],

            if (driverPhone.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),

              Row(
                children: <Widget>[
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        _callPhone(
                          driverPhone,
                        );
                      },
                      icon: const Icon(
                        Icons.call,
                      ),
                      label: const Text(
                        'Call Driver',
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        _sendSms(
                          driverPhone,
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
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _confirmDelete(
    Map<String, dynamic> order,
  ) async {
    final bool? shouldDelete =
        await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title:
              const Text('Remove order?'),
          content: const Text(
            'This order will be removed from local order history.',
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
                  const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    orderHistory.removeWhere(
      (
        Map<String, dynamic> item,
      ) =>
          item['id']?.toString() ==
          order['id']?.toString(),
    );

    await saveOrders();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // =========================================================
  // OPEN TRACKING
  // =========================================================

  void _openTracking(
    Map<String, dynamic> order,
  ) {
    final String orderId =
        order['id']
                ?.toString()
                .trim() ??
            '';

    if (orderId.isEmpty) {
      _showMessage(
        'Order ID is not available.',
      );

      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            OrderTrackingPage(
          orderId: orderId,
        ),
      ),
    );
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'Pending':
        return Colors.orange;

      case 'Confirmed':
        return Colors.green;

      case 'Processing':
        return Colors.blue;

      case 'Shipped':
        return Colors.deepPurple;

      case 'Delivered':
        return Colors.teal;

      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<Map<String, dynamic>>
        customerOrders =
        _currentCustomerOrders();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : customerOrders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: <Widget>[
                      Icon(
                        Icons
                            .receipt_long_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      Text(
                        'No orders yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 6,
                      ),
                      Text(
                        'Your placed orders will appear here.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    itemCount:
                        customerOrders.length,
                    itemBuilder: (
                      BuildContext context,
                      int index,
                    ) {
                      final Map<String,
                              dynamic>
                          order =
                          customerOrders[
                              index];

                      final double discount =
                          _amount(
                        order,
                        'discount',
                      );

                      final double delivery =
                          _amount(
                        order,
                        'delivery',
                      );

                      final String status =
                          (order['status'] ??
                                  'Pending')
                              .toString();

                      final String
                          trackingStatus =
                          (order[
                                      'trackingStatus'] ??
                                  'Order Placed')
                              .toString();

                      final double?
                          customerLat =
                          _customerLatitude(
                        order,
                      );

                      final double?
                          customerLng =
                          _customerLongitude(
                        order,
                      );

                      final bool
                          hasCustomerLocation =
                          customerLat !=
                                  null &&
                              customerLng !=
                                  null;

                      return Card(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 12,
                        ),
                        child:
                            ExpansionTile(
                          leading:
                              CircleAvatar(
                            backgroundColor:
                                _statusColor(
                                      status,
                                    )
                                    .withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(
                              Icons
                                  .local_shipping,
                              color:
                                  _statusColor(
                                status,
                              ),
                            ),
                          ),

                          title: Text(
                            'Order #${order['id']?.toString() ?? ''}',
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children:
                                <Widget>[
                              Text(
                                'Final Total: Rs. '
                                '${_amount(order, 'amount').toStringAsFixed(0)}',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.green,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                'Tracking: '
                                '$trackingStatus',
                                style:
                                    TextStyle(
                                  fontSize: 12,
                                  color: Colors
                                      .grey
                                      .shade700,
                                ),
                              ),
                            ],
                          ),

                          trailing: Chip(
                            label:
                                Text(status),
                            backgroundColor:
                                _statusColor(
                                      status,
                                    )
                                    .withValues(
                              alpha: 0.15,
                            ),
                          ),

                          childrenPadding:
                              const EdgeInsets
                                  .fromLTRB(
                            16,
                            0,
                            16,
                            14,
                          ),

                          children:
                              <Widget>[
                            const Divider(),

                            _detailRow(
                              'Customer',
                              order['name']
                                      ?.toString() ??
                                  '-',
                            ),

                            _detailRow(
                              'Phone',
                              order['phone']
                                      ?.toString() ??
                                  '-',
                            ),

                            _detailRow(
                              'Order Date',
                              _orderDate(
                                order,
                              ),
                            ),

                            _detailRow(
                              'Area',
                              order['deliveryArea']
                                      ?.toString() ??
                                  '-',
                            ),

                            _detailRow(
                              'Address',
                              _customerAddress(
                                order,
                              ),
                            ),

                            _detailRow(
                              'Payment',
                              order['payment']
                                      ?.toString() ??
                                  '-',
                            ),

                            const Divider(),

                            _productsSection(
                              order,
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _sellerSection(
                              order,
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _customerLocationSection(
                              order,
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _deliveryPersonSection(
                              order,
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            const Divider(),

                            _detailRow(
                              'Subtotal',
                              'Rs. ${_amount(order, 'subtotal').toStringAsFixed(0)}',
                            ),

                            if (discount > 0)
                              _detailRow(
                                'Discount',
                                '- Rs. '
                                '${discount.toStringAsFixed(0)}',
                                valueColor:
                                    Colors.red,
                              ),

                            _detailRow(
                              'Delivery',
                              delivery == 0
                                  ? 'Free'
                                  : 'Rs. ${delivery.toStringAsFixed(0)}',
                              valueColor:
                                  delivery == 0
                                      ? Colors
                                          .green
                                      : null,
                            ),

                            const Divider(),

                            _detailRow(
                              'Final Total',
                              'Rs. ${_amount(order, 'amount').toStringAsFixed(0)}',
                              valueColor:
                                  Colors.green,
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            SizedBox(
                              width:
                                  double.infinity,
                              height: 54,
                              child:
                                  ElevatedButton
                                      .icon(
                                onPressed: () {
                                  _openTracking(
                                    order,
                                  );
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .location_searching,
                                ),
                                label:
                                    const Text(
                                  'Track Order',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Row(
                              children:
                                  <Widget>[
                                Icon(
                                  hasCustomerLocation
                                      ? Icons
                                          .check_circle
                                      : Icons
                                          .warning_amber,
                                  size: 17,
                                  color: hasCustomerLocation
                                      ? Colors
                                          .green
                                      : Colors
                                          .orange,
                                ),
                                const SizedBox(
                                  width: 6,
                                ),
                                Expanded(
                                  child: Text(
                                    hasCustomerLocation
                                        ? 'Customer map location available'
                                        : 'Map coordinates are not available for this order',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          12,
                                      color: Colors
                                          .grey
                                          .shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            Align(
                              alignment:
                                  Alignment
                                      .centerRight,
                              child:
                                  TextButton.icon(
                                onPressed: () {
                                  _confirmDelete(
                                    order,
                                  );
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .delete_outline,
                                  color:
                                      Colors.red,
                                ),
                                label:
                                    const Text(
                                  'Remove',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}