import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PropertyPartnerProfilePage extends StatefulWidget {
  const PropertyPartnerProfilePage({super.key});

  @override
  State<PropertyPartnerProfilePage> createState() =>
      _PropertyPartnerProfilePageState();
}

class _PropertyPartnerProfilePageState
    extends State<PropertyPartnerProfilePage> {
  

  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _officeName = TextEditingController();
  final TextEditingController _contactPerson = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _district = TextEditingController();
  final TextEditingController _municipality = TextEditingController();
  final TextEditingController _ward = TextEditingController();
  final TextEditingController _registrationNumber =
      TextEditingController();
  final TextEditingController _panVatNumber =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingProfile = false;
  bool _uploadingOffice = false;

  String _partnerId = '';
  String _email = '';
  String _partnerType = '';
  String _profilePhotoUrl = '';
  String _officePhotoUrl = '';
  String _status = 'pending';
  bool _isApproved = false;

  static const List<String> _partnerTypes = <String>[
    'Owner',
    'Agent',
    'Office',
    'Company',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _showMessage('Please login as a Property Partner first.');
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('property_partners')
              .doc(user.uid)
              .get();

      if (!doc.exists) {
        throw StateError('Property Partner profile was not found.');
      }

      final Map<String, dynamic> data =
          doc.data() ?? <String, dynamic>{};

      _partnerId = data['partnerId']?.toString().trim() ?? '';
      _email =
          data['email']?.toString().trim() ??
          user.email?.trim() ??
          '';
      _partnerType =
          data['partnerType']?.toString().trim() ?? '';
      _profilePhotoUrl =
          data['photoUrl']?.toString().trim() ?? '';
      _officePhotoUrl =
          data['officePhotoUrl']?.toString().trim() ?? '';
      _status =
          data['status']?.toString().trim().toLowerCase() ??
          'pending';
      _isApproved = data['isApproved'] == true;

      _fullName.text =
          data['fullName']?.toString().trim() ?? '';
      _phone.text =
          data['phone']?.toString().trim() ?? '';
      _officeName.text =
          data['officeName']?.toString().trim() ?? '';
      _contactPerson.text =
          data['contactPerson']?.toString().trim() ?? '';
      _address.text =
          data['address']?.toString().trim() ?? '';
      _district.text =
          data['district']?.toString().trim() ?? '';
      _municipality.text =
          data['municipality']?.toString().trim() ?? '';
      _ward.text =
          data['ward']?.toString().trim() ?? '';
      _registrationNumber.text =
          data['registrationNumber']?.toString().trim() ?? '';
      _panVatNumber.text =
          data['panVatNumber']?.toString().trim() ?? '';
    } catch (error) {
      _showMessage(
        error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String> _uploadImage(
    XFile image, {
    required String label,
  }) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] = _uploadPreset;

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
      throw Exception('$label upload failed: $body');
    }

    final dynamic decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid $label upload response.');
    }

    final String url =
        decoded['secure_url']?.toString().trim() ?? '';

    if (url.isEmpty) {
      throw Exception('$label image URL was not received.');
    }

    return url;
  }

  Future<void> _pickProfilePhoto() async {
    if (_uploadingProfile || _uploadingOffice || _saving) {
      return;
    }

    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _uploadingProfile = true;
    });

    try {
      final String url = await _uploadImage(
        image,
        label: 'Profile photo',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoUrl = url;
      });

      _showMessage('Profile photo uploaded.');
    } catch (error) {
      _showMessage('Profile photo upload failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingProfile = false;
        });
      }
    }
  }

  Future<void> _pickOfficePhoto() async {
    if (_uploadingProfile || _uploadingOffice || _saving) {
      return;
    }

    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _uploadingOffice = true;
    });

    try {
      final String url = await _uploadImage(
        image,
        label: 'Office photo',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _officePhotoUrl = url;
      });

      _showMessage('Office photo uploaded.');
    } catch (error) {
      _showMessage('Office photo upload failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingOffice = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_saving ||
        _uploadingProfile ||
        _uploadingOffice ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      _showMessage('Property Partner login is required.');
      return;
    }

    if (_partnerType.isEmpty) {
      _showMessage('Please select Partner Type.');
      return;
    }

    if (_profilePhotoUrl.isEmpty) {
      _showMessage('Please upload your profile photo.');
      return;
    }

    if ((_partnerType == 'Office' ||
            _partnerType == 'Company') &&
        _officePhotoUrl.isEmpty) {
      _showMessage('Please upload the office photo.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('property_partners')
          .doc(user.uid)
          .update(
        <String, dynamic>{
          'fullName': _fullName.text.trim(),
          'email': _email.trim().toLowerCase(),
          'phone': _phone.text.trim(),
          'photoUrl': _profilePhotoUrl,
          'officePhotoUrl': _officePhotoUrl,
          'partnerType': _partnerType,
          'officeName': _officeName.text.trim(),
          'contactPerson': _contactPerson.text.trim(),
          'address': _address.text.trim(),
          'district': _district.text.trim(),
          'municipality': _municipality.text.trim(),
          'ward': _ward.text.trim(),
          'registrationNumber':
              _registrationNumber.text.trim(),
          'panVatNumber': _panVatNumber.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      _showMessage(
        'Property Partner profile saved successfully.',
      );
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ?? 'Could not save Property Partner profile.',
      );
    } catch (error) {
      _showMessage(
        'Could not save Property Partner profile: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _photoCard({
    required String title,
    required String url,
    required IconData icon,
    required bool uploading,
    required VoidCallback onTap,
    required String helper,
  }) {
    final bool hasImage = url.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 78,
                height: 78,
                child: hasImage
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          size: 34,
                          color: Colors.grey.shade700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasImage ? 'Uploaded' : helper,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasImage
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed:
                  uploading || _saving ? null : onTap,
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload_rounded),
              label: Text(
                hasImage ? 'Change' : 'Upload',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyInfo({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization:
          keyboardType == TextInputType.phone
              ? TextCapitalization.none
              : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (String? value) {
        final String text = value?.trim() ?? '';

        if (required && text.isEmpty) {
          return 'Please enter $label';
        }

        if (keyboardType == TextInputType.phone &&
            text.isNotEmpty &&
            text.length < 7) {
          return 'Please enter a valid phone number';
        }

        return null;
      },
    );
  }

  bool get _officePartner =>
      _partnerType == 'Office' ||
      _partnerType == 'Company';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bool approved =
        _isApproved || _status == 'approved';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Property Partner Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  Card(
                    color: approved
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            approved
                                ? Icons.verified_rounded
                                : Icons.pending_actions_rounded,
                            color: approved
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              approved
                                  ? 'Verified Property Partner'
                                  : 'Verification status: ${_status.isEmpty ? 'pending' : _status}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _readOnlyInfo(
                    label: 'Property Partner ID',
                    value: _partnerId,
                    icon: Icons.badge_rounded,
                  ),
                  const SizedBox(height: 14),
                  _readOnlyInfo(
                    label: 'Google Login Email',
                    value: _email,
                    icon: Icons.email_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _fullName,
                    label: 'Full Name / Owner Name',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _phone,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _partnerTypes.contains(_partnerType)
                            ? _partnerType
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Partner Type',
                      prefixIcon:
                          Icon(Icons.business_center_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: _partnerTypes
                        .map(
                          (String type) =>
                              DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (String? value) {
                            setState(() {
                              _partnerType = value ?? '';
                            });
                          },
                    validator: (String? value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Please select Partner Type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _photoCard(
                    title: 'Profile Photo',
                    url: _profilePhotoUrl,
                    icon: Icons.person_outline_rounded,
                    uploading: _uploadingProfile,
                    onTap: _pickProfilePhoto,
                    helper: 'Required for partner profile',
                  ),
                  if (_officePartner) ...<Widget>[
                    const SizedBox(height: 14),
                    _field(
                      controller: _officeName,
                      label: 'Office / Company Name',
                      icon: Icons.apartment_rounded,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _contactPerson,
                      label: 'Contact Person',
                      icon: Icons.contact_page_rounded,
                    ),
                    const SizedBox(height: 14),
                    _photoCard(
                      title: 'Office Photo',
                      url: _officePhotoUrl,
                      icon: Icons.storefront_rounded,
                      uploading: _uploadingOffice,
                      onTap: _pickOfficePhoto,
                      helper:
                          'Required for Office / Company verification',
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _registrationNumber,
                      label: 'Registration Number',
                      icon: Icons.description_rounded,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _panVatNumber,
                      label: 'PAN / VAT Number',
                      icon: Icons.receipt_long_rounded,
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 14),
                    _field(
                      controller: _officeName,
                      label: 'Office / Agency Name (Optional)',
                      icon: Icons.apartment_rounded,
                      required: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _registrationNumber,
                      label: 'Registration Number (Optional)',
                      icon: Icons.description_rounded,
                      required: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _panVatNumber,
                      label: 'PAN / VAT Number (Optional)',
                      icon: Icons.receipt_long_rounded,
                      required: false,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _field(
                    controller: _address,
                    label: 'Full Address',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _district,
                    label: 'District',
                    icon: Icons.map_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _municipality,
                    label: 'Municipality / Rural Municipality',
                    icon: Icons.location_city_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _ward,
                    label: 'Ward Number',
                    icon: Icons.signpost_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: const Color(0xFFFFF8E1),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: const <Widget>[
                          Icon(
                            Icons.security_rounded,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sensitive identity and legal documents are not uploaded from this profile page. They will be connected through a protected verification flow so private documents are not exposed through a public image URL.',
                              style: TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _saving ||
                              _uploadingProfile ||
                              _uploadingOffice
                          ? null
                          : _saveProfile,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : 'Save Property Partner Profile',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _officeName.dispose();
    _contactPerson.dispose();
    _address.dispose();
    _district.dispose();
    _municipality.dispose();
    _ward.dispose();
    _registrationNumber.dispose();
    _panVatNumber.dispose();
    super.dispose();
  }
}
