import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'ride_driver_requests_page.dart';

class RideDriverAuthPage extends StatefulWidget {
  const RideDriverAuthPage({super.key});

  @override
  State<RideDriverAuthPage> createState() =>
      _RideDriverAuthPageState();
}

class _RideDriverAuthPageState
    extends State<RideDriverAuthPage> {
  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset =
      'rd_online_shop_products';

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _licenseExpiryController =
      TextEditingController();
  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _uploadingLicense = false;

  String _licenseFrontUrl = '';
  String _licenseBackUrl = '';

  String _vehicleType = 'Bike';

  static const List<String> _vehicleTypes = <String>[
    'Bike',
    'Auto',
    'Taxi',
    'Car',
    'Jeep / SUV',
    'Van / Hiace',
    'Microbus',
    'Mini Bus',
    'Bus',
    'Ambulance',
    'Pickup',
    'Truck',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleNumberController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _uploadLicenseImage(
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
        'Driving licence upload failed: $body',
      );
    }

    final dynamic decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid licence upload response.',
      );
    }

    final String url =
        decoded['secure_url']?.toString().trim() ?? '';

    if (url.isEmpty) {
      throw Exception(
        'Driving licence image URL was not received.',
      );
    }

    return url;
  }

  Future<void> _pickLicenseImage({
    required bool front,
  }) async {
    if (_uploadingLicense || _isLoading) {
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
      _uploadingLicense = true;
    });

    try {
      final String url =
          await _uploadLicenseImage(image);

      if (!mounted) {
        return;
      }

      setState(() {
        if (front) {
          _licenseFrontUrl = url;
        } else {
          _licenseBackUrl = url;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            front
                ? 'Driving licence front uploaded.'
                : 'Driving licence back uploaded.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Licence upload failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLicense = false;
        });
      }
    }
  }

  Future<void> _selectLicenseExpiry() async {
    final DateTime now = DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: now.add(
        const Duration(days: 365),
      ),
      firstDate: now,
      lastDate: DateTime(
        now.year + 20,
        12,
        31,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    _licenseExpiryController.text =
        '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';

    setState(() {});
  }

  Future<void> _submit() async {
    final bool valid =
        _formKey.currentState?.validate() ?? false;

    if (!valid || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegistering) {
        if (_licenseFrontUrl.isEmpty ||
            _licenseBackUrl.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please upload both front and back of the driving licence.',
              ),
            ),
          );
          return;
        }

        await _registerDriver();
      } else {
        await _loginDriver();
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Ride Driver authentication failed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerDriver() async {
    final UserCredential credential =
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final User? user = credential.user;

    if (user == null) {
      throw StateError(
        'Ride Driver account could not be created.',
      );
    }

    await FirebaseFirestore.instance
        .collection('ride_drivers')
        .doc(user.uid)
        .set(
      <String, dynamic>{
        'driverId': user.uid,
        'authUid': user.uid,
        'role': 'ride_driver',
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'vehicleType': _vehicleType,
        'vehicleNumber':
            _vehicleNumberController.text.trim(),

        // Driving licence
        'drivingLicenseNumber':
            _licenseNumberController.text.trim(),
        'drivingLicenseExpiry':
            _licenseExpiryController.text.trim(),
        'drivingLicenseFrontUrl':
            _licenseFrontUrl,
        'drivingLicenseBackUrl':
            _licenseBackUrl,
        'drivingLicenseVerified': false,

        'photoUrl': '',
        'rating': 0.0,
        'isActive': false,
        'isApproved': false,
        'isOnline': false,
        'latitude': null,
        'longitude': null,
        'locationUpdatedAt': null,
        'currentRideRequestId': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.hourglass_top_rounded,
            size: 42,
          ),
          title: const Text(
            'Registration Submitted',
          ),
          content: const Text(
            'Your Ride Driver account and driving licence were submitted. Admin approval and licence verification are required before you can go online and receive ride requests.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loginDriver() async {
    final UserCredential credential =
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final User? user = credential.user;

    if (user == null) {
      throw StateError(
        'Ride Driver login failed.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
        await FirebaseFirestore.instance
            .collection('ride_drivers')
            .doc(user.uid)
            .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();

      throw StateError(
        'Ride Driver profile was not found.',
      );
    }

    final Map<String, dynamic> data =
        doc.data() ?? <String, dynamic>{};

    final bool isActive = data['isActive'] == true;
    final bool isApproved = data['isApproved'] == true;
    final bool licenseVerified =
        data['drivingLicenseVerified'] == true;
    final String role = data['role']?.toString().trim() ?? '';
    final String approvalStatus =
        data['approvalStatus']?.toString().trim().toLowerCase() ?? '';
    final bool isSuspended =
        isApproved && !isActive && approvalStatus == 'suspended';

    if (role != 'ride_driver') {
      await FirebaseAuth.instance.signOut();

      throw StateError(
        'This account is not a Ride Driver account.',
      );
    }

    // A suspended, already-approved driver may still enter the driver
    // dashboard to see the amount due and submit a reactivation request.
    // Suspension only blocks Online / new-ride access.
    if (isSuspended && licenseVerified) {
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RideDriverRequestsPage(
            driverId: user.uid,
          ),
        ),
      );
      return;
    }

    if (!isApproved || !isActive || !licenseVerified) {
      if (!mounted) {
        return;
      }

      final bool rejected = approvalStatus == 'rejected';
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: Icon(
              rejected
                  ? Icons.cancel_rounded
                  : Icons.pending_actions_rounded,
              size: 42,
            ),
            title: Text(
              rejected ? 'Driver Account Rejected' : 'Approval Pending',
            ),
            content: Text(
              rejected
                  ? 'This Ride Driver account is currently rejected. Contact Admin if you need the account reviewed again.'
                  : 'Your Ride Driver account is not active yet. Admin approval and driving licence verification are required.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RideDriverRequestsPage(
          driverId: user.uid,
        ),
      ),
    );
  }

  void _toggleMode() {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isRegistering = !_isRegistering;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          _isRegistering
              ? 'Ride Driver Register'
              : 'Ride Driver Login',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Card(
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 38,
                          child: Icon(
                            Icons.directions_car_rounded,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isRegistering
                              ? 'Become an RD Ride Driver'
                              : 'Welcome Back',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isRegistering
                              ? 'Register your ride driver profile. Admin approval is required.'
                              : 'Login to view and manage your ride requests.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (_isRegistering) ...<Widget>[
                          TextFormField(
                            controller: _nameController,
                            textInputAction:
                                TextInputAction.next,
                            decoration:
                                _inputDecoration(
                              label: 'Full Name',
                              icon: Icons.person_rounded,
                            ),
                            validator: (String? value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType:
                                TextInputType.phone,
                            textInputAction:
                                TextInputAction.next,
                            decoration:
                                _inputDecoration(
                              label: 'Phone Number',
                              icon: Icons.phone_rounded,
                            ),
                            validator: (String? value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Please enter phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _vehicleType,
                            decoration:
                                _inputDecoration(
                              label: 'Vehicle Type',
                              icon: Icons
                                  .directions_car_filled_rounded,
                            ),
                            items: _vehicleTypes
                                .map(
                                  (String type) =>
                                      DropdownMenuItem<
                                          String>(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _vehicleType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller:
                                _vehicleNumberController,
                            textInputAction:
                                TextInputAction.next,
                            decoration:
                                _inputDecoration(
                              label: 'Vehicle Number',
                              icon: Icons.badge_outlined,
                            ),
                            validator: (String? value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Please enter vehicle number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller:
                                _licenseNumberController,
                            textInputAction:
                                TextInputAction.next,
                            decoration:
                                _inputDecoration(
                              label:
                                  'Driving Licence Number',
                              icon: Icons
                                  .credit_card_rounded,
                            ),
                            validator: (String? value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Please enter driving licence number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller:
                                _licenseExpiryController,
                            readOnly: true,
                            onTap: _selectLicenseExpiry,
                            decoration: InputDecoration(
                              labelText:
                                  'Licence Expiry Date',
                              prefixIcon: const Icon(
                                Icons.event_rounded,
                              ),
                              suffixIcon: IconButton(
                                onPressed:
                                    _selectLicenseExpiry,
                                icon: const Icon(
                                  Icons
                                      .calendar_month_rounded,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                              ),
                            ),
                            validator: (String? value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Please select licence expiry date';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _licenseUploadCard(
                            title:
                                'Driving Licence Front',
                            url: _licenseFrontUrl,
                            onTap: () =>
                                _pickLicenseImage(
                              front: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _licenseUploadCard(
                            title:
                                'Driving Licence Back',
                            url: _licenseBackUrl,
                            onTap: () =>
                                _pickLicenseImage(
                              front: false,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Email',
                            icon: Icons.email_rounded,
                          ),
                          validator: (String? value) {
                            final String email =
                                value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Please enter email';
                            }

                            if (!email.contains('@')) {
                              return 'Please enter a valid email';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller:
                              _passwordController,
                          obscureText: _obscurePassword,
                          onFieldSubmitted: (_) {
                            _submit();
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(
                              Icons.lock_rounded,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                        .visibility_rounded
                                    : Icons
                                        .visibility_off_rounded,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed:
                                _isLoading || _uploadingLicense
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
                                        ? Icons
                                            .person_add_rounded
                                        : Icons
                                            .login_rounded,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Please wait...'
                                  : _isRegistering
                                      ? 'Register'
                                      : 'Login',
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed:
                              _isLoading ? null : _toggleMode,
                          child: Text(
                            _isRegistering
                                ? 'Already registered? Login'
                                : 'New Ride Driver? Register',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _licenseUploadCard({
    required String title,
    required String url,
    required VoidCallback onTap,
  }) {
    final bool uploaded = url.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: uploaded
              ? Colors.green
              : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                uploaded
                    ? Icons.verified_rounded
                    : Icons.badge_rounded,
                color: uploaded
                    ? Colors.green
                    : Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (uploaded)
                const Text(
                  'Uploaded',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (uploaded) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                height: 130,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return const SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'Licence preview unavailable.',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
                _uploadingLicense ? null : onTap,
            icon: _uploadingLicense
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.upload_file_rounded,
                  ),
            label: Text(
              uploaded
                  ? 'Change Image'
                  : 'Upload Image',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
