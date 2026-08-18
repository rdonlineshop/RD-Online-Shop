import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'data/product_data.dart';

enum SellerProductSort {
  newest,
  name,
  priceLow,
  priceHigh,
}

class SellerProductPage extends StatefulWidget {
  const SellerProductPage({super.key});

  @override
  State<SellerProductPage> createState() =>
      _SellerProductPageState();
}

class _SellerProductPageState extends State<SellerProductPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _selectedCategory = 'All';
  String _stockFilter = 'All';

  SellerProductSort _sort = SellerProductSort.newest;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _priceValue(
    Map<String, dynamic> product,
  ) {
    final dynamic value = product['priceValue'];

    if (value is num) {
      return value.toDouble();
    }

    final String text = product['price']
            ?.toString()
            .replaceAll(',', '')
            .replaceAll(
              RegExp(r'[^0-9.]'),
              '',
            ) ??
        '';

    return double.tryParse(text) ?? 0;
  }

  int _timeValue(
    Map<String, dynamic> product,
  ) {
    final dynamic value = product['updatedAt'];

    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  List<Map<String, dynamic>> _filteredProducts(
    List<Map<String, dynamic>> input,
  ) {
    final String query =
        _searchController.text.trim().toLowerCase();

    final List<Map<String, dynamic>> result =
        input.where(
      (Map<String, dynamic> product) {
        final String category =
            product['category']?.toString() ?? '';

        final bool inStock =
            product['inStock'] == true;

        if (_selectedCategory != 'All' &&
            category != _selectedCategory) {
          return false;
        }

        if (_stockFilter == 'In Stock' &&
            !inStock) {
          return false;
        }

        if (_stockFilter == 'Out of Stock' &&
            inStock) {
          return false;
        }

        if (query.isNotEmpty) {
          final String searchText = <String>[
            product['name']?.toString() ?? '',
            product['brand']?.toString() ?? '',
            product['sku']?.toString() ?? '',
            category,
          ].join(' ').toLowerCase();

          if (!searchText.contains(query)) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    switch (_sort) {
      case SellerProductSort.newest:
        result.sort(
          (
            Map<String, dynamic> a,
            Map<String, dynamic> b,
          ) {
            return _timeValue(b).compareTo(
              _timeValue(a),
            );
          },
        );
        break;

      case SellerProductSort.name:
        result.sort(
          (
            Map<String, dynamic> a,
            Map<String, dynamic> b,
          ) {
            return (a['name']?.toString() ?? '')
                .toLowerCase()
                .compareTo(
                  (b['name']?.toString() ?? '')
                      .toLowerCase(),
                );
          },
        );
        break;

      case SellerProductSort.priceLow:
        result.sort(
          (
            Map<String, dynamic> a,
            Map<String, dynamic> b,
          ) {
            return _priceValue(a).compareTo(
              _priceValue(b),
            );
          },
        );
        break;

      case SellerProductSort.priceHigh:
        result.sort(
          (
            Map<String, dynamic> a,
            Map<String, dynamic> b,
          ) {
            return _priceValue(b).compareTo(
              _priceValue(a),
            );
          },
        );
        break;
    }

    return result;
  }

  String _primaryImage(
    Map<String, dynamic> product,
  ) {
    final dynamic paths = product['imagePaths'];

    if (paths is List) {
      for (final dynamic path in paths) {
        if (path is String &&
            path.trim().isNotEmpty) {
          return path.trim();
        }
      }
    }

    return product['imagePath']
            ?.toString()
            .trim() ??
        '';
  }

  Widget _productImage(
    Map<String, dynamic> product,
  ) {
    final String path = _primaryImage(product);

    final IconData icon = iconForCategory(
      product['category']?.toString() ?? '',
    );

    final Widget fallback = Center(
      child: Icon(
        icon,
        color: Colors.blue,
        size: 34,
      ),
    );

    if (path.isEmpty) {
      return fallback;
    }

    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      return Image.network(
        path,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    return Image.file(
      File(path),
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return fallback;
      },
    );
  }

  Future<void> _openForm({
    Map<String, dynamic>? product,
    required Map<String, dynamic> seller,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SellerProductFormPage(
          product: product,
          sellerShopName:
              seller['shopName']?.toString() ?? '',
          sellerEmail:
              seller['email']?.toString() ??
                  _user?.email ??
                  '',
        ),
      ),
    );
  }

  Future<void> _deleteProduct(
    Map<String, dynamic> product,
  ) async {
    final User? user = _user;

    if (user == null) {
      return;
    }

    final bool? confirm =
        await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Product?',
          ),
          content: Text(
            '${product['name']} will be permanently removed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await deleteSellerProduct(
        product['id'].toString(),
        sellerId: user.uid,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Products'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Seller login required.',
          ),
        ),
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<Map<String, dynamic>>>
            sellerSnapshot,
      ) {
        if (sellerSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Products'),
              centerTitle: true,
            ),
            body: Center(
              child: Text(
                'Could not load seller:\n'
                '${sellerSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!sellerSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Products'),
              centerTitle: true,
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!sellerSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Products'),
              centerTitle: true,
            ),
            body: const Center(
              child: Text(
                'Seller account was not found.',
              ),
            ),
          );
        }

        final Map<String, dynamic> seller =
            sellerSnapshot.data!.data() ??
                <String, dynamic>{};

        if (seller['isActive'] == false) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Products'),
              centerTitle: true,
            ),
            body: const Center(
              child: Text(
                'Seller account is inactive.',
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'My Products',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: () {
              _openForm(
                seller: seller,
              );
            },
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Product',
            ),
          ),
          body: StreamBuilder<
              List<Map<String, dynamic>>>(
            stream: sellerProductsStream(
              user.uid,
            ),
            builder: (
              BuildContext context,
              AsyncSnapshot<
                      List<Map<String, dynamic>>>
                  snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(24),
                    child: Text(
                      'Could not load products:\n'
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
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

              final List<Map<String, dynamic>>
                  sellerProducts =
                  _filteredProducts(
                snapshot.data!,
              );

              return Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 1000,
                  ),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          5,
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
                                'Search product, brand or SKU',
                            prefixIcon:
                                const Icon(
                              Icons.search,
                            ),
                            suffixIcon:
                                _searchController
                                        .text
                                        .isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController
                                              .clear();

                                          setState(
                                            () {},
                                          );
                                        },
                                        icon:
                                            const Icon(
                                          Icons.close,
                                        ),
                                      ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            SizedBox(
                              width: 190,
                              child:
                                  DropdownButtonFormField<
                                      String>(
                                initialValue:
                                    _selectedCategory,
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Category',
                                  border:
                                      OutlineInputBorder(),
                                ),
                                items: <String>[
                                  'All',
                                  ...productCategories,
                                ].map(
                                  (
                                    String category,
                                  ) {
                                    return DropdownMenuItem<
                                        String>(
                                      value:
                                          category,
                                      child: Text(
                                        category,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                      ),
                                    );
                                  },
                                ).toList(),
                                onChanged:
                                    (String? value) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedCategory =
                                        value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child:
                                  DropdownButtonFormField<
                                      String>(
                                initialValue:
                                    _stockFilter,
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Stock',
                                  border:
                                      OutlineInputBorder(),
                                ),
                                items:
                                    const <String>[
                                  'All',
                                  'In Stock',
                                  'Out of Stock',
                                ].map(
                                  (
                                    String item,
                                  ) {
                                    return DropdownMenuItem<
                                        String>(
                                      value: item,
                                      child:
                                          Text(item),
                                    );
                                  },
                                ).toList(),
                                onChanged:
                                    (String? value) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setState(() {
                                    _stockFilter =
                                        value;
                                  });
                                },
                              ),
                            ),
                            PopupMenuButton<
                                SellerProductSort>(
                              tooltip:
                                  'Sort Products',
                              onSelected:
                                  (
                                SellerProductSort
                                    value,
                              ) {
                                setState(() {
                                  _sort = value;
                                });
                              },
                              itemBuilder:
                                  (
                                BuildContext context,
                              ) {
                                return const <
                                    PopupMenuEntry<
                                        SellerProductSort>>[
                                  PopupMenuItem<
                                      SellerProductSort>(
                                    value:
                                        SellerProductSort
                                            .newest,
                                    child: Text(
                                      'Newest',
                                    ),
                                  ),
                                  PopupMenuItem<
                                      SellerProductSort>(
                                    value:
                                        SellerProductSort
                                            .name,
                                    child: Text(
                                      'Name',
                                    ),
                                  ),
                                  PopupMenuItem<
                                      SellerProductSort>(
                                    value:
                                        SellerProductSort
                                            .priceLow,
                                    child: Text(
                                      'Price Low to High',
                                    ),
                                  ),
                                  PopupMenuItem<
                                      SellerProductSort>(
                                    value:
                                        SellerProductSort
                                            .priceHigh,
                                    child: Text(
                                      'Price High to Low',
                                    ),
                                  ),
                                ];
                              },
                              child: const Chip(
                                avatar: Icon(
                                  Icons.sort,
                                ),
                                label:
                                    Text('Sort'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child:
                            sellerProducts.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No seller products found.',
                                    ),
                                  )
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets
                                            .fromLTRB(
                                      12,
                                      0,
                                      12,
                                      90,
                                    ),
                                    itemCount:
                                        sellerProducts
                                            .length,
                                    itemBuilder:
                                        (
                                      BuildContext
                                          context,
                                      int index,
                                    ) {
                                      final Map<
                                              String,
                                              dynamic>
                                          product =
                                          sellerProducts[
                                              index];

                                      final int
                                          stock =
                                          (product['stockQuantity']
                                                      as num?)
                                                  ?.toInt() ??
                                              0;

                                      final String
                                          approval =
                                          product['approvalStatus']
                                                  ?.toString() ??
                                              'approved';

                                      final bool
                                          active =
                                          product['productStatus'] !=
                                              'inactive';

                                      return Card(
                                        margin:
                                            const EdgeInsets
                                                .only(
                                          bottom:
                                              10,
                                        ),
                                        child:
                                            ListTile(
                                          contentPadding:
                                              const EdgeInsets
                                                  .all(
                                            10,
                                          ),
                                          leading:
                                              ClipRRect(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              10,
                                            ),
                                            child:
                                                Container(
                                              width:
                                                  60,
                                              height:
                                                  60,
                                              color:
                                                  Colors
                                                      .blue
                                                      .shade50,
                                              child:
                                                  _productImage(
                                                product,
                                              ),
                                            ),
                                          ),
                                          title:
                                              Text(
                                            product['name']
                                                    ?.toString() ??
                                                '',
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                            ),
                                          ),
                                          subtitle:
                                              Text(
                                            '${product['price']}'
                                            '\nStock: $stock • ${product['category']}'
                                            '\n${active ? 'Active' : 'Inactive'} • $approval',
                                          ),
                                          isThreeLine:
                                              true,
                                          trailing:
                                              Wrap(
                                            children: <Widget>[
                                              IconButton(
                                                tooltip:
                                                    'Edit Product',
                                                onPressed:
                                                    () {
                                                  _openForm(
                                                    product:
                                                        product,
                                                    seller:
                                                        seller,
                                                  );
                                                },
                                                icon:
                                                    const Icon(
                                                  Icons
                                                      .edit,
                                                  color:
                                                      Colors
                                                          .blue,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    'Delete Product',
                                                onPressed:
                                                    () {
                                                  _deleteProduct(
                                                    product,
                                                  );
                                                },
                                                icon:
                                                    const Icon(
                                                  Icons
                                                      .delete_outline,
                                                  color:
                                                      Colors
                                                          .red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class SellerProductFormPage extends StatefulWidget {
  final Map<String, dynamic>? product;
  final String sellerShopName;
  final String sellerEmail;

  const SellerProductFormPage({
    super.key,
    this.product,
    required this.sellerShopName,
    required this.sellerEmail,
  });

  @override
  State<SellerProductFormPage> createState() =>
      _SellerProductFormPageState();
}

class _SellerProductFormPageState
    extends State<SellerProductFormPage> {
  static const String _cloudName =
      'p83ttfym';

  static const String _uploadPreset =
      'rd_online_shop_products';

  static const List<String> _colors =
      <String>[
    'Black',
    'White',
    'Grey',
    'Silver',
    'Red',
    'Maroon',
    'Pink',
    'Purple',
    'Blue',
    'Navy',
    'Sky Blue',
    'Green',
    'Yellow',
    'Gold',
    'Orange',
    'Brown',
    'Beige',
    'Cream',
  ];

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _originalPrice;
  late final TextEditingController _stock;
  late final TextEditingController _sku;
  late final TextEditingController _sizes;

  late String _category;
  late bool _active;

  late List<String> _imagePaths;
  late Set<String> _selectedColors;

  bool _saving = false;
  bool _uploading = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? product =
        widget.product;

    _name = TextEditingController(
      text:
          product?['name']?.toString() ?? '',
    );

    _brand = TextEditingController(
      text:
          product?['brand']?.toString() ?? '',
    );

    _description = TextEditingController(
      text:
          product?['description']?.toString() ??
              '',
    );

    _price = TextEditingController(
      text: product?['price']
              ?.toString()
              .replaceAll('Rs. ', '')
              .replaceAll(',', '') ??
          '',
    );

    _originalPrice = TextEditingController(
      text: product?['originalPrice']
              ?.toString()
              .replaceAll('Rs. ', '')
              .replaceAll(',', '') ??
          '',
    );

    _stock = TextEditingController(
      text:
          (product?['stockQuantity'] as num?)
                  ?.toInt()
                  .toString() ??
              '1',
    );

    _sku = TextEditingController(
      text:
          product?['sku']?.toString() ?? '',
    );

    _sizes = TextEditingController(
      text:
          (product?['sizeOptions'] as List?)
                  ?.whereType<String>()
                  .join(', ') ??
              '',
    );

    _category =
        product?['category']?.toString() ??
            'Phones';

    _active =
        product?['productStatus'] !=
            'inactive';

    _imagePaths =
        (product?['imagePaths'] as List?)
                ?.whereType<String>()
                .toList() ??
            <String>[];

    if (_imagePaths.isEmpty &&
        product?['imagePath'] is String &&
        (product!['imagePath'] as String)
            .trim()
            .isNotEmpty) {
      _imagePaths.add(
        product['imagePath'] as String,
      );
    }

    _selectedColors =
        (product?['colorOptions'] as List?)
                ?.whereType<String>()
                .toSet() ??
            <String>{};
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _description.dispose();
    _price.dispose();
    _originalPrice.dispose();
    _stock.dispose();
    _sku.dispose();
    _sizes.dispose();

    super.dispose();
  }

  double _number(
    String text,
  ) {
    return double.tryParse(
          text
              .replaceAll(',', '')
              .trim(),
        ) ??
        0;
  }

  int get _discount {
    final double price =
        _number(_price.text);

    final double original =
        _number(_originalPrice.text);

    if (price <= 0 ||
        original <= price) {
      return 0;
    }

    return (((original - price) /
                original) *
            100)
        .round();
  }

  List<String> _sizeOptions() {
    return _sizes.text
        .split(',')
        .map(
          (String value) =>
              value.trim(),
        )
        .where(
          (String value) =>
              value.isNotEmpty,
        )
        .toList();
  }

  Future<String> _uploadPhoto(
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
      await http.MultipartFile.fromPath(
        'file',
        image.path,
      ),
    );

    final http.StreamedResponse response =
        await request.send();

    final String body =
        await response.stream.bytesToString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Photo upload failed: $body',
      );
    }

    final dynamic decoded = jsonDecode(body);

    if (decoded
        is! Map<String, dynamic>) {
      throw Exception(
        'Invalid Cloudinary response.',
      );
    }

    final String url =
        decoded['secure_url']
                ?.toString()
                .trim() ??
            '';

    if (url.isEmpty) {
      throw Exception(
        'Cloudinary image URL was not received.',
      );
    }

    return url;
  }

  Future<void> _choosePhotos() async {
    if (_uploading) {
      return;
    }

    if (_imagePaths.length >= 8) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum 8 product photos are allowed.',
          ),
        ),
      );
      return;
    }

    final List<XFile> selected =
        await ImagePicker()
            .pickMultiImage(
      imageQuality: 85,
    );

    if (selected.isEmpty) {
      return;
    }

    final int remaining =
        8 - _imagePaths.length;

    final List<XFile> selectedPhotos =
        selected.take(remaining).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final List<String> urls =
          <String>[];

      for (final XFile image
          in selectedPhotos) {
        urls.add(
          await _uploadPhoto(image),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _imagePaths.addAll(urls);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${urls.length} photo(s) uploaded successfully.',
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
            error
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Widget _preview(
    String path,
  ) {
    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      return Image.network(
        path,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 90,
            height: 90,
            alignment: Alignment.center,
            color: Colors.grey.shade200,
            child: const Icon(
              Icons.broken_image_outlined,
            ),
          );
        },
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
      );
    }

    return Image.file(
      File(path),
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Container(
          width: 90,
          height: 90,
          alignment: Alignment.center,
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.broken_image_outlined,
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState
            ?.validate() !=
        true) {
      return;
    }

    if (_saving || _uploading) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final DocumentSnapshot<
              Map<String, dynamic>>
          seller =
          await FirebaseFirestore.instance
              .collection('sellers')
              .doc(user.uid)
              .get();

      if (!seller.exists) {
        throw Exception(
          'Seller account was not found.',
        );
      }

      if (seller.data()?['isActive'] ==
          false) {
        throw Exception(
          'Seller account is inactive.',
        );
      }

      final int stock =
          int.tryParse(
                _stock.text.trim(),
              ) ??
              0;

      final String sellingPrice =
          _price.text.trim();

      final String originalPrice =
          _originalPrice.text.trim();

      final Map<String, dynamic> data =
          <String, dynamic>{
        'name': _name.text.trim(),
        'brand': _brand.text.trim(),
        'description':
            _description.text.trim(),
        'sku': _sku.text.trim(),
        'price':
            'Rs. $sellingPrice',
        'priceValue':
            _number(sellingPrice),
        'originalPrice':
            originalPrice.isEmpty
                ? null
                : 'Rs. $originalPrice',
        'originalPriceValue':
            originalPrice.isEmpty
                ? 0
                : _number(
                    originalPrice,
                  ),
        'discount': _discount,
        'category': _category,
        'stockQuantity':
            stock < 0 ? 0 : stock,
        'inStock':
            _active && stock > 0,
        'productStatus':
            _active
                ? 'active'
                : 'inactive',
        'imagePaths': _imagePaths,
        'imagePath':
            _imagePaths.isEmpty
                ? null
                : _imagePaths.first,
        'colorOptions':
            _selectedColors.toList(),
        'sizeOptions':
            _sizeOptions(),
        'approvalStatus':
            widget.product?[
                    'approvalStatus'] ??
                'approved',
        'rating':
            widget.product?['rating'] ??
                0.0,
        'reviewCount':
            widget.product?[
                    'reviewCount'] ??
                0,
        'soldCount':
            widget.product?[
                    'soldCount'] ??
                0,
      };

      final String shopName =
          seller.data()?['shopName']
                  ?.toString() ??
              widget.sellerShopName;

      final String sellerEmail =
          seller.data()?['email']
                  ?.toString() ??
              widget.sellerEmail;

      if (_editing) {
        await updateSellerProduct(
          widget.product!['id']
              .toString(),
          data,
          sellerId: user.uid,
          sellerShopName: shopName,
          sellerEmail: sellerEmail,
        );
      } else {
        await addSellerProduct(
          data,
          sellerId: user.uid,
          sellerShopName: shopName,
          sellerEmail: sellerEmail,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );

      setState(() {
        _saving = false;
      });
    }
  }

  Color _colorValue(
    String name,
  ) {
    switch (name) {
      case 'Black':
        return Colors.black;

      case 'White':
        return Colors.white;

      case 'Grey':
        return Colors.grey;

      case 'Silver':
        return Colors.blueGrey.shade300;

      case 'Red':
        return Colors.red;

      case 'Maroon':
        return const Color(
          0xFF800000,
        );

      case 'Pink':
        return Colors.pink;

      case 'Purple':
        return Colors.purple;

      case 'Blue':
        return Colors.blue;

      case 'Navy':
        return const Color(
          0xFF000080,
        );

      case 'Sky Blue':
        return Colors.lightBlue;

      case 'Green':
        return Colors.green;

      case 'Yellow':
        return Colors.yellow;

      case 'Gold':
        return const Color(
          0xFFFFD700,
        );

      case 'Orange':
        return Colors.orange;

      case 'Brown':
        return Colors.brown;

      case 'Beige':
        return const Color(
          0xFFF5F5DC,
        );

      case 'Cream':
        return const Color(
          0xFFFFFDD0,
        );

      default:
        return Colors.blue;
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? type,
    int lines = 1,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border:
            const OutlineInputBorder(),
      ),
      validator: requiredField
          ? (String? value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return '$label is required.';
              }

              return null;
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit My Product'
              : 'Add My Product',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: <Widget>[
            _field(
              _name,
              'Product Name',
              requiredField: true,
            ),
            const SizedBox(height: 12),
            _field(
              _brand,
              'Brand (optional)',
            ),
            const SizedBox(height: 12),
            _field(
              _description,
              'Product Description',
              lines: 4,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _field(
                    _price,
                    'Selling Price',
                    type:
                        TextInputType.number,
                    requiredField: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _originalPrice,
                    'Original Price',
                    type:
                        TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Automatic Discount: $_discount%',
              style: const TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration:
                  const InputDecoration(
                labelText: 'Category',
                border:
                    OutlineInputBorder(),
              ),
              items: productCategories.map(
                (String category) {
                  return DropdownMenuItem<
                      String>(
                    value: category,
                    child: Text(category),
                  );
                },
              ).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _field(
                    _stock,
                    'Stock Quantity',
                    type:
                        TextInputType.number,
                    requiredField: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _sku,
                    'SKU (optional)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Product Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_imagePaths.isNotEmpty)
              SizedBox(
                height: 90,
                child:
                    ListView.separated(
                  scrollDirection:
                      Axis.horizontal,
                  itemCount:
                      _imagePaths.length,
                  separatorBuilder:
                      (
                    BuildContext context,
                    int index,
                  ) {
                    return const SizedBox(
                      width: 8,
                    );
                  },
                  itemBuilder:
                      (
                    BuildContext context,
                    int index,
                  ) {
                    return Stack(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                          child: _preview(
                            _imagePaths[
                                index],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child:
                              CircleAvatar(
                            radius: 13,
                            child:
                                IconButton(
                              padding:
                                  EdgeInsets
                                      .zero,
                              onPressed: () {
                                setState(() {
                                  _imagePaths
                                      .removeAt(
                                    index,
                                  );
                                });
                              },
                              icon:
                                  const Icon(
                                Icons.close,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  _uploading
                      ? null
                      : _choosePhotos,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .photo_library_outlined,
                    ),
              label: Text(
                _uploading
                    ? 'Uploading...'
                    : 'Choose Product Photos',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Color Options',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map(
                (String color) {
                  final bool selected =
                      _selectedColors
                          .contains(
                    color,
                  );

                  return InkWell(
                    borderRadius:
                        BorderRadius
                            .circular(
                      24,
                    ),
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedColors
                              .remove(
                            color,
                          );
                        } else {
                          _selectedColors
                              .add(
                            color,
                          );
                        }
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            _colorValue(
                          color,
                        ),
                        border:
                            Border.all(
                          color: selected
                              ? Colors.blue
                              : Colors
                                  .grey,
                          width: selected
                              ? 4
                              : 1,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check,
                              size: 17,
                              color: color ==
                                          'White' ||
                                      color ==
                                          'Yellow'
                                  ? Colors
                                      .black
                                  : Colors
                                      .white,
                            )
                          : null,
                    ),
                  );
                },
              ).toList(),
            ),
            const SizedBox(height: 16),
            _field(
              _sizes,
              'Sizes (example: S, M, L, XL)',
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,
              title: const Text(
                'Product Active',
              ),
              subtitle: const Text(
                'Turn off to temporarily hide this product.',
              ),
              value: _active,
              onChanged: (bool value) {
                setState(() {
                  _active = value;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _saving ||
                            _uploading
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
                      : _editing
                          ? 'Save Changes'
                          : 'Add Product',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}