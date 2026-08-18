import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'data/product_data.dart';

class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key});

  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    await loadProducts();

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _openForm([
    Map<String, dynamic>? product,
  ]) async {
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AdminProductFormPage(
          product: product,
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteProduct(
    Map<String, dynamic> product,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: Text(
            '${product['name']} will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await deleteProduct(
      product['id'].toString(),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _image(
    String? path,
    IconData icon,
  ) {
    if (path == null || path.isEmpty) {
      return Icon(
        icon,
        color: Colors.blue,
      );
    }

    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Icon(
            icon,
            color: Colors.blue,
          );
        },
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Icon(
            icon,
            color: Colors.blue,
          );
        },
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Icon(
          icon,
          color: Colors.blue,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Management',
        ),
        centerTitle: true,
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : products.isEmpty
              ? const Center(
                  child: Text(
                    'No products available.',
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    final Map<String, dynamic>
                        product =
                        products[index];

                    final List<String> paths =
                        (product['imagePaths']
                                    as List?)
                                ?.whereType<String>()
                                .toList() ??
                            <String>[];

                    final String? path =
                        paths.isNotEmpty
                            ? paths.first
                            : product['imagePath']
                                as String?;

                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 52,
                          height: 52,
                          clipBehavior:
                              Clip.antiAlias,
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .blue.shade50,
                            borderRadius:
                                BorderRadius
                                    .circular(10),
                          ),
                          child: _image(
                            path,
                            product['icon']
                                as IconData,
                          ),
                        ),
                        title: Text(
                          product['name']
                              .toString(),
                        ),
                        subtitle: Text(
                          '${product['price']} • '
                          '${product['category']}\n'
                          '${product['inStock'] == true ? 'In Stock' : 'Out of Stock'}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  _openForm(
                                product,
                              ),
                              icon: const Icon(
                                Icons.edit,
                                color:
                                    Colors.blue,
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _deleteProduct(
                                product,
                              ),
                              icon: const Icon(
                                Icons
                                    .delete_outline,
                                color:
                                    Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class AdminProductFormPage
    extends StatefulWidget {
  final Map<String, dynamic>? product;

  const AdminProductFormPage({
    super.key,
    this.product,
  });

  @override
  State<AdminProductFormPage>
      createState() =>
          _AdminProductFormPageState();
}

class _AdminProductFormPageState
    extends State<AdminProductFormPage> {
  static const String _cloudName =
      'p83ttfym';

  static const String _uploadPreset =
      'rd_online_shop_products';

  static const List<String> _colorPalette =
      <String>[
    'Black',
    'White',
    'Grey',
    'Silver',
    'Red',
    'Maroon',
    'Pink',
    'Magenta',
    'Purple',
    'Violet',
    'Indigo',
    'Blue',
    'Navy',
    'Sky Blue',
    'Cyan',
    'Teal',
    'Turquoise',
    'Green',
    'Lime',
    'Olive',
    'Yellow',
    'Gold',
    'Orange',
    'Coral',
    'Brown',
    'Beige',
    'Cream',
    'Khaki',
  ];

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController
      _originalPrice;
  late final TextEditingController _discount;
  late final TextEditingController _rating;
  late final TextEditingController _sizes;

  late String _category;
  late bool _inStock;

  late List<String> _imagePaths;
  late Set<String> _selectedColors;

  bool _saving = false;
  bool _uploadingPhotos = false;

  bool get _editing =>
      widget.product != null;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? p =
        widget.product;

    _name = TextEditingController(
      text: p?['name']?.toString() ?? '',
    );

    _price = TextEditingController(
      text: p?['price']
              ?.toString()
              .replaceAll('Rs. ', '') ??
          '',
    );

    _originalPrice =
        TextEditingController(
      text: p?['originalPrice']
              ?.toString()
              .replaceAll('Rs. ', '') ??
          '',
    );

    _discount = TextEditingController(
      text:
          p?['discount']?.toString() ?? '0',
    );

    _rating = TextEditingController(
      text:
          p?['rating']?.toString() ?? '4.0',
    );

    _sizes = TextEditingController(
      text:
          (p?['sizeOptions'] as List?)
                  ?.join(', ') ??
              '',
    );

    _category =
        p?['category']?.toString() ??
            'Phones';

    _inStock =
        p?['inStock'] != false;

    final dynamic saved =
        p?['imagePaths'];

    _imagePaths = saved is List
        ? saved
            .whereType<String>()
            .toList()
        : <String>[];

    if (_imagePaths.isEmpty &&
        p?['imagePath'] is String) {
      _imagePaths.add(
        p!['imagePath'] as String,
      );
    }

    _selectedColors =
        (p?['colorOptions'] as List?)
                ?.whereType<String>()
                .where(
                  _colorPalette.contains,
                )
                .toSet() ??
            <String>{};
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _originalPrice.dispose();
    _discount.dispose();
    _rating.dispose();
    _sizes.dispose();

    super.dispose();
  }

  List<String> _options(
    String text,
  ) {
    return text
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

  Color _colorValue(
    String color,
  ) {
    switch (color) {
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
        return const Color(0xFF800000);
      case 'Pink':
        return Colors.pink;
      case 'Magenta':
        return Colors.purpleAccent;
      case 'Purple':
        return Colors.purple;
      case 'Violet':
        return const Color(0xFF7F00FF);
      case 'Indigo':
        return Colors.indigo;
      case 'Blue':
        return Colors.blue;
      case 'Navy':
        return const Color(0xFF000080);
      case 'Sky Blue':
        return Colors.lightBlue;
      case 'Cyan':
        return Colors.cyan;
      case 'Teal':
        return Colors.teal;
      case 'Turquoise':
        return const Color(0xFF40E0D0);
      case 'Green':
        return Colors.green;
      case 'Lime':
        return Colors.lime;
      case 'Olive':
        return const Color(0xFF808000);
      case 'Yellow':
        return Colors.yellow;
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Orange':
        return Colors.orange;
      case 'Coral':
        return const Color(0xFFFF7F50);
      case 'Brown':
        return Colors.brown;
      case 'Beige':
        return const Color(0xFFF5F5DC);
      case 'Cream':
        return const Color(0xFFFFFDD0);
      case 'Khaki':
        return const Color(0xFFC3B091);
      default:
        return Colors.blue;
    }
  }

  Future<String> _uploadPhotoToCloudinary(
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
        await response.stream
            .bytesToString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed: $body',
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(body)
            as Map<String, dynamic>;

    final String? secureUrl =
        json['secure_url']
            ?.toString();

    if (secureUrl == null ||
        secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary did not return image URL.',
      );
    }

    return secureUrl;
  }

  Future<void> _choosePhotos() async {
    final List<XFile> selected =
        await ImagePicker()
            .pickMultiImage(
      imageQuality: 85,
    );

    if (selected.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _uploadingPhotos = true;
    });

    try {
      final List<String> uploadedUrls =
          <String>[];

      for (final XFile image
          in selected) {
        final String url =
            await _uploadPhotoToCloudinary(
          image,
        );

        uploadedUrls.add(url);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _imagePaths.addAll(
          uploadedUrls,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${uploadedUrls.length} photo(s) uploaded successfully.',
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
          _uploadingPhotos = false;
        });
      }
    }
  }

  Widget _previewImage(
    String path,
  ) {
    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      return Image.network(
        path,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 84,
            height: 84,
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
        width: 84,
        height: 84,
        fit: BoxFit.cover,
      );
    }

    return Image.file(
      File(path),
      width: 84,
      height: 84,
      fit: BoxFit.cover,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Container(
          width: 84,
          height: 84,
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
    if (!_formKey.currentState!
            .validate() ||
        _saving ||
        _uploadingPhotos) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> data =
          <String, dynamic>{
        'name':
            _name.text.trim(),
        'price':
            'Rs. ${_price.text.trim()}',
        'originalPrice':
            _originalPrice.text
                    .trim()
                    .isEmpty
                ? null
                : 'Rs. ${_originalPrice.text.trim()}',
        'discount':
            int.tryParse(
                  _discount.text.trim(),
                ) ??
                0,
        'rating':
            double.tryParse(
                  _rating.text.trim(),
                ) ??
                4.0,
        'category': _category,
        'inStock': _inStock,
        'imagePaths':
            _imagePaths,
        'imagePath':
            _imagePaths.isEmpty
                ? null
                : _imagePaths.first,
        'colorOptions':
            _colorPalette
                .where(
                  _selectedColors
                      .contains,
                )
                .toList(),
        'sizeOptions':
            _options(
          _sizes.text,
        ),
      };

      if (_editing) {
        await updateProduct(
          widget.product!['id']
              .toString(),
          data,
        );
      } else {
        await addProduct(data);
      }

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: $error',
          ),
        ),
      );

      setState(() {
        _saving = false;
      });
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? type,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration:
            InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit Product'
              : 'Add New Product',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration:
                  const InputDecoration(
                labelText:
                    'Product Name',
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  (String? value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Enter product name.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: 12,
            ),
            TextFormField(
              controller: _price,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText:
                    'Selling Price',
                prefixText: 'Rs. ',
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  (String? value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Enter selling price.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: 12,
            ),
            _field(
              _originalPrice,
              'Original Price (optional)',
              type:
                  TextInputType.number,
            ),
            DropdownButtonFormField<
                String>(
              initialValue:
                  _category,
              decoration:
                  const InputDecoration(
                labelText: 'Category',
                border:
                    OutlineInputBorder(),
              ),
              items: productCategories
                  .map(
                    (String category) {
                  return DropdownMenuItem<
                      String>(
                    value: category,
                    child:
                        Text(category),
                  );
                },
              ).toList(),
              onChanged:
                  (String? value) {
                if (value != null) {
                  setState(() {
                    _category =
                        value;
                  });
                }
              },
            ),
            const SizedBox(
              height: 12,
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _discount,
                    'Discount %',
                    type:
                        TextInputType
                            .number,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: _field(
                    _rating,
                    'Rating',
                    type:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Color Options',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorPalette
                  .map(
                    (String color) {
                final bool selected =
                    _selectedColors
                        .contains(
                  color,
                );

                return InkWell(
                  borderRadius:
                      BorderRadius
                          .circular(24),
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
                    width: 25,
                    height: 25,
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
                                .grey
                                .shade400,
                        width:
                            selected
                                ? 4
                                : 1,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
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
              }).toList(),
            ),
            const SizedBox(
              height: 12,
            ),
            _field(
              _sizes,
              'Sizes (example: S, M, L, XL, XX,XXX )',
            ),
            const Text(
              'Product Photos',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            if (_imagePaths.isNotEmpty)
              SizedBox(
                height: 84,
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
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            8,
                          ),
                          child:
                              _previewImage(
                            _imagePaths[
                                index],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _imagePaths
                                    .removeAt(
                                  index,
                                );
                              });
                            },
                            child:
                                const CircleAvatar(
                              radius: 12,
                              child: Icon(
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
            const SizedBox(
              height: 8,
            ),
            OutlinedButton.icon(
              onPressed:
                  _uploadingPhotos
                      ? null
                      : _choosePhotos,
              icon: _uploadingPhotos
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
                _uploadingPhotos
                    ? 'Uploading Photos...'
                    : 'Choose Photos from Gallery',
              ),
            ),
            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,
              title:
                  const Text(
                'In Stock',
              ),
              value: _inStock,
              onChanged:
                  (bool value) {
                setState(() {
                  _inStock =
                      value;
                });
              },
            ),
            const SizedBox(
              height: 12,
            ),
            SizedBox(
              height: 52,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _saving ||
                            _uploadingPhotos
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