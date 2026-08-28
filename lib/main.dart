import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/product_data.dart';
import 'data/wishlist_data.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

bool get _supportsFirebaseMessaging {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (_supportsFirebaseMessaging) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  final FirebaseAuth auth = FirebaseAuth.instance;

  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  // Push notification permission + FCM device token
  await NotificationService.initialize();

  await Future.wait(<Future<void>>[
    loadWishlist(),
    loadProducts(),
  ]);

  runApp(
    const RDOnlineShop(),
  );
}

class RDOnlineShop extends StatelessWidget {
  const RDOnlineShop({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RD Online Shop',
      home: const HomePage(),
    );
  }
}