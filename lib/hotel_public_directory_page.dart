import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HotelPublicDirectoryPage extends StatefulWidget {
  const HotelPublicDirectoryPage({super.key});

  @override
  State<HotelPublicDirectoryPage> createState() =>
      _HotelPublicDirectoryPageState();
}

class _HotelPublicDirectoryPageState
    extends State<HotelPublicDirectoryPage> {
  static const Color _rdBlue = Color(0xFF1565C0);
  static const Color _rdGreen = Color(0xFF2E7D32);

  final TextEditingController _searchController =
      TextEditingController();

  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> hotel) {
    final String query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    final String haystack = <String>[
      hotel['name']?.toString() ?? '',
      hotel['location']?.toString() ?? '',
      hotel['address']?.toString() ?? '',
      hotel['city']?.toString() ?? '',
      hotel['area']?.toString() ?? '',
      hotel['description']?.toString() ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  String _text(
    Map<String, dynamic> data,
    String key, {
    String fallback = '',
  }) {
    final String value =
        data[key]?.toString().trim() ?? '';

    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'A signed-in customer or Hotel Partner session is required.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Browse Hotels',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
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
                    QuerySnapshot<Map<String, dynamic>>>
                snapshot,
          ) {
            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load public Hotel information.\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                hotels = <QueryDocumentSnapshot<
                    Map<String, dynamic>>>[
              ...?snapshot.data?.docs,
            ].where(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    doc,
              ) =>
                  _matches(doc.data()),
            ).toList();

            hotels.sort(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    first,
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    second,
              ) =>
                  _text(
                    first.data(),
                    'name',
                    fallback: 'Hotel',
                  ).toLowerCase().compareTo(
                        _text(
                          second.data(),
                          'name',
                          fallback: 'Hotel',
                        ).toLowerCase(),
                      ),
            );

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _rdBlue.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.security_rounded,
                            color: _rdBlue,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Public Hotel View only. You can see approved Hotel '
                              'profile, contact, facilities and room information. '
                              'Customer names, booking IDs, phone numbers, payments, '
                              'Hotel fees and private Partner details are not shown.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (String value) {
                        setState(() {
                          _search = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Search Hotel / City / Area',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                        ),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _search = '';
                                  });
                                },
                                icon: const Icon(
                                  Icons.clear_rounded,
                                ),
                              ),
                        border:
                            const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Approved Hotels (${hotels.length})',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (hotels.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No approved active Hotel found.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...hotels.map(
                        (
                          QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              doc,
                        ) =>
                            _hotelCard(
                          context,
                          doc,
                          user.uid,
                        ),
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

  Widget _hotelCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUid,
  ) {
    final Map<String, dynamic> hotel = doc.data();

    final String name =
        _text(hotel, 'name', fallback: 'Hotel');

    final String location =
        _text(hotel, 'location');

    final String city = _text(hotel, 'city');

    final String area = _text(hotel, 'area');

    final String coverUrl =
        _text(hotel, 'coverUrl');

    final String profileUrl =
        _text(hotel, 'profileUrl');

    final bool ownHotel =
        _text(hotel, 'partnerId') == currentUid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _HotelPublicDetailPage(
              hotelId: doc.id,
              hotel: hotel,
              isOwnHotel: ownHotel,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) =>
                              _imageFallback(),
                    )
                  else
                    _imageFallback(),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: CircleAvatar(
                      radius: 31,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          profileUrl.isNotEmpty
                              ? NetworkImage(profileUrl)
                              : null,
                      child: profileUrl.isEmpty
                          ? const Icon(
                              Icons.hotel_rounded,
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                  if (ownHotel)
                    const Positioned(
                      right: 12,
                      top: 12,
                      child: Chip(
                        avatar: Icon(
                          Icons.verified_rounded,
                          color: _rdGreen,
                          size: 18,
                        ),
                        label: Text(
                          'MY HOTEL',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (location.isNotEmpty)
                    Text(
                      location,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (city.isNotEmpty || area.isNotEmpty)
                    Text(
                      <String>[
                        if (area.isNotEmpty) area,
                        if (city.isNotEmpty) city,
                      ].join(', '),
                    ),
                  const SizedBox(height: 10),
                  const Row(
                    children: <Widget>[
                      Icon(
                        Icons.visibility_rounded,
                        size: 18,
                        color: _rdBlue,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'View public Hotel details',
                        style: TextStyle(
                          color: _rdBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.hotel_rounded,
          size: 62,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _HotelPublicDetailPage extends StatelessWidget {
  const _HotelPublicDetailPage({
    required this.hotelId,
    required this.hotel,
    required this.isOwnHotel,
  });

  final String hotelId;
  final Map<String, dynamic> hotel;
  final bool isOwnHotel;

  static const Color _rdBlue = Color(0xFF1565C0);
  static const Color _rdGreen = Color(0xFF2E7D32);

  String _text(
    String key, {
    String fallback = '',
  }) {
    final String value =
        hotel[key]?.toString().trim() ?? '';

    return value.isEmpty ? fallback : value;
  }

  List<String> _strings(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ?? 0;

    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final String name =
        _text('name', fallback: 'Hotel');

    final String coverUrl =
        _text('coverUrl');

    final String profileUrl =
        _text('profileUrl');

    final List<String> photos =
        _strings(hotel['photoUrls']);

    final List<String> facilities =
        _strings(hotel['facilities']);

    final String description =
        _text('description');

    final String location =
        _text('location');

    final String address =
        _text('address');

    final String phone =
        _text('phone');

    final String email =
        _text('email');

    final String checkIn =
        _text('checkInTime');

    final String checkOut =
        _text('checkOutTime');

    final String cancellation =
        _text('cancellationPolicy');

    final String houseRules =
        _text('houseRules');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 220,
                    child: coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) =>
                                    _coverFallback(),
                          )
                        : _coverFallback(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 34,
                      backgroundImage:
                          profileUrl.isNotEmpty
                              ? NetworkImage(profileUrl)
                              : null,
                      child: profileUrl.isEmpty
                          ? const Icon(
                              Icons.hotel_rounded,
                              size: 34,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (isOwnHotel)
                                const Chip(
                                  label: Text(
                                    'MY HOTEL',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (location.isNotEmpty)
                            Text(
                              location,
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          if (address.isNotEmpty)
                            Text(address),
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _section(
                    title: 'About Hotel',
                    child: Text(
                      description,
                      style: const TextStyle(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                if (phone.isNotEmpty ||
                    email.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _section(
                    title: 'Public Contact',
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        if (phone.isNotEmpty)
                          SelectableText(
                            'Phone: $phone',
                          ),
                        if (email.isNotEmpty)
                          SelectableText(
                            'Email: $email',
                          ),
                      ],
                    ),
                  ),
                ],
                if (facilities.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _section(
                    title: 'Facilities',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: facilities
                          .map(
                            (String item) => Chip(
                              avatar: const Icon(
                                Icons.check_circle_rounded,
                                color: _rdGreen,
                                size: 18,
                              ),
                              label: Text(item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (photos.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _section(
                    title: 'Hotel Photos',
                    child: SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(width: 8),
                        itemBuilder: (
                          BuildContext context,
                          int index,
                        ) {
                          return ClipRRect(
                            borderRadius:
                                BorderRadius.circular(12),
                            child: Image.network(
                              photos[index],
                              width: 220,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) =>
                                      Container(
                                width: 220,
                                color:
                                    Colors.grey.shade200,
                                child: const Icon(
                                  Icons
                                      .image_not_supported_outlined,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                if (checkIn.isNotEmpty ||
                    checkOut.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _section(
                    title: 'Check-in / Check-out',
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        if (checkIn.isNotEmpty)
                          Text(
                            'Check-in: $checkIn',
                          ),
                        if (checkOut.isNotEmpty)
                          Text(
                            'Check-out: $checkOut',
                          ),
                      ],
                    ),
                  ),
                ],
                if (cancellation.isNotEmpty ||
                    houseRules.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _section(
                    title: 'Policies',
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        if (cancellation.isNotEmpty) ...<
                            Widget>[
                          const Text(
                            'Cancellation Policy',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(cancellation),
                          const SizedBox(height: 8),
                        ],
                        if (houseRules.isNotEmpty) ...<Widget>[
                          const Text(
                            'House Rules',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(houseRules),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Rooms',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('hotel_rooms')
                      .where(
                        'hotelId',
                        isEqualTo: hotelId,
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
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child:
                              CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Card(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(18),
                          child: Text(
                            'Could not load public room information.\n'
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final List<
                            QueryDocumentSnapshot<
                                Map<String, dynamic>>>
                        rooms =
                        snapshot.data?.docs ??
                            <QueryDocumentSnapshot<
                                Map<String, dynamic>>>[];

                    if (rooms.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No active public room information is available.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: rooms
                          .map(
                            (
                              QueryDocumentSnapshot<
                                      Map<String, dynamic>>
                                  room,
                            ) =>
                                _roomCard(
                              room.data(),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _rdBlue.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Privacy protected: this page does not read Hotel bookings, '
                    'customer records, Hotel fee invoices/payments, bank details '
                    'or private Hotel Partner registration documents.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
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

  Widget _roomCard(Map<String, dynamic> room) {
    final String name =
        room['name']?.toString().trim().isNotEmpty == true
            ? room['name'].toString().trim()
            : 'Room';

    final String roomClass =
        room['roomClass']?.toString().trim() ?? '';

    final String bed =
        room['bed']?.toString().trim() ?? '';

    final String description =
        room['description']?.toString().trim() ?? '';

    final String photoUrl =
        room['photoUrl']?.toString().trim() ?? '';

    final List<String> photos =
        room['photoUrls'] is List
            ? (room['photoUrls'] as List<dynamic>)
                .map(
                  (dynamic item) =>
                      item.toString().trim(),
                )
                .where(
                  (String item) => item.isNotEmpty,
                )
                .toList()
            : <String>[];

    final String displayPhoto =
        photoUrl.isNotEmpty
            ? photoUrl
            : photos.isNotEmpty
                ? photos.first
                : '';

    final List<String> facilities =
        room['facilities'] is List
            ? (room['facilities'] as List<dynamic>)
                .map(
                  (dynamic item) =>
                      item.toString().trim(),
                )
                .where(
                  (String item) => item.isNotEmpty,
                )
                .toList()
            : <String>[];

    final bool isAc =
        room['isAc'] == true;

    final bool breakfast =
        room['breakfastIncluded'] == true;

    final bool freeCancellation =
        room['freeCancellation'] == true;

    final int maxGuests =
        (room['maxGuests'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: <Widget>[
          if (displayPhoto.isNotEmpty)
            Image.network(
              displayPhoto,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) =>
                      const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (roomClass.isNotEmpty ||
                    bed.isNotEmpty)
                  Text(
                    <String>[
                      if (roomClass.isNotEmpty)
                        roomClass,
                      isAc ? 'AC Room' : 'Non-AC Room',
                      if (bed.isNotEmpty) bed,
                    ].join(' • '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(description),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    if (maxGuests > 0)
                      Chip(
                        label: Text(
                          'Max $maxGuests guests',
                        ),
                      ),
                    if (breakfast)
                      const Chip(
                        label:
                            Text('Breakfast Included'),
                      ),
                    if (freeCancellation)
                      const Chip(
                        label:
                            Text('Free Cancellation'),
                      ),
                  ],
                ),
                if (facilities.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 7),
                  Text(
                    facilities.join(' • '),
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  '${_money(room['pricePerNight'])} / night',
                  style: const TextStyle(
                    color: _rdBlue,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.hotel_rounded,
          size: 70,
          color: Colors.grey,
        ),
      ),
    );
  }
}
