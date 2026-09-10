import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openHotelDirections(
  BuildContext context, {
  required double? hotelLatitude,
  required double? hotelLongitude,
  required String hotelName,
}) async {
  if (hotelLatitude == null ||
      hotelLongitude == null) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Hotel GPS location is not saved yet. '
            'Hotel Partner must enable Location, capture current location '
            'and save the Hotel Profile first.',
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
            '$hotelLatitude,$hotelLongitude',
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
            'Could not start navigation to $hotelName.\n$error',
          ),
        ),
      );
  }
}

Future<void> _openHotelPin(
  BuildContext context, {
  required double? hotelLatitude,
  required double? hotelLongitude,
  required String hotelName,
}) async {
  if (hotelLatitude == null ||
      hotelLongitude == null) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Hotel GPS location is not saved yet.',
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
        'query': '$hotelLatitude,$hotelLongitude',
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
            'Could not open $hotelName location.\n$error',
          ),
        ),
      );
  }
}

class HotelBookingPage extends StatefulWidget {
  const HotelBookingPage({super.key});

  @override
  State<HotelBookingPage> createState() =>
      _HotelBookingPageState();
}

class _HotelBookingPageState
    extends State<HotelBookingPage> {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _sessionReady = true;
        _sessionError = '';
      });
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

  bool _matches(
    Map<String, dynamic> data,
  ) {
    final String query =
        _search.text
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    return <String>[
      data['name']?.toString() ?? '',
      data['location']?.toString() ?? '',
      data['city']?.toString() ?? '',
      data['area']?.toString() ?? '',
    ].any(
      (String value) =>
          value
              .toLowerCase()
              .contains(query),
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

    if (dates.isEmpty) {
      return 0;
    }

    for (final DateTime date in dates) {
      final DocumentSnapshot<
              Map<String, dynamic>>
          inventory =
          await FirebaseFirestore.instance
              .collection(
                'hotel_room_inventory',
              )
              .doc(
                '${roomId}_${_dateKey(date)}',
              )
              .get();

      if (!inventory.exists) {
        continue;
      }

      final Map<String, dynamic> data =
          inventory.data() ??
              <String, dynamic>{};

      if (data['isOpen'] == false) {
        return 0;
      }

      final int available =
          (data['availableRooms'] as num?)
                  ?.toInt() ??
              0;

      if (available < minimum) {
        minimum = available;
      }
    }

    return minimum < 0 ? 0 : minimum;
  }

  Future<_HotelSummary>
      _hotelAvailability(
    String hotelId,
  ) async {
    final QuerySnapshot<
            Map<String, dynamic>>
        rooms =
        await FirebaseFirestore.instance
            .collection('hotel_rooms')
            .where(
              'hotelId',
              isEqualTo: hotelId,
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

    return _HotelSummary(
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
            const MyHotelBookingsPage(),
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
                  .hotel_class_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose an approved hotel. '
              'Check photos, facilities, room price '
              'and real date-wise availability before booking.',
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
                    'Search hotel or location',
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

  Widget _hotelCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> hotel =
        doc.data();

    final String cover =
        hotel['coverUrl']
                ?.toString()
                .trim() ??
            '';

    final String profile =
        hotel['profileUrl']
                ?.toString()
                .trim() ??
            '';

    return FutureBuilder<_HotelSummary>(
      future:
          _hotelAvailability(doc.id),
      builder: (
        BuildContext context,
        AsyncSnapshot<_HotelSummary>
            snapshot,
      ) {
        final bool loading =
            snapshot.connectionState ==
                ConnectionState.waiting;

        final _HotelSummary summary =
            snapshot.data ??
                const _HotelSummary(
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
                    HotelDetailsPage(
                  hotelId: doc.id,
                  hotel: hotel,
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
                                        .hotel_class_rounded,
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
                              hotel['name']
                                      ?.toString() ??
                                  'Hotel',
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
                              hotel['location']
                                      ?.toString() ??
                                  '',
                            ),
                            if ((hotel['phone']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty)
                              SelectableText(
                                hotel['phone']
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
              const Text('Hotels'),
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

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Hotels',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip:
                'My Hotel Bookings',
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
              .collection('hotels')
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
                    'Could not load hotels.\n'
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
                    Text(
                      'Available Hotels '
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
                            'No approved hotel is available yet.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...docs.map(
                        _hotelCard,
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

class HotelDetailsPage
    extends StatelessWidget {
  const HotelDetailsPage({
    required this.hotelId,
    required this.hotel,
    required this.checkIn,
    required this.checkOut,
    super.key,
  });

  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);

  final String hotelId;
  final Map<String, dynamic> hotel;
  final DateTime checkIn;
  final DateTime checkOut;

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  Widget _hotelGallery() {
    final List<dynamic> photos =
        hotel['photoUrls'] is List
            ? hotel['photoUrls']
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
        hotel['coverUrl']
                ?.toString()
                .trim() ??
            '';

    final String profile =
        hotel['profileUrl']
                ?.toString()
                .trim() ??
            '';

    final List<dynamic> facilities =
        hotel['facilities'] is List
            ? hotel['facilities']
                as List<dynamic>
            : <dynamic>[];

    final double? hotelLatitude =
        (hotel['latitude'] as num?)?.toDouble();

    final double? hotelLongitude =
        (hotel['longitude'] as num?)?.toDouble();

    final bool hasHotelGps =
        hotelLatitude != null &&
            hotelLongitude != null;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          hotel['name']?.toString() ??
              'Hotel',
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
                                              .hotel_class_rounded,
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
                                    hotel['name']
                                            ?.toString() ??
                                        'Hotel',
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
                                          hotel['location']?.toString() ??
                                              '',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((hotel['phone']
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
                                          hotel['phone']
                                              .toString(),
                                        ),
                                      ],
                                    ),
                                  if ((hotel['email']
                                              ?.toString()
                                              .trim() ??
                                          '')
                                      .isNotEmpty)
                                    SelectableText(
                                      hotel['email']
                                          .toString(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((hotel['description']
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
                            hotel[
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
                          'Hotel Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasHotelGps
                              ? 'Hotel GPS location is saved. '
                                  'You can view the hotel pin or navigate '
                                  'from your current live location.'
                              : 'Hotel GPS location has not been saved yet.',
                          style: TextStyle(
                            color: hasHotelGps
                                ? _rdGreen
                                : Colors.orange,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        if (hasHotelGps) ...<Widget>[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openHotelPin(
                                  context,
                                  hotelLatitude:
                                      hotelLatitude,
                                  hotelLongitude:
                                      hotelLongitude,
                                  hotelName:
                                      hotel['name']
                                              ?.toString() ??
                                          'Hotel',
                                ),
                                icon: const Icon(
                                  Icons
                                      .location_on_rounded,
                                ),
                                label: const Text(
                                  'View Hotel Location',
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    _openHotelDirections(
                                  context,
                                  hotelLatitude:
                                      hotelLatitude,
                                  hotelLongitude:
                                      hotelLongitude,
                                  hotelName:
                                      hotel['name']
                                              ?.toString() ??
                                          'Hotel',
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
                _hotelGallery(),
                if ((hotel['photoUrls']
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
                            'Hotel Facilities',
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
                if ((hotel['cancellationPolicy']
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
                        hotel[
                                'cancellationPolicy']
                            .toString(),
                      ),
                    ),
                  ),
                ],
                if ((hotel['houseRules']
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
                        hotel['houseRules']
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
                        'hotel_rooms',
                      )
                      .where(
                        'hotelId',
                        isEqualTo:
                            hotelId,
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
                              hotelId:
                                  hotelId,
                              hotel: hotel,
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
    required this.hotelId,
    required this.hotel,
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

  final String hotelId;
  final Map<String, dynamic> hotel;
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

    int minimum =
        (room['totalRooms'] as num?)
                ?.toInt() ??
            0;

    for (final DateTime date
        in _stayDates()) {
      final DocumentSnapshot<
              Map<String, dynamic>>
          inventory =
          await FirebaseFirestore.instance
              .collection(
                'hotel_room_inventory',
              )
              .doc(
                '${roomDoc.id}_${_dateKey(date)}',
              )
              .get();

      if (!inventory.exists) {
        continue;
      }

      final Map<String, dynamic> data =
          inventory.data() ??
              <String, dynamic>{};

      if (data['isOpen'] == false) {
        return 0;
      }

      final int available =
          (data['availableRooms'] as num?)
                  ?.toInt() ??
              0;

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
                                            HotelRoomBookingPage(
                                      hotelId:
                                          hotelId,
                                      hotel:
                                          hotel,
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

class HotelRoomBookingPage
    extends StatefulWidget {
  const HotelRoomBookingPage({
    required this.hotelId,
    required this.hotel,
    required this.roomId,
    required this.room,
    required this.checkIn,
    required this.checkOut,
    required this.available,
    super.key,
  });

  final String hotelId;
  final Map<String, dynamic> hotel;
  final String roomId;
  final Map<String, dynamic> room;
  final DateTime checkIn;
  final DateTime checkOut;
  final int available;

  @override
  State<HotelRoomBookingPage>
      createState() =>
          _HotelRoomBookingPageState();
}

class _HotelRoomBookingPageState
    extends State<HotelRoomBookingPage> {
  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);

  final TextEditingController
      _guestName =
      TextEditingController();

  final TextEditingController _phone =
      TextEditingController();

  int _roomCount = 1;

  String _paymentOption =
      'pay_at_hotel';

  bool _submitting = false;

  @override
  void dispose() {
    _guestName.dispose();
    _phone.dispose();
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
                'hotel_bookings',
              )
              .doc();

      final String paymentStatus =
          _paymentOption ==
                  'pay_at_hotel'
              ? 'pay_at_hotel_pending'
              : 'online_pending';

      await reference.set(
        <String, dynamic>{
          'bookingId':
              reference.id,
          'serviceType': 'hotel',
          'customerAuthUid':
              user.uid,
          'customerId': user.uid,
          'partnerId': widget
                  .hotel['partnerId']
                  ?.toString() ??
              '',
          'hotelId':
              widget.hotelId,
          'hotelName': widget
                  .hotel['name']
                  ?.toString() ??
              'Hotel',
          'hotelLocation': widget
                  .hotel['location']
                  ?.toString() ??
              '',
          'hotelLatitude':
              (widget.hotel['latitude'] as num?)
                  ?.toDouble(),
          'hotelLongitude':
              (widget.hotel['longitude'] as num?)
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
              'Booking ID: '
              '${reference.id}\n'
              '${widget.hotel['name'] ?? 'Hotel'}\n'
              '${widget.room['name'] ?? 'Room'} × $_roomCount\n'
              '${_date(widget.checkIn)} → '
              '${_date(widget.checkOut)}\n'
              'Total: '
              '${_money(_total)}\n\n'
              'The Hotel Partner will confirm '
              'availability. This request is not '
              'a confirmed reservation until '
              'the status becomes Confirmed.',
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
                          widget.hotel[
                                      'name']
                                  ?.toString() ??
                              'Hotel',
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
                                  'pay_at_hotel',
                              label: Text(
                                'Pay at Hotel',
                              ),
                              icon: Icon(
                                Icons
                                    .hotel_rounded,
                              ),
                            ),
                            ButtonSegment<
                                String>(
                              value:
                                  'online',
                              label: Text(
                                'Online',
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
                            'online') ...<
                            Widget>[
                          const SizedBox(
                            height: 8,
                          ),
                          const Text(
                            'Online payment gateway is not connected yet. '
                            'The booking will be saved as Online Pending.',
                            style: TextStyle(
                              color:
                                  Colors.orange,
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

class MyHotelBookingsPage
    extends StatelessWidget {
  const MyHotelBookingsPage({
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
          'My Hotel Bookings',
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
              'hotel_bookings',
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
                              'No hotel booking yet.',
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

    final double? hotelLatitude =
        (data['hotelLatitude'] as num?)
            ?.toDouble();

    final double? hotelLongitude =
        (data['hotelLongitude'] as num?)
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
                    data['hotelName']
                            ?.toString() ??
                        'Hotel',
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
                              ? 'Hotel booking is confirmed. '
                                  'Show this booking ID at the hotel.'
                              : issueClosed
                                  ? 'This booking is no longer active.'
                                  : 'Voucher will be issued automatically '
                                      'after Hotel Partner confirms the booking.',
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
                    hotelLatitude;
                double? longitude =
                    hotelLongitude;

                if ((latitude == null ||
                        longitude == null) &&
                    (data['hotelId']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty) {
                  try {
                    final DocumentSnapshot<
                            Map<String, dynamic>>
                        hotelDoc =
                        await FirebaseFirestore
                            .instance
                            .collection(
                              'hotels',
                            )
                            .doc(
                              data['hotelId']
                                  .toString(),
                            )
                            .get();

                    latitude =
                        (hotelDoc.data()?[
                                    'latitude']
                                as num?)
                            ?.toDouble();

                    longitude =
                        (hotelDoc.data()?[
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

                await _openHotelDirections(
                  context,
                  hotelLatitude:
                      latitude,
                  hotelLongitude:
                      longitude,
                  hotelName:
                      data['hotelName']
                              ?.toString() ??
                          'Hotel',
                );
              },
              icon: const Icon(
                Icons.navigation_rounded,
              ),
              label: const Text(
                'Navigate to Hotel from My Live Location',
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

class _HotelSummary {
  const _HotelSummary({
    required this.activeRoomTypes,
    required this.availableRooms,
    required this.lowestAvailablePrice,
  });

  final int activeRoomTypes;
  final int availableRooms;
  final double? lowestAvailablePrice;
}
