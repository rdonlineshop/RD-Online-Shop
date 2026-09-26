import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'krishi_seller_dashboard_page.dart';
import 'services/platform_capabilities.dart';

class KrishiSellerAuthPage extends StatefulWidget {
  const KrishiSellerAuthPage({super.key});

  @override
  State<KrishiSellerAuthPage> createState() =>
      _KrishiSellerAuthPageState();
}

class _KrishiSellerAuthPageState extends State<KrishiSellerAuthPage> {
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

  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

  String _businessRegistrationDocumentUrl = '';
  String _panDocumentUrl = '';
  String _vatDocumentUrl = '';
  bool _isUploadingDocument = false;

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
      _openRememberedKrishiSellerSession();
    });
  }

  Future<void> _openRememberedKrishiSellerSession() async {
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
          seller['role']?.toString().trim() == 'seller' &&
          seller['sellerType']?.toString().trim() == 'krishi';

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
          builder: (_) => const KrishiSellerDashboardPage(),
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
          'Please type the farm / shop address manually on Windows.',
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

  Future<String> _uploadLegalDocument(
    XFile image,
  ) async {
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
      throw Exception(
        'Document upload response is invalid.',
      );
    }

    final String url =
        decoded['secure_url']?.toString().trim() ?? '';

    if (url.isEmpty) {
      throw Exception(
        'Uploaded document URL is missing.',
      );
    }

    return url;
  }

  Future<void> _pickLegalDocument(
    String type,
  ) async {
    if (_isUploadingDocument) {
      return;
    }

    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (image == null) {
      return;
    }

    setState(() {
      _isUploadingDocument = true;
    });

    try {
      final String url =
          await _uploadLegalDocument(image);

      if (!mounted) {
        return;
      }

      setState(() {
        if (type == 'registration') {
          _businessRegistrationDocumentUrl = url;
        } else if (type == 'pan') {
          _panDocumentUrl = url;
        } else {
          _vatDocumentUrl = url;
        }
      });

      _message('Certificate uploaded successfully.');
    } catch (error) {
      _message(
        'Certificate upload failed: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDocument = false;
        });
      }
    }
  }

  Widget _legalDocumentButton({
    required String title,
    required String url,
    required VoidCallback onPressed,
    bool optional = false,
  }) {
    final bool uploaded = url.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: OutlinedButton.icon(
        onPressed:
            _isUploadingDocument ? null : onPressed,
        icon: Icon(
          uploaded
              ? Icons.check_circle_rounded
              : Icons.upload_file_rounded,
          color: uploaded ? Colors.green : null,
        ),
        label: Text(
          uploaded
              ? '$title Uploaded'
              : 'Upload $title${optional ? ' (optional)' : ''}',
        ),
      ),
    );
  }

  Future<void> _registerKrishiSeller() async {
    User? createdUser;

    final String vatNumber =
        _vatNumberController.text.trim();

    if (_businessRegistrationDocumentUrl.isEmpty ||
        _panDocumentUrl.isEmpty) {
      _message(
        'Upload Business Registration Certificate and PAN Certificate.',
      );
      return;
    }

    if (vatNumber.isNotEmpty &&
        _vatDocumentUrl.isEmpty) {
      _message(
        'Upload VAT Certificate because VAT Number is entered.',
      );
      return;
    }

    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception(
          'Krishi seller account could not be created.',
        );
      }

      final String sellerId = createdUser.uid;

      await createdUser.updateDisplayName(
        _ownerNameController.text.trim(),
      );

      await _sellers.doc(sellerId).set(
        <String, dynamic>{
          'sellerId': sellerId,
          'role': 'seller',
          'accountType': 'seller',
          'sellerType': 'krishi',
          'marketplace': 'krishi',
          'krishiSeller': true,

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
          'adminReviewRequested': true,
          'legalSubmittedAt':
              FieldValue.serverTimestamp(),

          // Government certificate images.
          'businessRegistrationDocumentUrl':
              _businessRegistrationDocumentUrl,
          'panDocumentUrl':
              _panDocumentUrl,
          'vatDocumentUrl':
              _vatDocumentUrl,
          'ownerIdDocumentUrl': '',
          'otherLegalDocumentUrls': <String>[],

          // Seller photo fields.
          // Shop Profile page will update these.
          'photoUrl': '',
          'shopPhotoUrl': '',
          'shopImageUrl': '',
          'imageUrl': '',
          'logoUrl': '',
          'shopPhotos': <String>[],
          'photoStorage': '',

          // Admin must approve the seller before login.
          'isActive': false,

// Seller shop location. Keep both the canonical and legacy
// coordinate fields during the launch transition so every existing
// customer/seller page reads the same current position.
'shopLat': _shopLatitude,
'shopLng': _shopLongitude,
'shopLatitude': _shopLatitude,
'shopLongitude': _shopLongitude,
if (_shopLatitude != null && _shopLongitude != null)
  'shopLocation': GeoPoint(
    _shopLatitude!,
    _shopLongitude!,
  ),
'shopLocationSource':
    _shopLatitude != null && _shopLongitude != null
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
        'Krishi seller account created. Your login is saved on this device until you logout.',
      );

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const KrishiSellerDashboardPage(),
        ),
      );
    } catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  Future<void> _loginKrishiSeller() async {
    final UserCredential credential =
        await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final User? user = credential.user;

    if (user == null) {
      throw Exception(
        'Krishi seller login failed.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>
        sellerDocument =
        await _sellers.doc(user.uid).get();

    if (!sellerDocument.exists) {
      await _restoreCustomerSession();

      throw Exception(
        'This account is not registered as a Krishi seller.',
      );
    }

    final Map<String, dynamic> seller =
        sellerDocument.data() ??
            <String, dynamic>{};

    if (seller['role']?.toString().trim() != 'seller' ||
        seller['sellerType']?.toString().trim() != 'krishi') {
      await _restoreCustomerSession();

      throw Exception(
        'This account is not registered as a Krishi seller.',
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
            const KrishiSellerDashboardPage(),
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

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegistering) {
        await _registerKrishiSeller();
      } else {
        await _loginKrishiSeller();
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
              'Krishi seller account was not found.';
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
        'First enter your Krishi seller email address.',
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
                'Opening saved Krishi seller account...',
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
              ? 'Krishi Seller Registration'
              : 'Krishi Seller Login',
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
                    ? 'Create your Krishi seller account'
                    : 'Login to manage your farm / shop',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isRegistering
                    ? 'Register your farm / agriculture shop with NRD Krishi'
                    : 'Enter your Krishi seller email and password',
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
                    labelText: 'Farm / Shop Name',
                    prefixIcon:
                        Icon(Icons.store),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter farm / shop name.';
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
                    labelText: 'Farm / Shop Address',
                    prefixIcon:
                        Icon(Icons.location_on),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter farm / shop address.';
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
                  'Enter the legal registration details of the farm/agriculture business. '
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
                    labelText: 'Business / Farm Registration Number',
                    prefixIcon: Icon(Icons.verified_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter business/farm registration number.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                _legalDocumentButton(
                  title: 'Registration Certificate',
                  url: _businessRegistrationDocumentUrl,
                  onPressed: () {
                    _pickLegalDocument('registration');
                  },
                ),

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

                const SizedBox(height: 10),

                _legalDocumentButton(
                  title: 'PAN Certificate / Card',
                  url: _panDocumentUrl,
                  onPressed: () {
                    _pickLegalDocument('pan');
                  },
                ),

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

                const SizedBox(height: 10),

                _legalDocumentButton(
                  title: 'VAT Certificate',
                  url: _vatDocumentUrl,
                  optional:
                      _vatNumberController.text.trim().isEmpty,
                  onPressed: () {
                    _pickLegalDocument('vat');
                  },
                ),

                const SizedBox(height: 8),

                CheckboxListTile(
                  value: _legalDeclarationAccepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I confirm this farm/agriculture business is legally registered and the information provided is correct.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'NRD Admin will verify the registration details before Krishi seller activation.',
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
                            ? 'Create Krishi Seller Account'
                            : 'Krishi Seller Login',
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
                      ? 'Already have a Krishi seller account? Login'
                      : 'New Krishi seller? Create account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
