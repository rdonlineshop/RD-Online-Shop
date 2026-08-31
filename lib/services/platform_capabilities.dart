import 'package:flutter/foundation.dart';

/// Central place for RD Online Shop platform feature support.
///
/// Keep platform checks here so Android/iOS/Windows/macOS behavior does not
/// drift apart as the project grows.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop => isWindows || isMacOS;

  /// Firebase Messaging is intentionally enabled only where the current RD
  /// implementation has been verified and token storage is configured.
  static bool get supportsPushNotifications => isAndroid || isIOS;

  /// The geocoding package used by RD has Android and Apple implementations,
  /// but no Windows implementation in the current dependency set.
  static bool get supportsNativeGeocoding =>
      isAndroid || isIOS || isMacOS;

  /// webview_flutter has Android and Apple implementations in this project,
  /// but no Windows implementation.
  static bool get supportsEmbeddedWebView =>
      isAndroid || isIOS || isMacOS;

  /// mobile_scanner is available for Android/iOS/macOS in the current lockfile,
  /// but not Windows. Windows uses manual OTP verification instead.
  static bool get supportsQrCameraScanner =>
      isAndroid || isIOS || isMacOS;

  static String get platformName {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
