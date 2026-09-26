import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class KrishiProductPage extends StatefulWidget {
  const KrishiProductPage({super.key});

  @override
  State<KrishiProductPage> createState() =>
      _KrishiProductPageState();
}

class _KrishiProductPageState extends State<KrishiProductPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String get _sellerId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

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

  String _firstImage(
    Map<String, dynamic> data,
  ) {
    final dynamic rawPaths = data['imagePaths'];

    if (rawPaths is List) {
      for (final dynamic item in rawPaths) {
        final String value = item?.toString().trim() ?? '';
        if (value.startsWith('http://') ||
            value.startsWith('https://')) {
          return value;
        }
      }
    }

    final String imagePath =
        data['imagePath']?.toString().trim() ?? '';

    if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://')) {
      return imagePath;
    }

    return '';
  }

  Future<void> _openEditor({
    Map<String, dynamic>? product,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _KrishiProductEditorPage(
          product: product,
        ),
      ),
    );
  }

  Future<void> _deleteProduct(
    String productId,
    String productName,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Krishi Product?',
          ),
          content: Text(
            '$productName will be permanently removed.',
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
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .delete();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Krishi product deleted.',
        ),
      ),
    );
  }

  Future<void> _toggleStock(
    String productId,
    bool value,
    int stockQuantity,
  ) async {
    int quantity = stockQuantity;

    if (value && quantity <= 0) {
      quantity = 1;
    }

    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .set(
      <String, dynamic>{
        'inStock': value,
        'stockQuantity': value ? quantity : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Widget _productImage(
    Map<String, dynamic> data,
  ) {
    final String url = _firstImage(data);

    if (url.isEmpty) {
      return Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.agriculture_rounded,
          color: Colors.green,
          size: 42,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 82,
        height: 82,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 82,
            height: 82,
            color: Colors.green.withValues(alpha: 0.10),
            child: const Icon(
              Icons.agriculture_rounded,
              color: Colors.green,
              size: 42,
            ),
          );
        },
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
    final String sellerId = _sellerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Krishi Products',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sellerId.isEmpty
            ? null
            : () {
                _openEditor();
              },
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Product',
        ),
      ),
      body: sellerId.isEmpty
          ? const Center(
              child: Text(
                'Krishi seller login required.',
              ),
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Search my Krishi products...',
                      prefixIcon:
                          const Icon(Icons.search),
                      border:
                          const OutlineInputBorder(),
                      suffixIcon:
                          _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.clear,
                                  ),
                                ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<
                          Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .where(
                          'sellerId',
                          isEqualTo: sellerId,
                        )
                        .snapshots(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<
                              QuerySnapshot<
                                  Map<String, dynamic>>>
                          snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(20),
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
                                  Map<String, dynamic>>>
                          docs = snapshot.data!.docs
                              .where(
                        (
                          QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              doc,
                        ) {
                          final Map<String, dynamic>
                              data = doc.data();

                          if (!_isKrishiProduct(
                            data,
                          )) {
                            return false;
                          }

                          if (search.isEmpty) {
                            return true;
                          }

                          final String searchable =
                              <dynamic>[
                            data['name'],
                            data['brand'],
                            data['category'],
                            data['variety'],
                            data['origin'],
                            data['description'],
                          ].join(' ').toLowerCase();

                          return searchable.contains(
                            search,
                          );
                        },
                      ).toList();

                      docs.sort(
                        (
                          QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              a,
                          QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              b,
                        ) {
                          final dynamic aRaw =
                              a.data()['updatedAt'] ??
                                  a.data()['createdAt'];
                          final dynamic bRaw =
                              b.data()['updatedAt'] ??
                                  b.data()['createdAt'];

                          final DateTime aDate =
                              aRaw is Timestamp
                                  ? aRaw.toDate()
                                  : DateTime
                                      .fromMillisecondsSinceEpoch(
                                      0,
                                    );
                          final DateTime bDate =
                              bRaw is Timestamp
                                  ? bRaw.toDate()
                                  : DateTime
                                      .fromMillisecondsSinceEpoch(
                                      0,
                                    );

                          return bDate.compareTo(aDate);
                        },
                      );

                      if (docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding:
                                EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons
                                      .agriculture_rounded,
                                  size: 70,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'No Krishi products yet.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Tap Add Product to publish your first agriculture product.',
                                  textAlign:
                                      TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          100,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (
                          BuildContext context,
                          int index,
                        ) {
                          final QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              doc = docs[index];
                          final Map<String, dynamic>
                              data = <String, dynamic>{
                            ...doc.data(),
                            'id': doc.id,
                          };

                          final String name =
                              data['name']
                                      ?.toString()
                                      .trim() ??
                                  'Krishi Product';
                          final String category =
                              data['category']
                                      ?.toString()
                                      .trim() ??
                                  'Agriculture';
                          final String unit =
                              data['unit']
                                      ?.toString()
                                      .trim() ??
                                  '';
                          final String price =
                              data['price']
                                      ?.toString()
                                      .trim() ??
                                  'Rs. 0';
                          final int stock =
                              (data['stockQuantity']
                                          as num?)
                                      ?.toInt() ??
                                  0;
                          final bool inStock =
                              data['inStock'] != false &&
                                  stock > 0;

                          return Card(
                            margin:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(
                                12,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: <Widget>[
                                  _productImage(
                                    data,
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
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 3,
                                        ),
                                        Text(
                                          category,
                                          style:
                                              const TextStyle(
                                            color:
                                                Colors.green,
                                            fontWeight:
                                                FontWeight
                                                    .w700,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        Text(
                                          unit.isEmpty
                                              ? price
                                              : '$price / $unit',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                        Text(
                                          'Stock: $stock',
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: <Widget>[
                                            OutlinedButton
                                                .icon(
                                              onPressed:
                                                  () {
                                                _openEditor(
                                                  product:
                                                      data,
                                                );
                                              },
                                              icon:
                                                  const Icon(
                                                Icons
                                                    .edit_outlined,
                                              ),
                                              label:
                                                  const Text(
                                                'Edit',
                                              ),
                                            ),
                                            OutlinedButton
                                                .icon(
                                              onPressed:
                                                  () {
                                                _deleteProduct(
                                                  doc.id,
                                                  name,
                                                );
                                              },
                                              icon:
                                                  const Icon(
                                                Icons
                                                    .delete_outline,
                                              ),
                                              label:
                                                  const Text(
                                                'Delete',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: <Widget>[
                                      Switch(
                                        value: inStock,
                                        onChanged:
                                            (bool value) {
                                          _toggleStock(
                                            doc.id,
                                            value,
                                            stock,
                                          );
                                        },
                                      ),
                                      Text(
                                        inStock
                                            ? 'In Stock'
                                            : 'Out',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: inStock
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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

class _KrishiProductEditorPage extends StatefulWidget {
  final Map<String, dynamic>? product;

  const _KrishiProductEditorPage({
    this.product,
  });

  @override
  State<_KrishiProductEditorPage> createState() =>
      _KrishiProductEditorPageState();
}

class _KrishiProductEditorPageState
    extends State<_KrishiProductEditorPage> {
  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset =
      'rd_online_shop_products';

  static const List<String> _categories = <String>[
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

  static const List<String> _units = <String>[
    'kg',
    'gram',
    'quintal',
    'ton',
    'liter',
    'ml',
    'piece',
    'dozen',
    'bundle',
    'crate',
    'sack',
    'packet',
  ];

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _name =
      TextEditingController();
  final TextEditingController _brand =
      TextEditingController();
  final TextEditingController _variety =
      TextEditingController();
  final TextEditingController _origin =
      TextEditingController();
  final TextEditingController _price =
      TextEditingController();
  final TextEditingController _originalPrice =
      TextEditingController();
  final TextEditingController _stock =
      TextEditingController();
  final TextEditingController _harvestDate =
      TextEditingController();
  final TextEditingController _description =
      TextEditingController();

  String _category = _categories.first;
  String _unit = _units.first;
  bool _organic = false;
  bool _saving = false;
  bool _uploading = false;

  List<String> _imageUrls = <String>[];

  bool get _editing =>
      widget.product != null &&
      widget.product!['id']
              ?.toString()
              .trim()
              .isNotEmpty ==
          true;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? product =
        widget.product;

    if (product == null) {
      return;
    }

    _name.text =
        product['name']?.toString() ?? '';
    _brand.text =
        product['brand']?.toString() ?? '';
    _variety.text =
        product['variety']?.toString() ?? '';
    _origin.text =
        product['origin']?.toString() ?? '';
    _price.text =
        _numberText(
      product['priceValue'] ?? product['price'],
    );
    _originalPrice.text =
        _numberText(
      product['originalPriceValue'] ??
          product['originalPrice'],
    );
    _stock.text =
        ((product['stockQuantity'] as num?)
                    ?.toInt() ??
                0)
            .toString();
    _harvestDate.text =
        product['harvestDate']?.toString() ?? '';
    _description.text =
        product['description']?.toString() ?? '';

    final String category =
        product['category']?.toString() ?? '';
    if (_categories.contains(category)) {
      _category = category;
    }

    final String unit =
        product['unit']?.toString() ?? '';
    if (_units.contains(unit)) {
      _unit = unit;
    }

    _organic = product['isOrganic'] == true;

    final dynamic rawImages =
        product['imagePaths'];

    if (rawImages is List) {
      _imageUrls = rawImages
          .map(
            (dynamic value) =>
                value?.toString().trim() ?? '',
          )
          .where(
            (String value) =>
                value.startsWith('http://') ||
                value.startsWith('https://'),
          )
          .toList();
    }

    if (_imageUrls.isEmpty) {
      final String single =
          product['imagePath']
                  ?.toString()
                  .trim() ??
              '';
      if (single.startsWith('http://') ||
          single.startsWith('https://')) {
        _imageUrls = <String>[single];
      }
    }
  }

  String _numberText(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      if (value.toDouble() ==
          value.toDouble().roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }

    return value
        .toString()
        .replaceAll(',', '')
        .replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
  }

  String _formatMoney(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  int _discount(
    double sellingPrice,
    double originalPrice,
  ) {
    if (sellingPrice <= 0 ||
        originalPrice <= sellingPrice) {
      return 0;
    }

    return (((originalPrice - sellingPrice) /
                originalPrice) *
            100)
        .round();
  }

  Future<String> _uploadImage(
    XFile image,
  ) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
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

    final http.StreamedResponse streamed =
        await request.send();

    final String body =
        await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 ||
        streamed.statusCode >= 300) {
      throw Exception(
        'Image upload failed (${streamed.statusCode}).',
      );
    }

    final dynamic decoded =
        jsonDecode(body);

    if (decoded is! Map) {
      throw Exception(
        'Image upload response is invalid.',
      );
    }

    final String url =
        decoded['secure_url']?.toString() ?? '';

    if (url.isEmpty) {
      throw Exception(
        'Uploaded image URL is missing.',
      );
    }

    return url;
  }

  Future<void> _pickImages() async {
    if (_uploading) {
      return;
    }

    final List<XFile> images =
        await ImagePicker().pickMultiImage(
      imageQuality: 85,
    );

    if (images.isEmpty) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final List<String> uploaded =
          <String>[];

      for (final XFile image in images) {
        uploaded.add(
          await _uploadImage(image),
        );

        if (_imageUrls.length +
                uploaded.length >=
            5) {
          break;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _imageUrls = <String>[
          ..._imageUrls,
          ...uploaded,
        ].take(5).toList();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${uploaded.length} product photo(s) uploaded.',
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
            'Photo upload failed: $error',
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

  Future<void> _chooseHarvestDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(
                _harvestDate.text,
              ) ??
              now,
      firstDate:
          DateTime(now.year - 2),
      lastDate:
          DateTime(now.year + 2),
    );

    if (picked == null) {
      return;
    }

    _harvestDate.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
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

    if (user == null ||
        user.isAnonymous) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Krishi seller login required.',
          ),
        ),
      );
      return;
    }

    final double sellingPrice =
        double.tryParse(
              _price.text
                  .replaceAll(',', '')
                  .trim(),
            ) ??
            0;

    final double originalPrice =
        double.tryParse(
              _originalPrice.text
                  .replaceAll(',', '')
                  .trim(),
            ) ??
            0;

    final int stockQuantity =
        int.tryParse(
              _stock.text.trim(),
            ) ??
            0;

    if (sellingPrice <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid selling price.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final DocumentSnapshot<
              Map<String, dynamic>>
          sellerSnapshot =
          await FirebaseFirestore.instance
              .collection('sellers')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> seller =
          sellerSnapshot.data() ??
              <String, dynamic>{};

      if (seller['role']
                  ?.toString()
                  .trim() !=
              'seller' ||
          seller['sellerType']
                  ?.toString()
                  .trim() !=
              'krishi') {
        throw Exception(
          'This account is not a Krishi seller.',
        );
      }

      if (seller['isActive'] == false) {
        throw Exception(
          'Admin approval is required before adding products.',
        );
      }

      final Map<String, dynamic> data =
          <String, dynamic>{
        'name': _name.text.trim(),
        'brand': _brand.text.trim(),
        'variety': _variety.text.trim(),
        'origin': _origin.text.trim(),
        'description':
            _description.text.trim(),
        'price':
            'Rs. ${_formatMoney(sellingPrice)}',
        'priceValue': sellingPrice,
        'originalPrice':
            originalPrice > 0
                ? 'Rs. ${_formatMoney(originalPrice)}'
                : '',
        'originalPriceValue':
            originalPrice,
        'discount': _discount(
          sellingPrice,
          originalPrice,
        ),
        'category': _category,
        'krishiCategory': _category,
        'unit': _unit,
        'stockQuantity':
            stockQuantity < 0
                ? 0
                : stockQuantity,
        'inStock':
            stockQuantity > 0,
        'harvestDate':
            _harvestDate.text.trim(),
        'isOrganic': _organic,
        'imagePath':
            _imageUrls.isEmpty
                ? ''
                : _imageUrls.first,
        'imagePaths': _imageUrls,
        'colorOptions': <String>[],
        'sizeOptions': <String>[],
        'sellerId': user.uid,
        'sellerShopName':
            seller['shopName']
                    ?.toString()
                    .trim() ??
                '',
        'sellerEmail':
            seller['email']
                    ?.toString()
                    .trim() ??
                user.email ??
                '',
        'sellerType': 'krishi',
        'marketplace': 'krishi',
        'productType': 'krishi',
        'productStatus': 'active',
        'approvalStatus': 'approved',
        'rating':
            widget.product?['rating'] ??
                0.0,
        'reviewCount':
            widget.product?['reviewCount'] ??
                0,
        'soldCount':
            widget.product?['soldCount'] ??
                0,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      final dynamic shopLat =
          seller['shopLat'] ??
              seller['shopLatitude'];
      final dynamic shopLng =
          seller['shopLng'] ??
              seller['shopLongitude'];

      if (shopLat != null) {
        data['sellerShopLat'] =
            shopLat;
      }

      if (shopLng != null) {
        data['sellerShopLng'] =
            shopLng;
      }

      data['sellerShopAddress'] =
          seller['address']
                  ?.toString()
                  .trim() ??
              '';

      final CollectionReference<
              Map<String, dynamic>>
          products =
          FirebaseFirestore.instance
              .collection('products');

      if (_editing) {
        await products
            .doc(
              widget.product!['id']
                  .toString(),
            )
            .set(
              data,
              SetOptions(merge: true),
            );
      } else {
        data['createdAt'] =
            FieldValue.serverTimestamp();
        await products.add(data);
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
            'Could not save Krishi product: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _variety.dispose();
    _origin.dispose();
    _price.dispose();
    _originalPrice.dispose();
    _stock.dispose();
    _harvestDate.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit Krishi Product'
              : 'Add Krishi Product',
          style: const TextStyle(
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
            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green
                    .withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.green
                      .withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.agriculture_rounded,
                    color: Colors.green,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only agriculture-related products should be added here.',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _field(
              _name,
              'Product Name',
              requiredField: true,
              hint:
                  'e.g. Fresh Tomato',
            ),
            _field(
              _brand,
              'Brand / Farm Name',
              hint:
                  'e.g. NRD Organic Farm',
            ),
            _field(
              _variety,
              'Variety / Type',
              hint:
                  'e.g. Roma, Basmati, Local',
            ),
            _field(
              _origin,
              'Origin / District',
              hint:
                  'e.g. Chitwan, Jhapa',
            ),

            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child:
                  DropdownButtonFormField<
                      String>(
                initialValue: _category,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Agriculture Category',
                  border:
                      OutlineInputBorder(),
                ),
                items: _categories
                    .map(
                      (String value) =>
                          DropdownMenuItem<
                              String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged:
                    (String? value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),
            ),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: _field(
                    _price,
                    'Selling Price (Rs.)',
                    requiredField: true,
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child:
                        DropdownButtonFormField<
                            String>(
                      initialValue: _unit,
                      decoration:
                          const InputDecoration(
                        labelText: 'Unit',
                        border:
                            OutlineInputBorder(),
                      ),
                      items: _units
                          .map(
                            (String value) =>
                                DropdownMenuItem<
                                    String>(
                              value: value,
                              child:
                                  Text(value),
                            ),
                          )
                          .toList(),
                      onChanged:
                          (String? value) {
                        if (value != null) {
                          setState(() {
                            _unit = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),

            _field(
              _originalPrice,
              'Original Price (optional)',
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
            ),

            _field(
              _stock,
              'Stock Quantity',
              requiredField: true,
              keyboardType:
                  TextInputType.number,
              hint:
                  'Available quantity',
            ),

            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child: TextFormField(
                controller: _harvestDate,
                readOnly: true,
                onTap: _chooseHarvestDate,
                decoration:
                    InputDecoration(
                  labelText:
                      'Harvest / Production Date (optional)',
                  border:
                      const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed:
                        _chooseHarvestDate,
                    icon: const Icon(
                      Icons
                          .calendar_month_rounded,
                    ),
                  ),
                ),
              ),
            ),

            SwitchListTile(
              value: _organic,
              activeThumbColor:
                  Colors.green,
              contentPadding:
                  EdgeInsets.zero,
              title: const Text(
                'Organic Product',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Mark only when this product is genuinely sold as organic.',
              ),
              onChanged: (bool value) {
                setState(() {
                  _organic = value;
                });
              },
            ),
            const SizedBox(height: 6),

            _field(
              _description,
              'Product Description',
              maxLines: 4,
              hint:
                  'Quality, farming method, packaging, usage, etc.',
            ),

            const SizedBox(height: 4),
            const Text(
              'Product Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (_imageUrls.isNotEmpty)
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection:
                      Axis.horizontal,
                  itemCount:
                      _imageUrls.length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    width: 8,
                  ),
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    final String url =
                        _imageUrls[index];

                    return Stack(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor:
                                Colors.black54,
                            child: IconButton(
                              padding:
                                  EdgeInsets.zero,
                              iconSize: 16,
                              onPressed: () {
                                setState(() {
                                  _imageUrls
                                      .removeAt(
                                    index,
                                  );
                                });
                              },
                              icon: const Icon(
                                Icons.close,
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            OutlinedButton.icon(
              onPressed:
                  _uploading ||
                          _imageUrls.length >=
                              5
                      ? null
                      : _pickImages,
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
                          .add_photo_alternate_outlined,
                    ),
              label: Text(
                _uploading
                    ? 'Uploading...'
                    : 'Add Product Photos (max 5)',
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed:
                    _saving ||
                            _uploading
                        ? null
                        : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .save_rounded,
                      ),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _editing
                          ? 'Update Product'
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
