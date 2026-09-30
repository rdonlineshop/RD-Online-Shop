import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'cart_page.dart';
import 'customer_dashboard_page.dart';
import 'data/cart_data.dart';
import 'krishi_seller_auth_page.dart';

class KrishiMarketplacePage extends StatefulWidget {
  const KrishiMarketplacePage({super.key});

  @override
  State<KrishiMarketplacePage> createState() =>
      _KrishiMarketplacePageState();
}

class _KrishiMarketplacePageState
    extends State<KrishiMarketplacePage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _selectedCategory = 'All';

  static const List<String> _categories = <String>[
    'All',
    'Vegetables',
    'Fruits',
    'Grains & Cereals',
    'Pulses & Beans',
    'Seeds',
    'Spices',
    'Herbs',
    'Dairy',
    'Eggs',
    'Honey',
    'Organic Products',
    'Nursery & Plants',
    'Fertilizer & Compost',
    'Animal Feed',
    'Agriculture Tools',
    'Other Agriculture',
  ];

  static const Map<String, String> _defaultProductImages =
      <String, String>{
    'All':
        'assets/categories/krishi_default_all.jpg',
    'Vegetables':
        'assets/categories/krishi_default_vegetables.jpg',
    'Fruits':
        'assets/categories/krishi_default_fruits.jpg',
    'Grains & Cereals':
        'assets/categories/krishi_default_grains_cereals.jpg',
    'Pulses & Beans':
        'assets/categories/krishi_default_pulses_beans.jpg',
    'Seeds':
        'assets/categories/krishi_default_seeds.jpg',
    'Spices':
        'assets/categories/krishi_default_spices.jpg',
    'Herbs':
        'assets/categories/krishi_default_herbs.jpg',
    'Dairy':
        'assets/categories/krishi_default_dairy.jpg',
    'Eggs':
        'assets/categories/krishi_default_eggs.jpg',
    'Honey':
        'assets/categories/krishi_default_honey.jpg',
    'Organic Products':
        'assets/categories/krishi_default_organic_products.jpg',
    'Nursery & Plants':
        'assets/categories/krishi_default_nursery_plants.jpg',
    'Fertilizer & Compost':
        'assets/categories/krishi_default_fertilizer_compost.jpg',
    'Animal Feed':
        'assets/categories/krishi_default_animal_feed.jpg',
    'Agriculture Tools':
        'assets/categories/krishi_default_agriculture_tools.jpg',
    'Other Agriculture':
        'assets/categories/krishi_default_other_agriculture.jpg',
  };

  String _defaultProductImage(
    Map<String, dynamic> product,
  ) {
    final String category =
        product['category']?.toString().trim() ?? '';

    final String? exact =
        _defaultProductImages[category];

    if (exact != null) {
      return exact;
    }

    final String normalized =
        category.toLowerCase();

    if (normalized.contains('vegetable')) {
      return _defaultProductImages['Vegetables']!;
    }
    if (normalized.contains('fruit')) {
      return _defaultProductImages['Fruits']!;
    }
    if (normalized.contains('grain') ||
        normalized.contains('cereal') ||
        normalized.contains('rice')) {
      return _defaultProductImages['Grains & Cereals']!;
    }
    if (normalized.contains('pulse') ||
        normalized.contains('bean') ||
        normalized.contains('lentil')) {
      return _defaultProductImages['Pulses & Beans']!;
    }
    if (normalized.contains('seed')) {
      return _defaultProductImages['Seeds']!;
    }
    if (normalized.contains('spice')) {
      return _defaultProductImages['Spices']!;
    }
    if (normalized.contains('herb')) {
      return _defaultProductImages['Herbs']!;
    }
    if (normalized.contains('dairy') ||
        normalized.contains('milk')) {
      return _defaultProductImages['Dairy']!;
    }
    if (normalized.contains('egg')) {
      return _defaultProductImages['Eggs']!;
    }
    if (normalized.contains('honey')) {
      return _defaultProductImages['Honey']!;
    }
    if (normalized.contains('organic')) {
      return _defaultProductImages['Organic Products']!;
    }
    if (normalized.contains('nursery') ||
        normalized.contains('plant')) {
      return _defaultProductImages['Nursery & Plants']!;
    }
    if (normalized.contains('fertilizer') ||
        normalized.contains('compost')) {
      return _defaultProductImages['Fertilizer & Compost']!;
    }
    if (normalized.contains('feed')) {
      return _defaultProductImages['Animal Feed']!;
    }
    if (normalized.contains('tool')) {
      return _defaultProductImages['Agriculture Tools']!;
    }

    return _defaultProductImages['Other Agriculture']!;
  }

  bool _isKrishiProduct(
    Map<String, dynamic> data,
  ) {
    final String marketplace =
        data['marketplace']?.toString().trim().toLowerCase() ?? '';
    final String productType =
        data['productType']?.toString().trim().toLowerCase() ?? '';

    return marketplace == 'krishi' ||
        productType == 'krishi' ||
        productType == 'agriculture';
  }

  List<String> _images(
    Map<String, dynamic> data,
  ) {
    final List<String> result = <String>[];

    final dynamic raw = data['imagePaths'];
    if (raw is List) {
      for (final dynamic item in raw) {
        final String value = item?.toString().trim() ?? '';
        if (value.isNotEmpty && !result.contains(value)) {
          result.add(value);
        }
      }
    }

    for (final String key in <String>[
      'imagePath',
      'imageUrl',
      'photoUrl',
      'thumbnailUrl',
      'image',
    ]) {
      final String value =
          data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && !result.contains(value)) {
        result.add(value);
      }
    }

    return result;
  }

  double _number(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    final String cleaned = value
            ?.toString()
            .replaceAll(RegExp(r'[^0-9.\-]'), '')
            .trim() ??
        '';

    return double.tryParse(cleaned) ?? fallback;
  }

  double? _stock(
    Map<String, dynamic> product,
  ) {
    for (final String key in <String>[
      'stock',
      'stockQuantity',
      'availableQty',
      'availableQuantity',
      'quantity',
    ]) {
      if (product[key] == null) {
        continue;
      }

      final double parsed = _number(
        product[key],
        fallback: -1,
      );

      if (parsed >= 0) {
        return parsed;
      }
    }

    return null;
  }

  String _unit(
    Map<String, dynamic> product,
  ) {
    for (final String key in <String>[
      'unit',
      'priceUnit',
      'sellingUnit',
      'stockUnit',
    ]) {
      final String value =
          product[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'kg';
  }

  String _numberText(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    String text = value.toStringAsFixed(2);

    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }

    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }

    return text;
  }

  double _quantityStep(
    String unit,
  ) {
    final String normalized =
        unit.trim().toLowerCase();

    if (<String>[
      'kg',
      'kilogram',
      'kilograms',
      'l',
      'ltr',
      'litre',
      'liter',
      'litres',
      'liters',
    ].contains(normalized)) {
      return 0.5;
    }

    return 1;
  }

  bool _wholeNumberUnit(
    String unit,
  ) {
    final String normalized =
        unit.trim().toLowerCase();

    return <String>[
      'pc',
      'pcs',
      'piece',
      'pieces',
      'dozen',
      'packet',
      'packets',
      'pack',
      'bag',
      'bags',
      'sack',
      'sacks',
      'box',
      'boxes',
      'crate',
      'crates',
      'tray',
      'trays',
      'bottle',
      'bottles',
      'bundle',
      'bundles',
    ].contains(normalized);
  }

  String _priceText(
    Map<String, dynamic> product,
  ) {
    final dynamic raw =
        product['price'] ?? product['retailPrice'];

    final double price = _number(raw);

    return 'Rs. ${_numberText(price)}';
  }

  double _priceNumber(
    Map<String, dynamic> product,
  ) {
    return _number(
      product['price'] ?? product['retailPrice'],
    );
  }

  int _columns(
    double width,
  ) {
    if (width >= 1200) {
      return 5;
    }

    if (width >= 950) {
      return 4;
    }

    if (width >= 650) {
      return 3;
    }

    return 2;
  }

  Widget _imageWidget(
    String? image,
  ) {
    final Widget fallback = Container(
      color: Colors.green.shade50,
      alignment: Alignment.center,
      child: const Icon(
        Icons.agriculture_rounded,
        size: 54,
        color: Colors.green,
      ),
    );

    if (image == null || image.trim().isEmpty) {
      return fallback;
    }

    final String value = image.trim();

    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    return fallback;
  }

  double? _coordinate(
    Map<String, dynamic> seller,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic value = seller[key];

      if (value is num) {
        return value.toDouble();
      }

      final double? parsed =
          double.tryParse(value?.toString() ?? '');

      if (parsed != null) {
        return parsed;
      }
    }

    final dynamic location = seller['shopLocation'];

    if (location is GeoPoint) {
      if (keys.any(
        (String key) =>
            key.toLowerCase().contains('lat'),
      )) {
        return location.latitude;
      }

      return location.longitude;
    }

    return null;
  }

  Future<Map<String, dynamic>> _sellerInfo(
    String sellerId,
  ) async {
    if (sellerId.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          snapshot = await FirebaseFirestore.instance
              .collection('sellers')
              .doc(sellerId)
              .get();

      return snapshot.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _addToCart({
    required String productId,
    required Map<String, dynamic> product,
    required List<String> images,
    required double selectedQuantity,
  }) async {
    final double? stock = _stock(product);
    final String unit = _unit(product);

    await loadCart(
      marketplace: 'krishi',
    );

    double alreadyInCart = 0;

    for (final Map<String, dynamic> item
        in cartItems) {
      if (item['productId']?.toString() ==
          productId) {
        alreadyInCart =
            double.tryParse(
                  item['quantity']?.toString() ?? '0',
                ) ??
                0;
        break;
      }
    }

    if (stock != null &&
        stock > 0 &&
        alreadyInCart + selectedQuantity >
            stock + 0.000001) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${_numberText(stock)} $unit is available. '
            'You already have ${_numberText(alreadyInCart)} $unit in cart.',
          ),
        ),
      );

      return;
    }

    final String sellerId =
        product['sellerId']?.toString().trim() ?? '';

    final Map<String, dynamic> seller =
        await _sellerInfo(sellerId);

    final String sellerShopName =
        product['sellerShopName']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? product['sellerShopName'].toString().trim()
            : (seller['shopName']?.toString().trim() ?? '');

    final double? sellerLatitude =
        _coordinate(
              seller,
              <String>[
                'shopLat',
                'shopLatitude',
              ],
            ) ??
            _numberOrNull(
              product['sellerLatitude'] ??
                  product['sellerLat'],
            );

    final double? sellerLongitude =
        _coordinate(
              seller,
              <String>[
                'shopLng',
                'shopLongitude',
              ],
            ) ??
            _numberOrNull(
              product['sellerLongitude'] ??
                  product['sellerLng'],
            );

    final double price = _priceNumber(product);

    final Map<String, dynamic> cartProduct =
        <String, dynamic>{
      'productId': productId,
      'sellerId': sellerId,
      'sellerShopName': sellerShopName,
      'sellerLatitude': sellerLatitude,
      'sellerLongitude': sellerLongitude,
      'productName':
          product['name'] ?? 'Krishi Product',
      'name':
          product['name'] ?? 'Krishi Product',
      'price': 'Rs. ${_numberText(price)}',
      'pricePerUnit': price,
      'unit': unit,
      'stock': stock,
      'marketplace': 'krishi',
      'productType': 'krishi',
      'sellerType': 'krishi',
      'brand': product['brand'],
      'variety': product['variety'],
      'origin': product['origin'],
      'category': product['category'],
      'organic':
          product['organic'] ?? product['isOrganic'],
      'image': images.isEmpty ? null : images.first,
      'icon': Icons.agriculture_rounded,
    };

    await addProductToCart(
      cartProduct,
      selectedQuantity: selectedQuantity,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_numberText(selectedQuantity)} $unit '
          '${cartProduct['name']} added to cart.',
        ),
        action: SnackBarAction(
          label: 'VIEW CART',
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CartPage(
                  marketplace: 'krishi',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double? _numberOrNull(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  Future<void> _openQuantitySelector(
    String productId,
    Map<String, dynamic> product,
    List<String> images,
  ) async {
    final String unit = _unit(product);
    final double? stock = _stock(product);
    final double step = _quantityStep(unit);
    final bool wholeNumber =
        _wholeNumberUnit(unit);

    double quantity = step;

    if (stock != null &&
        stock > 0 &&
        stock < quantity) {
      quantity = stock;
    }

    final TextEditingController controller =
        TextEditingController(
      text: _numberText(quantity),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (
        BuildContext sheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            final double price =
                _priceNumber(product);

            final double total =
                price * quantity;

            void updateQuantity(
              double value,
            ) {
              if (wholeNumber) {
                value = value.roundToDouble();
              }

              if (value < step) {
                value = step;
              }

              if (stock != null &&
                  stock > 0 &&
                  value > stock) {
                value = stock;
              }

              quantity = value;
              controller.text =
                  _numberText(quantity);
              controller.selection =
                  TextSelection.collapsed(
                offset: controller.text.length,
              );

              setSheetState(() {});
            }

            final bool outOfStock =
                product['inStock'] == false ||
                    (stock != null &&
                        stock <= 0);

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                bottom:
                    MediaQuery.viewInsetsOf(context)
                            .bottom +
                        18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product['name']
                              ?.toString() ??
                          'Krishi Product',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_priceText(product)} / $unit',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stock == null
                          ? 'Available stock: Contact seller'
                          : 'Available: ${_numberText(stock)} $unit',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'How much do you need?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        IconButton.filledTonal(
                          onPressed: outOfStock
                              ? null
                              : () {
                                  updateQuantity(
                                    quantity -
                                        step,
                                  );
                                },
                          icon: const Icon(
                            Icons.remove,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller:
                                controller,
                            enabled: !outOfStock,
                            textAlign:
                                TextAlign.center,
                            keyboardType:
                                TextInputType
                                    .numberWithOptions(
                              decimal:
                                  !wholeNumber,
                            ),
                            decoration:
                                InputDecoration(
                              labelText:
                                  'Quantity ($unit)',
                              border:
                                  const OutlineInputBorder(),
                            ),
                            onChanged: (
                              String value,
                            ) {
                              final double?
                                  parsed =
                                  double.tryParse(
                                value.trim(),
                              );

                              if (parsed == null ||
                                  parsed <= 0) {
                                return;
                              }

                              double newValue =
                                  parsed;

                              if (wholeNumber) {
                                newValue =
                                    parsed
                                        .roundToDouble();
                              }

                              if (stock != null &&
                                  stock > 0 &&
                                  newValue >
                                      stock) {
                                newValue =
                                    stock;
                              }

                              quantity =
                                  newValue;

                              setSheetState(
                                () {},
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: outOfStock
                              ? null
                              : () {
                                  updateQuantity(
                                    quantity +
                                        step,
                                  );
                                },
                          icon:
                              const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            Colors.green.shade50,
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Selected: ${_numberText(quantity)} $unit',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            'Product total: Rs. ${_numberText(total)}',
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w900,
                              color:
                                  Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed: outOfStock
                            ? null
                            : () async {
                                final double?
                                    typed =
                                    double.tryParse(
                                  controller.text
                                      .trim(),
                                );

                                if (typed == null ||
                                    typed <= 0) {
                                  ScaffoldMessenger
                                          .of(
                                    sheetContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter a valid quantity.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                double finalQty =
                                    typed;

                                if (wholeNumber) {
                                  finalQty = typed
                                      .roundToDouble();
                                }

                                if (stock != null &&
                                    stock > 0 &&
                                    finalQty >
                                        stock) {
                                  ScaffoldMessenger
                                          .of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Only ${_numberText(stock)} $unit is available.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(
                                  sheetContext,
                                );

                                await _addToCart(
                                  productId:
                                      productId,
                                  product:
                                      product,
                                  images: images,
                                  selectedQuantity:
                                      finalQty,
                                );
                              },
                        icon: const Icon(
                          Icons
                              .add_shopping_cart_rounded,
                        ),
                        label: Text(
                          outOfStock
                              ? 'Out of Stock'
                              : 'Add ${_numberText(quantity)} $unit to Cart',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Widget _productCard(
    String productId,
    Map<String, dynamic> product,
  ) {
    final List<String> images =
        _images(product);

    // Product cards keep the Seller's real uploaded photo.
    // The category photo is used only when a product has no photo.
    if (images.isEmpty) {
      images.add(
        _defaultProductImage(product),
      );
    }

    final String unit = _unit(product);
    final double? stock = _stock(product);
    final bool outOfStock =
        product['inStock'] == false ||
            (stock != null && stock <= 0);

    final String brand =
        product['brand']?.toString().trim() ?? '';
    final String variety =
        product['variety']?.toString().trim() ?? '';
    final String origin =
        product['origin']?.toString().trim() ?? '';

    final bool organic =
        product['organic'] == true ||
            product['isOrganic'] == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: outOfStock
            ? null
            : () {
                _openQuantitySelector(
                  productId,
                  product,
                  images,
                );
              },
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _imageWidget(
                    images.first,
                  ),
                  if (organic)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.green.shade700,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: const Text(
                          'ORGANIC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (outOfStock)
                    Container(
                      color: Colors.black45,
                      alignment:
                          Alignment.center,
                      child: const Text(
                        'OUT OF STOCK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                10,
                10,
                4,
              ),
              child: Text(
                product['name']
                        ?.toString() ??
                    'Krishi Product',
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            if (brand.isNotEmpty ||
                variety.isNotEmpty ||
                origin.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                child: Text(
                  <String>[
                    if (brand.isNotEmpty)
                      brand,
                    if (variety.isNotEmpty)
                      variety,
                    if (origin.isNotEmpty)
                      origin,
                  ].join(' • '),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                6,
                10,
                2,
              ),
              child: Text(
                '${_priceText(product)} / $unit',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              child: Text(
                stock == null
                    ? 'Stock available'
                    : 'Available: ${_numberText(stock)} $unit',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: outOfStock
                      ? Colors.red
                      : Colors.black54,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.all(10),
              child: SizedBox(
                width: double.infinity,
                child:
                    FilledButton.tonalIcon(
                  onPressed: outOfStock
                      ? null
                      : () {
                          _openQuantitySelector(
                            productId,
                            product,
                            images,
                          );
                        },
                  icon: const Icon(
                    Icons.scale_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Select Quantity',
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.agriculture_rounded,
              color: Colors.green,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'NRD Krishi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Cart',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CartPage(
                        marketplace: 'krishi',
                      ),
                ),
              );
            },
            icon: const Icon(
              Icons.shopping_cart_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Customer',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CustomerDashboardPage(
                        krishiOnly: true,
                      ),
                ),
              );
            },
            icon: const Icon(
              Icons.account_circle_rounded,
              size: 29,
            ),
          ),
          IconButton(
            tooltip: 'Krishi Seller',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const KrishiSellerAuthPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.storefront_rounded,
              size: 28,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              14,
              14,
              14,
              8,
            ),
            child: TextField(
              controller:
                  _searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration:
                  InputDecoration(
                hintText:
                    'Search Krishi products...',
                prefixIcon:
                    const Icon(Icons.search),
                border:
                    const OutlineInputBorder(),
                suffixIcon:
                    _searchController
                            .text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController
                                  .clear();
                              setState(() {});
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          ),
              ),
            ),
          ),
          SizedBox(
            height: 118,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              itemCount: _categories.length,
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final String category =
                    _categories[index];
                final bool selected =
                    _selectedCategory == category;
                final String imagePath =
                    _defaultProductImages[category] ??
                        _defaultProductImages['All']!;

                return InkWell(
                  borderRadius: BorderRadius.circular(44),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: Container(
                    width: 88,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 180,
                          ),
                          width: 68,
                          height: 68,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              width: selected ? 3 : 1,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const ColoredBox(
                                  color: Color(0xFFE8F5E9),
                                  child: Icon(
                                    Icons.agriculture_rounded,
                                    color: Colors.green,
                                    size: 30,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.05,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? Colors.green.shade800
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: FirebaseFirestore
                  .instance
                  .collection(
                    'products',
                  )
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>
                    snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      child: Text(
                        'Could not load Krishi products:\n${snapshot.error}',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final String search =
                    _searchController.text
                        .trim()
                        .toLowerCase();

                final List<
                        QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>>
                    docs =
                    snapshot.data!.docs.where(
                  (
                    QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        doc,
                  ) {
                    final Map<String, dynamic>
                        data = doc.data();

                    if (!_isKrishiProduct(
                      data,
                    )) {
                      return false;
                    }

                    if (data['productStatus']
                            ?.toString()
                            .trim()
                            .toLowerCase() ==
                        'inactive') {
                      return false;
                    }

                    if (data['approvalStatus']
                            ?.toString()
                            .trim()
                            .toLowerCase() ==
                        'rejected') {
                      return false;
                    }

                    final String category =
                        data['category']
                                ?.toString()
                                .trim() ??
                            '';

                    if (_selectedCategory !=
                            'All' &&
                        category !=
                            _selectedCategory) {
                      return false;
                    }

                    if (search.isEmpty) {
                      return true;
                    }

                    final String searchable =
                        <dynamic>[
                      data['name'],
                      data['brand'],
                      data['variety'],
                      data['origin'],
                      data['category'],
                      data['description'],
                      data['unit'],
                    ].join(' ').toLowerCase();

                    return searchable
                        .contains(search);
                  },
                ).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        28,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons
                                .agriculture_rounded,
                            size: 78,
                            color:
                                Colors.green,
                          ),
                          SizedBox(
                            height: 14,
                          ),
                          Text(
                            'No Krishi products found.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          Text(
                            'Products added by Krishi Sellers will appear here.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints
                        constraints,
                  ) {
                    final int columns =
                        _columns(
                      constraints.maxWidth,
                    );

                    return GridView.builder(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        14,
                        8,
                        14,
                        18,
                      ),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            columns,
                        crossAxisSpacing:
                            12,
                        mainAxisSpacing:
                            12,
                        childAspectRatio:
                            constraints
                                        .maxWidth >=
                                    900
                                ? 0.76
                                : 0.62,
                      ),
                      itemCount:
                          docs.length,
                      itemBuilder: (
                        BuildContext context,
                        int index,
                      ) {
                        final QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>
                            doc =
                            docs[index];

                        return _productCard(
                          doc.id,
                          doc.data(),
                        );
                      },
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
