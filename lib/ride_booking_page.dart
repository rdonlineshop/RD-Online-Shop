import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'nearby_drivers_page.dart';
import 'services/platform_capabilities.dart';

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

  bool _isFindingDriver = false;
  bool _isGettingLocation = false;
  bool _isFindingDestination = false;
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _destinationLatitude;
  double? _destinationLongitude;

  bool get _supportsNativeGeocoding =>
      PlatformCapabilities.supportsNativeGeocoding;

  @override
  void initState() {
    super.initState();

    if (_supportsNativeGeocoding) {
      _geocoding = Geocoding();
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _findNearbyDriver() async {
    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (_pickupLatitude == null || _pickupLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please use Current Location for pickup first.',
          ),
        ),
      );
      return;
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

    setState(() {
      _isFindingDriver = true;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 700),
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
          destinationLatitude: _destinationLatitude!,
          destinationLongitude: _destinationLongitude!,
          pickupAddress: _pickupController.text.trim(),
          destinationAddress:
              _destinationController.text.trim(),
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
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
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

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission is permanently denied. Open app settings to allow it.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String readableAddress =
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';

      final Geocoding? geocoder = _geocoding;

      if (geocoder != null) {
        try {
          final List<Placemark> placemarks =
              await geocoder.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (placemarks.isNotEmpty) {
            final Placemark place = placemarks.first;

            final List<String> parts = <String>[
              place.street ?? '',
              place.subLocality ?? '',
              place.locality ?? '',
              place.administrativeArea ?? '',
              place.country ?? '',
            ].where(
              (String part) => part.trim().isNotEmpty,
            ).toList();

            if (parts.isNotEmpty) {
              readableAddress = parts.join(', ');
            }
          }
        } catch (_) {
          // Coordinates stay valid even if reverse geocoding fails.
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pickupLatitude = position.latitude;
        _pickupLongitude = position.longitude;
        _pickupController.text = readableAddress;
      });

      _pickupFieldKey.currentState?.validate();

      ScaffoldMessenger.of(context).showSnackBar(
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

      ScaffoldMessenger.of(context).showSnackBar(
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

  ({double latitude, double longitude})? _parseCoordinates(
    String value,
  ) {
    final List<String> parts = value
        .split(',')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.length != 2) {
      return null;
    }

    final double? latitude = double.tryParse(parts[0]);
    final double? longitude = double.tryParse(parts[1]);

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return (
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<bool> _resolveDestination({
    bool showSuccessMessage = true,
  }) async {
    if (_isFindingDestination) {
      return false;
    }

    final bool valid =
        _destinationFieldKey.currentState?.validate() ?? false;

    if (!valid) {
      return false;
    }

    final String destination =
        _destinationController.text.trim();

    setState(() {
      _isFindingDestination = true;
    });

    try {
      final Geocoding? geocoder = _geocoding;

      if (geocoder == null) {
        final ({double latitude, double longitude})? coordinates =
            _parseCoordinates(destination);

        if (coordinates == null) {
          if (!mounted) {
            return false;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'On browser/Windows, enter destination as latitude, longitude for now.',
              ),
            ),
          );
          return false;
        }

        if (!mounted) {
          return false;
        }

        setState(() {
          _destinationLatitude = coordinates.latitude;
          _destinationLongitude = coordinates.longitude;
        });
      } else {
        final List<Location> locations =
            await geocoder.locationFromAddress(
          destination,
        );

        if (locations.isEmpty) {
          if (!mounted) {
            return false;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Destination was not found. Please enter a more specific place.',
              ),
            ),
          );
          return false;
        }

        final Location location = locations.first;

        if (!mounted) {
          return false;
        }

        setState(() {
          _destinationLatitude = location.latitude;
          _destinationLongitude = location.longitude;
        });
      }

      _destinationFieldKey.currentState?.validate();

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
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

      ScaffoldMessenger.of(context).showSnackBar(
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
                      'Only nearby ${widget.vehicleType} drivers will be shown. Browser/Windows currently uses GPS coordinates for destination entry.',
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                hintText: 'Enter pickup location',
                prefixIcon: const Icon(
                  Icons.my_location_rounded,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please enter pickup location';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  _isGettingLocation ? null : _useCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.gps_fixed_rounded,
                    ),
              label: Text(
                _isGettingLocation
                    ? 'Getting Location...'
                    : 'Use Current Location',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: _destinationFieldKey,
              controller: _destinationController,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                if (_destinationLatitude != null ||
                    _destinationLongitude != null) {
                  setState(() {
                    _destinationLatitude = null;
                    _destinationLongitude = null;
                  });
                }
              },
              onFieldSubmitted: (_) {
                _resolveDestination();
              },
              decoration: InputDecoration(
                labelText: 'Destination',
                hintText: _supportsNativeGeocoding
                    ? 'Example: Riyadh Airport'
                    : 'Example: 24.94549, 46.70891',
                prefixIcon: const Icon(
                  Icons.location_on_rounded,
                ),
                suffixIcon: _destinationLatitude != null &&
                        _destinationLongitude != null
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Please enter destination';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _isFindingDestination
                  ? null
                  : _resolveDestination,
              icon: _isFindingDestination
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.location_searching_rounded,
                    ),
              label: Text(
                _isFindingDestination
                    ? 'Finding Destination...'
                    : _supportsNativeGeocoding
                          ? 'Set Destination'
                          : 'Set Destination GPS',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
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
              icon: Icons.payments_outlined,
              label: 'Fare',
              value: 'Calculated next',
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
