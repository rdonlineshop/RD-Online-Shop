import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'services/ride_incoming_share_service.dart';
import 'services/ride_location_input_service.dart';

class RidePickedLocation {
  const RidePickedLocation({
    required this.latitude,
    required this.longitude,
    required this.sourceLabel,
  });

  final double latitude;
  final double longitude;
  final String sourceLabel;
}

enum _SharedImportAction {
  received,
  clipboard,
  manual,
}

class RideLocationPickerPage extends StatefulWidget {
  const RideLocationPickerPage({
    required this.title,
    this.initialLatitude,
    this.initialLongitude,
    super.key,
  });

  final String title;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<RideLocationPickerPage> createState() =>
      _RideLocationPickerPageState();
}

class _RideLocationPickerPageState
    extends State<RideLocationPickerPage> {
  static const LatLng _fallbackCenter = LatLng(
    24.7136,
    46.6753,
  );

  final MapController _mapController = MapController();
  final RideLocationInputService _locationInputService =
      const RideLocationInputService();
  final RideIncomingShareService _incomingShareService =
      RideIncomingShareService.instance;

  StreamSubscription<String>? _incomingShareSubscription;

  LatLng? _selectedLocation;
  LatLng? _currentLocation;

  bool _gettingCurrentLocation = false;
  bool _resolvingSharedLocation = false;

  @override
  void initState() {
    super.initState();

    final double? latitude =
        widget.initialLatitude;
    final double? longitude =
        widget.initialLongitude;

    if (latitude != null && longitude != null) {
      _selectedLocation = LatLng(
        latitude,
        longitude,
      );
    }

    _incomingShareSubscription =
        _incomingShareService.sharedTextStream.listen(
      (String text) {
        if (!mounted ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }

        if (_resolvingSharedLocation) {
          _incomingShareService.keepPendingText(text);
          return;
        }

        _incomingShareService.consumePendingText();

        unawaited(
          _resolveSharedText(
            text,
            fromIncomingShare: true,
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (_selectedLocation != null) {
          _moveTo(
            _selectedLocation!,
            zoom: 16,
          );
        } else {
          _moveTo(
            _fallbackCenter,
            zoom: 12,
          );
        }

        unawaited(
          _consumePendingSharedLocation(),
        );
      },
    );
  }

  @override
  void dispose() {
    _incomingShareSubscription?.cancel();
    super.dispose();
  }

  Future<void> _consumePendingSharedLocation() async {
    final String? text =
        _incomingShareService.consumePendingText();

    if (text == null || text.trim().isEmpty) {
      return;
    }

    await _resolveSharedText(
      text,
      fromIncomingShare: true,
    );
  }

  void _moveTo(
    LatLng location, {
    double? zoom,
  }) {
    if (!mounted) {
      return;
    }

    final double currentZoom =
        _mapController.camera.zoom;

    _mapController.move(
      location,
      zoom ?? currentZoom,
    );
  }

  void _zoomIn() {
    final MapCamera camera =
        _mapController.camera;

    final double nextZoom =
        camera.zoom >= 19
            ? 19
            : camera.zoom + 1;

    _mapController.move(
      camera.center,
      nextZoom,
    );
  }

  void _zoomOut() {
    final MapCamera camera =
        _mapController.camera;

    final double nextZoom =
        camera.zoom <= 2
            ? 2
            : camera.zoom - 1;

    _mapController.move(
      camera.center,
      nextZoom,
    );
  }

  Future<Position?> _getCurrentPosition() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please turn on GPS / Location service first.',
            ),
          ),
        );
      }
      return null;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required to use current GPS.',
            ),
          ),
        );
      }
      return null;
    }

    if (permission ==
        LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission is permanently denied.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed:
                  Geolocator.openAppSettings,
            ),
          ),
        );
      }
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingCurrentLocation) {
      return;
    }

    setState(() {
      _gettingCurrentLocation = true;
    });

    try {
      final Position? position =
          await _getCurrentPosition();

      if (position == null || !mounted) {
        return;
      }

      final LatLng location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentLocation = location;
        _selectedLocation = location;
      });

      _moveTo(
        location,
        zoom: 16,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not get current GPS: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingCurrentLocation = false;
        });
      }
    }
  }

  Future<void> _pasteSharedLocation() async {
    if (_resolvingSharedLocation) {
      return;
    }

    final ClipboardData? clipboardData =
        await Clipboard.getData(
      Clipboard.kTextPlain,
    );

    final String text =
        clipboardData?.text?.trim() ?? '';

    if (text.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard does not contain a GPS location or map link.',
          ),
        ),
      );
      return;
    }

    await _resolveSharedText(text);
  }

  Future<void> _typeSharedLocation() async {
    String typedValue = '';

    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Shared GPS / Map Link',
          ),
          content: SizedBox(
            width: 520,
            child: TextField(
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              onChanged: (String value) {
                typedValue = value;
              },
              onSubmitted: (String value) {
                final String clean = value.trim();
                if (clean.isNotEmpty) {
                  Navigator.pop(dialogContext, clean);
                }
              },
              decoration: const InputDecoration(
                hintText:
                    'Paste 24.7136, 46.6753 or a Google Maps shared link',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final String clean = typedValue.trim();
                if (clean.isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, clean);
              },
              icon: const Icon(
                Icons.location_searching_rounded,
              ),
              label: const Text('Use Location'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null || value.trim().isEmpty) {
      return;
    }

    await _resolveSharedText(value.trim());
  }

  Future<void> _resolveSharedText(
    String text, {
    bool fromIncomingShare = false,
  }) async {
    if (_resolvingSharedLocation) {
      return;
    }

    setState(() {
      _resolvingSharedLocation = true;
    });

    try {
      final RideSharedLocation? location =
          await _locationInputService
              .resolveSharedLocation(text);

      if (location == null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read GPS from that shared location. Try a full Google Maps link or latitude, longitude.',
            ),
          ),
        );
        return;
      }

      final LatLng point = LatLng(
        location.latitude,
        location.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocation = point;
      });

      _moveTo(
        point,
        zoom: 16,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fromIncomingShare
                ? 'Shared location received. Check the map, then tap Use This Location.'
                : 'Shared GPS location added. Check the map, then confirm it.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resolvingSharedLocation = false;
        });
      }
    }
  }

  Future<void> _openImportSharedLocationSheet() async {
    final bool directShareAvailable =
        _incomingShareService.supportsDirectShareTarget;

    final _SharedImportAction? action =
        await showModalBottomSheet<_SharedImportAction>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      child: Icon(
                        Icons.share_location_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Import Shared Location',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        directShareAvailable
                            ? 'From WhatsApp, Messenger, Email, Instagram, or Google Maps: open the received location, tap Share, then choose RD Online Shop.'
                            : 'From WhatsApp, Messenger, Email, Instagram, or Google Maps: copy the received map link, return here, then use Paste from Clipboard.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: <Widget>[
                          Chip(label: Text('WhatsApp')),
                          Chip(label: Text('Messenger')),
                          Chip(label: Text('Email')),
                          Chip(label: Text('Instagram')),
                          Chip(label: Text('Google Maps')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_incomingShareService.pendingText != null) ...<Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _SharedImportAction.received,
                    ),
                    icon: const Icon(Icons.move_to_inbox_rounded),
                    label: const Text('Use Received Shared Location'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    _SharedImportAction.clipboard,
                  ),
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Paste from Clipboard'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    _SharedImportAction.manual,
                  ),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Enter Map Link / GPS'),
                ),
                const SizedBox(height: 10),
                Text(
                  'RD only reads the location/link you explicitly share or paste. It cannot read private chats or messages inside other apps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _SharedImportAction.received:
        final String? pendingText =
            _incomingShareService.consumePendingText();
        if (pendingText == null || pendingText.trim().isEmpty) {
          return;
        }
        await _resolveSharedText(
          pendingText,
          fromIncomingShare: true,
        );
        return;
      case _SharedImportAction.clipboard:
        await _pasteSharedLocation();
        return;
      case _SharedImportAction.manual:
        await _typeSharedLocation();
        return;
    }
  }

  void _confirmSelection() {
    final LatLng? selected =
        _selectedLocation;

    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tap the map or add a GPS location first.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      RidePickedLocation(
        latitude: selected.latitude,
        longitude: selected.longitude,
        sourceLabel:
            '${selected.latitude.toStringAsFixed(6)}, '
            '${selected.longitude.toStringAsFixed(6)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialCenter =
        _selectedLocation ??
            _currentLocation ??
            _fallbackCenter;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: FlutterMap(
                      mapController:
                          _mapController,
                      options: MapOptions(
                        initialCenter:
                            initialCenter,
                        initialZoom:
                            _selectedLocation !=
                                    null
                                ? 16
                                : 12,
                        minZoom: 2,
                        maxZoom: 19,
                        interactionOptions:
                            const InteractionOptions(
                          flags:
                              InteractiveFlag.all,
                        ),
                        onTap: (
                          TapPosition tapPosition,
                          LatLng point,
                        ) {
                          setState(() {
                            _selectedLocation =
                                point;
                          });
                        },
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.rd.onlineshop',
                        ),
                        MarkerLayer(
                          markers: <Marker>[
                            if (_currentLocation !=
                                null)
                              Marker(
                                point:
                                    _currentLocation!,
                                width: 42,
                                height: 42,
                                child:
                                    const _PickerPin(
                                  icon: Icons
                                      .my_location_rounded,
                                  color:
                                      Colors.green,
                                  tooltip:
                                      'Current GPS',
                                ),
                              ),
                            if (_selectedLocation !=
                                null)
                              Marker(
                                point:
                                    _selectedLocation!,
                                width: 56,
                                height: 56,
                                child:
                                    const _PickerPin(
                                  icon: Icons
                                      .location_on_rounded,
                                  color:
                                      Colors.red,
                                  tooltip:
                                      'Selected location',
                                ),
                              ),
                          ],
                        ),
                        const RichAttributionWidget(
                          attributions:
                              <SourceAttribution>[
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: <Widget>[
                        _PickerRoundButton(
                          tooltip: 'Zoom in',
                          icon:
                              Icons.add_rounded,
                          onPressed: _zoomIn,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        _PickerRoundButton(
                          tooltip: 'Zoom out',
                          icon:
                              Icons.remove_rounded,
                          onPressed: _zoomOut,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        _PickerRoundButton(
                          tooltip:
                              'Use current GPS',
                          icon: _gettingCurrentLocation
                              ? Icons
                                  .hourglass_top_rounded
                              : Icons
                                  .my_location_rounded,
                          onPressed:
                              _gettingCurrentLocation
                                  ? () {}
                                  : _useCurrentLocation,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 72,
                    top: 12,
                    child: Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        child: Text(
                          _selectedLocation == null
                              ? 'Tap anywhere on the map to choose a location.'
                              : 'Selected: '
                                  '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                                  '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  12,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed:
                          _resolvingSharedLocation
                              ? null
                              : _openImportSharedLocationSheet,
                      icon: const Icon(
                        Icons.share_location_rounded,
                      ),
                      label: Text(
                        _resolvingSharedLocation
                            ? 'Reading Shared Location...'
                            : 'Import Shared Location',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _selectedLocation == null
                          ? null
                          : _confirmSelection,
                      icon: const Icon(
                        Icons.check_rounded,
                      ),
                      label: Text(
                        _selectedLocation == null
                            ? 'Select a Location First'
                            : 'Use This Location',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRoundButton
    extends StatelessWidget {
  const _PickerRoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 3,
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder:
              const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              color:
                  const Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerPin extends StatelessWidget {
  const _PickerPin({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 27,
        ),
      ),
    );
  }
}
