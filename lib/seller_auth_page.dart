import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'seller_dashboard_page.dart';
import 'services/platform_capabilities.dart';

class SellerAuthPage extends StatefulWidget {
  const SellerAuthPage({super.key});

  @override
  State<SellerAuthPage> createState() =>
      _SellerAuthPageState();
}

class _SellerAuthPageState extends State<SellerAuthPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _shopNameController =
      TextEditingController();

  final TextEditingController _ownerNameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _addressController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _businessRegistrationController =
      TextEditingController();

  final TextEditingController _panNumberController =
      TextEditingController();

  final TextEditingController _vatNumberController =
      TextEditingController();

  bool _legalDeclarationAccepted = false;

  final ImagePicker _documentPicker = ImagePicker();

  XFile? _businessRegistrationDocument;
  XFile? _panDocument;
  XFile? _vatDocument;
  XFile? _ownerIdDocument;
  final List<XFile> _otherLegalDocuments = <XFile>[];

  bool _isPickingDocument = false;

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _showPassword = false;
  bool _checkingExistingSession = true;
  double? _shopLatitude;
  double? _shopLongitude;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _sellers =>
      FirebaseFirestore.instance.collection('sellers');

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openRememberedSellerSession();
    });
  }

  Future<void> _openRememberedSellerSession() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null || user.isAnonymous) {
        if (mounted) {
          setState(() {
            _checkingExistingSession = false;
          });
        }
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> sellerDocument =
          await _sellers.doc(user.uid).get();

      final Map<String, dynamic> seller =
          sellerDocument.data() ?? <String, dynamic>{};

      final bool isSeller = sellerDocument.exists &&
          seller['role']?.toString().trim() == 'seller';

      if (!isSeller) {
        if (mounted) {
          setState(() {
            _checkingExistingSession = false;
          });
        }
        return;
      }

      await _sellers.doc(user.uid).set(
        <String, dynamic>{
          'lastSessionOpenedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const SellerDashboardPage(),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingExistingSession = false;
        });
      }
    }
  }

  Future<void> _restoreCustomerSession() async {
    await _auth.signOut();
    await _auth.signInAnonymously();
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }


  String _documentExtension(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0) {
      return '.jpg';
    }

    final String extension =
        fileName.substring(dot).toLowerCase();

    const Set<String> supported = <String>{
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.heic',
      '.heif',
    };

    return supported.contains(extension)
        ? extension
        : '.jpg';
  }

  String _documentContentType(String fileName) {
    final String lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.heic') ||
        lower.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  Future<XFile?> _pickDocumentImage() async {
    if (_isPickingDocument) {
      return null;
    }

    setState(() {
      _isPickingDocument = true;
    });

    try {
      return await _documentPicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2400,
      );
    } catch (error) {
      _message(
        'Could not select document image. '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isPickingDocument = false;
        });
      }
    }
  }

  Future<void> _pickRequiredDocument(
    String documentType,
  ) async {
    final XFile? file = await _pickDocumentImage();

    if (file == null || !mounted) {
      return;
    }

    setState(() {
      switch (documentType) {
        case 'registration':
          _businessRegistrationDocument = file;
          break;
        case 'pan':
          _panDocument = file;
          break;
        case 'vat':
          _vatDocument = file;
          break;
        case 'owner_id':
          _ownerIdDocument = file;
          break;
      }
    });
  }

  Future<void> _addOtherLegalDocument() async {
    if (_otherLegalDocuments.length >= 3) {
      _message(
        'You can add up to 3 other legal documents.',
      );
      return;
    }

    final XFile? file = await _pickDocumentImage();

    if (file == null || !mounted) {
      return;
    }

    setState(() {
      _otherLegalDocuments.add(file);
    });
  }

  Widget _legalDocumentPicker({
    required String title,
    required String helper,
    required XFile? file,
    required VoidCallback onPick,
    bool requiredDocument = false,
    VoidCallback? onRemove,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: Icon(
          file == null
              ? Icons.upload_file_outlined
              : Icons.check_circle,
          color: file == null
              ? Colors.orange
              : Colors.green,
        ),
        title: Text(
          requiredDocument ? '$title *' : title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          file == null
              ? helper
              : 'Selected: ${file.name}',
        ),
        trailing: file == null
            ? TextButton(
                onPressed:
                    _isPickingDocument || _isLoading
                        ? null
                        : onPick,
                child: const Text('Choose'),
              )
            : IconButton(
                tooltip: 'Remove',
                onPressed:
                    _isLoading ? null : onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
      ),
    );
  }

  Future<String> _uploadLegalDocument({
    required String sellerId,
    required XFile file,
    required String documentKey,
  }) async {
    final bytes = await file.readAsBytes();

    const int maximumBytes = 10 * 1024 * 1024;

    if (bytes.length > maximumBytes) {
      throw Exception(
        '${file.name} is larger than 10 MB.',
      );
    }

    final String extension =
        _documentExtension(file.name);

    final String fileName =
        '${documentKey}_${DateTime.now().microsecondsSinceEpoch}$extension';

    final Reference reference = FirebaseStorage.instance
        .ref()
        .child(
          'seller_legal_documents/$sellerId/$fileName',
        );

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType:
            _documentContentType(file.name),
        customMetadata: <String, String>{
          'purpose':
              'seller_legal_verification',
          'sellerId': sellerId,
          'documentKey': documentKey,
          'originalFileName': file.name,
        },
      ),
    );

    return reference.fullPath;
  }

  Future<void> _deleteUploadedDocuments(
    Iterable<String> paths,
  ) async {
    for (final String path in paths) {
      if (path.trim().isEmpty) {
        continue;
      }

      try {
        await FirebaseStorage.instance
            .ref(path)
            .delete();
      } catch (_) {}
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isGettingLocation) {
      return;
    }

    setState(() {
      _isGettingLocation = true;
    });

    try {
      if (PlatformCapabilities.isWindows) {
        throw Exception(
          'Please type the shop address manually on Windows.',
        );
      }

      final bool locationEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!locationEnabled) {
        throw Exception(
          'Please turn on Location / GPS first.',
        );
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied.',
        );
      }

      if (permission ==
          LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
          'Enable it from phone settings.',
        );
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String address =
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';

      if (PlatformCapabilities.supportsNativeGeocoding) {
        final List<Placemark> placemarks =
            await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;
          final String readableAddress = <String?>[
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ]
              .whereType<String>()
              .where(
                (String value) => value.trim().isNotEmpty,
              )
              .join(', ');

          if (readableAddress.isNotEmpty) {
            address = readableAddress;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
  _addressController.text = address;
  _shopLatitude = position.latitude;
  _shopLongitude = position.longitude;
});
    } catch (error) {
      _message(
        error
            .toString()
            .replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _registerSeller() async {
    User? createdUser;
    final List<String> uploadedPaths = <String>[];

    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception(
          'Seller account could not be created.',
        );
      }

      final String sellerId = createdUser.uid;

      await createdUser.updateDisplayName(
        _ownerNameController.text.trim(),
      );

      final String registrationDocumentPath =
          await _uploadLegalDocument(
        sellerId: sellerId,
        file: _businessRegistrationDocument!,
        documentKey: 'business_registration',
      );
      uploadedPaths.add(registrationDocumentPath);

      final String panDocumentPath =
          await _uploadLegalDocument(
        sellerId: sellerId,
        file: _panDocument!,
        documentKey: 'pan',
      );
      uploadedPaths.add(panDocumentPath);

      String vatDocumentPath = '';

      if (_vatDocument != null) {
        vatDocumentPath =
            await _uploadLegalDocument(
          sellerId: sellerId,
          file: _vatDocument!,
          documentKey: 'vat',
        );
        uploadedPaths.add(vatDocumentPath);
      }

      final String ownerIdDocumentPath =
          await _uploadLegalDocument(
        sellerId: sellerId,
        file: _ownerIdDocument!,
        documentKey: 'owner_id',
      );
      uploadedPaths.add(ownerIdDocumentPath);

      final List<String> otherDocumentPaths =
          <String>[];

      for (int index = 0;
          index < _otherLegalDocuments.length;
          index++) {
        final String path =
            await _uploadLegalDocument(
          sellerId: sellerId,
          file: _otherLegalDocuments[index],
          documentKey:
              'other_${index + 1}',
        );

        otherDocumentPaths.add(path);
        uploadedPaths.add(path);
      }

      await _sellers.doc(sellerId).set(
        <String, dynamic>{
          'sellerId': sellerId,
          'role': 'seller',
          'accountType': 'seller',

          'shopName':
              _shopNameController.text.trim(),

          'ownerName':
              _ownerNameController.text.trim(),

          'phone':
              _phoneController.text.trim(),

          'address':
              _addressController.text.trim(),

          'email':
              _emailController.text.trim(),

          'description': '',

          // Government / legal business verification.
          'businessRegistrationNumber':
              _businessRegistrationController.text.trim(),
          'panNumber':
              _panNumberController.text.trim(),
          'vatNumber':
              _vatNumberController.text.trim(),
          'legalDeclarationAccepted':
              _legalDeclarationAccepted,
          'legalVerificationStatus': 'pending',
          'legalVerified': false,
          'legalVerifiedAt': null,
          'legalVerifiedBy': '',
          'legalRejectionReason': '',
          'adminReviewRequested': true,
          'legalDocumentsUploaded': true,
          'legalSubmittedAt':
              FieldValue.serverTimestamp(),

          // Private Firebase Storage paths.
          // Do not save public download URLs for legal documents.
          'businessRegistrationDocumentPath':
              registrationDocumentPath,
          'businessRegistrationDocumentName':
              _businessRegistrationDocument!.name,
          'panDocumentPath':
              panDocumentPath,
          'panDocumentName':
              _panDocument!.name,
          'vatDocumentPath':
              vatDocumentPath,
          'vatDocumentName':
              _vatDocument?.name ?? '',
          'ownerIdDocumentPath':
              ownerIdDocumentPath,
          'ownerIdDocumentName':
              _ownerIdDocument!.name,
          'otherLegalDocumentPaths':
              otherDocumentPaths,
          'otherLegalDocumentNames':
              _otherLegalDocuments
                  .map((XFile file) => file.name)
                  .toList(),

          // Legacy URL fields stay empty so sensitive legal
          // documents are never exposed through public URLs.
          'businessRegistrationDocumentUrl': '',
          'panDocumentUrl': '',
          'vatDocumentUrl': '',
          'ownerIdDocumentUrl': '',
          'otherLegalDocumentUrls': <String>[],

          // Seller photo fields.
          'photoUrl': '',
          'shopPhotoUrl': '',
          'shopImageUrl': '',
          'imageUrl': '',
          'logoUrl': '',
          'shopPhotos': <String>[],
          'photoStorage': '',

          // Admin must approve the seller before login.
          'isActive': false,

          // Seller shop location.
          'shopLat': _shopLatitude,
          'shopLng': _shopLongitude,
          'shopLatitude': _shopLatitude,
          'shopLongitude': _shopLongitude,
          if (_shopLatitude != null &&
              _shopLongitude != null)
            'shopLocation': GeoPoint(
              _shopLatitude!,
              _shopLongitude!,
            ),
          'shopLocationSource':
              _shopLatitude != null &&
                      _shopLongitude != null
                  ? 'registration_gps'
                  : '',
          'shopLocationUpdatedAt':
              FieldValue.serverTimestamp(),

          'createdAt':
              FieldValue.serverTimestamp(),

          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      _message(
        'Seller registration submitted. NRD Admin will review your legal documents. This page updates automatically after approval.',
      );

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              const SellerDashboardPage(),
        ),
      );
    } catch (error) {
      await _deleteUploadedDocuments(
        uploadedPaths.reversed,
      );

      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  Future<void> _loginSeller() async {
    final UserCredential credential =
        await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final User? user = credential.user;

    if (user == null) {
      throw Exception(
        'Seller login failed.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>
        sellerDocument =
        await _sellers.doc(user.uid).get();

    if (!sellerDocument.exists) {
      await _restoreCustomerSession();

      throw Exception(
        'This account is not registered as a seller.',
      );
    }

    final Map<String, dynamic> seller =
        sellerDocument.data() ??
            <String, dynamic>{};

    if (seller['role']?.toString().trim() != 'seller') {
      await _restoreCustomerSession();

      throw Exception(
        'This account is not registered as a seller.',
      );
    }

    await _sellers.doc(user.uid).set(
      <String, dynamic>{
        'lastLoginAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const SellerDashboardPage(),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_isRegistering && !_legalDeclarationAccepted) {
      _message(
        'Please confirm that the business is legally registered and the information is correct.',
      );
      return;
    }

    if (_isRegistering &&
        _businessRegistrationDocument == null) {
      _message(
        'Please upload the Business / Shop Registration Certificate.',
      );
      return;
    }

    if (_isRegistering && _panDocument == null) {
      _message(
        'Please upload the PAN Certificate.',
      );
      return;
    }

    if (_isRegistering &&
        _ownerIdDocument == null) {
      _message(
        'Please upload the Owner / Authorized Person ID.',
      );
      return;
    }

    if (_isRegistering &&
        _vatNumberController.text.trim().isNotEmpty &&
        _vatDocument == null) {
      _message(
        'VAT number was entered. Please upload the VAT Certificate.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegistering) {
        await _registerSeller();
      } else {
        await _loginSeller();
      }
    } on FirebaseAuthException catch (error) {
      String message =
          error.message ?? 'Authentication failed.';

      switch (error.code) {
        case 'email-already-in-use':
          message =
              'This email already has an account.';
          break;

        case 'invalid-email':
          message =
              'Please enter a valid email address.';
          break;

        case 'weak-password':
          message =
              'Please use a stronger password.';
          break;

        case 'user-not-found':
          message =
              'Seller account was not found.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Email or password is incorrect.';
          break;

        case 'too-many-requests':
          message =
              'Too many attempts. Please try again later.';
          break;
      }

      _message(message);
    } catch (error) {
      _message(
        error
            .toString()
            .replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final String email =
        _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _message(
        'First enter your seller email address.',
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: email,
      );

      _message(
        'Password reset email sent.',
      );
    } on FirebaseAuthException catch (error) {
      _message(
        error.message ??
            'Could not send password reset email.',
      );
    }
  }

  void _switchMode() {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isRegistering = !_isRegistering;
      _passwordController.clear();
      _showPassword = false;
    });
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _businessRegistrationController.dispose();
    _panNumberController.dispose();
    _vatNumberController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingExistingSession) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Opening saved seller account...',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRegistering
              ? 'Seller Registration'
              : 'Seller Login',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const SizedBox(height: 12),

              const Icon(
                Icons.storefront,
                size: 76,
                color: Colors.blue,
              ),

              const SizedBox(height: 14),

              Text(
                _isRegistering
                    ? 'Create your seller account'
                    : 'Login to manage your shop',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isRegistering
                    ? 'Register your shop with NRD Online Shop'
                    : 'Enter your seller email and password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 28),

              if (_isRegistering) ...<Widget>[
                TextFormField(
                  controller:
                      _shopNameController,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      const InputDecoration(
                    labelText: 'Shop Name',
                    prefixIcon:
                        Icon(Icons.store),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter shop name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller:
                      _ownerNameController,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      const InputDecoration(
                    labelText: 'Owner Name',
                    prefixIcon:
                        Icon(Icons.person),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter owner name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller:
                      _phoneController,
                  keyboardType:
                      TextInputType.phone,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon:
                        Icon(Icons.phone),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter phone number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller:
                      _addressController,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(
                    labelText: 'Shop Address',
                    prefixIcon:
                        Icon(Icons.location_on),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter shop address.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 4),

                Align(
                  alignment:
                      Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        _isGettingLocation
                            ? null
                            : _useCurrentLocation,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.my_location,
                          ),
                    label: Text(
                      _isGettingLocation
                          ? 'Finding location...'
                          : 'Use Current Location',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const SizedBox(height: 18),

                const Divider(),

                const SizedBox(height: 8),

                const Text(
                  'Government / Legal Verification',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Enter the legal registration details of the shop/business. '
                  'Admin will review these details before activating the seller account.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _businessRegistrationController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number',
                    prefixIcon: Icon(Icons.verified_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter business/shop registration number.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _panNumberController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'PAN Number',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter PAN number.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _vatNumberController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'VAT Number (if applicable)',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Leave blank if VAT registration is not applicable.',
                  ),
                ),


                const SizedBox(height: 18),

                const Text(
                  'Government Document Upload',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Upload clear photos/scans. Legal documents are stored privately and are only available to you and NRD Admin.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 10),

                _legalDocumentPicker(
                  title: 'Registration Certificate',
                  helper:
                      'Required government/business registration certificate',
                  file:
                      _businessRegistrationDocument,
                  requiredDocument: true,
                  onPick: () {
                    _pickRequiredDocument(
                      'registration',
                    );
                  },
                  onRemove: () {
                    setState(() {
                      _businessRegistrationDocument =
                          null;
                    });
                  },
                ),

                _legalDocumentPicker(
                  title: 'PAN Certificate',
                  helper:
                      'Required PAN registration certificate/card',
                  file: _panDocument,
                  requiredDocument: true,
                  onPick: () {
                    _pickRequiredDocument('pan');
                  },
                  onRemove: () {
                    setState(() {
                      _panDocument = null;
                    });
                  },
                ),

                _legalDocumentPicker(
                  title: 'VAT Certificate',
                  helper:
                      'Required only when VAT Number is entered',
                  file: _vatDocument,
                  onPick: () {
                    _pickRequiredDocument('vat');
                  },
                  onRemove: () {
                    setState(() {
                      _vatDocument = null;
                    });
                  },
                ),

                _legalDocumentPicker(
                  title: 'Owner / Authorized Person ID',
                  helper:
                      'Required identity document of the owner/authorized person',
                  file: _ownerIdDocument,
                  requiredDocument: true,
                  onPick: () {
                    _pickRequiredDocument(
                      'owner_id',
                    );
                  },
                  onRemove: () {
                    setState(() {
                      _ownerIdDocument = null;
                    });
                  },
                ),

                Card(
                  margin:
                      const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Other Legal Documents',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Optional — add up to 3 additional government/legal documents.',
                        ),
                        if (_otherLegalDocuments
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          ...List<Widget>.generate(
                            _otherLegalDocuments.length,
                            (int index) {
                              return ListTile(
                                dense: true,
                                contentPadding:
                                    EdgeInsets.zero,
                                leading: const Icon(
                                  Icons
                                      .description_outlined,
                                ),
                                title: Text(
                                  _otherLegalDocuments[
                                          index]
                                      .name,
                                ),
                                trailing: IconButton(
                                  tooltip: 'Remove',
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _otherLegalDocuments
                                                .removeAt(
                                              index,
                                            );
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        Align(
                          alignment:
                              Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isPickingDocument ||
                                        _isLoading
                                    ? null
                                    : _addOtherLegalDocument,
                            icon: const Icon(
                              Icons.add_a_photo_outlined,
                            ),
                            label: const Text(
                              'Add Other Document',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _legalDeclarationAccepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I confirm this shop/business is legally registered and the information provided is correct.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'NRD Admin will verify the registration details before seller activation.',
                  ),
                  onChanged: _isLoading
                      ? null
                      : (bool? value) {
                          setState(() {
                            _legalDeclarationAccepted = value == true;
                          });
                        },
                ),

                const SizedBox(height: 8),
              ],

              TextFormField(
                controller:
                    _emailController,
                keyboardType:
                    TextInputType.emailAddress,
                textInputAction:
                    TextInputAction.next,
                autofillHints: const <String>[
                  AutofillHints.email,
                ],
                decoration:
                    const InputDecoration(
                  labelText:
                      'Email Address',
                  prefixIcon:
                      Icon(Icons.email),
                  border:
                      OutlineInputBorder(),
                ),
                validator: (String? value) {
                  final String email =
                      value?.trim() ?? '';

                  if (email.isEmpty ||
                      !email.contains('@') ||
                      !email.contains('.')) {
                    return 'Enter a valid email.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller:
                    _passwordController,
                obscureText: !_showPassword,
                textInputAction:
                    TextInputAction.done,
                autofillHints: const <String>[
                  AutofillHints.password,
                ],
                onFieldSubmitted: (_) {
                  _submit();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      const Icon(Icons.lock),
                  border:
                      const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _showPassword =
                            !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
                validator: (String? value) {
                  if (value == null ||
                      value.length < 6) {
                    return 'Password must have at least 6 characters.';
                  }

                  return null;
                },
              ),

              if (!_isRegistering)
                Align(
                  alignment:
                      Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      _isLoading
                          ? null
                          : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          _isRegistering
                              ? Icons.person_add
                              : Icons.login,
                        ),
                  label: Text(
                    _isLoading
                        ? 'Please wait...'
                        : _isRegistering
                            ? 'Create Seller Account'
                            : 'Seller Login',
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed:
                    _isLoading
                        ? null
                        : _switchMode,
                child: Text(
                  _isRegistering
                      ? 'Already have a seller account? Login'
                      : 'New seller? Create account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
