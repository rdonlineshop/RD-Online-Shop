import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'property_partner_dashboard_page.dart';
import 'services/active_session_role.dart';

class PropertyPartnerAuthPage extends StatefulWidget {
  const PropertyPartnerAuthPage({super.key});

  @override
  State<PropertyPartnerAuthPage> createState() =>
      _PropertyPartnerAuthPageState();
}

class _PropertyPartnerAuthPageState
    extends State<PropertyPartnerAuthPage> {
  static const Color _propertyBrown = Color(0xFF795548);

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
      _restoreSavedPartnerSession();
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
      _propertyPartnerDocument(User user) async {
    if (user.isAnonymous) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('property_partners')
              .doc(user.uid)
              .get();

      if (!snapshot.exists) {
        return null;
      }

      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreSavedPartnerSession() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      _finishSavedSessionCheck();
      return;
    }

    final String? activeRole =
        await ActiveSessionRole.getRole();

    if (activeRole != null &&
        activeRole != ActiveSessionRole.propertyPartner) {
      _finishSavedSessionCheck();
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>>? partnerDoc =
        await _propertyPartnerDocument(user);

    if (partnerDoc == null) {
      _finishSavedSessionCheck();
      return;
    }

    await ActiveSessionRole.setRole(
      ActiveSessionRole.propertyPartner,
    );

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const PropertyPartnerDashboardPage(),
      ),
    );
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

  String _partnerIdForUid(String uid) {
    final String suffix =
        uid.length <= 12 ? uid : uid.substring(0, 12);

    return 'NRD-PROP-$suffix';
  }

  Future<void> _ensurePropertyPartnerAccount({
    required User user,
    required GoogleSignInAccount googleAccount,
  }) async {
    final DocumentReference<Map<String, dynamic>> partnerRef =
        FirebaseFirestore.instance
            .collection('property_partners')
            .doc(user.uid);

    final DocumentSnapshot<Map<String, dynamic>> existing =
        await partnerRef.get();

    if (existing.exists) {
      final Map<String, dynamic> existingData =
          existing.data() ?? <String, dynamic>{};

      final Map<String, dynamic> update =
          <String, dynamic>{
        'email':
            (user.email ?? googleAccount.email)
                .trim()
                .toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final String existingPhoto =
          existingData['photoUrl']?.toString().trim() ?? '';

      if (existingPhoto.isEmpty) {
        update['photoUrl'] =
            user.photoURL ?? googleAccount.photoUrl ?? '';
      }

      await partnerRef.set(
        update,
        SetOptions(merge: true),
      );
      return;
    }

    final String email =
        (user.email ?? googleAccount.email)
            .trim()
            .toLowerCase();

    final String displayName =
        (user.displayName ??
                googleAccount.displayName ??
                '')
            .trim();

    await partnerRef.set(
      <String, dynamic>{
        'authUid': user.uid,
        'partnerId': _partnerIdForUid(user.uid),
        'fullName': displayName,
        'email': email,
        'phone': '',
        'photoUrl':
            user.photoURL ?? googleAccount.photoUrl ?? '',
        'partnerType': '',
        'officeName': '',
        'address': '',
        'district': '',
        'municipality': '',
        'ward': '',
        'registrationNumber': '',
        'panVatNumber': '',
        'isApproved': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _continueWithGoogle() async {
    if (_isSigningIn) {
      return;
    }

    if (!_supportsNativeGoogleSignIn) {
      _showMessage(
        'Property Partner Google Sign-In should be tested on the Android mobile app.',
      );
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    final FirebaseAuth auth = FirebaseAuth.instance;

    try {
      await _initializeGoogleSignIn();

      // Never link the Property Partner credential into an anonymous
      // customer/guest Firebase account. Property Partner gets its own
      // authenticated Google session.
      if (auth.currentUser != null) {
        await auth.signOut();
      }

      await ActiveSessionRole.clear();

      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Continue to the interactive Google account chooser.
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

      final UserCredential result =
          await auth.signInWithCredential(credential);

      final User? user = result.user;

      if (user == null) {
        throw StateError(
          'Property Partner Google login did not return a Firebase user.',
        );
      }

      await _ensurePropertyPartnerAccount(
        user: user,
        googleAccount: googleAccount,
      );

      await ActiveSessionRole.setRole(
        ActiveSessionRole.propertyPartner,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const PropertyPartnerDashboardPage(),
        ),
      );
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
      } else if (error.code ==
          'account-exists-with-different-credential') {
        message =
            'This email already uses another Firebase sign-in method. Use the matching account method first.';
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
          title: const Text('NRD Property Partner'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Checking your saved Property Partner account...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'NRD Property Partner',
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
                    color: Colors.white,
                    border: Border.all(
                      color: _propertyBrown,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.real_estate_agent_rounded,
                    size: 62,
                    color: _propertyBrown,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Continue as Property Partner',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Use your Google account for secure login. After login, complete My Profile with your official owner, agent or office details and documents.',
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
                    onPressed:
                        _isSigningIn ? null : _continueWithGoogle,
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
                            mainAxisAlignment:
                                MainAxisAlignment.center,
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
                    color: _propertyBrown.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          _propertyBrown.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.security_rounded,
                        color: _propertyBrown,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Google verifies the login account. NRD Property Partner verification is separate: official profile, office details and documents will be reviewed before publishing privileges are approved.',
                          style: TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_supportsNativeGoogleSignIn) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    'Test Property Partner Google Sign-In on the Android mobile app. The native Google account chooser is not available the same way on Windows.',
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
