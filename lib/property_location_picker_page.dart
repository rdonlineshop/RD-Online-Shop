import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyLocationResult {
  final double latitude;
  final double longitude;
  final List<LatLng> boundaryPoints;

  const PropertyLocationResult({
    required this.latitude,
    required this.longitude,
    required this.boundaryPoints,
  });
}

class PropertyLocationPickerPage extends StatefulWidget {
  final bool enableBoundary;

  const PropertyLocationPickerPage({
    super.key,
    this.enableBoundary = false,
  });

  @override
  State<PropertyLocationPickerPage> createState() =>
      _PropertyLocationPickerPageState();
}

class _PropertyLocationPickerPageState
    extends State<PropertyLocationPickerPage> {
  final MapController _mapController = MapController();

  static const LatLng _nepalCenter = LatLng(28.3949, 84.1240);

  LatLng? _selectedPoint;
  final List<LatLng> _boundaryPoints = <LatLng>[];

  bool _isLoadingLocation = false;
  bool _boundaryMode = false;

  Future<void> _useCurrentLocation() async {
    if (_isLoadingLocation) {
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage(
          'Location service is OFF. Turn on GPS/location and try again.',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is required to use live GPS.',
        );
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final LatLng point = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPoint = point;
      });

      _mapController.move(point, 18);
    } catch (error) {
      _showMessage(
        'Could not get live location: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _handleMapTap(
    TapPosition tapPosition,
    LatLng point,
  ) {
    if (_boundaryMode && widget.enableBoundary) {
      setState(() {
        _boundaryPoints.add(point);
        _selectedPoint ??= point;
      });
      return;
    }

    setState(() {
      _selectedPoint = point;
    });
  }

  void _undoBoundaryPoint() {
    if (_boundaryPoints.isEmpty) {
      return;
    }

    setState(() {
      _boundaryPoints.removeLast();
    });
  }

  void _clearBoundary() {
    setState(() {
      _boundaryPoints.clear();
    });
  }

  Future<void> _openSatelliteMap() async {
    final LatLng? point = _selectedPoint;

    if (point == null) {
      _showMessage(
        'Select the property location first.',
      );
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps/@?api=1'
      '&map_action=map'
      '&center=${point.latitude},${point.longitude}'
      '&zoom=20'
      '&basemap=satellite',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      _showMessage(
        'Could not open satellite map.',
      );
    }
  }

  Future<void> _openDirections() async {
    final LatLng? point = _selectedPoint;

    if (point == null) {
      _showMessage(
        'Select the property location first.',
      );
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${point.latitude},${point.longitude}'
      '&travelmode=driving',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      _showMessage(
        'Could not open directions.',
      );
    }
  }

  void _confirmLocation() {
    final LatLng? point = _selectedPoint;

    if (point == null) {
      _showMessage(
        'Select the property location first.',
      );
      return;
    }

    if (widget.enableBoundary &&
        _boundaryPoints.isNotEmpty &&
        _boundaryPoints.length < 3) {
      _showMessage(
        'Land boundary needs at least 3 points, or clear the boundary.',
      );
      return;
    }

    Navigator.pop<PropertyLocationResult>(
      context,
      PropertyLocationResult(
        latitude: point.latitude,
        longitude: point.longitude,
        boundaryPoints:
            List<LatLng>.unmodifiable(_boundaryPoints),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center =
        _selectedPoint ?? _nepalCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Property Map Location',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom:
                        _selectedPoint == null ? 7 : 18,
                    minZoom: 3,
                    maxZoom: 19,
                    onTap: _handleMapTap,
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'rd_online_shop_new',
                    ),
                    if (_boundaryPoints.length >= 3)
                      PolygonLayer(
                        polygons: <Polygon>[
                          Polygon(
                            points: _boundaryPoints,
                            color: const Color(0x33795548),
                            borderColor:
                                const Color(0xFF795548),
                            borderStrokeWidth: 3,
                          ),
                        ],
                      ),
                    if (_boundaryPoints.isNotEmpty)
                      MarkerLayer(
                        markers: _boundaryPoints
                            .asMap()
                            .entries
                            .map(
                              (MapEntry<int, LatLng> entry) =>
                                  Marker(
                                point: entry.value,
                                width: 34,
                                height: 34,
                                child: Container(
                                  alignment:
                                      Alignment.center,
                                  decoration:
                                      const BoxDecoration(
                                    color:
                                        Color(0xFF795548),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${entry.key + 1}',
                                    style:
                                        const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (_selectedPoint != null)
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: _selectedPoint!,
                            width: 54,
                            height: 54,
                            alignment:
                                Alignment.topCenter,
                            child: const Icon(
                              Icons.location_pin,
                              size: 52,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: <Widget>[
                      FloatingActionButton.small(
                        heroTag: 'zoomIn',
                        onPressed: () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          );
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoomOut',
                        onPressed: () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          );
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _selectedPoint == null
                        ? 'Tap the map to select the exact property location.'
                        : 'Selected: '
                            '${_selectedPoint!.latitude.toStringAsFixed(6)}, '
                            '${_selectedPoint!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.enableBoundary) ...<Widget>[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _boundaryMode,
                      title: const Text(
                        'Mark Land Boundary',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        _boundaryMode
                            ? 'Tap map points around the land boundary.'
                            : '${_boundaryPoints.length} boundary point(s) selected.',
                      ),
                      onChanged: (bool value) {
                        setState(() {
                          _boundaryMode = value;
                        });
                      },
                    ),
                    if (_boundaryPoints.isNotEmpty)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _undoBoundaryPoint,
                              icon: const Icon(Icons.undo),
                              label: const Text(
                                'Undo Point',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _clearBoundary,
                              icon:
                                  const Icon(Icons.clear),
                              label:
                                  const Text('Clear'),
                            ),
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _isLoadingLocation
                            ? null
                            : _useCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                              ),
                        label: const Text(
                          'Use Live GPS',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openSatelliteMap,
                        icon: const Icon(
                          Icons.satellite_alt_rounded,
                        ),
                        label: const Text(
                          'Satellite / 3D',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openDirections,
                        icon: const Icon(
                          Icons.directions_rounded,
                        ),
                        label: const Text(
                          'Track / Directions',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _confirmLocation,
                    icon: const Icon(
                      Icons.check_circle_rounded,
                    ),
                    label: const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Use This Property Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Satellite/3D availability depends on the map provider and the selected area. Map boundary is for viewing/reference and is not a legal cadastral boundary.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
