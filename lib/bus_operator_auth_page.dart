import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bus_operator_dashboard_page.dart';

class BusOperatorAuthPage extends StatefulWidget {
  const BusOperatorAuthPage({super.key});

  @override
  State<BusOperatorAuthPage> createState() =>
      _BusOperatorAuthPageState();
}

class _BusOperatorAuthPageState
    extends State<BusOperatorAuthPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _companyController =
      TextEditingController();
  final TextEditingController _ownerController =
      TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController();
  final TextEditingController _addressController =
      TextEditingController();
  final TextEditingController _registrationController =
      TextEditingController();
  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _registering = false;
  bool _loading = false;
  bool _checkingSession = true;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _restoreBusOperatorSession();
  }

  Future<void> _restoreBusOperatorSession() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _checkingSession = false;
        });
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          operatorDocument =
          await FirebaseFirestore.instance
              .collection('bus_operators')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> operator =
          operatorDocument.data() ??
              <String, dynamic>{};

      if (!mounted) {
        return;
      }

      if (operatorDocument.exists &&
          operator['role']?.toString() ==
              'busOperator') {
        Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                const BusOperatorDashboardPage(),
          ),
        );
        return;
      }

      setState(() {
        _checkingSession = false;
      });
    } on FirebaseException {
      if (mounted) {
        setState(() {
          _checkingSession = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _registrationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must contain at least 6 characters.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-not-found':
        return 'Bus Operator account was not found.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  String? _requiredText(
    String? value,
    String label,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_loading ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final FirebaseAuth auth = FirebaseAuth.instance;
    final String email =
        _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;

    try {
      if (auth.currentUser != null) {
        await auth.signOut();
      }

      UserCredential credential;

      if (_registering) {
        try {
          credential =
              await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (error) {
          if (error.code != 'email-already-in-use') {
            rethrow;
          }

          // The same Firebase account may already be used by
          // Customer/Seller/Admin. Sign in to that account and
          // add only the Bus Operator profile for the same UID.
          credential =
              await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }

        final User user = credential.user!;

        final DocumentReference<Map<String, dynamic>>
            operatorRef = FirebaseFirestore.instance
                .collection('bus_operators')
                .doc(user.uid);

        final DocumentSnapshot<Map<String, dynamic>>
            existingOperator = await operatorRef.get();

        if (existingOperator.exists) {
          if (!mounted) {
            return;
          }

          _show(
            'This Firebase account is already registered as a Bus Operator. Please use Login.',
          );
          return;
        }

        await operatorRef.set(
          <String, dynamic>{
            'authUid': user.uid,
            'operatorId': user.uid,
            'role': 'busOperator',
            'companyName':
                _companyController.text.trim(),
            'ownerName':
                _ownerController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'registrationNumber':
                _registrationController.text.trim(),
            'email': email,
            'isApproved': false,
            'isActive': false,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          },
        );
      } else {
        credential =
            await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final User user = credential.user!;

        final DocumentSnapshot<Map<String, dynamic>>
            operatorDocument =
            await FirebaseFirestore.instance
                .collection('bus_operators')
                .doc(user.uid)
                .get();

        final Map<String, dynamic> operator =
            operatorDocument.data() ??
                <String, dynamic>{};

        if (!operatorDocument.exists ||
            operator['role']?.toString() !=
                'busOperator') {
          await auth.signOut();
          await auth.signInAnonymously();

          if (!mounted) {
            return;
          }

          _show(
            'This account is not registered as a Bus Operator.',
          );
          return;
        }

        await operatorDocument.reference.set(
          <String, dynamic>{
            'lastLoginAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              const BusOperatorDashboardPage(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      _show(_authMessage(error));
    } on FirebaseException catch (error) {
      _show(
        'Could not open Bus Operator account: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      _show(
        'Could not open Bus Operator account: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final String email =
        _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _show('Enter your Bus Operator email first.');
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);

      _show(
        'Password reset email sent to $email.',
      );
    } on FirebaseAuthException catch (error) {
      _show(_authMessage(error));
    }
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FA),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Operator',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: <Widget>[
                const Icon(
                  Icons.directions_bus_filled_rounded,
                  size: 68,
                ),
                const SizedBox(height: 10),
                Text(
                  _registering
                      ? 'Register Bus Operator'
                      : 'Bus Operator Login',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _registering
                      ? 'Registration requires Admin approval before schedules and bookings can be managed.'
                      : 'Each operator sees only their own schedules and bookings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          if (_registering) ...<Widget>[
                            TextFormField(
                              controller: _companyController,
                              textInputAction:
                                  TextInputAction.next,
                              validator: (String? value) =>
                                  _requiredText(
                                value,
                                'Company / Bus Service name',
                              ),
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Company / Bus Service Name',
                                prefixIcon:
                                    Icon(Icons.business_rounded),
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ownerController,
                              textInputAction:
                                  TextInputAction.next,
                              validator: (String? value) =>
                                  _requiredText(
                                value,
                                'Owner name',
                              ),
                              decoration:
                                  const InputDecoration(
                                labelText: 'Owner Name',
                                prefixIcon:
                                    Icon(Icons.person_rounded),
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType:
                                  TextInputType.phone,
                              textInputAction:
                                  TextInputAction.next,
                              validator: (String? value) {
                                final String phone =
                                    value?.trim() ?? '';
                                if (phone.length < 7 ||
                                    phone.length > 30) {
                                  return 'Enter a valid phone number.';
                                }
                                return null;
                              },
                              decoration:
                                  const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon:
                                    Icon(Icons.phone_rounded),
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              textInputAction:
                                  TextInputAction.next,
                              validator: (String? value) =>
                                  _requiredText(
                                value,
                                'Address',
                              ),
                              decoration:
                                  const InputDecoration(
                                labelText: 'Office Address',
                                prefixIcon:
                                    Icon(Icons.location_on_outlined),
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller:
                                  _registrationController,
                              textInputAction:
                                  TextInputAction.next,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Registration / PAN Number (optional)',
                                prefixIcon:
                                    Icon(Icons.badge_outlined),
                                border:
                                    OutlineInputBorder(),
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
                            validator: (String? value) {
                              final String email =
                                  value?.trim() ?? '';
                              if (!email.contains('@') ||
                                  !email.contains('.')) {
                                return 'Enter a valid email.';
                              }
                              return null;
                            },
                            decoration:
                                const InputDecoration(
                              labelText: 'Email',
                              prefixIcon:
                                  Icon(Icons.email_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            validator: (String? value) {
                              if ((value ?? '').length < 6) {
                                return 'Password must contain at least 6 characters.';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_rounded),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _hidePassword =
                                        !_hidePassword;
                                  });
                                },
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons
                                          .visibility_off_outlined,
                                ),
                              ),
                              border:
                                  const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            width: double.infinity,
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
                                              .app_registration_rounded
                                          : Icons.login_rounded,
                                    ),
                              label: Text(
                                _registering
                                    ? 'Register'
                                    : 'Login',
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (!_registering)
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : _resetPassword,
                              child: const Text(
                                'Forgot Password?',
                              ),
                            ),
                        ],
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
                        : 'New Bus Operator? Register',
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
    );
  }
}
