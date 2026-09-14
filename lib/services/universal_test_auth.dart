import 'package:firebase_auth/firebase_auth.dart';

class UniversalTestAuth {
  UniversalTestAuth._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// TEMPORARY TESTING AUTH
  ///
  /// - Email नयाँ छ भने Firebase account create गर्छ।
  /// - Email पहिले नै use भएको छ भने त्यही email/password बाट login गर्छ।
  ///
  /// यसले एउटै test email लाई Seller / Hotel / Homestay /
  /// Ride Driver / Bus / Delivery आदि portal मा reuse गर्न दिन्छ।
  static Future<UserCredential> createOrSignIn({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();

    try {
      return await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
      }

      rethrow;
    }
  }
}