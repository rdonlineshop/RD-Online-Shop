import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'data/product_data.dart';
import 'data/wishlist_data.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'services/notification_service.dart';
import 'services/platform_capabilities.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'FCM background message: ${message.messageId}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (PlatformCapabilities.supportsPushNotifications) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  // Render Flutter immediately. Platform/Firebase startup happens inside the
  // gate so a failed plugin or network initialization can never leave the
  // desktop app as an unexplained black window.
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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
  });

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _initializeApplication();
  }

  Future<void> _initializeApplication() async {
    debugPrint(
      'RD STARTUP: ${PlatformCapabilities.platformName}',
    );

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('RD STARTUP: Firebase initialized.');

    final FirebaseAuth auth = FirebaseAuth.instance;

    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    debugPrint('RD STARTUP: Firebase Auth ready.');

    if (PlatformCapabilities.supportsPushNotifications) {
      try {
        await NotificationService.initialize();
        debugPrint('RD STARTUP: Push notification ready.');
      } catch (error, stackTrace) {
        debugPrint('RD STARTUP: Push notification skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } else {
      debugPrint(
        'RD STARTUP: Push notification skipped on '
        '${PlatformCapabilities.platformName}.',
      );
    }

    await Future.wait(<Future<void>>[
      loadWishlist(),
      loadProducts(),
    ]);

    debugPrint('RD STARTUP: Local data loaded.');
  }

  void _retry() {
    setState(() {
      _startupFuture = _initializeApplication();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startupFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<void> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return _StartupErrorPage(
              error: snapshot.error,
              onRetry: _retry,
            );
          }

          return const HomePage();
        }

        return const _StartupLoadingPage();
      },
    );
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text(
              'RD Online Shop',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('Starting application...'),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _StartupErrorPage({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RD Online Shop'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Application startup failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  error?.toString() ?? 'Unknown startup error.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
