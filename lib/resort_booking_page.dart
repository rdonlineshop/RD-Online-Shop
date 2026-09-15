import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'resort_cloudinary_service.dart';
import 'resort_partner_auth_page.dart';
import 'resort_partner_dashboard_page.dart';
import 'services/active_session_role.dart';

Future<void> _openResortDirections(
  BuildContext context, {
  required double? resortLatitude,
  required double? resortLongitude,
  required String resortName,
}) async {
  if (resortLatitude == null ||
      resortLongitude == null) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Resort GPS location is not saved yet. '
            'Resort Partner must enable Location, capture current location '
            'and save the Resort Profile first.',
          ),
        ),
      );
    return;
  }

  try {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw StateError(
        'Please turn ON phone Location/GPS first.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      throw StateError(
        'Customer live location permission is required for navigation.',
      );
    }

    final Position customerPosition =
        await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final Uri directionsUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{
        'api': '1',
        'origin':
            '${customerPosition.latitude},${customerPosition.longitude}',
        'destination':
            '$resortLatitude,$resortLongitude',
        'destination_place_id': '',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      }..removeWhere(
          (String key, String value) => value.isEmpty,
        ),
    );

    final bool opened = await launchUrl(
      directionsUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw StateError(
        'Could not open map/navigation app.',
      );
    }
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Could not start navigation to $resortName.\n$error',
          ),
        ),
      );
  }
}

Future<void> _openResortPin(
  BuildContext context, {
  required double? resortLatitude,
  required double? resortLongitude,
  required String resortName,
}) async {
  if (resortLatitude == null ||
      resortLongitude == null) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Resort GPS location is not saved yet.',
          ),
        ),
      );
    return;
  }

  try {
    final Uri mapUri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': '$resortLatitude,$resortLongitude',
      },
    );

    final bool opened = await launchUrl(
      mapUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw StateError(
        'Could not open map.',
      );
    }
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Could not open $resortName location.\n$error',
          ),
        ),
      );
  }
}

class ResortBookingPage extends StatefulWidget {
  const ResortBookingPage({super.key});

  @override
  State<ResortBookingPage> createState() =>
      _ResortBookingPageState();
}

class _ResortBookingPageState
    extends State<ResortBookingPage> {
  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  final TextEditingController _search =
      TextEditingController();

  DateTime _checkIn =
      DateTime.now()
          .add(const Duration(days: 1));

  DateTime _checkOut =
      DateTime.now()
          .add(const Duration(days: 2));

  bool _sessionReady = false;
  String _sessionError = '';
  bool _resortPartnerSessionActive = false;

  Position? _customerPosition;
  bool _locatingCustomer = false;
  bool _nearestFirst = false;
  String _locationStatus = '';

  @override
  void initState() {
    super.initState();
    _ensureSession();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _ensureSession() async {
    try {
      if (FirebaseAuth.instance.currentUser ==
          null) {
        await FirebaseAuth.instance
            .signInAnonymously();
      }

      final User? user =
          FirebaseAuth.instance.currentUser;

      final String? activeRole =
          await ActiveSessionRole.resolveForCurrentUser(
        fallbackPartnerCollection: 'resort_partners',
        fallbackPartnerRole:
            ActiveSessionRole.resortPartner,
      );

      bool partnerSession = false;

      if (activeRole ==
              ActiveSessionRole.resortPartner &&
          user != null &&
          !user.isAnonymous) {
        try {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              partnerDoc =
              await FirebaseFirestore.instance
                  .collection(
                    'resort_partners',
                  )
                  .doc(user.uid)
                  .get();

          final Map<String, dynamic> data =
              partnerDoc.data() ??
                  <String, dynamic>{};

          partnerSession =
              partnerDoc.exists &&
                  data['isApproved'] == true &&
                  data['isActive'] == true &&
                  data['role'] ==
                      'resort_partner';
        } catch (_) {
          partnerSession = false;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _sessionReady = true;
        _sessionError = '';
        _resortPartnerSessionActive =
            partnerSession;
      });

      if (!partnerSession) {
        await _loadLocationIfAlreadyAllowed();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sessionReady = false;
        _sessionError =
            'Could not start customer session.\n$error';
      });
    }
  }

  DateTime _day(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      );

  int get _nights {
    final int value = _day(_checkOut)
        .difference(_day(_checkIn))
        .inDays;

    return value < 1 ? 1 : value;
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _stayDates(
    DateTime checkIn,
    DateTime checkOut,
  ) {
    final int nights = _day(checkOut)
        .difference(_day(checkIn))
        .inDays;

    if (nights < 1) {
      return <DateTime>[];
    }

    return List<DateTime>.generate(
      nights,
      (int index) => _day(checkIn)
          .add(Duration(days: index)),
    );
  }

  Future<void> _pickCheckIn() async {
    final DateTime now = DateTime.now();
    final DateTime first =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          _checkIn.isBefore(first)
              ? first
              : _checkIn,
      firstDate: first,
      lastDate:
          DateTime(now.year + 2, 12, 31),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _checkIn = picked;

      if (!_checkOut
          .isAfter(_checkIn)) {
        _checkOut =
            _checkIn.add(
          const Duration(days: 1),
        );
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final DateTime first =
        _checkIn.add(
      const Duration(days: 1),
    );

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          _checkOut.isBefore(first)
              ? first
              : _checkOut,
      firstDate: first,
      lastDate: DateTime(
        _checkIn.year + 2,
        12,
        31,
      ),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _checkOut = picked;
    });
  }

  String _normalized(String value) {
    return value
        .toLowerCase()
        .replaceAll('काठमाडौं', 'kathmandu')
        .replaceAll('काठमाडौँ', 'kathmandu')
        .replaceAll('ललितपुर', 'lalitpur')
        .replaceAll('भक्तपुर', 'bhaktapur')
        .trim();
  }

  bool _isKathmanduValleySearch(String query) {
    final String normalized = _normalized(query);

    return normalized.contains('kathmandu') ||
        normalized.contains('kathmandu valley') ||
        normalized.contains('ktm valley');
  }

  bool _matches(
    Map<String, dynamic> data,
  ) {
    final String query =
        _normalized(_search.text);

    if (query.isEmpty) {
      return true;
    }

    final String searchable = _normalized(
      <String>[
        data['name']?.toString() ?? '',
        data['location']?.toString() ?? '',
        data['address']?.toString() ?? '',
        data['city']?.toString() ?? '',
        data['area']?.toString() ?? '',
        data['description']?.toString() ?? '',
      ].join(' '),
    );

    if (searchable.contains(query)) {
      return true;
    }

    if (_isKathmanduValleySearch(query)) {
      const List<String> valleyTerms = <String>[
        'kathmandu',
        'lalitpur',
        'patan',
        'bhaktapur',
        'kirtipur',
        'tokha',
        'budhanilkantha',
        'madhyapur',
        'thimi',
        'chandragiri',
        'gokarneshwor',
        'nagarjun',
        'tarakeshwor',
      ];

      return valleyTerms.any(
        (String term) =>
            searchable.contains(term),
      );
    }

    return false;
  }

  double? _resortDistanceKm(
    Map<String, dynamic> resort,
  ) {
    final Position? customer =
        _customerPosition;

    final double? latitude =
        (resort['latitude'] as num?)
            ?.toDouble();

    final double? longitude =
        (resort['longitude'] as num?)
            ?.toDouble();

    if (customer == null ||
        latitude == null ||
        longitude == null) {
      return null;
    }

    final double meters =
        Geolocator.distanceBetween(
      customer.latitude,
      customer.longitude,
      latitude,
      longitude,
    );

    return meters / 1000;
  }

  int? _estimatedDriveMinutes(
    Map<String, dynamic> resort,
  ) {
    final double? distance =
        _resortDistanceKm(resort);

    if (distance == null) {
      return null;
    }

    final double averageKph =
        distance <= 10
            ? 25
            : distance <= 40
                ? 35
                : 50;

    final int minutes =
        ((distance / averageKph) * 60)
            .round();

    return minutes < 1 ? 1 : minutes;
  }

  Future<void> _loadLocationIfAlreadyAllowed() async {
    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        return;
      }

      final LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission !=
              LocationPermission.always &&
          permission !=
              LocationPermission.whileInUse) {
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customerPosition = position;
        _nearestFirst = true;
        _locationStatus =
            'Nearest approved Resorts are shown first.';
      });
    } catch (_) {
      // Near Me remains optional until tapped.
    }
  }

  Future<void> _useMyLocation() async {
    if (_locatingCustomer) {
      return;
    }

    setState(() {
      _locatingCustomer = true;
      _locationStatus =
          'Getting your live location...';
    });

    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw StateError(
          'Please turn ON phone Location/GPS first.',
        );
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
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is required to show nearest Resorts.',
        );
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customerPosition = position;
        _nearestFirst = true;
        _locationStatus =
            'Nearest approved Resorts are shown first.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationStatus = error.toString();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not use Near Me.\n$error',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _locatingCustomer = false;
        });
      }
    }
  }

  void _sortResortsByDistance(
    List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        docs,
  ) {
    if (!_nearestFirst ||
        _customerPosition == null) {
      return;
    }

    docs.sort(
      (
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            first,
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            second,
      ) {
        final double firstDistance =
            _resortDistanceKm(first.data()) ??
                double.infinity;

        final double secondDistance =
            _resortDistanceKm(second.data()) ??
                double.infinity;

        return firstDistance
            .compareTo(secondDistance);
      },
    );
  }

  Future<int> _roomAvailability({
    required String roomId,
    required int totalRooms,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    int minimum = totalRooms;

    final List<DateTime> dates =
        _stayDates(
      checkIn,
      checkOut,
    );

    if (dates.isEmpty ||
        totalRooms < 1) {
      return 0;
    }

    for (final DateTime date in dates) {
      final DocumentSnapshot<
              Map<String, dynamic>>
          inventory =
          await FirebaseFirestore.instance
              .collection(
                'resort_room_inventory',
              )
              .doc(
                '${roomId}_${_dateKey(date)}',
              )
              .get();

      // No inventory document means the Resort has not blocked/closed
      // this future date and no RD booking has reserved it yet.
      // In that case all rooms are available by default.
      if (!inventory.exists) {
        continue;
      }

      final Map<String, dynamic> data =
          inventory.data() ??
              <String, dynamic>{};

      // Resort Partner can explicitly close a date.
      if (data['isOpen'] == false) {
        return 0;
      }

      final int blocked =
          (data['blockedRooms'] as num?)
                  ?.toInt() ??
              0;

      final int booked =
          (data['bookedRooms'] as num?)
                  ?.toInt() ??
              0;

      // Recalculate from the current room total instead of trusting a
      // stale availableRooms value left by an older test/update.
      final int calculated =
          totalRooms - blocked - booked;

      final int available =
          calculated < 0
              ? 0
              : calculated > totalRooms
                  ? totalRooms
                  : calculated;

      if (available < minimum) {
        minimum = available;
      }
    }

    return minimum < 0 ? 0 : minimum;
  }

  Future<_ResortSummary>
      _resortAvailability(
    String resortId,
  ) async {
    final QuerySnapshot<
            Map<String, dynamic>>
        rooms =
        await FirebaseFirestore.instance
            .collection('resort_rooms')
            .where(
              'resortId',
              isEqualTo: resortId,
            )
            .where(
              'isActive',
              isEqualTo: true,
            )
            .get();

    int totalAvailable = 0;
    double? lowestAvailablePrice;

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        room in rooms.docs) {
      final Map<String, dynamic> data =
          room.data();

      final int total =
          (data['totalRooms'] as num?)
                  ?.toInt() ??
              0;

      final int available =
          await _roomAvailability(
        roomId: room.id,
        totalRooms: total,
        checkIn: _checkIn,
        checkOut: _checkOut,
      );

      if (available > 0) {
        totalAvailable += available;

        final double price =
            (data['pricePerNight']
                        as num?)
                    ?.toDouble() ??
                0;

        if (lowestAvailablePrice ==
                null ||
            price <
                lowestAvailablePrice) {
          lowestAvailablePrice =
              price;
        }
      }
    }

    return _ResortSummary(
      activeRoomTypes:
          rooms.docs.length,
      availableRooms:
          totalAvailable,
      lowestAvailablePrice:
          lowestAvailablePrice,
    );
  }

  void _openMyBookings() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const MyResortBookingsPage(),
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(
            Icons
                .calendar_month_rounded,
          ),
          border:
              const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: <Color>[
            _rdBlue,
            _rdGreen,
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Row(
        children: <Widget>[
          CircleAvatar(
            radius: 27,
            backgroundColor:
                Colors.white24,
            child: Icon(
              Icons
                  .bed_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose an approved resort. Use Near Me to see closest Resorts first, '
              'or search Resort / city / area such as Kathmandu. '
              'Check photos, facilities, price and real date-wise availability before booking.',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _search,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Search Resort / city / area (e.g. Kathmandu)',
                prefixIcon: Icon(
                  Icons.search_rounded,
                ),
                border:
                    OutlineInputBorder(),
              ),
              onChanged: (_) =>
                  setState(() {}),
            ),
            const SizedBox(
              height: 10,
            ),
            LayoutBuilder(
              builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final Widget nearMe =
                    FilledButton.tonalIcon(
                  onPressed: _locatingCustomer
                      ? null
                      : _useMyLocation,
                  icon: _locatingCustomer
                      ? const SizedBox.square(
                          dimension: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                        ),
                  label: Text(
                    _customerPosition == null
                        ? 'Near Me'
                        : 'Refresh Near Me',
                  ),
                );

                final Widget orderButton =
                    OutlinedButton.icon(
                  onPressed:
                      _customerPosition == null
                          ? null
                          : () {
                              setState(() {
                                _nearestFirst =
                                    !_nearestFirst;
                              });
                            },
                  icon: Icon(
                    _nearestFirst
                        ? Icons.near_me_rounded
                        : Icons
                            .format_list_numbered_rounded,
                  ),
                  label: Text(
                    _nearestFirst
                        ? 'Nearest First'
                        : 'Original Order',
                  ),
                );

                if (constraints.maxWidth >=
                    560) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: nearMe),
                      const SizedBox(width: 10),
                      Expanded(child: orderButton),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: <Widget>[
                    nearMe,
                    const SizedBox(height: 8),
                    orderButton,
                  ],
                );
              },
            ),
            if (_locationStatus.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _locationStatus,
                style: const TextStyle(
                  color: _rdBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(
              height: 10,
            ),
            LayoutBuilder(
              builder:
                  (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final Widget checkIn =
                    _dateBox(
                  label: 'Check-in',
                  value:
                      _date(_checkIn),
                  onTap:
                      _pickCheckIn,
                );

                final Widget checkOut =
                    _dateBox(
                  label: 'Check-out',
                  value:
                      _date(_checkOut),
                  onTap:
                      _pickCheckOut,
                );

                if (constraints
                        .maxWidth >=
                    620) {
                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: checkIn,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: checkOut,
                      ),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    checkIn,
                    const SizedBox(
                      height: 10,
                    ),
                    checkOut,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Stay: $_nights night(s)',
              style: const TextStyle(
                color: _rdBlue,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearbyResortsMap(
    List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        docs,
  ) {
    final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        mappedResorts = docs.where(
      (
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            doc,
      ) {
        final Map<String, dynamic> resort =
            doc.data();

        return resort['latitude'] is num &&
            resort['longitude'] is num;
      },
    ).toList();

    if (mappedResorts.isEmpty &&
        _customerPosition == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.map_outlined,
                color: _rdBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  docs.isEmpty
                      ? 'No Resort is available on the map yet.'
                      : 'Resort map is waiting for saved GPS coordinates. '
                          'Resort Partners must save their Resort location first.',
                  style: const TextStyle(
                    height: 1.4,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    LatLng center;

    if (_customerPosition != null) {
      center = LatLng(
        _customerPosition!.latitude,
        _customerPosition!.longitude,
      );
    } else {
      final Map<String, dynamic> first =
          mappedResorts.first.data();

      center = LatLng(
        (first['latitude'] as num)
            .toDouble(),
        (first['longitude'] as num)
            .toDouble(),
      );
    }

    final List<Marker> markers = <Marker>[
      if (_customerPosition != null)
        Marker(
          point: LatLng(
            _customerPosition!.latitude,
            _customerPosition!.longitude,
          ),
          width: 52,
          height: 52,
          child: const Tooltip(
            message: 'My Location',
            child: Icon(
              Icons.my_location_rounded,
              size: 34,
              color: _rdBlue,
            ),
          ),
        ),
      ...mappedResorts.map(
        (
          QueryDocumentSnapshot<
                  Map<String, dynamic>>
              doc,
        ) {
          final Map<String, dynamic> resort =
              doc.data();

          final double latitude =
              (resort['latitude'] as num)
                  .toDouble();

          final double longitude =
              (resort['longitude'] as num)
                  .toDouble();

          final String resortName =
              resort['name']?.toString() ??
                  'Resort';

          return Marker(
            point:
                LatLng(latitude, longitude),
            width: 60,
            height: 60,
            child: Tooltip(
              message: resortName,
              child: GestureDetector(
                onTap: () =>
                    _openResortPin(
                  context,
                  resortLatitude: latitude,
                  resortLongitude:
                      longitude,
                  resortName: resortName,
                ),
                child: const Icon(
                  Icons.holiday_village_rounded,
                  size: 39,
                  color: _rdGreen,
                ),
              ),
            ),
          );
        },
      ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              14,
              12,
              14,
              10,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.map_rounded,
                  color: _rdBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Nearby Resorts Map',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                if (_customerPosition != null)
                  Text(
                    '${mappedResorts.length} Resort(s)',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 285,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom:
                    _customerPosition != null
                        ? 13
                        : 12,
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'rd_online_shop_new',
                ),
                MarkerLayer(
                  markers: markers,
                ),
                RichAttributionWidget(
                  attributions: const <
                      SourceAttribution>[
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Blue marker = your location • Green Resort marker = approved Resort. '
              'Tap a Resort marker to open its map location.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resortCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> resort =
        doc.data();

    final String cover =
        resort['coverUrl']
                ?.toString()
                .trim() ??
            '';

    final String profile =
        resort['profileUrl']
                ?.toString()
                .trim() ??
            '';

    final double? distanceKm =
        _resortDistanceKm(resort);

    final int? driveMinutes =
        _estimatedDriveMinutes(resort);

    final double? resortLatitude =
        (resort['latitude'] as num?)
            ?.toDouble();

    final double? resortLongitude =
        (resort['longitude'] as num?)
            ?.toDouble();

    return FutureBuilder<_ResortSummary>(
      future:
          _resortAvailability(doc.id),
      builder: (
        BuildContext context,
        AsyncSnapshot<_ResortSummary>
            snapshot,
      ) {
        final bool loading =
            snapshot.connectionState ==
                ConnectionState.waiting;

        final _ResortSummary summary =
            snapshot.data ??
                const _ResortSummary(
                  activeRoomTypes: 0,
                  availableRooms: 0,
                  lowestAvailablePrice:
                      null,
                );

        final bool fullyBooked =
            !loading &&
                summary.activeRoomTypes >
                    0 &&
                summary.availableRooms <=
                    0;

        return Card(
          margin:
              const EdgeInsets.only(
            bottom: 12,
          ),
          clipBehavior:
              Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    ResortDetailsPage(
                  resortId: doc.id,
                  resort: resort,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    SizedBox(
                      height: 180,
                      width:
                          double.infinity,
                      child: cover.isEmpty
                          ? Container(
                              color: _rdBlue
                                  .withValues(
                                alpha: 0.08,
                              ),
                              alignment:
                                  Alignment
                                      .center,
                              child: const Icon(
                                Icons
                                    .hotel_rounded,
                                color:
                                    _rdBlue,
                                size: 58,
                              ),
                            )
                          : Image.network(
                              cover,
                              fit:
                                  BoxFit.cover,
                              errorBuilder:
                                  (
                                _,
                                __,
                                ___,
                              ) =>
                                      Container(
                                color: _rdBlue
                                    .withValues(
                                  alpha: 0.08,
                                ),
                                alignment:
                                    Alignment
                                        .center,
                                child:
                                    const Icon(
                                  Icons
                                      .hotel_rounded,
                                  color:
                                      _rdBlue,
                                  size: 58,
                                ),
                              ),
                            ),
                    ),
                    if (fullyBooked)
                      Positioned.fill(
                        child: Container(
                          alignment:
                              Alignment
                                  .center,
                          color: Colors.black
                              .withValues(
                            alpha: 0.48,
                          ),
                          child:
                              const Text(
                            'FULLY BOOKED',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding:
                      const EdgeInsets
                          .all(13),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            _rdGreen
                                .withValues(
                          alpha: 0.10,
                        ),
                        backgroundImage:
                            profile.isEmpty
                                ? null
                                : NetworkImage(
                                    profile,
                                  ),
                        child:
                            profile.isEmpty
                                ? const Icon(
                                    Icons
                                        .bed_rounded,
                                    color:
                                        _rdGreen,
                                  )
                                : null,
                      ),
                      const SizedBox(
                        width: 11,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: <Widget>[
                            Text(
                              resort['name']
                                      ?.toString() ??
                                  'Resort',
                              style:
                                  const TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              resort['location']
                                      ?.toString() ??
                                  '',
                            ),
                            if ((resort['phone']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty)
                              SelectableText(
                                resort['phone']
                                    .toString(),
                                style:
                                    const TextStyle(
                                  color:
                                      _rdGreen,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            const SizedBox(
                              height: 7,
                            ),
                            if (loading)
                              const SizedBox(
                                width: 140,
                                child:
                                    LinearProgressIndicator(),
                              )
                            else if (summary
                                    .activeRoomTypes ==
                                0)
                              const Text(
                                'No active room type yet',
                                style:
                                    TextStyle(
                                  color:
                                      Colors
                                          .grey,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              )
                            else if (fullyBooked)
                              const Text(
                                'No room available for selected dates',
                                style:
                                    TextStyle(
                                  color:
                                      _rdRed,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              )
                            else
                              Text(
                                '${summary.availableRooms} room(s) available'
                                '${summary.lowestAvailablePrice == null ? '' : ' • from Rs. ${summary.lowestAvailablePrice!.toStringAsFixed(0)}/night'}',
                                style:
                                    const TextStyle(
                                  color:
                                      _rdGreen,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                            if (distanceKm != null) ...<Widget>[
                              const SizedBox(
                                height: 6,
                              ),
                              Text(
                                'Distance: '
                                '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km'
                                '${driveMinutes == null ? '' : ' • approx. $driveMinutes min drive'}',
                                style:
                                    const TextStyle(
                                  color:
                                      _rdBlue,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'Approximate only. Use Navigate for live Maps route/time.',
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ],
                            if (resortLatitude != null &&
                                resortLongitude != null) ...<Widget>[
                              const SizedBox(
                                height: 7,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openResortPin(
                                      context,
                                      resortLatitude:
                                          resortLatitude,
                                      resortLongitude:
                                          resortLongitude,
                                      resortName:
                                          resort['name']
                                                  ?.toString() ??
                                              'Resort',
                                    ),
                                    icon: const Icon(
                                      Icons.map_rounded,
                                    ),
                                    label: const Text(
                                      'Map',
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openResortDirections(
                                      context,
                                      resortLatitude:
                                          resortLatitude,
                                      resortLongitude:
                                          resortLongitude,
                                      resortName:
                                          resort['name']
                                                  ?.toString() ??
                                              'Resort',
                                    ),
                                    icon: const Icon(
                                      Icons
                                          .navigation_rounded,
                                    ),
                                    label: const Text(
                                      'Navigate',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(
                              height: 5,
                            ),
                            const Text(
                              'Tap to view rooms',
                              style:
                                  TextStyle(
                                color:
                                    _rdBlue,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Resorts'),
        ),
        body: Center(
          child:
              _sessionError.isEmpty
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _sessionError,
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          FilledButton(
                            onPressed:
                                _ensureSession,
                            child:
                                const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      );
    }

    if (_resortPartnerSessionActive) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text(
            'Resorts',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              tooltip: 'Resort Partner Dashboard',
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ResortPartnerDashboardPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.person_outline,
              ),
            ),
            IconButton(
              tooltip:
                  'Customer bookings unavailable while Resort Partner is logged in',
              onPressed: null,
              icon: const Icon(
                Icons.book_online_rounded,
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 520,
            ),
            child: Card(
              margin:
                  const EdgeInsets.all(20),
              child: Padding(
                padding:
                    const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_person_rounded,
                      size: 54,
                      color: _rdBlue,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Resort Partner session is active',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This Resort page stays open so the Partner Dashboard and Logout remain accessible. '
                      'Customer Resort browsing and My Resort Bookings stay blocked while the '
                      'Resort Partner session is active.\n\n'
                      'Open the Partner Dashboard and logout when you want to use Resort booking '
                      'as a customer.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const ResortPartnerDashboardPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.dashboard_rounded,
                      ),
                      label: const Text(
                        'Open Resort Partner Dashboard',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(
                        context,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                      ),
                      label: const Text(
                        'Back',
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

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Resorts',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Resort Partner Login',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ResortPartnerAuthPage(),
              ),
            ),
            icon: const Icon(
              Icons.person_outline,
            ),
          ),
          IconButton(
            tooltip:
                'My Resort Bookings',
            onPressed:
                _openMyBookings,
            icon: const Icon(
              Icons
                  .book_online_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('resorts')
              .where(
                'isApproved',
                isEqualTo: true,
              )
              .where(
                'isActive',
                isEqualTo: true,
              )
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    QuerySnapshot<
                        Map<String, dynamic>>>
                snapshot,
          ) {
            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  child: Text(
                    'Could not load resorts.\n'
                    '${snapshot.error}',
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              );
            }

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                docs =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>>[])
                    .where(
                      (
                        QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>
                            doc,
                      ) =>
                          _matches(
                        doc.data(),
                      ),
                    )
                    .toList();

            _sortResortsByDistance(docs);

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1100,
                ),
                child: ListView(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  children: <Widget>[
                    _header(),
                    const SizedBox(
                      height: 14,
                    ),
                    _searchCard(),
                    const SizedBox(
                      height: 16,
                    ),
                    _nearbyResortsMap(
                      docs,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Text(
                      'Available Resorts '
                      '(${docs.length})',
                      style:
                          const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(
                            24,
                          ),
                          child: Text(
                            'No approved resort is available yet.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...docs.map(
                        _resortCard,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ResortDetailsPage
    extends StatelessWidget {
  const ResortDetailsPage({
    required this.resortId,
    required this.resort,
    required this.checkIn,
    required this.checkOut,
    super.key,
  });

  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);

  final String resortId;
  final Map<String, dynamic> resort;
  final DateTime checkIn;
  final DateTime checkOut;

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  Widget _resortGallery() {
    final List<dynamic> photos =
        resort['photoUrls'] is List
            ? resort['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    final List<String> urls =
        photos
            .map(
              (dynamic value) =>
                  value.toString().trim(),
            )
            .where(
              (String value) =>
                  value.isNotEmpty,
            )
            .toSet()
            .toList();

    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 8,
        ),
        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return ClipRRect(
            borderRadius:
                BorderRadius.circular(12),
            child: Image.network(
              urls[index],
              width: 195,
              height: 145,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) =>
                      Container(
                width: 195,
                height: 145,
                color: _rdBlue
                    .withValues(
                  alpha: 0.08,
                ),
                child: const Icon(
                  Icons.image_rounded,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary(
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: <Widget>[
        Icon(
          icon,
          color: _rdBlue,
        ),
        const SizedBox(height: 3),
        Text(label),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cover =
        resort['coverUrl']
                ?.toString()
                .trim() ??
            '';

    final String profile =
        resort['profileUrl']
                ?.toString()
                .trim() ??
            '';

    final List<dynamic> facilities =
        resort['facilities'] is List
            ? resort['facilities']
                as List<dynamic>
            : <dynamic>[];

    final double? resortLatitude =
        (resort['latitude'] as num?)?.toDouble();

    final double? resortLongitude =
        (resort['longitude'] as num?)?.toDouble();

    final bool hasResortGps =
        resortLatitude != null &&
            resortLongitude != null;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          resort['name']?.toString() ??
              'Resort',
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1050,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: <Widget>[
                Card(
                  clipBehavior:
                      Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 230,
                        child: cover.isEmpty
                            ? Container(
                                color: _rdBlue
                                    .withValues(
                                  alpha: 0.08,
                                ),
                                alignment:
                                    Alignment
                                        .center,
                                child:
                                    const Icon(
                                  Icons
                                      .hotel_rounded,
                                  color:
                                      _rdBlue,
                                  size: 64,
                                ),
                              )
                            : Image.network(
                                cover,
                                fit:
                                    BoxFit.cover,
                                errorBuilder:
                                    (
                                  _,
                                  __,
                                  ___,
                                ) =>
                                        Container(
                                  color: _rdBlue
                                      .withValues(
                                    alpha: 0.08,
                                  ),
                                  alignment:
                                      Alignment
                                          .center,
                                  child:
                                      const Icon(
                                    Icons
                                        .hotel_rounded,
                                    color:
                                        _rdBlue,
                                    size: 64,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets
                                .all(14),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 32,
                              backgroundColor:
                                  _rdGreen
                                      .withValues(
                                alpha: 0.10,
                              ),
                              backgroundImage:
                                  profile
                                          .isEmpty
                                      ? null
                                      : NetworkImage(
                                          profile,
                                        ),
                              child:
                                  profile
                                          .isEmpty
                                      ? const Icon(
                                          Icons
                                              .bed_rounded,
                                          color:
                                              _rdGreen,
                                          size:
                                              34,
                                        )
                                      : null,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: <Widget>[
                                  Text(
                                    resort['name']
                                            ?.toString() ??
                                        'Resort',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          22,
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons
                                            .location_on_rounded,
                                        color:
                                            Colors.red,
                                        size:
                                            18,
                                      ),
                                      const SizedBox(
                                        width:
                                            4,
                                      ),
                                      Expanded(
                                        child: Text(
                                          resort['location']?.toString() ??
                                              '',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((resort['phone']
                                              ?.toString()
                                              .trim() ??
                                          '')
                                      .isNotEmpty)
                                    Row(
                                      children: <Widget>[
                                        const Icon(
                                          Icons
                                              .phone_rounded,
                                          color:
                                              _rdGreen,
                                          size:
                                              18,
                                        ),
                                        const SizedBox(
                                          width:
                                              4,
                                        ),
                                        SelectableText(
                                          resort['phone']
                                              .toString(),
                                        ),
                                      ],
                                    ),
                                  if ((resort['email']
                                              ?.toString()
                                              .trim() ??
                                          '')
                                      .isNotEmpty)
                                    SelectableText(
                                      resort['email']
                                          .toString(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((resort['description']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            14,
                            0,
                            14,
                            14,
                          ),
                          child: Text(
                            resort[
                                    'description']
                                .toString(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Resort Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasResortGps
                              ? 'Resort GPS location is saved. '
                                  'You can view the resort pin or navigate '
                                  'from your current live location.'
                              : 'Resort GPS location has not been saved yet.',
                          style: TextStyle(
                            color: hasResortGps
                                ? _rdGreen
                                : Colors.orange,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        if (hasResortGps) ...<Widget>[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openResortPin(
                                  context,
                                  resortLatitude:
                                      resortLatitude,
                                  resortLongitude:
                                      resortLongitude,
                                  resortName:
                                      resort['name']
                                              ?.toString() ??
                                          'Resort',
                                ),
                                icon: const Icon(
                                  Icons
                                      .location_on_rounded,
                                ),
                                label: const Text(
                                  'View Resort Location',
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    _openResortDirections(
                                  context,
                                  resortLatitude:
                                      resortLatitude,
                                  resortLongitude:
                                      resortLongitude,
                                  resortName:
                                      resort['name']
                                              ?.toString() ??
                                          'Resort',
                                ),
                                icon: const Icon(
                                  Icons
                                      .navigation_rounded,
                                ),
                                label: const Text(
                                  'Navigate from My Live Location',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                _resortGallery(),
                if ((resort['photoUrls']
                            as List?)
                        ?.isNotEmpty ==
                    true)
                  const SizedBox(
                    height: 12,
                  ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _summary(
                            'Check-in',
                            _date(checkIn),
                            Icons
                                .login_rounded,
                          ),
                        ),
                        Expanded(
                          child: _summary(
                            'Check-out',
                            _date(checkOut),
                            Icons
                                .logout_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (facilities.isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 12,
                  ),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: <Widget>[
                          const Text(
                            'Resort Facilities',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children:
                                facilities
                                    .map(
                              (
                                dynamic value,
                              ) =>
                                  Chip(
                                avatar:
                                    const Icon(
                                  Icons
                                      .check_circle_rounded,
                                  color:
                                      _rdGreen,
                                  size:
                                      17,
                                ),
                                label: Text(
                                  value
                                      .toString(),
                                ),
                              ),
                            )
                                    .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if ((resort['cancellationPolicy']
                            ?.toString()
                            .trim() ??
                        '')
                    .isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 12,
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons
                            .event_busy_rounded,
                      ),
                      title: const Text(
                        'Cancellation Policy',
                        style: TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      subtitle: Text(
                        resort[
                                'cancellationPolicy']
                            .toString(),
                      ),
                    ),
                  ),
                ],
                if ((resort['houseRules']
                            ?.toString()
                            .trim() ??
                        '')
                    .isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 8,
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.rule_rounded,
                      ),
                      title: const Text(
                        'House Rules',
                        style: TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      subtitle: Text(
                        resort['houseRules']
                            .toString(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  'Rooms',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(
                        'resort_rooms',
                      )
                      .where(
                        'resortId',
                        isEqualTo:
                            resortId,
                      )
                      .where(
                        'isActive',
                        isEqualTo:
                            true,
                      )
                      .snapshots(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<
                            QuerySnapshot<
                                Map<String,
                                    dynamic>>>
                        snapshot,
                  ) {
                    if (snapshot
                                .connectionState ==
                            ConnectionState
                                .waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    if (snapshot
                        .hasError) {
                      return Text(
                        'Could not load rooms.\n'
                        '${snapshot.error}',
                      );
                    }

                    final List<
                            QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>>
                        docs =
                        snapshot
                                .data
                                ?.docs ??
                            <QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>>[];

                    if (docs.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding:
                              EdgeInsets
                                  .all(
                            24,
                          ),
                          child: Text(
                            'No active room is available.',
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: docs
                          .map(
                            (
                              QueryDocumentSnapshot<
                                      Map<String,
                                          dynamic>>
                                  roomDoc,
                            ) =>
                                CustomerRoomCard(
                              resortId:
                                  resortId,
                              resort: resort,
                              roomDoc:
                                  roomDoc,
                              checkIn:
                                  checkIn,
                              checkOut:
                                  checkOut,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerRoomCard
    extends StatelessWidget {
  const CustomerRoomCard({
    required this.resortId,
    required this.resort,
    required this.roomDoc,
    required this.checkIn,
    required this.checkOut,
    super.key,
  });

  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  final String resortId;
  final Map<String, dynamic> resort;
  final QueryDocumentSnapshot<
      Map<String, dynamic>> roomDoc;
  final DateTime checkIn;
  final DateTime checkOut;

  DateTime _day(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      );

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _stayDates() {
    final int nights = _day(checkOut)
        .difference(_day(checkIn))
        .inDays;

    if (nights < 1) {
      return <DateTime>[];
    }

    return List<DateTime>.generate(
      nights,
      (int index) =>
          _day(checkIn).add(
        Duration(days: index),
      ),
    );
  }

  Future<int> _availableForStay() async {
    final Map<String, dynamic> room =
        roomDoc.data();

    final int totalRooms =
        (room['totalRooms'] as num?)
                ?.toInt() ??
            0;

    int minimum = totalRooms;

    if (totalRooms < 1) {
      return 0;
    }

    for (final DateTime date
        in _stayDates()) {
      final DocumentSnapshot<
              Map<String, dynamic>>
          inventory =
          await FirebaseFirestore.instance
              .collection(
                'resort_room_inventory',
              )
              .doc(
                '${roomDoc.id}_${_dateKey(date)}',
              )
              .get();

      // Missing date inventory = open by default with all rooms
      // available, unless a booking/block/closed record exists.
      if (!inventory.exists) {
        continue;
      }

      final Map<String, dynamic> data =
          inventory.data() ??
              <String, dynamic>{};

      if (data['isOpen'] == false) {
        return 0;
      }

      final int blocked =
          (data['blockedRooms'] as num?)
                  ?.toInt() ??
              0;

      final int booked =
          (data['bookedRooms'] as num?)
                  ?.toInt() ??
              0;

      final int calculated =
          totalRooms - blocked - booked;

      final int available =
          calculated < 0
              ? 0
              : calculated > totalRooms
                  ? totalRooms
                  : calculated;

      if (available < minimum) {
        minimum = available;
      }
    }

    return minimum < 0 ? 0 : minimum;
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ??
            0;

    return 'Rs. '
        '${amount.toStringAsFixed(0)}';
  }

  Widget _roomPhotos(
    List<String> photos,
  ) {
    if (photos.isEmpty) {
      return Container(
        height: 175,
        color:
            _rdBlue.withValues(
          alpha: 0.08,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.bed_rounded,
          color: _rdBlue,
          size: 52,
        ),
      );
    }

    if (photos.length == 1) {
      return SizedBox(
        height: 175,
        child: Image.network(
          photos.first,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  Container(
            color:
                _rdBlue.withValues(
              alpha: 0.08,
            ),
            child: const Icon(
              Icons.bed_rounded,
              size: 52,
              color: _rdBlue,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 175,
      child: PageView.builder(
        itemCount: photos.length,
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          return Image.network(
            photos[index],
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    Container(
              color:
                  _rdBlue.withValues(
                alpha: 0.08,
              ),
              child: const Icon(
                Icons.bed_rounded,
                size: 52,
                color: _rdBlue,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> room =
        roomDoc.data();

    final List<dynamic> rawPhotos =
        room['photoUrls'] is List
            ? room['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    final List<String> photos =
        rawPhotos
            .map(
              (dynamic value) =>
                  value.toString().trim(),
            )
            .where(
              (String value) =>
                  value.isNotEmpty,
            )
            .toSet()
            .toList();

    final String single =
        room['photoUrl']
                ?.toString()
                .trim() ??
            '';

    if (single.isNotEmpty &&
        !photos.contains(single)) {
      photos.insert(0, single);
    }

    final List<dynamic> facilities =
        room['facilities'] is List
            ? room['facilities']
                as List<dynamic>
            : <dynamic>[];

    return FutureBuilder<int>(
      future: _availableForStay(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        final bool loading =
            snapshot.connectionState ==
                ConnectionState.waiting;

        final int available =
            snapshot.data ?? 0;

        return Card(
          margin:
              const EdgeInsets.only(
            bottom: 10,
          ),
          clipBehavior:
              Clip.antiAlias,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  _roomPhotos(photos),
                  if (!loading &&
                      available <= 0)
                    Positioned.fill(
                      child: Container(
                        alignment:
                            Alignment
                                .center,
                        color: Colors.black
                            .withValues(
                          alpha: 0.48,
                        ),
                        child:
                            const Text(
                          'NOT AVAILABLE',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets
                        .all(13),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: <Widget>[
                    Text(
                      room['name']
                              ?.toString() ??
                          'Room',
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    Text(
                      '${room['roomClass'] ?? ''} • '
                      '${room['isAc'] == true ? 'AC Room' : 'Non-AC'} • '
                      '${room['bed'] ?? ''}',
                    ),
                    if ((room['description']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 4,
                        ),
                        child: Text(
                          room['description']
                              .toString(),
                        ),
                      ),
                    const SizedBox(
                      height: 6,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        Chip(
                          label: Text(
                            'Max '
                            '${room['maxGuests'] ?? 0} guests',
                          ),
                        ),
                        if (room[
                                'breakfastIncluded'] ==
                            true)
                          const Chip(
                            label: Text(
                              'Breakfast Included',
                            ),
                          ),
                        if (room[
                                'freeCancellation'] ==
                            true)
                          const Chip(
                            label: Text(
                              'Free Cancellation',
                            ),
                          ),
                      ],
                    ),
                    if (facilities
                        .isNotEmpty) ...<
                        Widget>[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        facilities
                            .map(
                              (
                                dynamic value,
                              ) =>
                                  value
                                      .toString(),
                            )
                            .join(' • '),
                        style: TextStyle(
                          color: Colors
                              .grey
                              .shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 7,
                    ),
                    Text(
                      '${_money(room['pricePerNight'])} / night',
                      style:
                          const TextStyle(
                        color: _rdBlue,
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    if (loading)
                      const LinearProgressIndicator()
                    else
                      Text(
                        available > 0
                            ? '$available room(s) available for selected dates'
                            : 'Fully booked for selected dates',
                        style: TextStyle(
                          color: available > 0
                              ? _rdGreen
                              : _rdRed,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    const SizedBox(
                      height: 9,
                    ),
                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed: !loading &&
                                available >
                                    0
                            ? () =>
                                Navigator.push<
                                    void>(
                                  context,
                                  MaterialPageRoute<
                                      void>(
                                    builder:
                                        (_) =>
                                            ResortRoomBookingPage(
                                      resortId:
                                          resortId,
                                      resort:
                                          resort,
                                      roomId:
                                          roomDoc.id,
                                      room:
                                          room,
                                      checkIn:
                                          checkIn,
                                      checkOut:
                                          checkOut,
                                      available:
                                          available,
                                    ),
                                  ),
                                )
                            : null,
                        icon: const Icon(
                          Icons
                              .book_online_rounded,
                        ),
                        label: Text(
                          available > 0
                              ? 'Book Now'
                              : 'Full',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ResortRoomBookingPage
    extends StatefulWidget {
  const ResortRoomBookingPage({
    required this.resortId,
    required this.resort,
    required this.roomId,
    required this.room,
    required this.checkIn,
    required this.checkOut,
    required this.available,
    super.key,
  });

  final String resortId;
  final Map<String, dynamic> resort;
  final String roomId;
  final Map<String, dynamic> room;
  final DateTime checkIn;
  final DateTime checkOut;
  final int available;

  @override
  State<ResortRoomBookingPage>
      createState() =>
          _ResortRoomBookingPageState();
}

class _ResortRoomBookingPageState
    extends State<ResortRoomBookingPage> {
  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);

  final TextEditingController
      _guestName =
      TextEditingController();

  final TextEditingController _phone =
      TextEditingController();

  final TextEditingController
      _paymentReference =
      TextEditingController();

  int _roomCount = 1;

  String _paymentOption =
      'pay_at_resort';

  String _paymentMethod =
      'bank_transfer';

  bool _submitting = false;
  bool _loadingDirectPayment = true;
  bool _uploadingPaymentProof = false;

  String _paymentProofUrl = '';

  Map<String, dynamic> _directPayment =
      <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadDirectPayment();
  }

  @override
  void dispose() {
    _guestName.dispose();
    _phone.dispose();
    _paymentReference.dispose();
    super.dispose();
  }

  DateTime _day(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      );

  int get _nights {
    final int value =
        _day(widget.checkOut)
            .difference(
              _day(widget.checkIn),
            )
            .inDays;

    return value < 1 ? 1 : value;
  }

  double get _price =>
      (widget.room['pricePerNight']
                  as num?)
              ?.toDouble() ??
          0;

  double get _total =>
      _price *
      _nights *
      _roomCount;

  String _money(double value) =>
      'Rs. '
      '${value.toStringAsFixed(0)}';

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  Future<User> _ensureUser() async {
    final User? current =
        FirebaseAuth.instance.currentUser;

    if (current != null) {
      return current;
    }

    final UserCredential credential =
        await FirebaseAuth.instance
            .signInAnonymously();

    final User? user = credential.user;

    if (user == null) {
      throw StateError(
        'Could not create customer session.',
      );
    }

    return user;
  }

  String get _partnerId =>
      widget.resort['partnerId']
              ?.toString()
              .trim() ??
          '';

  Future<void> _loadDirectPayment() async {
    final String partnerId = _partnerId;

    if (partnerId.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingDirectPayment = false;
        });
      }
      return;
    }

    try {
      final DocumentSnapshot<
              Map<String, dynamic>>
          doc =
          await FirebaseFirestore.instance
              .collection(
                'resort_direct_payment_accounts',
              )
              .doc(partnerId)
              .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _directPayment =
            doc.data() ??
                <String, dynamic>{};

        _loadingDirectPayment = false;

        final List<String> methods =
            _availablePaymentMethods();

        if (methods.isNotEmpty &&
            !methods.contains(
              _paymentMethod,
            )) {
          _paymentMethod =
              methods.first;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDirectPayment = false;
          _directPayment =
              <String, dynamic>{};
        });
      }
    }
  }

  bool get _directPaymentEnabled =>
      _directPayment['enabled'] == true &&
      _availablePaymentMethods().isNotEmpty;

  List<String> _availablePaymentMethods() {
    final List<String> methods =
        <String>[];

    if ((_directPayment['esewaNumber']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('esewa');
    }

    if ((_directPayment['khaltiNumber']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('khalti');
    }

    if ((_directPayment['bankName']
                ?.toString()
                .trim() ??
            '')
            .isNotEmpty &&
        (_directPayment['bankAccountNumber']
                ?.toString()
                .trim() ??
            '')
            .isNotEmpty) {
      methods.add('bank_transfer');
    }

    if ((_directPayment['connectIpsId']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('connectips');
    }

    if ((_directPayment[
                    'mobileBankingDetails']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('mobile_banking');
    }

    if ((_directPayment['paymentQrUrl']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('resort_qr');
    }

    return methods;
  }

  String _paymentMethodLabel(
    String method,
  ) {
    switch (method) {
      case 'esewa':
        return 'eSewa';
      case 'khalti':
        return 'Khalti';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'connectips':
        return 'connectIPS';
      case 'mobile_banking':
        return 'Mobile Banking';
      case 'resort_qr':
        return 'Resort Payment QR';
      default:
        return method;
    }
  }

  Widget _detailLine(
    String label,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _directPaymentSection() {
    if (_loadingDirectPayment) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (!_directPaymentEnabled) {
      return Container(
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange
              .withValues(alpha: 0.10),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: const Text(
          'This Resort has not enabled Direct Online Payment yet. '
          'Please choose Pay at Resort.',
          style: TextStyle(
            color: Colors.orange,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      );
    }

    final List<String> methods =
        _availablePaymentMethods();

    final String qrUrl =
        _directPayment['paymentQrUrl']
                ?.toString()
                .trim() ??
            '';

    final String instructions =
        _directPayment['instructions']
                ?.toString()
                .trim() ??
            '';

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding:
              const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _rdGreen
                .withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: const Text(
            'Payment goes DIRECTLY to this Resort account. '
            'RD Online Shop does not receive this booking payment. '
            'After transfer, enter the transaction reference and upload proof. '
            'The Resort Partner must verify actual receipt before payment becomes PAID.',
            style: TextStyle(
              color: _rdGreen,
              fontWeight:
                  FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue:
              methods.contains(
                _paymentMethod,
              )
                  ? _paymentMethod
                  : methods.first,
          decoration:
              const InputDecoration(
            labelText:
                'Direct Payment Method',
            prefixIcon: Icon(
              Icons.payments_rounded,
            ),
            border:
                OutlineInputBorder(),
          ),
          items: methods
              .map(
                (String method) =>
                    DropdownMenuItem<
                        String>(
                  value: method,
                  child: Text(
                    _paymentMethodLabel(
                      method,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }

            setState(() {
              _paymentMethod = value;
            });
          },
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding:
                const EdgeInsets.all(
              12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                Text(
                  '${widget.resort['name'] ?? 'Resort'} Receiving Details',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                if (_paymentMethod ==
                    'esewa') ...<Widget>[
                  _detailLine(
                    'Account Name',
                    _directPayment[
                                'esewaName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'eSewa ID',
                    _directPayment[
                                'esewaNumber']
                            ?.toString() ??
                        '',
                  ),
                ],
                if (_paymentMethod ==
                    'khalti') ...<Widget>[
                  _detailLine(
                    'Account Name',
                    _directPayment[
                                'khaltiName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'Khalti ID',
                    _directPayment[
                                'khaltiNumber']
                            ?.toString() ??
                        '',
                  ),
                ],
                if (_paymentMethod ==
                    'bank_transfer') ...<
                    Widget>[
                  _detailLine(
                    'Bank',
                    _directPayment[
                                'bankName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'Account Name',
                    _directPayment[
                                'bankAccountName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'Account No.',
                    _directPayment[
                                'bankAccountNumber']
                            ?.toString() ??
                        '',
                  ),
                ],
                if (_paymentMethod ==
                    'connectips')
                  _detailLine(
                    'connectIPS',
                    _directPayment[
                                'connectIpsId']
                            ?.toString() ??
                        '',
                  ),
                if (_paymentMethod ==
                    'mobile_banking')
                  _detailLine(
                    'Details',
                    _directPayment[
                                'mobileBankingDetails']
                            ?.toString() ??
                        '',
                  ),
                if (_paymentMethod ==
                        'resort_qr' &&
                    qrUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    child: Image.network(
                      qrUrl,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ),
                if (instructions.isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Resort instruction: '
                    '$instructions',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller:
              _paymentReference,
          textCapitalization:
              TextCapitalization
                  .characters,
          decoration:
              const InputDecoration(
            labelText:
                'Transaction / Payment Reference',
            hintText:
                'Enter reference after payment',
            prefixIcon: Icon(
              Icons.numbers_rounded,
            ),
            border:
                OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed:
              _uploadingPaymentProof
                  ? null
                  : _uploadPaymentProof,
          icon: _uploadingPaymentProof
              ? const SizedBox.square(
                  dimension: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  _paymentProofUrl
                          .isEmpty
                      ? Icons
                          .upload_file_rounded
                      : Icons
                          .check_circle_rounded,
                ),
          label: Text(
            _paymentProofUrl.isEmpty
                ? 'Upload Payment Proof'
                : 'Payment Proof Uploaded • Replace',
          ),
        ),
        if (_paymentProofUrl
            .isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child: Image.network(
              _paymentProofUrl,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Never enter OTP, PIN, bank password, eSewa/Khalti PIN or card PIN in RD Online Shop.',
          style: TextStyle(
            color: _rdBlue,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void>
      _uploadPaymentProof() async {
    if (_uploadingPaymentProof) {
      return;
    }

    setState(() {
      _uploadingPaymentProof = true;
    });

    try {
      final String? url =
          await ResortCloudinaryService
              .pickAndUploadImage(
        imageQuality: 88,
      );

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        _paymentProofUrl = url;
      });

      _message(
        'Payment proof uploaded.',
      );
    } catch (error) {
      _message(
        'Could not upload payment proof.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPaymentProof =
              false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    if (_guestName.text
            .trim()
            .length <
        2) {
      _message(
        'Please enter guest full name.',
      );
      return;
    }

    if (_phone.text
            .trim()
            .length <
        7) {
      _message(
        'Please enter a valid phone number.',
      );
      return;
    }

    if (_roomCount >
        widget.available) {
      _message(
        'Only ${widget.available} '
        'room(s) are available.',
      );
      return;
    }

    if (_paymentOption ==
        'direct_resort_online') {
      if (!_directPaymentEnabled) {
        _message(
          'This Resort has not enabled '
          'Direct Online Payment. '
          'Please choose Pay at Resort.',
        );
        return;
      }

      if (!_availablePaymentMethods()
          .contains(_paymentMethod)) {
        _message(
          'Please select a valid Resort payment method.',
        );
        return;
      }

      if (_paymentReference.text
          .trim()
          .isEmpty) {
        _message(
          'Enter the transaction / payment reference after paying the Resort.',
        );
        return;
      }

      if (_paymentProofUrl
          .trim()
          .isEmpty) {
        _message(
          'Upload payment proof before submitting the booking.',
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
    });

    try {
      final User user =
          await _ensureUser();

      final DocumentReference<
              Map<String, dynamic>>
          reference =
          FirebaseFirestore.instance
              .collection(
                'resort_bookings',
              )
              .doc();

      final String paymentStatus =
          _paymentOption ==
                  'pay_at_resort'
              ? 'pay_at_resort_pending'
              : _paymentOption ==
                      'direct_resort_online'
                  ? 'submitted_to_resort'
                  : 'online_pending';

      await reference.set(
        <String, dynamic>{
          'bookingId':
              reference.id,
          'serviceType': 'resort',
          'customerAuthUid':
              user.uid,
          'customerId': user.uid,
          'partnerId': widget
                  .resort['partnerId']
                  ?.toString() ??
              '',
          'resortId':
              widget.resortId,
          'resortName': widget
                  .resort['name']
                  ?.toString() ??
              'Resort',
          'resortLocation': widget
                  .resort['location']
                  ?.toString() ??
              '',
          'resortLatitude':
              (widget.resort['latitude'] as num?)
                  ?.toDouble(),
          'resortLongitude':
              (widget.resort['longitude'] as num?)
                  ?.toDouble(),
          'roomId': widget.roomId,
          'roomName': widget
                  .room['name']
                  ?.toString() ??
              'Room',
          'checkIn':
              Timestamp.fromDate(
            _day(widget.checkIn),
          ),
          'checkOut':
              Timestamp.fromDate(
            _day(widget.checkOut),
          ),
          'nights': _nights,
          'roomCount': _roomCount,
          'guestName':
              _guestName.text.trim(),
          'guestPhone':
              _phone.text.trim(),
          'pricePerNight': _price,
          'totalAmount': _total,
          'currency': 'Rs.',
          'paymentOption':
              _paymentOption,
          'paymentStatus':
              paymentStatus,
          if (_paymentOption ==
              'direct_resort_online') ...<
              String, dynamic>{
            'paymentMethod':
                _paymentMethod,
            'paymentReference':
                _paymentReference.text
                    .trim(),
            'paymentProofUrl':
                _paymentProofUrl.trim(),
            'paymentSubmittedAt':
                FieldValue
                    .serverTimestamp(),
            'paymentReceiverPartnerId':
                _partnerId,
            'paymentReceiverResortId':
                widget.resortId,
            'paymentReceiverType':
                'resort_direct',
          },
          'bookingStatus':
              'request_submitted',
          'confirmationStatus':
              'pending',
          'partnerConfirmed':
              false,
          'adminConfirmed': false,
          'refundStatus': 'none',
          'createdAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      final String bookingSubmitMessage =
          _paymentOption == 'direct_resort_online'
              ? 'Your payment proof was sent directly to the Resort Partner. '
                  'The payment becomes PAID only after the Resort confirms '
                  'that the money arrived in its own receiving account.\n\n'
                  'The Resort Partner will also confirm room availability. '
                  'This request is not a confirmed reservation until '
                  'the booking status becomes Confirmed.'
              : 'The Resort Partner will confirm '
                  'availability. This request is not '
                  'a confirmed reservation until '
                  'the status becomes Confirmed.';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (
          BuildContext dialogContext,
        ) {
          return AlertDialog(
            icon: const Icon(
              Icons
                  .check_circle_rounded,
              color: _rdGreen,
              size: 44,
            ),
            title: const Text(
              'Booking Request Submitted',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            content: Text(
              'Booking ID: ${reference.id}\n'
              '${widget.resort['name'] ?? 'Resort'}\n'
              '${widget.room['name'] ?? 'Room'} × $_roomCount\n'
              '${_date(widget.checkIn)} → '
              '${_date(widget.checkOut)}\n'
              'Total: ${_money(_total)}\n\n'
              '$bookingSubmitMessage',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                ),
                child:
                    const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      _message(
        'Could not submit booking.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Widget _row(
    String label,
    String value, {
    bool strong = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Book Room',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 700,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: <Widget>[
                        Text(
                          widget.resort[
                                      'name']
                                  ?.toString() ??
                              'Resort',
                          style:
                              const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        Text(
                          widget.room[
                                      'name']
                                  ?.toString() ??
                              'Room',
                        ),
                        Text(
                          '${_money(_price)} / night',
                          style:
                              const TextStyle(
                            color: _rdBlue,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        Text(
                          '${widget.available} room(s) available for selected dates',
                          style:
                              const TextStyle(
                            color:
                                _rdGreen,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextField(
                  controller:
                      _guestName,
                  textCapitalization:
                      TextCapitalization
                          .words,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Guest Full Name',
                    prefixIcon:
                        Icon(
                      Icons
                          .person_rounded,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextField(
                  controller: _phone,
                  keyboardType:
                      TextInputType.phone,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Phone Number',
                    prefixIcon:
                        Icon(
                      Icons
                          .phone_rounded,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(12),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Number of Rooms',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _roomCount > 1
                                  ? () =>
                                      setState(
                                        () {
                                          _roomCount--;
                                        },
                                      )
                                  : null,
                          icon: const Icon(
                            Icons
                                .remove_circle_outline_rounded,
                          ),
                        ),
                        Text(
                          '$_roomCount',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _roomCount <
                                      widget
                                          .available
                                  ? () =>
                                      setState(
                                        () {
                                          _roomCount++;
                                        },
                                      )
                                  : null,
                          icon: const Icon(
                            Icons
                                .add_circle_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: <Widget>[
                        const Text(
                          'Payment Option',
                          style:
                              TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        SegmentedButton<
                            String>(
                          segments: const <
                              ButtonSegment<
                                  String>>[
                            ButtonSegment<
                                String>(
                              value:
                                  'pay_at_resort',
                              label: Text(
                                'Pay at Resort',
                              ),
                              icon: Icon(
                                Icons
                                    .hotel_rounded,
                              ),
                            ),
                            ButtonSegment<
                                String>(
                              value:
                                  'direct_resort_online',
                              label: Text(
                                'Direct Online to Resort',
                              ),
                              icon: Icon(
                                Icons
                                    .payments_rounded,
                              ),
                            ),
                          ],
                          selected: <String>{
                            _paymentOption,
                          },
                          onSelectionChanged:
                              (
                            Set<String>
                                value,
                          ) {
                            setState(() {
                              _paymentOption =
                                  value.first;
                            });
                          },
                        ),
                        if (_paymentOption ==
                            'direct_resort_online') ...<
                            Widget>[
                          const SizedBox(
                            height: 10,
                          ),
                          _directPaymentSection(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(14),
                    child: Column(
                      children: <Widget>[
                        _row(
                          'Check-in',
                          _date(
                            widget
                                .checkIn,
                          ),
                        ),
                        _row(
                          'Check-out',
                          _date(
                            widget
                                .checkOut,
                          ),
                        ),
                        _row(
                          'Nights',
                          '$_nights',
                        ),
                        _row(
                          'Rooms',
                          '$_roomCount',
                        ),
                        const Divider(),
                        _row(
                          'Total',
                          _money(
                            _total,
                          ),
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                SizedBox(
                  height: 52,
                  child:
                      FilledButton.icon(
                    onPressed:
                        _submitting
                            ? null
                            : _submit,
                    icon: _submitting
                        ? const SizedBox
                            .square(
                            dimension: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .book_online_rounded,
                          ),
                    label: const Text(
                      'Submit Booking Request',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyResortBookingsPage
    extends StatelessWidget {
  const MyResortBookingsPage({
    super.key,
  });

  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  String _date(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }

    final DateTime date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _cancel(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) async {
    String reason = '';

    final String? result =
        await showDialog<String>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Request Cancellation',
          ),
          content: TextField(
            maxLines: 3,
            onChanged: (String value) {
              reason = value.trim();
            },
            decoration:
                const InputDecoration(
              labelText: 'Reason',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child:
                  const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.isNotEmpty) {
                  Navigator.pop(
                    dialogContext,
                    reason,
                  );
                }
              },
              child: const Text(
                'Request Cancel',
              ),
            ),
          ],
        );
      },
    );

    if (result == null ||
        result.trim().isEmpty ||
        !context.mounted) {
      return;
    }

    try {
      await doc.reference.update(
        <String, dynamic>{
          'bookingStatus':
              'cancel_requested',
          'cancellationReason':
              result.trim(),
          'cancelRequestedAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Cancellation requested.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not request cancellation.\n'
            '$error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No customer session found.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'My Resort Bookings',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(
              'resort_bookings',
            )
            .where(
              'customerAuthUid',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  QuerySnapshot<
                      Map<String, dynamic>>>
              snapshot,
        ) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load bookings.\n'
                '${snapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            );
          }

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              docs =
              snapshot.data?.docs ??
                  <QueryDocumentSnapshot<
                      Map<String, dynamic>>>[];

          docs.sort(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  first,
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  second,
            ) {
              final Timestamp? a =
                  first.data()['createdAt']
                      as Timestamp?;

              final Timestamp? b =
                  second.data()['createdAt']
                      as Timestamp?;

              return (b
                          ?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                a?.millisecondsSinceEpoch ??
                    0,
              );
            },
          );

          return Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 900,
              ),
              child: ListView(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                children: docs.isEmpty
                    ? <Widget>[
                        const Card(
                          child: Padding(
                            padding:
                                EdgeInsets.all(
                              24,
                            ),
                            child: Text(
                              'No resort booking yet.',
                              textAlign:
                                  TextAlign.center,
                            ),
                          ),
                        ),
                      ]
                    : docs
                        .map(
                          (
                            QueryDocumentSnapshot<
                                    Map<String,
                                        dynamic>>
                                doc,
                          ) =>
                              _bookingCard(
                            context,
                            doc,
                          ),
                        )
                        .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bookingCard(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final String status =
        data['bookingStatus']
                ?.toString() ??
            'request_submitted';

    final bool cancellable =
        <String>[
      'request_submitted',
      'confirmed',
    ].contains(status);

    final bool issued =
        <String>[
      'confirmed',
      'checked_in',
      'completed',
    ].contains(status);

    final bool issueClosed =
        <String>[
      'rejected',
      'cancelled',
    ].contains(status);

    final String issueText =
        issued
            ? 'ISSUED'
            : issueClosed
                ? 'CLOSED'
                : 'NOT ISSUED';

    final Color issueColor =
        issued
            ? _rdGreen
            : issueClosed
                ? _rdRed
                : Colors.orange;

    final double? resortLatitude =
        (data['resortLatitude'] as num?)
            ?.toDouble();

    final double? resortLongitude =
        (data['resortLongitude'] as num?)
            ?.toDouble();

    Color statusColor = Colors.orange;

    if (status == 'confirmed' ||
        status == 'checked_in' ||
        status == 'completed') {
      statusColor = _rdGreen;
    } else if (status == 'cancelled' ||
        status == 'rejected') {
      statusColor = _rdRed;
    }

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    data['resortName']
                            ?.toString() ??
                        'Resort',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              data['roomName']
                      ?.toString() ??
                  'Room',
            ),
            Text(
              '${_date(data['checkIn'])} → '
              '${_date(data['checkOut'])}',
            ),
            Text(
              '${data['roomCount'] ?? 0} room(s) • '
              '${data['nights'] ?? 0} night(s)',
            ),
            Text(
              'Total: Rs. '
              '${((data['totalAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            Text(
              'Payment: '
              '${data['paymentStatus'] ?? ''}',
            ),
            if (data['paymentOption'] ==
                'direct_resort_online') ...<
                Widget>[
              Text(
                'Direct to Resort: '
                '${data['paymentMethod'] ?? ''}',
              ),
              SelectableText(
                'Transaction / Reference: '
                '${data['paymentReference'] ?? ''}',
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: issueColor
                    .withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: issueColor
                      .withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    issued
                        ? Icons
                            .verified_rounded
                        : Icons
                            .confirmation_number_outlined,
                    color: issueColor,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Booking Voucher: '
                          '$issueText',
                          style: TextStyle(
                            color: issueColor,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        Text(
                          issued
                              ? 'Resort booking is confirmed. '
                                  'Show this booking ID at the resort.'
                              : issueClosed
                                  ? 'This booking is no longer active.'
                                  : 'Voucher will be issued automatically '
                                      'after Resort Partner confirms the booking.',
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (issued) ...<Widget>[
              const SizedBox(height: 8),
              SelectableText(
                'Issued Booking ID: ${doc.id}',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
            if ((data['rejectionReason']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Reason: '
                '${data['rejectionReason']}',
                style: const TextStyle(
                  color: _rdRed,
                ),
              ),
            if ((data['cancellationReason']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Cancellation: '
                '${data['cancellationReason']}',
                style: const TextStyle(
                  color: Colors.orange,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                double? latitude =
                    resortLatitude;
                double? longitude =
                    resortLongitude;

                if ((latitude == null ||
                        longitude == null) &&
                    (data['resortId']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty) {
                  try {
                    final DocumentSnapshot<
                            Map<String, dynamic>>
                        resortDoc =
                        await FirebaseFirestore
                            .instance
                            .collection(
                              'resorts',
                            )
                            .doc(
                              data['resortId']
                                  .toString(),
                            )
                            .get();

                    latitude =
                        (resortDoc.data()?[
                                    'latitude']
                                as num?)
                            ?.toDouble();

                    longitude =
                        (resortDoc.data()?[
                                    'longitude']
                                as num?)
                            ?.toDouble();
                  } catch (_) {
                    // The common navigation helper
                    // will show the missing-GPS message.
                  }
                }

                if (!context.mounted) {
                  return;
                }

                await _openResortDirections(
                  context,
                  resortLatitude:
                      latitude,
                  resortLongitude:
                      longitude,
                  resortName:
                      data['resortName']
                              ?.toString() ??
                          'Resort',
                );
              },
              icon: const Icon(
                Icons.navigation_rounded,
              ),
              label: const Text(
                'Navigate to Resort from My Live Location',
              ),
            ),
            if (cancellable) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _cancel(
                  context,
                  doc,
                ),
                icon: const Icon(
                  Icons
                      .event_busy_rounded,
                ),
                label: const Text(
                  'Request Cancellation',
                ),
              ),
            ],
            const SizedBox(height: 5),
            SelectableText(
              'Booking ID: ${doc.id}',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResortSummary {
  const _ResortSummary({
    required this.activeRoomTypes,
    required this.availableRooms,
    required this.lowestAvailablePrice,
  });

  final int activeRoomTypes;
  final int availableRooms;
  final double? lowestAvailablePrice;
}
