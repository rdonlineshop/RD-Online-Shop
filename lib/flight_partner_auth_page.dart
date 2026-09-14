import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FlightPartnerAuthPage extends StatefulWidget {
  const FlightPartnerAuthPage({super.key});

  @override
  State<FlightPartnerAuthPage> createState() =>
      _FlightPartnerAuthPageState();
}

class _FlightPartnerAuthPageState
    extends State<FlightPartnerAuthPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return error.message ?? 'Login failed.';
    }
  }

  Future<void> _login() async {
    if (_loading ||
        !(_formKey.currentState?.validate() ??
            false)) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email: _emailController.text
            .trim()
            .toLowerCase(),
        password: _passwordController.text,
      );

      if (credential.user == null) {
        throw StateError(
          'Flight Partner login failed.',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              const FlightPartnerDashboardPage(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_authMessage(error)),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Flight Partner login failed.\n$error',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Flight Partner Login',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 560,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.all(16),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(18),
                      child: Column(
                        children: <Widget>[
                          const CircleAvatar(
                            radius: 30,
                            child: Icon(
                              Icons.person_outline,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'RD Flight Partner',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Temporary universal runtime testing login. '
                            'Use the same existing RD test email and password.',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color:
                                  Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller:
                        _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    textCapitalization:
                        TextCapitalization.none,
                    autofillHints:
                        const <String>[
                      AutofillHints.email,
                    ],
                    decoration:
                        const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                      border:
                          OutlineInputBorder(),
                    ),
                    validator:
                        (String? value) {
                      final String email =
                          (value ?? '')
                              .trim();

                      if (email.isEmpty) {
                        return 'Email is required';
                      }

                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Enter a valid email';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller:
                        _passwordController,
                    obscureText: _hidePassword,
                    autofillHints:
                        const <String>[
                      AutofillHints.password,
                    ],
                    onFieldSubmitted: (_) {
                      _login();
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Show Password'
                            : 'Hide Password',
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
                    validator:
                        (String? value) {
                      if ((value ?? '').isEmpty) {
                        return 'Password is required';
                      }

                      if ((value ?? '').length <
                          6) {
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
                          _loading ? null : _login,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.login_rounded,
                            ),
                      label: const Text(
                        'Login',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
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

class FlightPartnerDashboardPage
    extends StatelessWidget {
  const FlightPartnerDashboardPage({
    super.key,
  });

  Future<void> _logout(
    BuildContext context,
  ) async {
    await FirebaseAuth.instance.signOut();

    try {
      await FirebaseAuth.instance
          .signInAnonymously();
    } catch (_) {
      // Customer/guest session can be restored by the main app flow.
    }

    if (!context.mounted) {
      return;
    }

    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const FlightPartnerAuthPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return const FlightPartnerAuthPage();
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Flight Partner Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Logout',
            onPressed: () =>
                _logout(context),
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 760,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 32,
                          child: Icon(
                            Icons.person_outline,
                            size: 36,
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        const Text(
                          'Flight Partner Test Dashboard',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        SelectableText(
                          user.email ??
                              'Signed-in RD test account',
                          textAlign:
                              TextAlign.center,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        const Text(
                          'Universal login runtime test is active. '
                          'Flight provider ownership, booking assignment and production permissions '
                          'should be connected in a later dedicated Flight Partner module.',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            height: 1.4,
                          ),
                        ),
                      ],
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
