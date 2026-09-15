import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActiveSessionRole {
  ActiveSessionRole._();

  static const String _roleKey = 'rd_active_session_role_v1';
  static const String _uidKey = 'rd_active_session_uid_v1';

  static const String admin = 'admin';
  static const String hotelPartner = 'hotel_partner';
  static const String homestayPartner = 'homestay_partner';
  static const String resortPartner = 'resort_partner';

  static const Set<String> _knownRoles = <String>{
    admin,
    hotelPartner,
    homestayPartner,
    resortPartner,
  };

  static Future<void> setRole(String role) async {
    if (!_knownRoles.contains(role)) {
      throw ArgumentError.value(
        role,
        'role',
        'Unknown RD active session role.',
      );
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      await clear();
      return;
    }

    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(_roleKey, role);
    await prefs.setString(_uidKey, user.uid);
  }

  static Future<String?> getRole() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      await clear();
      return null;
    }

    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    final String? role = prefs.getString(_roleKey);
    final String? uid = prefs.getString(_uidKey);

    if (role == null ||
        uid == null ||
        uid != user.uid ||
        !_knownRoles.contains(role)) {
      await clear();
      return null;
    }

    return role;
  }

  static Future<void> clear() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_uidKey);
  }

  static Future<String?> resolveForCurrentUser({
    String? fallbackPartnerCollection,
    String? fallbackPartnerRole,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      await clear();
      return null;
    }

    final String? storedRole = await getRole();
    if (storedRole != null) {
      return storedRole;
    }

    // Migration/safety fallback for a Firebase session that existed before
    // the local active-role marker was introduced. Admin wins first so an
    // Admin UID that is also registered as a Partner is never mistaken for
    // a Partner while the Admin session is active.
    try {
      final DocumentSnapshot<Map<String, dynamic>> adminDoc =
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> data =
          adminDoc.data() ?? <String, dynamic>{};

      final String role =
          data['role']?.toString().trim() ?? '';

      if (adminDoc.exists &&
          data['isActive'] == true &&
          (role == 'admin' || role == 'superAdmin')) {
        await setRole(admin);
        return admin;
      }
    } catch (_) {
      // Continue to the optional Partner fallback.
    }

    if (fallbackPartnerCollection != null &&
        fallbackPartnerRole != null) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> partnerDoc =
            await FirebaseFirestore.instance
                .collection(fallbackPartnerCollection)
                .doc(user.uid)
                .get();

        final Map<String, dynamic> data =
            partnerDoc.data() ?? <String, dynamic>{};

        if (partnerDoc.exists &&
            data['isApproved'] == true &&
            data['isActive'] == true &&
            data['role']?.toString() == fallbackPartnerRole) {
          await setRole(fallbackPartnerRole);
          return fallbackPartnerRole;
        }
      } catch (_) {
        // Leave the role unresolved. Firestore rules remain authoritative.
      }
    }

    return null;
  }
}
