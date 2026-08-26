import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_data.dart';
import 'order_details_page.dart';
import 'tracking/order_tracking_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() =>
      _OrderHistoryPageState();
}

class _OrderHistoryPageState
    extends State<OrderHistoryPage> {
  String customerId = '';

  bool isLoadingCustomer = true;

  @override
  void initState() {
    super.initState();

    _loadCustomerId();
  }

  // =========================================================
  // LOAD CUSTOMER ID
  // =========================================================

  Future<void> _loadCustomerId() async {
    try {
      final String id = await getOrCreateCustomerId();

      // Load customer-specific local backup, recover legacy device orders,
      // migrate what can be migrated, and start the realtime listener.
      await loadOrders();

      if (!mounted) {
        return;
      }

      setState(() {
        customerId = id;
        isLoadingCustomer = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        customerId = '';
        isLoadingCustomer = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not start customer session: $error',
          ),
        ),
      );
    }
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
  // CUSTOMER LOCATION
  // =========================================================

  double? _customerLatitude(
    Map<String, dynamic> order,
  ) {
    final double? latitude =
        _toDouble(
      order['customerLat'],
    );

    if (latitude != null) {
      return latitude;
    }

    return _toDouble(
      order['latitude'],
    );
  }

  double? _customerLongitude(
    Map<String, dynamic> order,
  ) {
    final double? longitude =
        _toDouble(
      order['customerLng'],
    );

    if (longitude != null) {
      return longitude;
    }

    return _toDouble(
      order['longitude'],
    );
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
  // CUSTOMER NAME
  // =========================================================

  String _customerName(
    Map<String, dynamic> order,
  ) {
    final String customerName =
        order['customerName']
                ?.toString()
                .trim() ??
            '';

    if (customerName.isNotEmpty) {
      return customerName;
    }

    final String name =
        order['name']
                ?.toString()
                .trim() ??
            '';

    if (name.isNotEmpty) {
      return name;
    }

    return 'Customer';
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
      for (final dynamic value
          in savedIds) {
        final String id =
            value?.toString().trim() ??
                '';

        if (id.isNotEmpty) {
          ids.add(id);
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
            ids.add(sellerId);
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
  // LOAD SELLERS
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
            await FirebaseFirestore
                .instance
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
        // Continue with other sellers.
      }
    }

    return sellers;
  }

  // =========================================================
  // CLEAN PHONE
  // =========================================================

  String _cleanPhone(
    String phone,
  ) {
    return phone
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');
  }

  // =========================================================
  // CALL
  // =========================================================

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
  // MAP
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
            width: 105,
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
        local.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String month =
        local.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String hour =
        local.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String minute =
        local.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  // =========================================================
  // PRODUCT IMAGE
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
  // PRODUCTS
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
                      onTap:
                          hasNetworkImage
                              ? () {
                                  _showProductImage(
                                    image,
                                  );
                                }
                              : null,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        child: Container(
                          width: 78,
                          height: 78,
                          color: Colors
                              .grey
                              .shade100,
                          child:
                              hasNetworkImage
                                  ? Image.network(
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
                                          size: 35,
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
  // SELLER SECTION
  // =========================================================

  Widget _sellerSection(
    Map<String, dynamic> order,
  ) {
    return FutureBuilder<
        List<Map<String, dynamic>>>(
      future:
          _loadSellerInformation(
        order,
      ),
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
                      seller[
                                  'sellerShopName']
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
                          const CircleAvatar(
                            child: Icon(
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
                                child: Text(
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
  // DELIVERY LOCATION
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
  // DELIVERY PERSON
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
                      Colors.blue
                          .withValues(
                    alpha: 0.15,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.blue,
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
              const SizedBox(
                height: 10,
              ),

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

              const SizedBox(
                height: 8,
              ),

              SizedBox(
                width: double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    _openMap(
                      driverLat,
                      driverLng,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .delivery_dining,
                  ),
                  label: const Text(
                    'Open Delivery Person Location',
                  ),
                ),
              ),
            ],

            if (driverPhone.isNotEmpty)
              ...<Widget>[
                const SizedBox(
                  height: 10,
                ),

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

                    const SizedBox(
                      width: 8,
                    ),

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
  // SECURE DELIVERY OTP / CODE
  // =========================================================

  Widget _deliveryVerificationSection(
    Map<String, dynamic> order,
  ) {
    final String deliveryOtp =
        order['deliveryOtp']
                ?.toString()
                .trim() ??
            '';

    final bool verified =
        order['deliveryOtpVerified'] ==
            true;

    final String status =
        order['status']
                ?.toString()
                .trim() ??
            'Pending';

    final String method =
        order['deliveryConfirmationMethod']
                ?.toString()
                .trim() ??
            '';

    // Old orders without OTP should not show an empty card.
    if (deliveryOtp.isEmpty &&
        !verified &&
        status != 'Delivered') {
      return const SizedBox.shrink();
    }

    final bool delivered =
        verified ||
            status == 'Delivered';

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor:
                      delivered
                          ? Colors.green
                              .withValues(
                              alpha: 0.15,
                            )
                          : Colors.orange
                              .withValues(
                              alpha: 0.15,
                            ),
                  child: Icon(
                    delivered
                        ? Icons.verified
                        : Icons.lock_outline,
                    color: delivered
                        ? Colors.green
                        : Colors.orange,
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
                      const Text(
                        'Secure Delivery Code',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        delivered
                            ? 'Delivery verified successfully'
                            : 'Give this code only after receiving your order.',
                        style: TextStyle(
                          fontSize: 12,
                          color: delivered
                              ? Colors.green
                              : Colors
                                  .grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!delivered &&
                deliveryOtp.isNotEmpty) ...<Widget>[
              const SizedBox(
                height: 16,
              ),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      Colors.orange.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color:
                        Colors.orange.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const Text(
                      'SCAN TO CONFIRM DELIVERY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.deepPurple,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: deliveryOtp,
                        version: QrVersions.auto,
                        size: 190,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Text(
                      'DELIVERY CODE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.orange,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    SelectableText(
                      deliveryOtp,
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        fontSize: 32,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.security,
                    size: 18,
                    color: Colors.red,
                  ),
                  SizedBox(
                    width: 7,
                  ),
                  Expanded(
                    child: Text(
                      'Do not share this code by phone or SMS. Give it to the delivery person only after you physically receive your product.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (delivered) ...<Widget>[
              const SizedBox(
                height: 14,
              ),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration: BoxDecoration(
                  color:
                      Colors.green.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.verified_user,
                      color: Colors.green,
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
                          const Text(
                            'Delivery Verified',
                            style: TextStyle(
                              color:
                                  Colors.green,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          if (method.isNotEmpty)
                            Text(
                              'Confirmation: $method',
                              style:
                                  const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ORDER DETAILS
  // =========================================================

  void _openOrderDetails(
    Map<String, dynamic> order,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsPage(
          order: Map<String, dynamic>.from(order),
        ),
      ),
    );
  }

  // =========================================================
  // TRACK ORDER
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

      case 'Cancelled':
        return Colors.red;

      case 'Returned':
        return Colors.brown;

      case 'Refunded':
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // CUSTOMER CANCEL / RETURN / REFUND REQUESTS
  // =========================================================

  String _requestStatus(
    Map<String, dynamic> order,
    String key,
  ) {
    return order[key]
            ?.toString()
            .trim() ??
        '';
  }

  Color _requestStatusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending review':
        return Colors.orange;
      case 'approved':
      case 'accepted':
      case 'refunded':
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'declined':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  bool _canRequestCancellation(
    Map<String, dynamic> order,
  ) {
    final String status =
        order['status']
                ?.toString()
                .trim() ??
            '';

    final String trackingStatus =
        order['trackingStatus']
                ?.toString()
                .trim() ??
            '';

    final String requestStatus =
        _requestStatus(
      order,
      'cancelRequestStatus',
    );

    if (requestStatus.isNotEmpty) {
      return false;
    }

    if (status == 'Delivered' ||
        status == 'Cancelled' ||
        status == 'Shipped') {
      return false;
    }

    final String tracking =
        trackingStatus.toLowerCase();

    if (tracking.contains('picked up') ||
        tracking.contains('out for delivery') ||
        tracking.contains('delivered')) {
      return false;
    }

    return true;
  }

  bool _canRequestReturn(
    Map<String, dynamic> order,
  ) {
    final String status =
        order['status']
                ?.toString()
                .trim() ??
            '';

    final String requestStatus =
        _requestStatus(
      order,
      'returnRequestStatus',
    );

    return status == 'Delivered' &&
        requestStatus.isEmpty;
  }

  Future<void> _showCustomerRequestDialog({
    required Map<String, dynamic> order,
    required bool isReturn,
  }) async {
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

    final List<String> reasons =
        isReturn
            ? <String>[
                'Damaged product',
                'Wrong product received',
                'Product not as described',
                'Product not working',
                'Missing item / accessory',
                'Changed my mind',
                'Other',
              ]
            : <String>[
                'Ordered by mistake',
                'Changed my mind',
                'Delivery is taking too long',
                'Wrong address / details',
                'Found another product',
                'Other',
              ];

    String selectedReason =
        reasons.first;

    final TextEditingController
        noteController =
        TextEditingController();

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        BuildContext dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(
              void Function(),
            ) setDialogState,
          ) {
            Future<void> submit() async {
              if (isSubmitting) {
                return;
              }

              setDialogState(() {
                isSubmitting = true;
              });

              try {
                final String now =
                    DateTime.now()
                        .toIso8601String();

                final Map<String, dynamic>
                    update =
                    isReturn
                        ? <String, dynamic>{
                            'returnRequestStatus':
                                'Pending',
                            'returnRequestReason':
                                selectedReason,
                            'returnRequestNote':
                                noteController.text
                                    .trim(),
                            'returnRequestedAt':
                                now,
                            'returnRequestedBy':
                                'customer',
                            'customerRequestType':
                                'Return',
                            'customerRequestStatus':
                                'Pending',
                            'customerRequestUpdatedAt':
                                now,
                          }
                        : <String, dynamic>{
                            'cancelRequestStatus':
                                'Pending',
                            'cancelRequestReason':
                                selectedReason,
                            'cancelRequestNote':
                                noteController.text
                                    .trim(),
                            'cancelRequestedAt':
                                now,
                            'cancelRequestedBy':
                                'customer',
                            'customerRequestType':
                                'Cancellation',
                            'customerRequestStatus':
                                'Pending',
                            'customerRequestUpdatedAt':
                                now,
                          };

                await updateOrderTrackingFields(
                  orderId,
                  update,
                );

                if (!mounted ||
                    !dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                await reloadOrdersForCurrentCustomer();

                if (!mounted) {
                  return;
                }

                setState(() {});

                _showMessage(
                  isReturn
                      ? 'Return request submitted successfully.'
                      : 'Cancellation request submitted successfully.',
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }

                _showMessage(
                  'Could not submit request: $error',
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSubmitting = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(
                isReturn
                    ? 'Request Return'
                    : 'Request Cancellation',
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
                      isReturn
                          ? 'Tell us why you want to return this delivered order.'
                          : 'Tell us why you want to cancel this order.',
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          selectedReason,
                      decoration:
                          const InputDecoration(
                        labelText: 'Reason',
                        border:
                            OutlineInputBorder(),
                      ),
                      items: reasons
                          .map<
                              DropdownMenuItem<
                                  String>>(
                            (
                              String reason,
                            ) =>
                                DropdownMenuItem<
                                    String>(
                              value: reason,
                              child:
                                  Text(reason),
                            ),
                          )
                          .toList(),
                      onChanged:
                          isSubmitting
                              ? null
                              : (
                                  String?
                                      value,
                                ) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setDialogState(
                                    () {
                                      selectedReason =
                                          value;
                                    },
                                  );
                                },
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      controller:
                          noteController,
                      enabled:
                          !isSubmitting,
                      minLines: 3,
                      maxLines: 5,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Additional details (optional)',
                        hintText:
                            'Write any useful details here.',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      isReturn
                          ? 'Your return request will be reviewed before any refund is processed.'
                          : 'Submitting this request does not instantly cancel the order. Seller/Admin approval may be required.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors
                            .grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      isSubmitting
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                  child:
                      const Text('Back'),
                ),
                FilledButton.icon(
                  onPressed:
                      isSubmitting
                          ? null
                          : submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isReturn
                              ? Icons
                                  .assignment_return_outlined
                              : Icons
                                  .cancel_outlined,
                        ),
                  label: Text(
                    isSubmitting
                        ? 'Submitting...'
                        : 'Submit Request',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  Widget _customerRequestSection(
    Map<String, dynamic> order,
  ) {
    final String cancelStatus =
        _requestStatus(
      order,
      'cancelRequestStatus',
    );

    final String cancelReason =
        _requestStatus(
      order,
      'cancelRequestReason',
    );

    final String returnStatus =
        _requestStatus(
      order,
      'returnRequestStatus',
    );

    final String returnReason =
        _requestStatus(
      order,
      'returnRequestReason',
    );

    final String refundStatus =
        _requestStatus(
      order,
      'refundStatus',
    );

    final String refundReference =
        _requestStatus(
      order,
      'refundReference',
    );

    final bool canCancel =
        _canRequestCancellation(
      order,
    );

    final bool canReturn =
        _canRequestReturn(
      order,
    );

    final bool hasRequest =
        cancelStatus.isNotEmpty ||
            returnStatus.isNotEmpty ||
            refundStatus.isNotEmpty;

    if (!canCancel &&
        !canReturn &&
        !hasRequest) {
      return const SizedBox
          .shrink();
    }

    Widget requestRow(
      String title,
      String status, {
      String reason = '',
      String reference = '',
    }) {
      final Color color =
          _requestStatusColor(
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
              alpha: 0.25,
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
                    alpha: 0.14,
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty)
              Text(
                'Reason: $reason',
              ),
            if (reference.isNotEmpty)
              Text(
                'Reference: $reference',
              ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
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
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancel / Return / Refund',
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
            if (cancelStatus
                .isNotEmpty)
              requestRow(
                'Cancellation Request',
                cancelStatus,
                reason:
                    cancelReason,
              ),
            if (returnStatus
                .isNotEmpty)
              requestRow(
                'Return Request',
                returnStatus,
                reason:
                    returnReason,
              ),
            if (refundStatus
                .isNotEmpty)
              requestRow(
                'Refund',
                refundStatus,
                reference:
                    refundReference,
              ),
            if (canCancel)
              SizedBox(
                width:
                    double.infinity,
                height: 50,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    _showCustomerRequestDialog(
                      order: order,
                      isReturn: false,
                    );
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Request Order Cancellation',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (canCancel &&
                canReturn)
              const SizedBox(
                height: 10,
              ),
            if (canReturn)
              SizedBox(
                width:
                    double.infinity,
                height: 50,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    _showCustomerRequestDialog(
                      order: order,
                      isReturn: true,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .assignment_return_outlined,
                  ),
                  label: const Text(
                    'Request Product Return',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (hasRequest) ...<Widget>[
              const SizedBox(
                height: 4,
              ),
              Text(
                'Seller/Admin review status will appear here automatically.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors
                      .grey.shade700,
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
        order['status']
                ?.toString()
                .trim() ??
            'Pending';

    final String trackingStatus =
        order['trackingStatus']
                ?.toString()
                .trim() ??
            'Order Placed';

    final double? customerLat =
        _customerLatitude(
      order,
    );

    final double? customerLng =
        _customerLongitude(
      order,
    );

    final bool hasCustomerLocation =
        customerLat != null &&
            customerLng != null;

    final String orderId =
        order['id']
                ?.toString()
                .replaceFirst(
                  'RD',
                  '',
                ) ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor:
              _statusColor(
                    status,
                  )
                  .withValues(
            alpha: 0.15,
          ),
          child: Icon(
            Icons.local_shipping,
            color:
                _statusColor(status),
          ),
        ),

        title: InkWell(
          onTap: () {
            _openOrderDetails(order);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: Text(
              'Order #$orderId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Final Total: Rs. '
              '${_amount(order, 'amount').toStringAsFixed(0)}',
              style:
                  const TextStyle(
                color: Colors.green,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              'Tracking: '
              '$trackingStatus',
              style: TextStyle(
                fontSize: 12,
                color: Colors
                    .grey.shade700,
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
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          14,
        ),

        children: <Widget>[
          const Divider(),

          _detailRow(
            'Customer',
            _customerName(
              order,
            ),
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

          // ==============================================
          // PRODUCTS
          // ==============================================

          _productsSection(
            order,
          ),

          const SizedBox(
            height: 10,
          ),

          // ==============================================
          // SELLER
          // ==============================================

          _sellerSection(
            order,
          ),

          const SizedBox(
            height: 10,
          ),

          // ==============================================
          // CUSTOMER DELIVERY LOCATION
          // ==============================================

          _customerLocationSection(
            order,
          ),

          const SizedBox(
            height: 10,
          ),

          // ==============================================
          // DELIVERY PERSON
          // ==============================================

          _deliveryPersonSection(
            order,
          ),

          const SizedBox(
            height: 10,
          ),

          // ==============================================
          // SECURE DELIVERY OTP
          // ==============================================

          _deliveryVerificationSection(
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
                    ? Colors.green
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

          // ==============================================
          // VIEW ORDER DETAILS
          // ==============================================

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                _openOrderDetails(order);
              },
              icon: const Icon(
                Icons.receipt_long,
              ),
              label: const Text(
                'View Order Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // ==============================================
          // TRACK ORDER
          // ==============================================

          SizedBox(
            width: double.infinity,
            height: 54,
            child:
                ElevatedButton.icon(
              onPressed: () {
                _openTracking(
                  order,
                );
              },
              icon: const Icon(
                Icons
                    .location_searching,
              ),
              label: const Text(
                'Track Order',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          // ==============================================
          // CANCEL / RETURN / REFUND REQUEST
          // ==============================================

          _customerRequestSection(
            order,
          ),

          const SizedBox(
            height: 8,
          ),

          Row(
            children: <Widget>[
              Icon(
                hasCustomerLocation
                    ? Icons
                        .check_circle
                    : Icons
                        .warning_amber,
                size: 17,
                color:
                    hasCustomerLocation
                        ? Colors.green
                        : Colors.orange,
              ),

              const SizedBox(
                width: 6,
              ),

              Expanded(
                child: Text(
                  hasCustomerLocation
                      ? 'Customer map location available'
                      : 'Map coordinates are not available for this order',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // RECOVER ORDER ON A NEW DEVICE
  // =========================================================

  Future<void> _showRecoverOrderDialog() async {
    final TextEditingController orderIdController =
        TextEditingController();

    final TextEditingController phoneController =
        TextEditingController();

    bool isRecovering = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        BuildContext dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setDialogState,
          ) {
            Future<void> recover() async {
              if (isRecovering) {
                return;
              }

              final String orderId =
                  orderIdController.text.trim();

              final String phone =
                  phoneController.text.trim();

              if (orderId.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter the Order ID and phone number.',
                    ),
                  ),
                );

                return;
              }

              setDialogState(() {
                isRecovering = true;
              });

              try {
                await recoverCustomerOrder(
                  orderId: orderId,
                  phone: phone,
                );

                if (!mounted || !dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                await reloadOrdersForCurrentCustomer();

                if (!mounted) {
                  return;
                }

                setState(() {});

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Order recovered successfully.',
                    ),
                  ),
                );
              } on FirebaseException catch (error) {
                if (!mounted) {
                  return;
                }

                final String message =
                    error.code == 'not-found'
                        ? 'Order not found. Please check the Order ID.'
                        : 'Order ID or phone number did not match.';

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                  ),
                );
              } on ArgumentError catch (error) {
                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.message?.toString() ??
                          'Please check the entered details.',
                    ),
                  ),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isRecovering = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text(
                'Recover My Order',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Enter the Order ID and the phone number used when placing the order.',
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: orderIdController,
                      enabled: !isRecovering,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Order ID',
                        hintText: 'RD123456789',
                        prefixIcon: Icon(Icons.receipt_long),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: phoneController,
                      enabled: !isRecovering,
                      keyboardType: TextInputType.phone,
                      onSubmitted: (_) {
                        recover();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isRecovering
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isRecovering ? null : recover,
                  icon: isRecovering
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.restore),
                  label: Text(
                    isRecovering ? 'Checking...' : 'Recover Order',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    orderIdController.dispose();
    phoneController.dispose();
  }

  List<Map<String, dynamic>> _mergeVisibleOrders(
    List<Map<String, dynamic>> cloudOrders,
  ) {
    final Map<String, Map<String, dynamic>> mergedById =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> localOrder in orderHistory) {
      if (localOrder['customerId']?.toString().trim() != customerId) {
        continue;
      }

      final String id = localOrder['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        mergedById[id] = Map<String, dynamic>.from(localOrder);
      }
    }

    // Cloud data wins when the same order exists locally and in Firestore.
    for (final Map<String, dynamic> cloudOrder in cloudOrders) {
      final String id = cloudOrder['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        mergedById[id] = Map<String, dynamic>.from(cloudOrder);
      }
    }

    final List<Map<String, dynamic>> orders =
        mergedById.values.toList();

    orders.sort(
      (Map<String, dynamic> first, Map<String, dynamic> second) {
        final DateTime? firstDate = DateTime.tryParse(
          first['orderDateTime']?.toString() ?? '',
        );
        final DateTime? secondDate = DateTime.tryParse(
          second['orderDateTime']?.toString() ?? '',
        );

        if (firstDate == null && secondDate == null) return 0;
        if (firstDate == null) return 1;
        if (secondDate == null) return -1;
        return secondDate.compareTo(firstDate);
      },
    );

    return orders;
  }

  Widget _ordersList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return _emptyOrders();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await reloadOrdersForCurrentCustomer();
        if (mounted) {
          setState(() {});
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          return _orderCard(orders[index]);
        },
      ),
    );
  }

  // =========================================================
  // EMPTY PAGE
  // =========================================================

  Widget _emptyOrders() {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
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
          'My Orders',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRecoverOrderDialog,
        icon: const Icon(Icons.restore),
        label: const Text(
          'Recover Order',
        ),
      ),

      body: isLoadingCustomer
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : customerId.isEmpty
              ? const Center(
                  child: Text(
                    'Customer account could not be loaded.',
                  ),
                )
              : StreamBuilder<
                  List<Map<String, dynamic>>>(
                  stream:
                      customerOrdersStream(
                    customerId,
                  ),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<
                            List<
                                Map<String,
                                    dynamic>>>
                        snapshot,
                  ) {
                    final List<Map<String, dynamic>> cloudOrders =
                        snapshot.data ?? <Map<String, dynamic>>[];

                    final List<Map<String, dynamic>> visibleOrders =
                        _mergeVisibleOrders(cloudOrders);

                    // Do not hide recovered local orders while Firestore is
                    // still connecting.
                    if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                        visibleOrders.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    // If Firestore temporarily fails but local orders exist,
                    // keep showing the local backup instead of an empty/error
                    // page.
                    if (snapshot.hasError && visibleOrders.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline,
                                size: 60,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Could not load your orders.',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return _ordersList(visibleOrders);
                  },
                ),
    );
  }
}
