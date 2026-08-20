import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'seller_dashboard_page.dart';

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

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _showPassword = false;
  double? _shopLatitude;
  double? _shopLongitude;
  
  FirebaseAuth get _auth => FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _sellers =>
      FirebaseFirestore.instance.collection('sellers');

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
      if (Platform.isWindows) {
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

      final List<Placemark> placemarks =
          await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception(
          'Address could not be found.',
        );
      }

      final Placemark place = placemarks.first;

      final String address = <String?>[
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

// Seller shop live tracking location
'shopLatitude': _shopLatitude,
'shopLongitude': _shopLongitude,
'shopLocationUpdatedAt':
    FieldValue.serverTimestamp(),

'createdAt':
    FieldValue.serverTimestamp(),

'updatedAt':
    FieldValue.serverTimestamp(),
        },
      );

      await _restoreCustomerSession();

      if (!mounted) {
        return;
      }

      _message(
        'Seller account created. Please wait for Admin approval before login.',
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

    if (seller['isActive'] == false) {
      await _restoreCustomerSession();

      throw Exception(
        'Your seller account is inactive. '
        'Please contact RD Online Shop admin.',
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

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    ? 'Register your shop with RD Online Shop'
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
