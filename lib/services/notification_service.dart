import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform_capabilities.dart';

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

  static const String _customerIdPreferenceKey =
      'rd_customer_id';

  // ============================================================
  // SUPPORTED PLATFORM
  // ============================================================

  static bool get _isSupportedPlatform =>
      PlatformCapabilities.supportsPushNotifications;

  // ============================================================
  // INITIALIZE
  // ============================================================

  static Future<void> initialize() async {
    if (!_isSupportedPlatform) {
      debugPrint(
        'FCM: Push notification is disabled on this platform.',
      );
      return;
    }

    try {
      final NotificationSettings settings =
          await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        'FCM permission: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus ==
              AuthorizationStatus.denied ||
          settings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        debugPrint(
          'FCM: Notification permission was not granted.',
        );
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        final String? apnsToken =
            await _messaging.getAPNSToken();

        if (apnsToken == null || apnsToken.isEmpty) {
          debugPrint(
            'FCM: APNs token is not available yet.',
          );
        }
      }

      final String? token =
          await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'FCM: Device token is not available.',
        );
        return;
      }

      await _saveTokenToFirestore(token);

      debugPrint(
        'FCM: Device token saved successfully.',
      );

      await _tokenRefreshSubscription?.cancel();

      _tokenRefreshSubscription =
          _messaging.onTokenRefresh.listen(
        (String newToken) async {
          try {
            await _saveTokenToFirestore(newToken);

            debugPrint(
              'FCM: Refreshed token saved successfully.',
            );
          } catch (error) {
            debugPrint(
              'FCM token refresh save error: $error',
            );
          }
        },
        onError: (Object error) {
          debugPrint(
            'FCM token refresh error: $error',
          );
        },
      );

      await _foregroundSubscription?.cancel();

      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          final String title =
              message.notification?.title ?? '';

          final String body =
              message.notification?.body ?? '';

          debugPrint(
            'FCM foreground message: '
            '${title.isEmpty ? 'No title' : title}'
            '${body.isEmpty ? '' : ' - $body'}',
          );
        },
        onError: (Object error) {
          debugPrint(
            'FCM foreground message error: $error',
          );
        },
      );
    } catch (error) {
      debugPrint(
        'FCM initialization error: $error',
      );
    }
  }

  // ============================================================
  // SAVE DEVICE TOKEN
  // ============================================================

  static Future<void> _saveTokenToFirestore(
    String token,
  ) async {
    final String cleanToken =
        token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint(
        'FCM: Firebase user is not available.',
      );
      return;
    }

    final DocumentReference<Map<String, dynamic>>
        customerReference =
        _firestore.collection('customers').doc(user.uid);

    String customerId = '';

    if (user.isAnonymous) {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      customerId =
          prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

      if (customerId.isEmpty) {
        customerId = user.uid;

        await prefs.setString(
          _customerIdPreferenceKey,
          customerId,
        );
      }

      await customerReference.set(
        <String, dynamic>{
          'authUid': user.uid,
          'customerId': customerId,
          'role': 'customer',
          'isActive': true,
        },
        SetOptions(
          merge: true,
        ),
      );
    } else {
      final DocumentSnapshot<Map<String, dynamic>>
          customerSnapshot =
          await customerReference.get();

      if (!customerSnapshot.exists) {
        debugPrint(
          'FCM: Current account is not a customer account.',
        );
        return;
      }

      final Map<String, dynamic> customerData =
          customerSnapshot.data() ??
              <String, dynamic>{};

      if (customerData['role']?.toString().trim() !=
              'customer' ||
          customerData['isActive'] == false) {
        debugPrint(
          'FCM: Token not saved for non-customer account.',
        );
        return;
      }

      customerId =
          customerData['customerId']?.toString().trim() ?? '';

      if (customerId.isEmpty) {
        customerId = user.uid;
      }
    }

    await customerReference.set(
      <String, dynamic>{
        'authUid': user.uid,
        'customerId': customerId,
        'fcmToken': cleanToken,
        'fcmTokens': FieldValue.arrayUnion(
          <String>[
            cleanToken,
          ],
        ),
        'notificationsEnabled': true,
        'fcmPlatform': _platformName,
        'fcmTokenUpdatedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // PLATFORM NAME
  // ============================================================

  static String get _platformName =>
      PlatformCapabilities.platformName;

  // ============================================================
  // DISPOSE
  // ============================================================

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
  }
}