import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'order_data.dart';

class CustomerAuthPage extends StatefulWidget {
  const CustomerAuthPage({super.key});

  @override
  State<CustomerAuthPage> createState() =>
      _CustomerAuthPageState();
}

class _CustomerAuthPageState extends State<CustomerAuthPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController();
  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must contain at least 6 characters.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-not-found':
        return 'Customer account was not found.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  Future<void> _restoreGuestSession(
    String previousCustomerId,
  ) async {
    try {
      await switchToGuestCustomerSession(
        preferredCustomerId:
            previousCustomerId.trim().isEmpty
                ? null
                : previousCustomerId,
      );
    } catch (_) {
      // Login/Register error message is more useful to the customer.
    }
  }

  Future<void> _submit() async {
    if (_isLoading ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final FirebaseAuth auth = FirebaseAuth.instance;
    final String email =
        _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;

    // Keep the current guest RD customer identity before changing Firebase
    // authentication. Registration will attach this permanent ID to the
    // new email/password account so existing My Orders stay linked.
    final String previousCustomerId =
        (await getSavedCustomerId())?.trim() ?? '';

    try {
      UserCredential credential;

      if (_isRegistering) {
        final AuthCredential emailCredential =
            EmailAuthProvider.credential(
          email: email,
          password: password,
        );

        final User? currentUser = auth.currentUser;

        if (currentUser?.isAnonymous == true) {
          // Best path: upgrade the anonymous guest account in-place.
          // Firebase UID stays the same.
          credential =
              await currentUser!.linkWithCredential(
            emailCredential,
          );
        } else {
          // Explicit customer registration action. If another role is logged
          // in, sign it out before creating the customer account.
          if (currentUser != null) {
            await auth.signOut();
          }

          credential =
              await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }

        final User user = credential.user!;

        final String permanentCustomerId =
            previousCustomerId.isNotEmpty
                ? previousCustomerId
                : user.uid;

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .set(
          <String, dynamic>{
            'authUid': user.uid,
            'customerId': permanentCustomerId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': email,
            'address': '',
            'role': 'customer',
            'isActive': true,
            'accountType': 'registered',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        await activateRegisteredCustomerSession(user);
      } else {
        // Customer login is an explicit role switch.
        if (auth.currentUser != null) {
          await auth.signOut();
        }

        credential =
            await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final User user = credential.user!;

        final DocumentSnapshot<Map<String, dynamic>>
            customerDocument =
            await FirebaseFirestore.instance
                .collection('customers')
                .doc(user.uid)
                .get();

        final Map<String, dynamic> customer =
            customerDocument.data() ??
                <String, dynamic>{};

        if (!customerDocument.exists ||
            customer['role']?.toString().trim() !=
                'customer' ||
            customer['isActive'] == false) {
          await _restoreGuestSession(
            previousCustomerId,
          );

          _showMessage(
            'This account is not registered as an active customer.',
          );
          return;
        }

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .set(
          <String, dynamic>{
            'authUid': user.uid,
            'email': email,
            'lastLoginAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        await activateRegisteredCustomerSession(user);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      // If login/create signed out the previous session before failing,
      // restore the customer's guest identity so My Orders do not disappear.
      if (FirebaseAuth.instance.currentUser == null) {
        await _restoreGuestSession(
          previousCustomerId,
        );
      }

      _showMessage(_authMessage(error));
    } catch (error) {
      if (FirebaseAuth.instance.currentUser == null) {
        await _restoreGuestSession(
          previousCustomerId,
        );
      }

      _showMessage(
        'Could not open customer account: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final String email =
        _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage(
        'Enter your customer email first.',
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: email,
      );

      _showMessage(
        'Password reset email sent.',
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_authMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color rdRed = Color(0xFFE50914);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRegistering
              ? 'Customer Register'
              : 'Customer Login',
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(
                        color: rdRed,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 58,
                      color: rdRed,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isRegistering
                        ? 'Create your RD customer account'
                        : 'Login to keep your orders safe',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _isRegistering
                        ? 'Your current RD orders will stay linked to this account.'
                        : 'Use the same account on another device to access your saved orders.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isRegistering) ...<Widget>[
                    TextFormField(
                      controller: _nameController,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon:
                            Icon(Icons.person),
                        border:
                            OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter your full name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
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
                        final String phone =
                            value?.trim() ?? '';

                        if (phone.isEmpty) {
                          return 'Enter your phone number.';
                        }

                        if (normalizeOrderRecoveryPhone(
                              phone,
                            ).length <
                            6) {
                          return 'Enter a valid phone number.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    textInputAction:
                        TextInputAction.next,
                    autocorrect: false,
                    decoration:
                        const InputDecoration(
                      labelText: 'Customer Email',
                      prefixIcon:
                          Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? value) {
                      final String email =
                          value?.trim() ?? '';

                      if (email.isEmpty ||
                          !email.contains('@') ||
                          !email.contains('.')) {
                        return 'Enter a valid email address.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    onFieldSubmitted: (_) =>
                        _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(Icons.lock),
                      border:
                          const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword =
                                !_hidePassword;
                          });
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null ||
                          value.length < 6) {
                        return 'Password must contain at least 6 characters.';
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
                            : _resetPassword,
                        child: const Text(
                          'Forgot Password?',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: rdRed,
                        foregroundColor:
                            Colors.white,
                      ),
                      onPressed:
                          _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isRegistering
                                  ? Icons.person_add
                                  : Icons.login,
                            ),
                      label: Text(
                        _isRegistering
                            ? 'Create Account'
                            : 'Customer Login',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isRegistering =
                                  !_isRegistering;
                            });
                          },
                    child: Text(
                      _isRegistering
                          ? 'Already have an account? Login'
                          : 'New customer? Create Account',
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
}
