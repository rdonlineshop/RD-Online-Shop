import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'nearby_drivers_page.dart';
import 'ride_location_picker_page.dart';
import 'services/ride_incoming_share_service.dart';
import 'services/ride_location_input_service.dart';
import 'services/ride_fare_service.dart';

class RideBookingPage extends StatefulWidget {
  const RideBookingPage({
    required this.vehicleType,
    super.key,
  });

  final String vehicleType;

  @override
  State<RideBookingPage> createState() => _RideBookingPageState();
}

class _RideBookingPageState extends State<RideBookingPage> {
  final TextEditingController _pickupController =
      TextEditingController();
  final TextEditingController _destinationController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _pickupFieldKey =
      GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _destinationFieldKey =
      GlobalKey<FormFieldState<String>>();
  Geocoding? _geocoding;
  final RideLocationInputService _locationInputService =
      const RideLocationInputService();
  final RideIncomingShareService _incomingShareService =
      RideIncomingShareService.instance;
  final RideFareService _fareService = RideFareService();

  StreamSubscription<String>? _incomingShareSubscription;

  bool _isFindingDriver = false;
  bool _isGettingLocation = false;
  bool _isFindingPickup = false;
  bool _isFindingDestination = false;
  bool _showingIncomingShareChooser = false;
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _destinationLatitude;
  double? _destinationLongitude;

  bool _isCalculatingFare = false;
  double? _routeDistanceKm;
  int? _routeDurationMinutes;
  double? _estimatedFare;
  bool _fareUsesRoadRoute = false;
  String? _fareError;
  late RideFareRule _fareRule;
  bool _fareSettingsLoading = true;
  bool _fareSettingsUsingFallback = true;
  String? _fareSettingsError;

  String get _fareCurrency => _fareRule.currency;

  bool get _supportsNativeGeocoding {
    if (foundation.kIsWeb) {
      return false;
    }

    return foundation.defaultTargetPlatform == foundation.TargetPlatform.android ||
        foundation.defaultTargetPlatform == foundation.TargetPlatform.iOS ||
        foundation.defaultTargetPlatform == foundation.TargetPlatform.macOS;
  }


  Map<String, String> get _nominatimHeaders {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': 'en',
    };

    if (!foundation.kIsWeb) {
      headers['User-Agent'] = 'RDOnlineShop/1.0 (Flutter)';
    }

    return headers;
  }

  @override
  void initState() {
    super.initState();
    _fareRule = RideFareService.defaultRuleFor(widget.vehicleType);
    unawaited(_loadFareSettings());

    if (_supportsNativeGeocoding) {
      _geocoding = Geocoding();
    }

    _incomingShareSubscription =
        _incomingShareService.sharedTextStream.listen(
      (String text) {
        if (!mounted ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }

        if (_showingIncomingShareChooser) {
          _incomingShareService.keepPendingText(text);
          return;
        }

        _incomingShareService.consumePendingText();
        unawaited(_offerIncomingSharedLocation(text));
      },
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        final String? pendingText =
            _incomingShareService.consumePendingText();

        if (pendingText == null ||
            pendingText.trim().isEmpty) {
          return;
        }

        unawaited(
          _offerIncomingSharedLocation(pendingText),
        );
      },
    );
  }

  @override
  void dispose() {
    _incomingShareSubscription?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadFareSettings() async {
    try {
      final RideFareRule rule =
          await _fareService.loadFareRule(widget.vehicleType);
      if (!mounted) return;

      setState(() {
        _fareRule = rule;
        _fareSettingsLoading = false;
        _fareSettingsUsingFallback = rule.isFallback;
        _fareSettingsError = null;
      });

      if (_pickupLatitude != null &&
          _pickupLongitude != null &&
          _destinationLatitude != null &&
          _destinationLongitude != null &&
          rule.isActive) {
        unawaited(_refreshFareEstimate());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fareSettingsLoading = false;
        _fareSettingsUsingFallback = true;
        _fareSettingsError = error.toString();
      });
    }
  }

  Future<void> _offerIncomingSharedLocation(
    String text,
  ) async {
    if (_showingIncomingShareChooser || !mounted) {
      return;
    }

    _showingIncomingShareChooser = true;

    try {
      final bool? useAsPickup =
          await showModalBottomSheet<bool>(
        context: context,
        builder: (BuildContext sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      CircleAvatar(
                        child: Icon(
                          Icons.share_location_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Shared Location Received',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose where to use the received location. RD will show it on the map before saving it.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use as Pickup'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, false),
                    icon: const Icon(Icons.location_on_rounded),
                    label: const Text('Use as Destination'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Not Now'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (useAsPickup == null || !mounted) {
        _incomingShareService.keepPendingText(text);
        return;
      }

      await _previewIncomingSharedLocation(
        text,
        pickup: useAsPickup,
      );
    } finally {
      _showingIncomingShareChooser = false;
    }
  }

  Future<void> _previewIncomingSharedLocation(
    String text, {
    required bool pickup,
  }) async {
    final RideSharedLocation? sharedLocation =
        await _locationInputService.resolveSharedLocation(text);

    if (sharedLocation == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'RD could not read GPS from that shared item. Copy the full map link and use Map / Shared GPS.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final RidePickedLocation? result =
        await Navigator.push<RidePickedLocation>(
      context,
      MaterialPageRoute<RidePickedLocation>(
        builder: (_) => RideLocationPickerPage(
          title: pickup
              ? 'Confirm Shared Pickup'
              : 'Confirm Shared Destination',
          initialLatitude: sharedLocation.latitude,
          initialLongitude: sharedLocation.longitude,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final String address =
        await _readableAddressForCoordinates(
      result.latitude,
      result.longitude,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (pickup) {
        _pickupLatitude = result.latitude;
        _pickupLongitude = result.longitude;
        _pickupController.text = address;
      } else {
        _destinationLatitude = result.latitude;
        _destinationLongitude = result.longitude;
        _destinationController.text = address;
      }
    });

    if (pickup) {
      _pickupFieldKey.currentState?.validate();
    } else {
      _destinationFieldKey.currentState?.validate();
    }

    unawaited(_refreshFareEstimate());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pickup
              ? 'Shared pickup confirmed.'
              : 'Shared destination confirmed.',
        ),
      ),
    );
  }

  void _clearFareEstimate() {
    _routeDistanceKm = null;
    _routeDurationMinutes = null;
    _estimatedFare = null;
    _fareUsesRoadRoute = false;
    _fareError = null;
  }

  double _roundedFare(double amount) {
    return (amount / 5).ceil() * 5.0;
  }

  double _fareForDistance(double distanceKm) {
    final RideFareRule rule = _fareRule;
    final double raw = rule.baseFare + (distanceKm * rule.perKm);
    final double withMinimum =
        raw < rule.minimumFare ? rule.minimumFare : raw;
    return _roundedFare(withMinimum);
  }

  Future<({double distanceKm, int durationMinutes, bool roadRoute})>
      _loadTripMetrics({
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      final Uri uri = Uri.parse(
        'https://router.project-osrm.org/'
        'route/v1/driving/'
        '$pickupLongitude,$pickupLatitude;'
        '$destinationLongitude,$destinationLatitude'
        '?overview=false&steps=false',
      );

      final Map<String, String> headers = <String, String>{
        'Accept': 'application/json',
      };

      if (!foundation.kIsWeb) {
        headers['User-Agent'] = 'RDOnlineShop/1.0';
      }

      final http.Response response = await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final dynamic routes = decoded['routes'];

          if (routes is List<dynamic> && routes.isNotEmpty) {
            final dynamic firstRoute = routes.first;

            if (firstRoute is Map<String, dynamic>) {
              final double? distanceMeters = double.tryParse(
                firstRoute['distance']?.toString() ?? '',
              );
              final double? durationSeconds = double.tryParse(
                firstRoute['duration']?.toString() ?? '',
              );

              if (distanceMeters != null &&
                  distanceMeters > 0 &&
                  durationSeconds != null &&
                  durationSeconds > 0) {
                final int durationMinutes =
                    (durationSeconds / 60).ceil();

                return (
                  distanceKm: distanceMeters / 1000,
                  durationMinutes:
                      durationMinutes < 1 ? 1 : durationMinutes,
                  roadRoute: true,
                );
              }
            }
          }
        }
      }
    } catch (_) {
      // If road routing is temporarily unavailable (including browser CORS),
      // keep fare preview usable with a clearly marked approximation.
    }

    final double directMeters = Geolocator.distanceBetween(
      pickupLatitude,
      pickupLongitude,
      destinationLatitude,
      destinationLongitude,
    );

    // Straight-line distance is normally shorter than road distance.
    // This fallback is only used when the road-route service is unavailable.
    final double approximateRoadKm = (directMeters / 1000) * 1.18;
    final double averageSpeed = _fareRule.fallbackAverageSpeedKmh;
    final int estimatedMinutes =
        ((approximateRoadKm / averageSpeed) * 60).ceil();

    return (
      distanceKm: approximateRoadKm,
      durationMinutes: estimatedMinutes < 1 ? 1 : estimatedMinutes,
      roadRoute: false,
    );
  }

  Future<void> _refreshFareEstimate() async {
    if (_isCalculatingFare) {
      return;
    }

    if (!_fareRule.isActive) {
      if (mounted) {
        setState(() {
          _routeDistanceKm = null;
          _routeDurationMinutes = null;
          _estimatedFare = null;
          _fareUsesRoadRoute = false;
          _fareError = 'Vehicle fare is disabled by Admin.';
        });
      }
      return;
    }

    final double? pickupLatitude = _pickupLatitude;
    final double? pickupLongitude = _pickupLongitude;
    final double? destinationLatitude = _destinationLatitude;
    final double? destinationLongitude = _destinationLongitude;

    if (pickupLatitude == null ||
        pickupLongitude == null ||
        destinationLatitude == null ||
        destinationLongitude == null) {
      if (mounted) {
        setState(_clearFareEstimate);
      }
      return;
    }

    setState(() {
      _isCalculatingFare = true;
      _fareError = null;
    });

    try {
      final ({double distanceKm, int durationMinutes, bool roadRoute})
          metrics = await _loadTripMetrics(
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
      );

      if (!mounted) {
        return;
      }

      // Do not apply an old async result if the customer changed a location.
      if (_pickupLatitude != pickupLatitude ||
          _pickupLongitude != pickupLongitude ||
          _destinationLatitude != destinationLatitude ||
          _destinationLongitude != destinationLongitude) {
        return;
      }

      setState(() {
        _routeDistanceKm = metrics.distanceKm;
        _routeDurationMinutes = metrics.durationMinutes;
        _estimatedFare = _fareForDistance(metrics.distanceKm);
        _fareUsesRoadRoute = metrics.roadRoute;
        _fareError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fareError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingFare = false;
        });
      }
    }
  }

  Future<void> _findNearbyDriver() async {
    if (!_fareRule.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This vehicle is currently unavailable for ride booking.',
          ),
        ),
      );
      return;
    }

    final bool valid =
        _formKey.currentState?.validate() ??
            false;

    if (!valid) {
      return;
    }

    if (_pickupLatitude == null ||
        _pickupLongitude == null) {
      final bool pickupReady =
          await _resolvePickup(
        showSuccessMessage: false,
      );

      if (!pickupReady) {
        return;
      }
    }

    if (_destinationLatitude == null ||
        _destinationLongitude == null) {
      final bool destinationReady =
          await _resolveDestination(
        showSuccessMessage: false,
      );

      if (!destinationReady) {
        return;
      }
    }

    if (_estimatedFare == null && !_isCalculatingFare) {
      await _refreshFareEstimate();
    }

    if (!mounted) {
      return;
    }

    final double? routeDistanceKm = _routeDistanceKm;
    final int? routeDurationMinutes = _routeDurationMinutes;
    final double? estimatedFare = _estimatedFare;

    if (routeDistanceKm == null ||
        routeDurationMinutes == null ||
        estimatedFare == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fare could not be prepared. Please tap Refresh Fare and try again.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isFindingDriver = true;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isFindingDriver = false;
    });

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NearbyDriversPage(
          vehicleType: widget.vehicleType,
          pickupLatitude: _pickupLatitude!,
          pickupLongitude: _pickupLongitude!,
          destinationLatitude:
              _destinationLatitude!,
          destinationLongitude:
              _destinationLongitude!,
          pickupAddress:
              _pickupController.text.trim(),
          destinationAddress:
              _destinationController.text.trim(),
          routeDistanceKm: routeDistanceKm,
          routeDurationMinutes: routeDurationMinutes,
          estimatedFare: estimatedFare,
          fareCurrency: _fareCurrency,
          fareUsesRoadRoute: _fareUsesRoadRoute,
          fareBaseFare: _fareRule.baseFare,
          farePerKm: _fareRule.perKm,
          fareMinimumFare: _fareRule.minimumFare,
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_isGettingLocation) {
      return;
    }

    setState(() {
      _isGettingLocation = true;
    });

    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Please turn on Location/GPS first.',
            ),
          ),
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required for ride pickup.',
            ),
          ),
        );
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission is permanently denied. Open app settings to allow it.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed:
                  Geolocator.openAppSettings,
            ),
          ),
        );
        return;
      }

      final Position position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final String readableAddress =
          await _readableAddressForCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pickupLatitude =
            position.latitude;
        _pickupLongitude =
            position.longitude;
        _pickupController.text =
            readableAddress;
      });

      _pickupFieldKey.currentState
          ?.validate();

      unawaited(_refreshFareEstimate());

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Current pickup location added.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not get current location: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<({double latitude, double longitude})?>
      _searchAddressWithOpenStreetMap(
    String query,
  ) async {
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '1',
      },
    );

    final http.Response response = await http
        .get(
          uri,
          headers: _nominatimHeaders,
        )
        .timeout(
          const Duration(seconds: 12),
        );

    if (response.statusCode != 200) {
      throw StateError(
        'Location search service returned ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List<dynamic> || decoded.isEmpty) {
      return null;
    }

    final dynamic first = decoded.first;

    if (first is! Map) {
      return null;
    }

    final double? latitude =
        double.tryParse(first['lat']?.toString() ?? '');
    final double? longitude =
        double.tryParse(first['lon']?.toString() ?? '');

    if (latitude == null || longitude == null) {
      return null;
    }

    return (
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<String?> _reverseGeocodeWithOpenStreetMap(
    double latitude,
    double longitude,
  ) async {
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      <String, String>{
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      },
    );

    try {
      final http.Response response = await http
          .get(
            uri,
            headers: _nominatimHeaders,
          )
          .timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final String displayName =
          decoded['display_name']?.toString().trim() ?? '';

      return displayName.isEmpty ? null : displayName;
    } catch (_) {
      return null;
    }
  }

  Future<String> _readableAddressForCoordinates(
    double latitude,
    double longitude,
  ) async {
    String readableAddress =
        '${latitude.toStringAsFixed(6)}, '
        '${longitude.toStringAsFixed(6)}';

    final Geocoding? geocoder =
        _geocoding;

    if (geocoder != null) {
      try {
        final List<Placemark> placemarks =
            await geocoder
                .placemarkFromCoordinates(
          latitude,
          longitude,
        );

        if (placemarks.isNotEmpty) {
          final Placemark place =
              placemarks.first;

          final List<String> parts =
              <String>[
            place.street ?? '',
            place.subLocality ?? '',
            place.locality ?? '',
            place.administrativeArea ?? '',
            place.country ?? '',
          ].where(
            (String part) =>
                part.trim().isNotEmpty,
          ).toList();

          if (parts.isNotEmpty) {
            readableAddress =
                parts.join(', ');
          }
        }
      } catch (_) {
        // The coordinates remain valid if reverse geocoding is unavailable.
      }
    } else {
      final String? webAddress =
          await _reverseGeocodeWithOpenStreetMap(
        latitude,
        longitude,
      );

      if (webAddress != null &&
          webAddress.trim().isNotEmpty) {
        readableAddress = webAddress;
      }
    }

    return readableAddress;
  }

  Future<({double latitude, double longitude})?>
      _resolveTextLocation(
    String input,
  ) async {
    final String clean = input.trim();

    if (clean.isEmpty) {
      return null;
    }

    final RideSharedLocation? shared =
        await _locationInputService
            .resolveSharedLocation(clean);

    if (shared != null) {
      return (
        latitude: shared.latitude,
        longitude: shared.longitude,
      );
    }

    final String placeQuery =
        _locationInputService
                .extractPlaceQuery(clean) ??
            clean;

    final Geocoding? geocoder =
        _geocoding;

    if (geocoder != null) {
      final List<Location> locations =
          await geocoder
              .locationFromAddress(
        placeQuery,
      );

      if (locations.isEmpty) {
        return null;
      }

      final Location location =
          locations.first;

      return (
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }

    return _searchAddressWithOpenStreetMap(
      placeQuery,
    );
  }

  Future<bool> _resolvePickup({
    bool showSuccessMessage = true,
  }) async {
    if (_isFindingPickup) {
      return false;
    }

    final bool valid =
        _pickupFieldKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return false;
    }

    setState(() {
      _isFindingPickup = true;
    });

    try {
      final ({double latitude, double longitude})?
          coordinates =
          await _resolveTextLocation(
        _pickupController.text,
      );

      if (coordinates == null) {
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Pickup was not found. Use Current Location, select it on the map, paste a shared GPS link, or enter a more specific place.',
            ),
          ),
        );
        return false;
      }

      if (!mounted) {
        return false;
      }

      setState(() {
        _pickupLatitude =
            coordinates.latitude;
        _pickupLongitude =
            coordinates.longitude;
      });

      _pickupFieldKey.currentState
          ?.validate();

      unawaited(_refreshFareEstimate());

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Pickup location added.',
            ),
          ),
        );
      }

      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not find pickup: $error',
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isFindingPickup = false;
        });
      }
    }
  }

  Future<bool> _resolveDestination({
    bool showSuccessMessage = true,
  }) async {
    if (_isFindingDestination) {
      return false;
    }

    final bool valid =
        _destinationFieldKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return false;
    }

    setState(() {
      _isFindingDestination = true;
    });

    try {
      final ({double latitude, double longitude})?
          coordinates =
          await _resolveTextLocation(
        _destinationController.text,
      );

      if (coordinates == null) {
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Destination was not found. Select it on the map, paste a shared GPS link, or enter a more specific place.',
            ),
          ),
        );
        return false;
      }

      if (!mounted) {
        return false;
      }

      setState(() {
        _destinationLatitude =
            coordinates.latitude;
        _destinationLongitude =
            coordinates.longitude;
      });

      _destinationFieldKey.currentState
          ?.validate();

      unawaited(_refreshFareEstimate());

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Destination location added.',
            ),
          ),
        );
      }

      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not find destination: $error',
          ),
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isFindingDestination = false;
        });
      }
    }
  }

  Future<void> _chooseLocationOnMap({
    required bool pickup,
  }) async {
    final RidePickedLocation? result =
        await Navigator.push<
            RidePickedLocation>(
      context,
      MaterialPageRoute<
          RidePickedLocation>(
        builder: (_) =>
            RideLocationPickerPage(
          title: pickup
              ? 'Choose Pickup'
              : 'Choose Destination',
          initialLatitude: pickup
              ? _pickupLatitude
              : _destinationLatitude,
          initialLongitude: pickup
              ? _pickupLongitude
              : _destinationLongitude,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final String address =
        await _readableAddressForCoordinates(
      result.latitude,
      result.longitude,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (pickup) {
        _pickupLatitude =
            result.latitude;
        _pickupLongitude =
            result.longitude;
        _pickupController.text =
            address;
      } else {
        _destinationLatitude =
            result.latitude;
        _destinationLongitude =
            result.longitude;
        _destinationController.text =
            address;
      }
    });

    if (pickup) {
      _pickupFieldKey.currentState
          ?.validate();
    } else {
      _destinationFieldKey.currentState
          ?.validate();
    }

    unawaited(_refreshFareEstimate());

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          pickup
              ? 'Pickup selected from map / shared GPS.'
              : 'Destination selected from map / shared GPS.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          '${widget.vehicleType} Booking',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 720,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _selectedVehicleCard(),
                    const SizedBox(height: 18),
                    _locationCard(),
                    const SizedBox(height: 18),
                    _summaryCard(),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _isFindingDriver
                            ? null
                            : _findNearbyDriver,
                        icon: _isFindingDriver
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.search_rounded,
                              ),
                        label: Text(
                          _isFindingDriver
                              ? 'Finding...'
                              : 'Find Nearby Driver',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Only nearby ${widget.vehicleType} drivers will be shown after pickup and destination are ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedVehicleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0D47A1),
            Color(0xFF1976D2),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Selected Vehicle',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.vehicleType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Trip Location',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: _pickupFieldKey,
              controller: _pickupController,
              textInputAction:
                  TextInputAction.search,
              onChanged: (_) {
                if (_pickupLatitude != null ||
                    _pickupLongitude != null) {
                  setState(() {
                    _pickupLatitude = null;
                    _pickupLongitude = null;
                    _clearFareEstimate();
                  });
                }
              },
              onFieldSubmitted: (_) {
                _resolvePickup();
              },
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                hintText:
                    'Current GPS, place name, coordinates, or shared map link',
                prefixIcon: const Icon(
                  Icons.my_location_rounded,
                ),
                suffixIcon:
                    _pickupLatitude != null &&
                            _pickupLongitude !=
                                null
                        ? const Icon(
                            Icons
                                .check_circle_rounded,
                            color: Colors.green,
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please enter or select pickup location';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed:
                      _isGettingLocation
                          ? null
                          : _useCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.gps_fixed_rounded,
                        ),
                  label: Text(
                    _isGettingLocation
                        ? 'Getting GPS...'
                        : 'Current Location',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isFindingPickup
                          ? null
                          : _resolvePickup,
                  icon: _isFindingPickup
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .location_searching_rounded,
                        ),
                  label: const Text(
                    'Set Pickup',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    _chooseLocationOnMap(
                      pickup: true,
                    );
                  },
                  icon: const Icon(
                    Icons.map_rounded,
                  ),
                  label: const Text(
                    'Map / Shared GPS',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: _destinationFieldKey,
              controller:
                  _destinationController,
              textInputAction:
                  TextInputAction.search,
              onChanged: (_) {
                if (_destinationLatitude !=
                        null ||
                    _destinationLongitude !=
                        null) {
                  setState(() {
                    _destinationLatitude =
                        null;
                    _destinationLongitude =
                        null;
                    _clearFareEstimate();
                  });
                }
              },
              onFieldSubmitted: (_) {
                _resolveDestination();
              },
              decoration: InputDecoration(
                labelText: 'Destination',
                hintText:
                    'Place name, coordinates, or shared map link',
                prefixIcon: const Icon(
                  Icons.location_on_rounded,
                ),
                suffixIcon:
                    _destinationLatitude !=
                                null &&
                            _destinationLongitude !=
                                null
                        ? const Icon(
                            Icons
                                .check_circle_rounded,
                            color: Colors.green,
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please enter or select destination';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed:
                      _isFindingDestination
                          ? null
                          : _resolveDestination,
                  icon: _isFindingDestination
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .location_searching_rounded,
                        ),
                  label: const Text(
                    'Set Destination',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    _chooseLocationOnMap(
                      pickup: false,
                    );
                  },
                  icon: const Icon(
                    Icons.map_rounded,
                  ),
                  label: const Text(
                    'Map / Shared GPS',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Shared GPS supports latitude/longitude and full Google Maps links. '
              'On Android/iPhone/Windows/macOS, many shortened Maps links can also be resolved. '
              'On Web, browser CORS may require a full link or coordinates.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Ride Summary',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _summaryRow(
              icon: Icons.directions_car_rounded,
              label: 'Vehicle',
              value: widget.vehicleType,
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.route_rounded,
              label: 'Distance',
              value: _isCalculatingFare
                  ? 'Calculating...'
                  : _routeDistanceKm == null
                      ? 'Set both locations'
                      : '${_routeDistanceKm!.toStringAsFixed(1)} km${_fareUsesRoadRoute ? '' : ' approx.'}',
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.timer_outlined,
              label: 'Estimated time',
              value: _isCalculatingFare
                  ? 'Calculating...'
                  : _routeDurationMinutes == null
                      ? '--'
                      : '${_routeDurationMinutes!} min',
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.payments_outlined,
              label: 'Estimated Fare',
              value: !_fareRule.isActive
                  ? 'Unavailable'
                  : _fareSettingsLoading
                      ? 'Loading rate...'
                      : _isCalculatingFare
                          ? 'Calculating...'
                          : _estimatedFare == null
                              ? '--'
                              : '$_fareCurrency ${_estimatedFare!.toStringAsFixed(0)}',
            ),
            const Divider(height: 22),
            _summaryRow(
              icon: Icons.schedule_rounded,
              label: 'Booking',
              value: 'Ride now',
            ),
            if (_pickupLatitude != null &&
                _pickupLongitude != null) ...<Widget>[
              const Divider(height: 22),
              _summaryRow(
                icon: Icons.gps_fixed_rounded,
                label: 'Pickup GPS',
                value: 'Ready',
              ),
            ],
            if (_destinationLatitude != null &&
                _destinationLongitude != null) ...<Widget>[
              const Divider(height: 22),
              _summaryRow(
                icon: Icons.location_on_rounded,
                label: 'Destination',
                value: 'Ready',
              ),
            ],
            if (_pickupLatitude != null &&
                _pickupLongitude != null &&
                _destinationLatitude != null &&
                _destinationLongitude != null) ...<Widget>[
              const SizedBox(height: 14),
              if (_fareError != null)
                Text(
                  'Fare service fallback is active. Distance and time may be approximate.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 6),
              if (!_fareRule.isActive)
                Text(
                  'This vehicle has been disabled from Admin Ride Fare Settings.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                )
              else ...<Widget>[
                Text(
                  'Estimate: base $_fareCurrency ${_fareRule.baseFare.toStringAsFixed(0)} + '
                  '$_fareCurrency ${_fareRule.perKm.toStringAsFixed(0)}/km, '
                  'minimum $_fareCurrency ${_fareRule.minimumFare.toStringAsFixed(0)}.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                if (_fareSettingsUsingFallback || _fareSettingsError != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Built-in safe fare rate is being used until Admin/Firestore rate is available.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Fare rate loaded from Admin settings.',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isCalculatingFare ||
                          _fareSettingsLoading ||
                          !_fareRule.isActive
                      ? null
                      : _refreshFareEstimate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Fare'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
