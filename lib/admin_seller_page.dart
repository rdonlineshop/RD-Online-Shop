import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSellerPage extends StatelessWidget {
  const AdminSellerPage({super.key});

  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

  CollectionReference<Map<String, dynamic>> get _sellers =>
      FirebaseFirestore.instance.collection('sellers');

  String _sellerPhoto(Map<String, dynamic> seller) {
    const List<String> possibleFields = <String>[
      'photoUrl',
      'shopPhotoUrl',
      'shopImageUrl',
      'imageUrl',
      'profilePhotoUrl',
      'profileImageUrl',
      'photo',
      'image',
    ];

    for (final String field in possibleFields) {
      final dynamic value = seller[field];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final dynamic photos = seller['shopPhotos'];

    if (photos is List) {
      for (final dynamic item in photos) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
    }

    return '';
  }

  Future<void> _contact(
    BuildContext context,
    String phone,
    bool sms,
  ) async {
    if (phone.trim().isEmpty) {
      return;
    }

    final Uri uri = Uri(
      scheme: sms ? 'sms' : 'tel',
      path: phone.replaceAll(' ', ''),
    );

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone application could not be opened.',
          ),
        ),
      );
    }
  }

  Future<void> _email(
    BuildContext context,
    String email,
  ) async {
    if (email.trim().isEmpty) {
      return;
    }

    final Uri uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
    );

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email application could not be opened.',
          ),
        ),
      );
    }
  }

  Future<void> _setActive(
    String sellerId,
    bool value,
  ) {
    return _sellers.doc(sellerId).update(
      <String, dynamic>{
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _deleteSeller(
    BuildContext context,
    String sellerId,
    String shopName,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Seller?'),
          content: Text(
            '$shopName will be permanently removed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
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

    await _sellers.doc(sellerId).delete();

    if (!context.mounted) {
      return;
    }

    Navigator.maybePop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seller deleted successfully.'),
      ),
    );
  }

  Widget _sellerAvatar(
    Map<String, dynamic> seller, {
    double radius = 28,
  }) {
    final String photo = _sellerPhoto(seller);
    final bool isActive = seller['isActive'] != false;

    if (photo.startsWith('http://') ||
        photo.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (
          Object exception,
          StackTrace? stackTrace,
        ) {},
      );
    }

    if (photo.startsWith('assets/')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: AssetImage(photo),
      );
    }

    if (photo.isNotEmpty) {
      final File file = File(photo);

      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: FileImage(file),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isActive ? Colors.blue.shade50 : Colors.red.shade50,
      child: Icon(
        Icons.storefront,
        color: isActive ? Colors.blue : Colors.red,
        size: radius,
      ),
    );
  }

  Widget _detail(
    IconData icon,
    String label,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSellerDetails(
    BuildContext context,
    String sellerId,
    Map<String, dynamic> seller,
  ) {
    final String shopName =
        seller['shopName']?.toString() ?? 'Unnamed Shop';

    final String ownerName =
        seller['ownerName']?.toString() ?? '';

    final String phone =
        seller['phone']?.toString() ?? '';

    final String email =
        seller['email']?.toString() ?? '';

    final String address =
        seller['address']?.toString() ?? '';

    final String description =
        seller['description']?.toString() ?? '';

    final bool isActive =
        seller['isActive'] != false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _sellerAvatar(
                      seller,
                      radius: 44,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            shopName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green
                                      .withValues(alpha: 0.12)
                                  : Colors.red
                                      .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              isActive
                                  ? 'Active'
                                  : 'Inactive',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _detail(
                  Icons.person,
                  'Owner',
                  ownerName,
                ),
                _detail(
                  Icons.phone,
                  'Phone',
                  phone,
                ),
                _detail(
                  Icons.email,
                  'Email',
                  email,
                ),
                _detail(
                  Icons.location_on,
                  'Shop Address',
                  address,
                ),
                _detail(
                  Icons.description,
                  'Description',
                  description,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty
                            ? null
                            : () {
                                _contact(
                                  context,
                                  phone,
                                  false,
                                );
                              },
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty
                            ? null
                            : () {
                                _contact(
                                  context,
                                  phone,
                                  true,
                                );
                              },
                        icon: const Icon(Icons.sms_outlined),
                        label: const Text('SMS'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (email.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _email(
                          context,
                          email,
                        );
                      },
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Email'),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);

                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _SellerFormPage(
                                sellerId: sellerId,
                                seller: seller,
                                cloudName: _cloudName,
                                uploadPreset:
                                    _uploadPreset,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Seller'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _deleteSeller(
                            sheetContext,
                            sellerId,
                            shopName,
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Delete Seller',
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seller Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton.icon(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _SellerFormPage(
                    cloudName: _cloudName,
                    uploadPreset: _uploadPreset,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Seller'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _sellers.snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  QuerySnapshot<Map<String, dynamic>>>
              snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load sellers:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              sellers = snapshot.data!.docs;

          if (sellers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.storefront_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No seller account has been created yet.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const _SellerFormPage(
                            cloudName: _cloudName,
                            uploadPreset:
                                _uploadPreset,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Seller'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sellers.length,
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  document = sellers[index];

              final Map<String, dynamic> seller =
                  document.data();

              final String shopName =
                  seller['shopName']?.toString() ??
                      'Unnamed Shop';

              final String ownerName =
                  seller['ownerName']?.toString() ??
                      'No owner name';

              final String phone =
                  seller['phone']?.toString() ?? '';

              final bool isActive =
                  seller['isActive'] != false;

              return Card(
                margin:
                    const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  onTap: () {
                    _showSellerDetails(
                      context,
                      document.id,
                      seller,
                    );
                  },
                  leading: _sellerAvatar(
                    seller,
                    radius: 30,
                  ),
                  title: Text(
                    shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Padding(
                    padding:
                        const EdgeInsets.only(top: 4),
                    child: Text(
                      '$ownerName'
                      '${phone.isEmpty ? '' : '\n$phone'}',
                    ),
                  ),
                  isThreeLine: phone.isNotEmpty,
                  trailing: Switch(
                    value: isActive,
                    onChanged: (bool value) {
                      _setActive(
                        document.id,
                        value,
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SellerFormPage extends StatefulWidget {
  final String? sellerId;
  final Map<String, dynamic>? seller;
  final String cloudName;
  final String uploadPreset;

  const _SellerFormPage({
    this.sellerId,
    this.seller,
    required this.cloudName,
    required this.uploadPreset,
  });

  @override
  State<_SellerFormPage> createState() =>
      _SellerFormPageState();
}

class _SellerFormPageState
    extends State<_SellerFormPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _shopName;
  late final TextEditingController _ownerName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _description;

  String _photoUrl = '';

  bool _isActive = true;
  bool _uploading = false;
  bool _saving = false;

  bool get _editing =>
      widget.sellerId != null;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? seller =
        widget.seller;

    _shopName = TextEditingController(
      text:
          seller?['shopName']?.toString() ?? '',
    );

    _ownerName = TextEditingController(
      text:
          seller?['ownerName']?.toString() ?? '',
    );

    _phone = TextEditingController(
      text: seller?['phone']?.toString() ?? '',
    );

    _email = TextEditingController(
      text: seller?['email']?.toString() ?? '',
    );

    _address = TextEditingController(
      text:
          seller?['address']?.toString() ?? '',
    );

    _description = TextEditingController(
      text: seller?['description']?.toString() ?? '',
    );

    _isActive =
        seller?['isActive'] != false;

    _photoUrl = _existingPhoto(
      seller,
    );
  }

  String _existingPhoto(
    Map<String, dynamic>? seller,
  ) {
    if (seller == null) {
      return '';
    }

    const List<String> fields = <String>[
      'photoUrl',
      'shopPhotoUrl',
      'shopImageUrl',
      'imageUrl',
      'profilePhotoUrl',
      'profileImageUrl',
      'photo',
      'image',
    ];

    for (final String field in fields) {
      final dynamic value =
          seller[field];

      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final dynamic photos =
        seller['shopPhotos'];

    if (photos is List) {
      for (final dynamic photo in photos) {
        if (photo is String &&
            photo.trim().isNotEmpty) {
          return photo.trim();
        }
      }
    }

    return '';
  }

  @override
  void dispose() {
    _shopName.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _description.dispose();

    super.dispose();
  }

  Future<String> _uploadToCloudinary(
    XFile image,
  ) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '${widget.cloudName}/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] =
        widget.uploadPreset;

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

    final Map<String, dynamic> data =
        jsonDecode(body)
            as Map<String, dynamic>;

    final String url =
        data['secure_url']?.toString() ?? '';

    if (url.isEmpty) {
      throw Exception(
        'Cloudinary image URL was not received.',
      );
    }

    return url;
  }

  Future<void> _choosePhoto() async {
    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final String url =
          await _uploadToCloudinary(
        image,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _photoUrl = url;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Seller photo uploaded successfully.',
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

  Future<void> _saveSeller() async {
    if (!_formKey.currentState!.validate() ||
        _saving ||
        _uploading) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> data =
          <String, dynamic>{
        'shopName':
            _shopName.text.trim(),
        'ownerName':
            _ownerName.text.trim(),
        'phone':
            _phone.text.trim(),
        'email':
            _email.text.trim(),
        'address':
            _address.text.trim(),
        'description':
            _description.text.trim(),
        'photoUrl': _photoUrl,
        'shopPhotoUrl': _photoUrl,
        'shopImageUrl': _photoUrl,
        'shopPhotos': _photoUrl.isEmpty
            ? <String>[]
            : <String>[_photoUrl],
        'isActive': _isActive,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      final CollectionReference<
              Map<String, dynamic>>
          sellers = FirebaseFirestore.instance
              .collection('sellers');

      if (_editing) {
        await sellers.doc(widget.sellerId).set(
              data,
              SetOptions(merge: true),
            );
      } else {
        data['createdAt'] =
            FieldValue.serverTimestamp();

        await sellers.add(data);
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
            'Could not save seller: $error',
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
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
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
      ),
    );
  }

  Widget _photoPreview() {
    if (_photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundColor:
            Colors.blue.shade50,
        child: const Icon(
          Icons.storefront,
          size: 52,
          color: Colors.blue,
        ),
      );
    }

    return CircleAvatar(
      radius: 52,
      backgroundColor:
          Colors.grey.shade200,
      backgroundImage:
          NetworkImage(_photoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit Seller'
              : 'Add Seller',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: <Widget>[
            Center(
              child: Stack(
                children: <Widget>[
                  _photoPreview(),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      child: IconButton(
                        onPressed: _uploading
                            ? null
                            : _choosePhoto,
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
                                Icons.camera_alt,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _field(
              _shopName,
              'Shop Name',
              requiredField: true,
            ),
            _field(
              _ownerName,
              'Owner Name',
              requiredField: true,
            ),
            _field(
              _phone,
              'Phone',
              keyboardType:
                  TextInputType.phone,
              requiredField: true,
            ),
            _field(
              _email,
              'Email',
              keyboardType:
                  TextInputType.emailAddress,
            ),
            _field(
              _address,
              'Shop Address',
              maxLines: 2,
            ),
            _field(
              _description,
              'Description',
              maxLines: 3,
            ),
            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,
              title:
                  const Text('Seller Active'),
              value: _isActive,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _saving || _uploading
                        ? null
                        : _saveSeller,
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
                          : 'Add Seller',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}