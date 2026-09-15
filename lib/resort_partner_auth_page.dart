import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'resort_partner_dashboard_page.dart';
import 'services/active_session_role.dart';

class ResortPartnerAuthPage extends StatefulWidget {
  const ResortPartnerAuthPage({super.key});

  @override
  State<ResortPartnerAuthPage> createState() =>
      _ResortPartnerAuthPageState();
}

class _ResortPartnerAuthPageState
    extends State<ResortPartnerAuthPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _businessName =
      TextEditingController();
  final TextEditingController _ownerName =
      TextEditingController();
  final TextEditingController _phone =
      TextEditingController();
  final TextEditingController _address =
      TextEditingController();
  final TextEditingController _registrationNumber =
      TextEditingController();
  final TextEditingController _panVatNumber =
      TextEditingController();
  final TextEditingController _email =
      TextEditingController();
  final TextEditingController _password =
      TextEditingController();

  bool _registering = false;
  bool _loading = false;
  bool _hidePassword = true;

  static const Color _rdGreen = Color(0xFF2E7D32);

  @override
  void dispose() {
    _businessName.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _address.dispose();
    _registrationNumber.dispose();
    _panVatNumber.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      if (_registering) {
        await _register();
      } else {
        await _login();
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(
        error.message ?? 'Authentication failed.',
      );
    } catch (error) {
      _showMessage('Could not continue.\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    final String email = _email.text.trim().toLowerCase();
    final String password = _password.text;

    UserCredential credential;
    bool createdNewAuthUser = false;

    try {
      credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdNewAuthUser = true;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') {
        rethrow;
      }

      // Universal test mode: reuse the same Firebase Auth account
      // and create a separate Resort Partner profile for this role.
      credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    final User? user = credential.user;
    if (user == null) {
      throw StateError(
        'Resort Partner account could not be created.',
      );
    }

    final DocumentReference<Map<String, dynamic>>
        reference = FirebaseFirestore.instance
            .collection('resort_partners')
            .doc(user.uid);

    try {
      await reference.set(
        <String, dynamic>{
          'partnerId': user.uid,
          'authUid': user.uid,
          'role': 'resort_partner',
          'businessName': _businessName.text.trim(),
          'ownerName': _ownerName.text.trim(),
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'address': _address.text.trim(),
          'registrationNumber':
              _registrationNumber.text.trim(),
          'panVatNumber': _panVatNumber.text.trim(),
          'photoUrl': '',
          'documentUrls': <String>[],
          'isApproved': false,
          'isActive': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // Delete only a brand-new Auth user created by this registration.
      // Never delete an existing RD account reused by another role.
      if (createdNewAuthUser) {
        try {
          await user.delete();
        } catch (_) {}
      }
      rethrow;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.hourglass_top_rounded,
            color: Colors.orange,
            size: 44,
          ),
          title: const Text(
            'Registration Submitted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Your Resort Partner account is waiting for Admin approval. '
            'After approval, sign in again to manage your resort, rooms, '
            'availability and bookings.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    await _restoreAnonymous();

    if (!mounted) {
      return;
    }

    setState(() {
      _registering = false;
      _password.clear();
    });
  }

  Future<void> _login() async {
    final UserCredential credential =
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(
      email: _email.text.trim(),
      password: _password.text,
    );

    final User? user = credential.user;
    if (user == null) {
      throw StateError('Resort Partner login failed.');
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
        await FirebaseFirestore.instance
            .collection('resort_partners')
            .doc(user.uid)
            .get();

    if (!doc.exists) {
      await _restoreAnonymous();
      _showMessage(
        'This account is not registered as a Resort Partner.',
      );
      return;
    }

    final Map<String, dynamic> data =
        doc.data() ?? <String, dynamic>{};

    final bool approved = data['isApproved'] == true;
    final bool active = data['isActive'] == true;
    final String status =
        data['status']?.toString().toLowerCase() ??
            'pending';

    if (status == 'rejected') {
      final String reason =
          data['rejectionReason']?.toString().trim() ??
              '';
      await _restoreAnonymous();
      _showMessage(
        reason.isEmpty
            ? 'This Resort Partner registration was rejected.'
            : 'Registration rejected: $reason',
      );
      return;
    }

    if (!approved) {
      await _restoreAnonymous();
      _showMessage(
        'Your Resort Partner account is waiting for Admin approval.',
      );
      return;
    }

    if (!active) {
      await _restoreAnonymous();
      _showMessage(
        'Your Resort Partner account is currently inactive. '
        'Please contact RD Admin.',
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('resort_partners')
        .doc(user.uid)
        .update(
      <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await ActiveSessionRole.setRole(
      ActiveSessionRole.resortPartner,
    );

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const ResortPartnerDashboardPage(),
      ),
    );
  }

  Future<void> _restoreAnonymous() async {
    await ActiveSessionRole.clear();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String? _required(
    String? value,
    String label,
  ) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final String password = value ?? '';
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          _registering
              ? 'Resort Partner Registration'
              : 'Resort Partner Login',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _headerCard(),
                  const SizedBox(height: 16),
                  if (_registering) ...<Widget>[
                    _field(
                      controller: _businessName,
                      label: 'Resort / Business Name',
                      icon: Icons.holiday_village_rounded,
                      validator: (String? value) =>
                          _required(
                        value,
                        'Resort / Business Name',
                      ),
                    ),
                    _gap(),
                    _field(
                      controller: _ownerName,
                      label: 'Owner Full Name',
                      icon: Icons.person_rounded,
                      validator: (String? value) =>
                          _required(
                        value,
                        'Owner Full Name',
                      ),
                    ),
                    _gap(),
                    _field(
                      controller: _phone,
                      label: 'Phone Number',
                      icon: Icons.phone_rounded,
                      keyboardType:
                          TextInputType.phone,
                      validator: (String? value) {
                        final String phone =
                            (value ?? '').trim();
                        if (phone.length < 7) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    _gap(),
                    _field(
                      controller: _address,
                      label: 'Business Address',
                      icon:
                          Icons.location_on_rounded,
                      validator: (String? value) =>
                          _required(
                        value,
                        'Business Address',
                      ),
                    ),
                    _gap(),
                    _field(
                      controller:
                          _registrationNumber,
                      label:
                          'Registration Number (optional)',
                      icon:
                          Icons.badge_outlined,
                    ),
                    _gap(),
                    _field(
                      controller: _panVatNumber,
                      label: 'PAN / VAT (optional)',
                      icon:
                          Icons.receipt_long_rounded,
                    ),
                    _gap(),
                  ],
                  _field(
                    controller: _email,
                    label: 'Email',
                    icon: Icons.email_rounded,
                    keyboardType:
                        TextInputType.emailAddress,
                    validator: _emailValidator,
                  ),
                  _gap(),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    validator: _passwordValidator,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(
                        Icons.lock_rounded,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword =
                                !_hidePassword;
                          });
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons
                                  .visibility_rounded
                              : Icons
                                  .visibility_off_rounded,
                        ),
                      ),
                      border:
                          const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _registering
                                  ? Icons
                                      .how_to_reg_rounded
                                  : Icons
                                      .login_rounded,
                            ),
                      label: Text(
                        _registering
                            ? 'Submit Registration'
                            : 'Login',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _registering =
                                  !_registering;
                            });
                          },
                    child: Text(
                      _registering
                          ? 'Already registered? Login'
                          : 'New Resort Partner? Register',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1565C0),
            _rdGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.business_center_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'RD Resort Partner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _registering
                      ? 'Register your resort business. Admin approval is required before management access.'
                      : 'Login to manage your approved resort business.',
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization:
          keyboardType == TextInputType.emailAddress
              ? TextCapitalization.none
              : TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _gap() =>
      const SizedBox(height: 11);
}
