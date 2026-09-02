import 'package:flutter/foundation.dart' as foundation;
import 'package:http/http.dart' as http;

class RideSharedLocation {
  const RideSharedLocation({
    required this.latitude,
    required this.longitude,
    required this.sourceText,
  });

  final double latitude;
  final double longitude;
  final String sourceText;
}

class RideLocationInputService {
  const RideLocationInputService();

  static final RegExp _coordinatePairPattern = RegExp(
    r'(-?\d{1,2}(?:\.\d+)?)\s*[, ]\s*(-?\d{1,3}(?:\.\d+)?)',
  );

  static final RegExp _googleAtPattern = RegExp(
    r'@(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
  );

  static final RegExp _googleDataPattern = RegExp(
    r'!3d(-?\d{1,2}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)',
  );

  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  RideSharedLocation? parseCoordinatesFromText(
    String input,
  ) {
    final String clean = input.trim();

    if (clean.isEmpty) {
      return null;
    }

    final RegExpMatch? googleAt =
        _googleAtPattern.firstMatch(clean);

    if (googleAt != null) {
      return _validated(
        googleAt.group(1),
        googleAt.group(2),
        clean,
      );
    }

    final RegExpMatch? googleData =
        _googleDataPattern.firstMatch(clean);

    if (googleData != null) {
      return _validated(
        googleData.group(1),
        googleData.group(2),
        clean,
      );
    }

    final Uri? uri = _firstUri(clean);

    if (uri != null) {
      final RideSharedLocation? fromUri =
          _coordinatesFromUri(uri, clean);

      if (fromUri != null) {
        return fromUri;
      }
    }

    final RegExpMatch? direct =
        _coordinatePairPattern.firstMatch(clean);

    if (direct == null) {
      return null;
    }

    return _validated(
      direct.group(1),
      direct.group(2),
      clean,
    );
  }

  Future<RideSharedLocation?> resolveSharedLocation(
    String input,
  ) async {
    final RideSharedLocation? direct =
        parseCoordinatesFromText(input);

    if (direct != null) {
      return direct;
    }

    final Uri? uri = _firstUri(input);

    if (uri == null || !_isShortMapLink(uri)) {
      return null;
    }

    if (foundation.kIsWeb) {
      // Browser CORS can block reading Google short-link redirects.
      return null;
    }

    try {
      final http.Client client = http.Client();

      try {
        final http.Request request =
            http.Request('GET', uri)
              ..followRedirects = true
              ..maxRedirects = 8
              ..headers.addAll(
                const <String, String>{
                  'Accept':
                      'text/html,application/xhtml+xml,application/json',
                  'User-Agent':
                      'RDOnlineShop/1.0 (Flutter Ride Location Resolver)',
                },
              );

        final http.StreamedResponse response =
            await client
                .send(request)
                .timeout(
                  const Duration(seconds: 12),
                );

        final Uri finalUri =
            response.request?.url ?? uri;

        final RideSharedLocation? fromFinalUri =
            _coordinatesFromUri(
          finalUri,
          finalUri.toString(),
        );

        if (fromFinalUri != null) {
          return fromFinalUri;
        }

        final String body =
            await response.stream
                .bytesToString()
                .timeout(
                  const Duration(seconds: 8),
                );

        final RideSharedLocation? fromBody =
            parseCoordinatesFromText(body);

        if (fromBody != null) {
          return fromBody;
        }

        final String? canonicalUrl =
            _extractCanonicalUrl(body);

        if (canonicalUrl != null) {
          return parseCoordinatesFromText(
            canonicalUrl,
          );
        }
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? extractPlaceQuery(
    String input,
  ) {
    final Uri? uri = _firstUri(input);

    if (uri == null) {
      return null;
    }

    for (final String key in <String>[
      'query',
      'q',
      'destination',
      'origin',
      'daddr',
      'saddr',
    ]) {
      final String? value =
          uri.queryParameters[key]
              ?.trim();

      if (value == null || value.isEmpty) {
        continue;
      }

      if (parseCoordinatesFromText(value) != null) {
        continue;
      }

      return value;
    }

    return null;
  }

  Uri? _firstUri(
    String input,
  ) {
    final RegExpMatch? match =
        _urlPattern.firstMatch(input);

    if (match == null) {
      final Uri? direct =
          Uri.tryParse(input.trim());

      if (direct != null &&
          (direct.scheme == 'http' ||
              direct.scheme == 'https' ||
              direct.scheme == 'geo')) {
        return direct;
      }

      return null;
    }

    String raw = match.group(0) ?? '';

    raw = raw.replaceAll(
      RegExp(r'[)\],.;]+$'),
      '',
    );

    return Uri.tryParse(raw);
  }

  bool _isShortMapLink(
    Uri uri,
  ) {
    final String host =
        uri.host.toLowerCase();

    return host == 'maps.app.goo.gl' ||
        host == 'goo.gl' ||
        host == 'g.co' ||
        host.endsWith('.goo.gl');
  }

  RideSharedLocation? _coordinatesFromUri(
    Uri uri,
    String sourceText,
  ) {
    if (uri.scheme == 'geo') {
      final String geoValue =
          uri.path.split('?').first;

      final RideSharedLocation? geo =
          parseCoordinatesFromText(
        geoValue,
      );

      if (geo != null) {
        return RideSharedLocation(
          latitude: geo.latitude,
          longitude: geo.longitude,
          sourceText: sourceText,
        );
      }
    }

    final RideSharedLocation? fromPath =
        parseCoordinatesFromText(
      uri.path,
    );

    if (fromPath != null) {
      return RideSharedLocation(
        latitude: fromPath.latitude,
        longitude: fromPath.longitude,
        sourceText: sourceText,
      );
    }

    for (final String key in <String>[
      'query',
      'q',
      'll',
      'center',
      'destination',
      'origin',
      'daddr',
      'saddr',
    ]) {
      final String? value =
          uri.queryParameters[key];

      if (value == null ||
          value.trim().isEmpty) {
        continue;
      }

      final RideSharedLocation? fromQuery =
          parseCoordinatesFromText(
        value,
      );

      if (fromQuery != null) {
        return RideSharedLocation(
          latitude:
              fromQuery.latitude,
          longitude:
              fromQuery.longitude,
          sourceText: sourceText,
        );
      }
    }

    final RideSharedLocation? fromFull =
        _validatedMatch(
      _googleAtPattern.firstMatch(
        uri.toString(),
      ),
      sourceText,
    );

    if (fromFull != null) {
      return fromFull;
    }

    final RegExpMatch? data =
        _googleDataPattern.firstMatch(
      uri.toString(),
    );

    if (data != null) {
      return _validated(
        data.group(1),
        data.group(2),
        sourceText,
      );
    }

    return null;
  }

  RideSharedLocation? _validatedMatch(
    RegExpMatch? match,
    String sourceText,
  ) {
    if (match == null) {
      return null;
    }

    return _validated(
      match.group(1),
      match.group(2),
      sourceText,
    );
  }

  RideSharedLocation? _validated(
    String? latitudeText,
    String? longitudeText,
    String sourceText,
  ) {
    final double? latitude =
        double.tryParse(
      latitudeText ?? '',
    );
    final double? longitude =
        double.tryParse(
      longitudeText ?? '',
    );

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return RideSharedLocation(
      latitude: latitude,
      longitude: longitude,
      sourceText: sourceText,
    );
  }

  String? _extractCanonicalUrl(
    String html,
  ) {
    final RegExp canonical = RegExp(
      r'''<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']''',
      caseSensitive: false,
    );

    final RegExpMatch? match =
        canonical.firstMatch(html);

    if (match == null) {
      return null;
    }

    final String? raw = match.group(1);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
