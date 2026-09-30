import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'delivery_person_dashboard_page.dart';

class DeliveryPersonAuthPage extends StatefulWidget {
  const DeliveryPersonAuthPage({super.key});

  @override
  State<DeliveryPersonAuthPage> createState() =>
      _DeliveryPersonAuthPageState();
}

class _DeliveryPersonAuthPageState
    extends State<DeliveryPersonAuthPage> {
  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

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
  bool _checkingSavedSession = true;
  bool _uploadingProfilePhoto = false;
  bool _uploadingLicense = false;

  String _profilePhotoUrl = '';
  String _licenseFrontUrl = '';
  String _licenseBackUrl = '';

  Map<String, dynamic>? _rememberedDeliveryData;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSavedDeliverySession();
    });
  }

  void _finishSavedSessionCheck({
    Map<String, dynamic>? rememberedDeliveryData,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _checkingSavedSession = false;
      _rememberedDeliveryData = rememberedDeliveryData;
    });
  }

  Future<void> _restoreSavedDeliverySession() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      _finishSavedSessionCheck();
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('delivery_persons')
              .doc(user.uid)
              .get();

      if (!doc.exists) {
        // Another RD role may currently be signed in. Do not sign it out just
        // because Delivery Person was opened.
        _finishSavedSessionCheck();
        return;
      }

      final Map<String, dynamic> data =
          doc.data() ?? <String, dynamic>{};

      final String role =
          data['role']?.toString().trim() ?? '';

      if (role != 'delivery_person') {
        _finishSavedSessionCheck();
        return;
      }

      final bool opened = await _openDeliveryAccount(
        user: user,
        data: data,
        showStatusMessage: false,
      );

      if (!opened) {
        _emailController.text =
            user.email?.trim() ?? data['email']?.toString().trim() ?? '';

        _finishSavedSessionCheck(
          rememberedDeliveryData: data,
        );
      }
    } catch (_) {
      _finishSavedSessionCheck();
    }
  }

  Future<bool> _openDeliveryAccount({
    required User user,
    required Map<String, dynamic> data,
    required bool showStatusMessage,
  }) async {
    final bool isActive =
        data['isActive'] != false;
    final bool isApproved =
        data['isApproved'] == true;

    if (!isActive || !isApproved) {
      if (showStatusMessage) {
        _showMessage(
          !isActive
              ? 'This delivery person account is inactive.'
              : 'Your delivery person account is waiting for Admin approval.',
        );
      }

      if (mounted) {
        setState(() {
          _rememberedDeliveryData = data;
        });
      }

      return false;
    }

    final String now =
        DateTime.now().toIso8601String();

    await FirebaseFirestore.instance
        .collection('delivery_persons')
        .doc(user.uid)
        .set(
      <String, dynamic>{
        'isOnline': true,
        'updatedAt': now,
      },
      SetOptions(
        merge: true,
      ),
    );

    if (!mounted) {
      return false;
    }

    await _openDashboard();
    return true;
  }

  Future<void> _refreshRememberedDelivery() async {
    if (_checkingSavedSession) {
      return;
    }

    setState(() {
      _checkingSavedSession = true;
    });

    await _restoreSavedDeliverySession();
  }

  Future<void> _logoutRememberedDelivery() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();

      if (!mounted) {
        return;
      }

      _emailController.clear();
      _passwordController.clear();

      setState(() {
        _rememberedDeliveryData = null;
        _isRegistering = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _checkingSavedSession = false;
        });
      }
    }
  }

  Future<void> _restoreCustomerSession() async {
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================================================
  // OPEN DELIVERY DASHBOARD
  // =========================================================

  Future<void> _openDashboard() async {
    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const DeliveryPersonDashboardPage(),
      ),
    );
  }

  // =========================================================
  // DELIVERY DOCUMENT UPLOADS
  // =========================================================

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
        '$label upload failed: $body',
      );
    }

    final dynamic decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid $label upload response.',
      );
    }

    final String url =
        decoded['secure_url']?.toString().trim() ?? '';

    if (url.isEmpty) {
      throw Exception(
        '$label image URL was not received.',
      );
    }

    return url;
  }

  Future<void> _pickProfilePhoto() async {
    if (_uploadingProfilePhoto ||
        _uploadingLicense ||
        _isLoading) {
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
      _uploadingProfilePhoto = true;
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

      _showMessage(
        'Profile photo uploaded.',
      );
    } catch (error) {
      _showMessage(
        'Profile photo upload failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingProfilePhoto = false;
        });
      }
    }
  }

  Future<void> _pickLicenseImage({
    required bool front,
  }) async {
    if (_uploadingLicense ||
        _uploadingProfilePhoto ||
        _isLoading) {
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
      final String url = await _uploadImage(
        image,
        label: front
            ? 'Driving licence front'
            : 'Driving licence back',
      );

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

      _showMessage(
        front
            ? 'Driving licence front uploaded.'
            : 'Driving licence back uploaded.',
      );
    } catch (error) {
      _showMessage(
        'Licence upload failed: $error',
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
    if (_isLoading) {
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime initialDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate,
      lastDate: DateTime(now.year + 20, 12, 31),
    );

    if (selected == null || !mounted) {
      return;
    }

    final String month =
        selected.month.toString().padLeft(2, '0');
    final String day =
        selected.day.toString().padLeft(2, '0');

    setState(() {
      _licenseExpiryController.text =
          '${selected.year}-$month-$day';
    });
  }

  Widget _imageUploadCard({
    required String title,
    required String url,
    required IconData icon,
    required bool uploading,
    required VoidCallback onTap,
  }) {
    final bool hasImage = url.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
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
                          size: 32,
                          color: Colors.grey.shade700,
                        ),
                      ),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasImage
                        ? 'Uploaded'
                        : 'Required for verification',
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
              onPressed: uploading || _isLoading
                  ? null
                  : onTap,
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.upload_rounded,
                    ),
              label: Text(
                hasImage ? 'Change' : 'Upload',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // REGISTER
  // =========================================================

  Future<void> _register() async {
    final FormState? form =
        _formKey.currentState;

    if (form == null ||
        !form.validate()) {
      return;
    }

    if (_isLoading ||
        _uploadingProfilePhoto ||
        _uploadingLicense) {
      return;
    }

    if (_profilePhotoUrl.isEmpty) {
      _showMessage(
        'Please upload a profile photo.',
      );
      return;
    }

    if (_licenseFrontUrl.isEmpty ||
        _licenseBackUrl.isEmpty) {
      _showMessage(
        'Please upload both front and back of the driving licence.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String name =
        _nameController.text.trim();

    final String phone =
        _phoneController.text.trim();

    final String vehicleNumber =
        _vehicleNumberController.text.trim();

    final String licenseNumber =
        _licenseNumberController.text.trim();

    final String licenseExpiry =
        _licenseExpiryController.text.trim();

    final String email =
        _emailController.text.trim();

    final String password =
        _passwordController.text;

    try {
      final UserCredential credential =
          await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user =
          credential.user;

      if (user == null) {
        _showMessage(
          'Could not create delivery person account.',
        );
        return;
      }

      final String now =
          DateTime.now().toIso8601String();

      await FirebaseFirestore.instance
          .collection('delivery_persons')
          .doc(user.uid)
          .set(
        <String, dynamic>{
          'deliveryPersonId': user.uid,
          'name': name,
          'phone': phone,
          'email': email,
          'role': 'delivery_person',

          // Delivery person identity / vehicle / licence.
          'photoUrl': _profilePhotoUrl,
          'vehicleNumber': vehicleNumber,
          'drivingLicenseNumber': licenseNumber,
          'drivingLicenseExpiry': licenseExpiry,
          'drivingLicenseFrontUrl': _licenseFrontUrl,
          'drivingLicenseBackUrl': _licenseBackUrl,
          'drivingLicenseVerified': false,
          'drivingLicenseVerifiedAt': null,

          // Admin approval / account state.
          'isActive': true,
          'isApproved': false,
          'approvalStatus': 'pending',
          'approvedAt': null,
          'approvedBy': '',

          'isOnline': false,
          'currentOrderId': '',

          // Delivery person's own latest GPS.
          'latitude': null,
          'longitude': null,
          'locationUpdatedAt': null,

          'createdAt': now,
          'updatedAt': now,
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Account created. Your profile and driving licence were submitted. Admin approval and licence verification are required before delivery work.',
      );

      setState(() {
        _checkingSavedSession = true;
      });

      await _restoreSavedDeliverySession();
    } on FirebaseAuthException catch (error) {
      String message =
          'Could not create account.';

      if (error.code ==
          'email-already-in-use') {
        message =
            'This email is already registered.';
      } else if (error.code ==
          'weak-password') {
        message =
            'Password is too weak.';
      } else if (error.code ==
          'invalid-email') {
        message =
            'Please enter a valid email.';
      } else if (error.code ==
          'network-request-failed') {
        message =
            'Internet connection problem.';
      }

      _showMessage(message);
    } catch (error) {
      _showMessage(
        'Something went wrong while creating account.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> _login() async {
    final FormState? form =
        _formKey.currentState;

    if (form == null ||
        !form.validate()) {
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String email =
        _emailController.text.trim();

    final String password =
        _passwordController.text;

    try {
      final UserCredential credential =
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user =
          credential.user;

      if (user == null) {
        _showMessage(
          'Login failed.',
        );
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('delivery_persons')
              .doc(user.uid)
              .get();

      // A Seller/Customer/Admin/Ride Driver account must never be treated as
      // a Delivery Person account.
      if (!doc.exists) {
        await _restoreCustomerSession();

        if (!mounted) {
          return;
        }

        _showMessage(
          'This account is not registered as a delivery person.',
        );
        return;
      }

      final Map<String, dynamic> data =
          doc.data() ?? <String, dynamic>{};

      final String role =
          data['role']?.toString().trim() ?? '';

      if (role != 'delivery_person') {
        await _restoreCustomerSession();

        if (!mounted) {
          return;
        }

        _showMessage(
          'This is not a delivery person account.',
        );
        return;
      }

      final bool opened =
          await _openDeliveryAccount(
        user: user,
        data: data,
        showStatusMessage: true,
      );

      if (!opened && mounted) {
        setState(() {
          _rememberedDeliveryData = data;
        });
      } else if (opened && mounted) {
        _showMessage(
          'Delivery person login successful.',
        );
      }
    } on FirebaseAuthException catch (error) {
      String message =
          'Could not login.';

      if (error.code ==
              'user-not-found' ||
          error.code ==
              'wrong-password' ||
          error.code ==
              'invalid-credential') {
        message =
            'Email or password is incorrect.';
      } else if (error.code ==
          'invalid-email') {
        message =
            'Please enter a valid email.';
      } else if (error.code ==
          'user-disabled') {
        message =
            'This account has been disabled.';
      } else if (error.code ==
          'network-request-failed') {
        message =
            'Internet connection problem.';
      } else if (error.code ==
          'too-many-requests') {
        message =
            'Too many attempts. Please try again later.';
      }

      _showMessage(message);
    } catch (error) {
      _showMessage(
        'Something went wrong while logging in.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // SUBMIT
  // =========================================================

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    if (_isRegistering) {
      await _register();
    } else {
      await _login();
    }
  }

  // =========================================================
  // SWITCH LOGIN / REGISTER
  // =========================================================

  void _switchMode() {
    if (_isLoading) {
      return;
    }

    _formKey.currentState?.reset();

    setState(() {
      _isRegistering =
          !_isRegistering;

      _obscurePassword = true;

      _passwordController.clear();

      if (!_isRegistering) {
        _nameController.clear();
        _phoneController.clear();
        _vehicleNumberController.clear();
        _licenseNumberController.clear();
        _licenseExpiryController.clear();
        _profilePhotoUrl = '';
        _licenseFrontUrl = '';
        _licenseBackUrl = '';
      }
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_checkingSavedSession) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Delivery Person',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Checking saved Delivery Person account...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic>? remembered =
        _rememberedDeliveryData;

    if (remembered != null) {
      final bool isActive =
          remembered['isActive'] != false;
      final bool isApproved =
          remembered['isApproved'] == true;

      final String name =
          remembered['name']?.toString().trim() ?? '';

      final String email =
          remembered['email']?.toString().trim() ??
              FirebaseAuth.instance.currentUser?.email ??
              '';

      final String title =
          !isActive
              ? 'Delivery Account Inactive'
              : !isApproved
                  ? 'Approval Pending'
                  : 'Delivery Person Account';

      final String message =
          !isActive
              ? 'This Delivery Person account remains saved on this device, but it is currently inactive.'
              : !isApproved
                  ? 'Your Delivery Person account remains signed in. You do not need to enter email or password again while waiting for Admin approval.'
                  : 'Your Delivery Person account is saved on this device.';

      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Delivery Person Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Icon(
                          !isActive
                              ? Icons.block_rounded
                              : Icons
                                  .pending_actions_rounded,
                          size: 58,
                          color: !isActive
                              ? Colors.red
                              : Colors.orange,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (name.isNotEmpty)
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (email.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _refreshRememberedDelivery,
                          icon: const Icon(
                            Icons.refresh_rounded,
                          ),
                          label: const Text(
                            'Check Account Status',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _logoutRememberedDelivery,
                          icon: const Icon(
                            Icons.logout_rounded,
                          ),
                          label: const Text(
                            'Logout / Use Another Account',
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRegistering
              ? 'Delivery Person Register'
              : 'Delivery Person Login',
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final bool isDesktop = constraints.maxWidth >= 800;
          final double horizontalPadding = isDesktop ? 56 : 20;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isDesktop ? 42 : 20,
              horizontalPadding,
              28,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  CircleAvatar(
                    radius: isDesktop ? 54 : 44,
                    child: Icon(
                      Icons.local_shipping,
                      size: isDesktop ? 58 : 48,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Text(
                    _isRegistering
                        ? 'Create NRD Delivery Person Account'
                        : 'NRD Delivery Person Login',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 32 : 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    _isRegistering
                        ? 'Register to receive NRD Online Shop delivery orders.'
                        : 'Login to see your assigned orders and share live location.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      color:
                          Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // ===========================================
                  // REGISTER ONLY FIELDS
                  // ===========================================

                  if (_isRegistering) ...<Widget>[
                    TextFormField(
                      controller:
                          _nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Full Name',
                        hintText:
                            'Delivery person name',
                        prefixIcon: Icon(
                          Icons.person,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      validator:
                          (String? value) {
                        if (value == null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Please enter full name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    TextFormField(
                      controller:
                          _phoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Phone Number',
                        hintText:
                            'Delivery phone number',
                        prefixIcon: Icon(
                          Icons.phone,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      validator:
                          (String? value) {
                        final String phone =
                            value?.trim() ??
                                '';

                        if (phone.isEmpty) {
                          return 'Please enter phone number';
                        }

                        if (phone.length <
                            7) {
                          return 'Please enter a valid phone number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    TextFormField(
                      controller:
                          _vehicleNumberController,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Vehicle Number',
                        hintText:
                            'Example: BA 00 PA 0000',
                        prefixIcon: Icon(
                          Icons.two_wheeler_rounded,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      validator:
                          (String? value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter vehicle number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    TextFormField(
                      controller:
                          _licenseNumberController,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Driving Licence Number',
                        hintText:
                            'Enter licence number',
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      validator:
                          (String? value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter driving licence number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    TextFormField(
                      controller:
                          _licenseExpiryController,
                      readOnly: true,
                      onTap: _selectLicenseExpiry,
                      decoration: InputDecoration(
                        labelText:
                            'Licence Expiry Date',
                        hintText:
                            'YYYY-MM-DD',
                        prefixIcon: const Icon(
                          Icons.event_available_outlined,
                        ),
                        border:
                            const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip:
                              'Select expiry date',
                          onPressed:
                              _selectLicenseExpiry,
                          icon: const Icon(
                            Icons.calendar_month_rounded,
                          ),
                        ),
                      ),
                      validator:
                          (String? value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please select licence expiry date';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _imageUploadCard(
                      title: 'Profile Photo',
                      url: _profilePhotoUrl,
                      icon: Icons.person_outline_rounded,
                      uploading: _uploadingProfilePhoto,
                      onTap: _pickProfilePhoto,
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _imageUploadCard(
                      title: 'Driving Licence Front',
                      url: _licenseFrontUrl,
                      icon: Icons.credit_card_rounded,
                      uploading: _uploadingLicense,
                      onTap: () {
                        _pickLicenseImage(
                          front: true,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _imageUploadCard(
                      title: 'Driving Licence Back',
                      url: _licenseBackUrl,
                      icon: Icons.credit_card_rounded,
                      uploading: _uploadingLicense,
                      onTap: () {
                        _pickLicenseImage(
                          front: false,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 14,
                    ),
                  ],

                  // ===========================================
                  // EMAIL
                  // ===========================================

                  TextFormField(
                    controller:
                        _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    autofillHints:
                        const <String>[
                      AutofillHints.email,
                    ],
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Email',
                      hintText:
                          'example@email.com',
                      prefixIcon: Icon(
                        Icons.email,
                      ),
                      border:
                          OutlineInputBorder(),
                    ),
                    validator:
                        (String? value) {
                      final String email =
                          value?.trim() ??
                              '';

                      if (email.isEmpty) {
                        return 'Please enter email';
                      }

                      if (!email.contains(
                            '@',
                          ) ||
                          !email.contains(
                            '.',
                          )) {
                        return 'Please enter a valid email';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ===========================================
                  // PASSWORD
                  // ===========================================

                  TextFormField(
                    controller:
                        _passwordController,
                    obscureText:
                        _obscurePassword,
                    autofillHints:
                        const <String>[
                      AutofillHints.password,
                    ],
                    decoration:
                        InputDecoration(
                      labelText:
                          'Password',
                      prefixIcon:
                          const Icon(
                        Icons.lock,
                      ),
                      border:
                          const OutlineInputBorder(),
                      suffixIcon:
                          IconButton(
                        tooltip:
                            _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons
                                  .visibility_off,
                        ),
                      ),
                    ),
                    validator:
                        (String? value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Please enter password';
                      }

                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }

                      return null;
                    },
                    onFieldSubmitted:
                        (_) {
                      _submit();
                    },
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ===========================================
                  // LOGIN / REGISTER BUTTON
                  // ===========================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: isDesktop ? 60 : 54,
                    child:
                        FilledButton.icon(
                      onPressed:
                          _isLoading ||
                                  _uploadingProfilePhoto ||
                                  _uploadingLicense
                              ? null
                              : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : Icon(
                              _isRegistering
                                  ? Icons
                                      .person_add
                                  : Icons.login,
                            ),
                      label: Text(
                        _isLoading
                            ? 'Please wait...'
                            : _isRegistering
                                ? 'Register'
                                : 'Login',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ===========================================
                  // SWITCH LOGIN / REGISTER
                  // ===========================================

                  TextButton(
                    onPressed:
                        _isLoading ||
                                _uploadingProfilePhoto ||
                                _uploadingLicense
                            ? null
                            : _switchMode,
                    child: Text(
                      _isRegistering
                          ? 'Already have an account? Login'
                          : 'New delivery person? Register',
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  if (!_isRegistering)
                    Text(
                      'Only registered delivery person accounts can open the Delivery Dashboard.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

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
}
