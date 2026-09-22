import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'data/product_data.dart';
import 'data/wishlist_data.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'services/notification_service.dart';
import 'services/bus_ticket_in_app_notice_service.dart';
import 'services/ride_driver_foreground_alert_service.dart';
import 'services/platform_capabilities.dart';
import 'services/ride_incoming_share_service.dart';

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

  await RideIncomingShareService.instance.initialize();

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
      scaffoldMessengerKey:
          NotificationService.messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'NRD Online Shop',
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

    await BusTicketInAppNoticeService.instance.initialize();
    debugPrint(
      'RD STARTUP: Bus Ticket in-app notice ready.',
    );

    await RideDriverForegroundAlertService.instance.initialize();
    debugPrint('RD STARTUP: Ride Driver foreground alert ready.');


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
    final double logoSize =
        MediaQuery.sizeOf(context).shortestSide < 500 ? 112 : 132;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF4F8FF),
              Colors.white,
              Color(0xFFFFF5F6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(
                    'assets/icon/logo.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NRD Online Shop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 88,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFF0066FF),
                          Color(0xFFE60012),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'From Nepal, Connecting to the World.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.15,
                      color: Color(0xFF5B6472),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: Color(0xFF0066FF),
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
        title: const Text('NRD Online Shop'),
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
