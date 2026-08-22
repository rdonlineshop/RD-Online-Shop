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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
    if (!mounted) {
      return;
    }

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

  Future<void> _restoreGuestSession() async {
    final FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    await auth.signInAnonymously();
    await reloadOrdersForCurrentCustomer();
  }

  Future<void> _submit() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final FirebaseAuth auth = FirebaseAuth.instance;
    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;

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
          credential = await currentUser!.linkWithCredential(
            emailCredential,
          );
        } else {
          if (currentUser != null) {
            await auth.signOut();
          }

          credential = await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }

        final User user = credential.user!;
        final String now = DateTime.now().toIso8601String();

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .set(
          <String, dynamic>{
            'customerId': user.uid,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': email,
            'address': '',
            'role': 'customer',
            'isActive': true,
            'createdAt': now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      } else {
        if (auth.currentUser != null) {
          await auth.signOut();
        }

        credential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final User user = credential.user!;
        final DocumentSnapshot<Map<String, dynamic>> customerDocument =
            await FirebaseFirestore.instance
                .collection('customers')
                .doc(user.uid)
                .get();

        final Map<String, dynamic> customer =
            customerDocument.data() ?? <String, dynamic>{};

        if (!customerDocument.exists ||
            customer['role'] != 'customer' ||
            customer['isActive'] == false) {
          await _restoreGuestSession();
          _showMessage('This account is not registered as a customer.');
          return;
        }

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .update(<String, dynamic>{
          'lastLoginAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      await reloadOrdersForCurrentCustomer();

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      _showMessage(_authMessage(error));
    } catch (error) {
      _showMessage('Could not open customer account: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final String email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage('Enter your customer email first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_authMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistering ? 'Customer Register' : 'Customer Login'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  const Icon(
                    Icons.person_pin_circle,
                    size: 90,
                    color: Colors.deepPurple,
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
                  const SizedBox(height: 24),
                  if (_isRegistering) ...<Widget>[
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your full name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your phone number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Customer Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? value) {
                      final String email = value?.trim() ?? '';
                      if (email.isEmpty || !email.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
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
                      if (value == null || value.length < 6) {
                        return 'Password must contain at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  if (!_isRegistering)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _isRegistering
                                  ? Icons.person_add
                                  : Icons.login,
                            ),
                      label: Text(
                        _isRegistering ? 'Create Account' : 'Customer Login',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isRegistering = !_isRegistering;
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
