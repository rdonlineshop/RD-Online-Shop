import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard_page.dart';
import 'services/active_session_role.dart';

class AdminAuthPage extends StatefulWidget {
  const AdminAuthPage({super.key});

  @override
  State<AdminAuthPage> createState() =>
      _AdminAuthPageState();
}

class _AdminAuthPageState extends State<AdminAuthPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _checkingSavedSession = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSavedAdminSession();
    });
  }

  void _finishSavedSessionCheck() {
    if (!mounted) {
      return;
    }

    setState(() {
      _checkingSavedSession = false;
    });
  }

  Future<void> _restoreSavedAdminSession() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      await ActiveSessionRole.clear();
      _finishSavedSessionCheck();
      return;
    }

    final String? activeRole =
        await ActiveSessionRole.getRole();

    if (activeRole != null &&
        activeRole != ActiveSessionRole.admin) {
      _finishSavedSessionCheck();
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> adminDocument =
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get();

      if (!adminDocument.exists) {
        // Another RD role may currently be signed in. Do not sign it out just
        // because the Admin entry page was opened.
        _finishSavedSessionCheck();
        return;
      }

      final Map<String, dynamic> admin =
          adminDocument.data() ?? <String, dynamic>{};

      final String role =
          admin['role']?.toString().trim() ?? '';

      final bool allowedRole =
          role == 'admin' || role == 'superAdmin';

      final bool isActive =
          admin['isActive'] == true;

      if (!allowedRole || !isActive) {
        _finishSavedSessionCheck();
        return;
      }

      await ActiveSessionRole.setRole(
        ActiveSessionRole.admin,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const AdminDashboardPage(),
        ),
      );
    } catch (_) {
      _finishSavedSessionCheck();
    }
  }

  Future<void> _restoreCustomerSession() async {
    await ActiveSessionRole.clear();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
  }

  Future<void> _login() async {
    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'admin-login-failed',
          message: 'Admin login failed.',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> adminDocument =
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> admin =
          adminDocument.data() ?? <String, dynamic>{};

      final String role =
          admin['role']?.toString().trim() ?? '';

      final bool allowedRole =
          role == 'admin' || role == 'superAdmin';

      if (!adminDocument.exists ||
          admin['isActive'] != true ||
          !allowedRole) {
        await _restoreCustomerSession();
        throw FirebaseAuthException(
          code: 'not-admin',
          message: 'This account does not have active Admin access.',
        );
      }

      await ActiveSessionRole.setRole(
        ActiveSessionRole.admin,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const AdminDashboardPage(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message = error.message ?? 'Admin login failed.';

      if (error.code == 'invalid-credential' ||
          error.code == 'wrong-password' ||
          error.code == 'user-not-found') {
        message = 'Incorrect Admin email or password.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin login failed: $error'),
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

  @override
  Widget build(BuildContext context) {
    if (_checkingSavedSession) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Checking saved Admin account...',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
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
              isDesktop ? 52 : 24,
              horizontalPadding,
              32,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.admin_panel_settings,
                      size: isDesktop ? 104 : 82,
                      color: Colors.blue,
                    ),
                    SizedBox(height: isDesktop ? 22 : 18),
                    Text(
                      'NRD Online Shop Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 32 : 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to open the NRD Admin Dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 34 : 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Admin Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: isDesktop ? 22 : 16,
                        ),
                      ),
                      validator: (String? value) {
                        final String email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Enter a valid Admin email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: isDesktop ? 22 : 16,
                        ),
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
                        if ((value ?? '').length < 6) {
                          return 'Password must contain at least 6 characters.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        _login();
                      },
                    ),
                    SizedBox(height: isDesktop ? 28 : 22),
                    SizedBox(
                      width: double.infinity,
                      height: isDesktop ? 60 : 52,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _login,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _isLoading ? 'Checking Admin...' : 'Admin Login',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
