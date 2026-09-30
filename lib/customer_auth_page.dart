import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'order_data.dart';

class CustomerAuthPage extends StatefulWidget {
  const CustomerAuthPage({super.key});

  @override
  State<CustomerAuthPage> createState() => _CustomerAuthPageState();
}

class _CustomerAuthPageState extends State<CustomerAuthPage> {
  static const Color _nrdRed = Color(0xFFE50914);

  bool _checkingSavedSession = true;
  bool _isSigningIn = false;
  bool _googleInitialized = false;

  bool get _supportsNativeGoogleSignIn {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSavedCustomerSession();
    });
  }

  Future<Map<String, dynamic>?> _customerDocument(User user) async {
    if (user.isAnonymous) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .get();

      if (!snapshot.exists) {
        return null;
      }

      final Map<String, dynamic> data =
          snapshot.data() ?? <String, dynamic>{};

      if (data['role']?.toString().trim() != 'customer' ||
          data['isActive'] == false) {
        return null;
      }

      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreSavedCustomerSession() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      _finishSavedSessionCheck();
      return;
    }

    final Map<String, dynamic>? customer = await _customerDocument(user);

    if (customer == null) {
      _finishSavedSessionCheck();
      return;
    }

    try {
      await activateRegisteredCustomerSession(user);

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .set(
        <String, dynamic>{
          'authUid': user.uid,
          'email': user.email?.trim().toLowerCase() ?? '',
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (_) {
      _finishSavedSessionCheck();
    }
  }

  void _finishSavedSessionCheck() {
    if (!mounted) {
      return;
    }

    setState(() {
      _checkingSavedSession = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }

    if (!_supportsNativeGoogleSignIn) {
      throw UnsupportedError(
        'Google account sign-in is currently available in the Android/iOS app.',
      );
    }

    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  Future<UserCredential> _firebaseGoogleSignIn(
    AuthCredential credential,
    User? previousFirebaseUser,
  ) async {
    // Preserve an anonymous customer UID when possible. This keeps orders that
    // were created before the customer connected a Google account attached to
    // the same Firebase identity.
    if (previousFirebaseUser?.isAnonymous == true) {
      try {
        return await previousFirebaseUser!.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        // The selected Google account may already belong to an existing
        // Firebase customer. Sign in to that existing account instead.
        if (error.code != 'credential-already-in-use' &&
            error.code != 'email-already-in-use' &&
            error.code != 'provider-already-linked') {
          rethrow;
        }
      }
    }

    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> _ensureCustomerProfile({
    required User user,
    required GoogleSignInAccount googleAccount,
    required String previousCustomerId,
  }) async {
    final DocumentReference<Map<String, dynamic>> customerRef =
        FirebaseFirestore.instance.collection('customers').doc(user.uid);

    final DocumentSnapshot<Map<String, dynamic>> existing =
        await customerRef.get();

    final Map<String, dynamic> existingData =
        existing.data() ?? <String, dynamic>{};

    String customerId =
        existingData['customerId']?.toString().trim() ?? '';

    // Keep the existing hidden compatibility ID when present. If this account
    // is being connected from an older guest session, preserve that ID so the
    // current device can keep its historical My Orders link.
    if (customerId.isEmpty) {
      customerId = previousCustomerId.trim().isNotEmpty
          ? previousCustomerId.trim()
          : user.uid;
    }

    final String email =
        (user.email ?? googleAccount.email).trim().toLowerCase();

    final String displayName =
        (user.displayName ?? googleAccount.displayName ?? '').trim();

    final Map<String, dynamic> data = <String, dynamic>{
      'authUid': user.uid,
      'customerId': customerId,
      'email': email,
      'name': displayName,
      'photoUrl': user.photoURL ?? googleAccount.photoUrl ?? '',
      'role': 'customer',
      'isActive': true,
      'accountType': 'google',
      'authProvider': 'google.com',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await customerRef.set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> _continueWithGoogle() async {
    if (_isSigningIn) {
      return;
    }

    if (!_supportsNativeGoogleSignIn) {
      _showMessage(
        'Google account sign-in is tested from the Android mobile app. Please run NRD on your phone for this login.',
      );
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? beforeLogin = auth.currentUser;
    final String previousCustomerId =
        (await getSavedCustomerId())?.trim() ?? '';

    try {
      await _initializeGoogleSignIn();

      // If Admin, Seller or Delivery is currently authenticated, do not link
      // the Google customer credential to that role account by accident.
      if (beforeLogin != null && !beforeLogin.isAnonymous) {
        final Map<String, dynamic>? customer =
            await _customerDocument(beforeLogin);

        if (customer == null) {
          await auth.signOut();
        }
      }

      // google_sign_in 7.x recommends signing out before requesting another
      // interactive account so the account chooser behaves consistently.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Continue to the interactive chooser.
      }

      final GoogleSignInAccount googleAccount =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleAccount.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.trim().isEmpty) {
        throw StateError(
          'Google did not return an ID token. Check Firebase Google Sign-In configuration.',
        );
      }

      final OAuthCredential credential =
          GoogleAuthProvider.credential(idToken: idToken);

      final User? linkCandidate =
          beforeLogin?.isAnonymous == true ? beforeLogin : null;

      final UserCredential result =
          await _firebaseGoogleSignIn(credential, linkCandidate);

      final User? user = result.user;

      if (user == null) {
        throw StateError('Google customer login did not return a Firebase user.');
      }

      await _ensureCustomerProfile(
        user: user,
        googleAccount: googleAccount,
        previousCustomerId: previousCustomerId,
      );

      await activateRegisteredCustomerSession(user);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        _showMessage('Google account selection was cancelled.');
      } else if (error.code ==
          GoogleSignInExceptionCode.clientConfigurationError) {
        _showMessage(
          'Google Sign-In configuration is incomplete. Check Android SHA-1/SHA-256 and Firebase Google provider settings.',
        );
      } else {
        _showMessage(
          error.description?.trim().isNotEmpty == true
              ? error.description!.trim()
              : 'Could not sign in with Google.',
        );
      }
    } on FirebaseAuthException catch (error) {
      String message = error.message ?? error.code;

      if (error.code == 'operation-not-allowed') {
        message =
            'Google Sign-In is not enabled in Firebase Authentication.';
      } else if (error.code == 'account-exists-with-different-credential') {
        message =
            'This email already has a customer account. Enable Google for the same Firebase account, then try again.';
      }

      _showMessage(message);
    } catch (error) {
      final String message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '')
          .replaceFirst('Unsupported operation: ', '');

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _checkingSavedSession = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSavedSession) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NRD Customer'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Checking your saved customer account...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NRD Customer',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: <Widget>[
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: _nrdRed,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 62,
                    color: _nrdRed,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Continue with your Google account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'No Customer ID to remember. No Gmail address or Gmail password needs to be typed inside NRD.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _isSigningIn
                        ? null
                        : _continueWithGoogle,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                      elevation: 1,
                    ),
                    child: _isSigningIn
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.white,
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _nrdRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _nrdRed.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.security_rounded,
                        color: _nrdRed,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your Google password is handled by Google. NRD only receives the authenticated Firebase customer account used for My Orders, Krishi orders and tracking.',
                          style: TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_supportsNativeGoogleSignIn) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    'Google account sign-in should be tested on the Android mobile app. The official Google Sign-In Flutter plugin does not provide the same native chooser on Windows.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
