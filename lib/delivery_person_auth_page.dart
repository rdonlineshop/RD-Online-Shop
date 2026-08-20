import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'delivery_person_dashboard_page.dart';

class DeliveryPersonAuthPage extends StatefulWidget {
  const DeliveryPersonAuthPage({super.key});

  @override
  State<DeliveryPersonAuthPage> createState() =>
      _DeliveryPersonAuthPageState();
}

class _DeliveryPersonAuthPageState
    extends State<DeliveryPersonAuthPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

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
  bool _obscurePassword = true;

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
  // REGISTER
  // =========================================================

  Future<void> _register() async {
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

    final String name =
        _nameController.text.trim();

    final String phone =
        _phoneController.text.trim();

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

          // Later Admin can control these.
          'isActive': true,
          'isApproved': false,

          'isOnline': true,
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

      await _restoreCustomerSession();

      if (!mounted) {
        return;
      }

      _showMessage(
        'Account created. Please wait for Admin approval before login.',
      );
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

      final DocumentSnapshot<
              Map<String, dynamic>>
          doc =
          await FirebaseFirestore.instance
              .collection('delivery_persons')
              .doc(user.uid)
              .get();

      // Delivery person collection मा account नभए
      // Seller/Customer account बाट Delivery Dashboard
      // खोल्न दिँदैन.
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
          doc.data() ??
              <String, dynamic>{};

      final String role =
          data['role']?.toString().trim() ??
              '';

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

      final bool isActive =
          data['isActive'] != false;

      if (!isActive) {
        await _restoreCustomerSession();

        if (!mounted) {
          return;
        }

        _showMessage(
          'This delivery person account is inactive.',
        );
        return;
      }

      final bool isApproved =
          data['isApproved'] == true;

      if (!isApproved) {
        await _restoreCustomerSession();

        if (!mounted) {
          return;
        }

        _showMessage(
          'Your delivery person account is waiting for Admin approval.',
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
          'isOnline': true,
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
        'Delivery person login successful.',
      );

      // LOGIN SUCCESS -> DELIVERY DASHBOARD
      await _openDashboard();
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

      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 520,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 44,
                    child: Icon(
                      Icons.local_shipping,
                      size: 48,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Text(
                    _isRegistering
                        ? 'Create Delivery Person Account'
                        : 'Delivery Person Login',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    _isRegistering
                        ? 'Register to receive RD Online Shop delivery orders.'
                        : 'Login to see your assigned orders and share live location.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
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
                    height: 54,
                    child:
                        FilledButton.icon(
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
                        _isLoading
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
        ),
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
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }
}
