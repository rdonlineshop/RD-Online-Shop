import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class KrishiLegalDocumentsPage extends StatefulWidget {
  const KrishiLegalDocumentsPage({super.key});

  @override
  State<KrishiLegalDocumentsPage> createState() =>
      _KrishiLegalDocumentsPageState();
}

class _KrishiLegalDocumentsPageState
    extends State<KrishiLegalDocumentsPage> {
  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

  final TextEditingController _registrationController =
      TextEditingController();
  final TextEditingController _panController =
      TextEditingController();
  final TextEditingController _vatController =
      TextEditingController();

  bool _declarationAccepted = false;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  String _registrationDocumentUrl = '';
  String _panDocumentUrl = '';
  String _vatDocumentUrl = '';

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final User? user = _user;
      if (user == null || user.isAnonymous) {
        throw Exception('Krishi seller login required.');
      }

      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('sellers')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> seller =
          snapshot.data() ?? <String, dynamic>{};

      _registrationController.text =
          seller['businessRegistrationNumber']?.toString() ?? '';
      _panController.text =
          seller['panNumber']?.toString() ?? '';
      _vatController.text =
          seller['vatNumber']?.toString() ?? '';

      _registrationDocumentUrl =
          seller['businessRegistrationDocumentUrl']
                  ?.toString()
                  .trim() ??
              '';
      _panDocumentUrl =
          seller['panDocumentUrl']?.toString().trim() ?? '';
      _vatDocumentUrl =
          seller['vatDocumentUrl']?.toString().trim() ?? '';
      _declarationAccepted =
          seller['legalDeclarationAccepted'] == true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String> _uploadImage(XFile image) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = _uploadPreset;

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
        'Document upload failed (${streamed.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw Exception('Document upload response is invalid.');
    }

    final String url =
        decoded['secure_url']?.toString().trim() ?? '';

    if (url.isEmpty) {
      throw Exception('Uploaded document URL is missing.');
    }

    return url;
  }

  Future<void> _pickDocument(String type) async {
    if (_uploading) {
      return;
    }

    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (image == null) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final String url = await _uploadImage(image);

      if (!mounted) {
        return;
      }

      setState(() {
        if (type == 'registration') {
          _registrationDocumentUrl = url;
        } else if (type == 'pan') {
          _panDocumentUrl = url;
        } else {
          _vatDocumentUrl = url;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: '
              '${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Widget _documentTile({
    required String title,
    required String url,
    required VoidCallback onUpload,
    required bool requiredDocument,
  }) {
    final bool hasDocument = url.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: hasDocument
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(
                          Icons.description_outlined,
                          color: Colors.green,
                          size: 36,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.description_outlined,
                      color: Colors.green,
                      size: 36,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasDocument
                        ? 'Uploaded'
                        : requiredDocument
                            ? 'Required'
                            : 'Optional',
                    style: TextStyle(
                      color: hasDocument
                          ? Colors.green
                          : requiredDocument
                              ? Colors.red
                              : Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _uploading ? null : onUpload,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(
                hasDocument ? 'Replace' : 'Upload',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || _uploading) {
      return;
    }

    final User? user = _user;
    if (user == null || user.isAnonymous) {
      return;
    }

    final String registration =
        _registrationController.text.trim();
    final String pan = _panController.text.trim();
    final String vat = _vatController.text.trim();

    if (registration.isEmpty ||
        pan.isEmpty ||
        !_declarationAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration number, PAN number and legal declaration are required.',
          ),
        ),
      );
      return;
    }

    if (_registrationDocumentUrl.isEmpty ||
        _panDocumentUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload Business Registration Certificate and PAN Certificate.',
          ),
        ),
      );
      return;
    }

    if (vat.isNotEmpty && _vatDocumentUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'VAT Certificate photo is required when VAT Number is entered.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .set(
        <String, dynamic>{
          'businessRegistrationNumber': registration,
          'panNumber': pan,
          'vatNumber': vat,
          'businessRegistrationDocumentUrl':
              _registrationDocumentUrl,
          'panDocumentUrl': _panDocumentUrl,
          'vatDocumentUrl': _vatDocumentUrl,
          'legalDeclarationAccepted': true,
          'legalVerificationStatus': 'pending',
          'legalVerified': false,
          'legalVerifiedAt': null,
          'legalVerifiedBy': '',
          'adminReviewRequested': true,
          'legalSubmittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Legal documents submitted for Admin verification.',
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'permission-denied'
                  ? 'Permission denied while saving legal documents.'
                  : 'Could not save documents: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _registrationController.dispose();
    _panController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Krishi Legal Documents',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                TextField(
                  controller: _registrationController,
                  decoration: const InputDecoration(
                    labelText:
                        'Business / Farm Registration Number',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.verified_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                _documentTile(
                  title:
                      'Business Registration Certificate',
                  url: _registrationDocumentUrl,
                  requiredDocument: true,
                  onUpload: () {
                    _pickDocument('registration');
                  },
                ),
                TextField(
                  controller: _panController,
                  decoration: const InputDecoration(
                    labelText: 'PAN Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                _documentTile(
                  title: 'PAN Certificate / Card',
                  url: _panDocumentUrl,
                  requiredDocument: true,
                  onUpload: () {
                    _pickDocument('pan');
                  },
                ),
                TextField(
                  controller: _vatController,
                  decoration: const InputDecoration(
                    labelText:
                        'VAT Number (if applicable)',
                    helperText:
                        'Leave blank if VAT is not applicable.',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                _documentTile(
                  title: 'VAT Certificate',
                  url: _vatDocumentUrl,
                  requiredDocument:
                      _vatController.text.trim().isNotEmpty,
                  onUpload: () {
                    _pickDocument('vat');
                  },
                ),
                CheckboxListTile(
                  value: _declarationAccepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity:
                      ListTileControlAffinity.leading,
                  title: const Text(
                    'I confirm these legal documents and numbers are correct.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onChanged: (bool? value) {
                    setState(() {
                      _declarationAccepted = value == true;
                    });
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                        _saving || _uploading ? null : _save,
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
                            Icons.verified_user_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Submitting...'
                          : 'Submit for Verification',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
