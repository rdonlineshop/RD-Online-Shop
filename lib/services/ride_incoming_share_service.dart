import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/services.dart';

class RideIncomingShareService {
  RideIncomingShareService._();

  static final RideIncomingShareService instance =
      RideIncomingShareService._();

  static const MethodChannel _channel = MethodChannel(
    'rd_online_shop/shared_text',
  );

  final StreamController<String> _sharedTextController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  String? _pendingText;

  Stream<String> get sharedTextStream =>
      _sharedTextController.stream;

  bool get supportsDirectShareTarget {
    if (foundation.kIsWeb) {
      return true;
    }

    return foundation.defaultTargetPlatform ==
        foundation.TargetPlatform.android;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    if (foundation.kIsWeb) {
      _captureWebShareTarget();
      return;
    }

    if (foundation.defaultTargetPlatform !=
        foundation.TargetPlatform.android) {
      return;
    }

    _channel.setMethodCallHandler(
      (MethodCall call) async {
        if (call.method != 'sharedText') {
          return;
        }

        _acceptText(call.arguments?.toString());
      },
    );

    try {
      final String? initialText =
          await _channel.invokeMethod<String>(
        'consumeSharedText',
      );

      _acceptText(initialText);
    } on MissingPluginException {
      // Other supported Flutter targets use clipboard/manual import fallback.
    } on PlatformException {
      // Share reception is optional; ride booking must still start normally.
    }
  }

  String? get pendingText => _pendingText;

  void keepPendingText(String value) {
    final String clean = value.trim();

    if (clean.isEmpty) {
      return;
    }

    _pendingText = clean;
  }

  String? consumePendingText() {
    final String? value = _pendingText;
    _pendingText = null;
    return value;
  }

  void _acceptText(String? value) {
    final String clean = value?.trim() ?? '';

    if (clean.isEmpty) {
      return;
    }

    _pendingText = clean;
    _sharedTextController.add(clean);
  }

  void _captureWebShareTarget() {
    final Uri uri = Uri.base;
    final String title =
        uri.queryParameters['rdShareTitle']?.trim() ?? '';
    final String text =
        uri.queryParameters['rdShareText']?.trim() ?? '';
    final String url =
        uri.queryParameters['rdShareUrl']?.trim() ?? '';

    final String combined = <String>[
      title,
      text,
      url,
    ].where((String item) => item.isNotEmpty).join('\n');

    _acceptText(combined);
  }
}
