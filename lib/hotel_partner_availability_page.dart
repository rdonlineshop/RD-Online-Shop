import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HotelPartnerAvailabilityPage
    extends StatefulWidget {
  const HotelPartnerAvailabilityPage({
    super.key,
  });

  @override
  State<HotelPartnerAvailabilityPage>
      createState() =>
          _HotelPartnerAvailabilityPageState();
}

class _HotelPartnerAvailabilityPageState
    extends State<
        HotelPartnerAvailabilityPage> {
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  String? _roomId;

  DateTime _from =
      DateTime.now()
          .add(const Duration(days: 1));

  DateTime _to =
      DateTime.now()
          .add(const Duration(days: 1));

  int _blockedRooms = 0;
  bool _isOpen = true;
  bool _saving = false;

  User? get _user =>
      FirebaseAuth.instance.currentUser;

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

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Future<void> _pickFrom() async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          _from.isBefore(first)
              ? first
              : _from,
      firstDate: first,
      lastDate:
          DateTime(now.year + 2, 12, 31),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _from = picked;

      if (_to.isBefore(_from)) {
        _to = _from;
      }
    });

    await _loadSelectedDay();
  }

  Future<void> _pickTo() async {
    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          _to.isBefore(_from)
              ? _from
              : _to,
      firstDate: _from,
      lastDate:
          DateTime(_from.year + 2, 12, 31),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _to = picked;
    });
  }

  Future<void> _loadSelectedDay() async {
    final String? roomId = _roomId;

    if (roomId == null) {
      return;
    }

    try {
      final DocumentSnapshot<
              Map<String, dynamic>>
          doc =
          await FirebaseFirestore.instance
              .collection(
                'hotel_room_inventory',
              )
              .doc(
                '${roomId}_${_dateKey(_from)}',
              )
              .get();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic>? data =
          doc.data();

      setState(() {
        _blockedRooms =
            (data?['blockedRooms'] as num?)
                    ?.toInt() ??
                0;

        _isOpen =
            data?['isOpen'] != false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _blockedRooms = 0;
          _isOpen = true;
        });
      }
    }
  }

  List<DateTime> _datesInRange() {
    final DateTime start = _day(_from);
    final DateTime end = _day(_to);

    final int count =
        end.difference(start).inDays + 1;

    return List<DateTime>.generate(
      count < 1 ? 0 : count,
      (int index) =>
          start.add(
        Duration(days: index),
      ),
    );
  }

  Future<void> _applyRange(
    Map<String, dynamic> room,
  ) async {
    final User? user = _user;
    final String? roomId = _roomId;

    if (user == null ||
        user.isAnonymous ||
        roomId == null) {
      _message(
        'Please select a room first.',
      );
      return;
    }

    final int totalRooms =
        (room['totalRooms'] as num?)
                ?.toInt() ??
            0;

    if (totalRooms < 1) {
      _message(
        'Room total is invalid.',
      );
      return;
    }

    if (_blockedRooms < 0 ||
        _blockedRooms > totalRooms) {
      _message(
        'Blocked rooms must be from '
        '0 to $totalRooms.',
      );
      return;
    }

    final List<DateTime> dates =
        _datesInRange();

    if (dates.isEmpty) {
      _message(
        'Please select a valid date range.',
      );
      return;
    }

    if (dates.length > 90) {
      _message(
        'Update a maximum of 90 days '
        'at one time.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      for (final DateTime date in dates) {
        final String inventoryId =
            '${roomId}_${_dateKey(date)}';

        final DocumentReference<
                Map<String, dynamic>>
            reference =
            FirebaseFirestore.instance
                .collection(
                  'hotel_room_inventory',
                )
                .doc(inventoryId);

        final DocumentSnapshot<
                Map<String, dynamic>>
            existing =
            await reference.get();

        final int bookedRooms =
            (existing.data()?['bookedRooms']
                        as num?)
                    ?.toInt() ??
                0;

        final int maxBlockable =
            totalRooms - bookedRooms < 0
                ? 0
                : totalRooms -
                    bookedRooms;

        final int safeBlocked =
            _blockedRooms > maxBlockable
                ? maxBlockable
                : _blockedRooms;

        final int blocked =
            _isOpen
                ? safeBlocked
                : maxBlockable;

        final int available =
            _isOpen
                ? totalRooms -
                    bookedRooms -
                    blocked
                : 0;

        if (existing.exists) {
          await reference.update(
            <String, dynamic>{
              'totalRooms': totalRooms,
              'blockedRooms': blocked,
              'bookedRooms':
                  bookedRooms,
              'availableRooms':
                  available,
              'isOpen': _isOpen,
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        } else {
          await reference.set(
            <String, dynamic>{
              'inventoryId':
                  inventoryId,
              'hotelId': user.uid,
              'roomId': roomId,
              'partnerId': user.uid,
              'date': Timestamp.fromDate(
                _day(date),
              ),
              'totalRooms':
                  totalRooms,
              'blockedRooms':
                  blocked,
              'bookedRooms':
                  bookedRooms,
              'availableRooms':
                  available,
              'isOpen': _isOpen,
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        }
      }

      if (!mounted) {
        return;
      }

      _message(
        'Availability updated for '
        '${dates.length} day(s).',
      );
    } catch (error) {
      _message(
        'Could not update availability.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
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

  Widget _dayPreview({
    required String roomId,
    required int totalRooms,
  }) {
    final String inventoryId =
        '${roomId}_${_dateKey(_from)}';

    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(
            'hotel_room_inventory',
          )
          .doc(inventoryId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        final Map<String, dynamic> data =
            snapshot.data?.data() ??
                <String, dynamic>{};

        final int booked =
            (data['bookedRooms'] as num?)
                    ?.toInt() ??
                0;

        final int blocked =
            (data['blockedRooms'] as num?)
                    ?.toInt() ??
                0;

        final bool open =
            data['isOpen'] != false;

        final int available =
            data.isEmpty
                ? totalRooms
                : (data['availableRooms']
                            as num?)
                        ?.toInt() ??
                    0;

        return Card(
          child: Padding(
            padding:
                const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                Text(
                  'Preview for '
                  '${_dateText(_from)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                _row(
                  'Open',
                  open ? 'Yes' : 'No',
                ),
                _row(
                  'Total Rooms',
                  '$totalRooms',
                ),
                _row(
                  'Booked by RD',
                  '$booked',
                ),
                _row(
                  'Blocked by Hotel',
                  '$blocked',
                ),
                const Divider(),
                _row(
                  'Available',
                  '$available',
                  strong: true,
                  color: available > 0
                      ? _rdGreen
                      : _rdRed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(
    String label,
    String value, {
    bool strong = false,
    Color? color,
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
              color: color,
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
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Hotel Partner login required.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Room Availability',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hotel_rooms')
              .where(
                'partnerId',
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
                  'Could not load rooms.\n'
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
                          doc.data()[
                                  'hotelId'] ==
                              user.uid &&
                          doc.data()[
                                  'isActive'] ==
                              true,
                    )
                    .toList();

            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding:
                      EdgeInsets.all(24),
                  child: Text(
                    'No active room type found. '
                    'Add and activate rooms first.',
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              );
            }

            if (_roomId == null ||
                !docs.any(
                  (
                    QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        doc,
                  ) =>
                      doc.id == _roomId,
                )) {
              _roomId = docs.first.id;
            }

            final QueryDocumentSnapshot<
                    Map<String, dynamic>>
                selected =
                docs.firstWhere(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    doc,
              ) =>
                  doc.id == _roomId,
            );

            final Map<String, dynamic>
                room = selected.data();

            final int totalRooms =
                (room['totalRooms'] as num?)
                        ?.toInt() ??
                    0;

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 800,
                ),
                child: ListView(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  children: <Widget>[
                    Container(
                      padding:
                          const EdgeInsets
                              .all(14),
                      decoration:
                          BoxDecoration(
                        color: _rdGreen
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(14),
                      ),
                      child: const Text(
                        'Availability is date-wise. '
                        'Blocked rooms are rooms held for maintenance, '
                        'walk-in guests or other reasons. '
                        'Confirmed RD bookings stay protected as booked rooms.',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .stretch,
                          children: <Widget>[
                            const Text(
                              'Room Type',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            InputDecorator(
                              decoration:
                                  const InputDecoration(
                                border:
                                    OutlineInputBorder(),
                              ),
                              child:
                                  DropdownButtonHideUnderline(
                                child:
                                    DropdownButton<
                                        String>(
                                  value:
                                      _roomId,
                                  isExpanded:
                                      true,
                                  items: docs
                                      .map(
                                        (
                                          QueryDocumentSnapshot<
                                                  Map<String,
                                                      dynamic>>
                                              doc,
                                        ) =>
                                            DropdownMenuItem<
                                                String>(
                                          value:
                                              doc.id,
                                          child: Text(
                                            '${doc.data()['name'] ?? 'Room'} '
                                            '(Total ${doc.data()['totalRooms'] ?? 0})',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged:
                                      (
                                    String?
                                        value,
                                  ) async {
                                    if (value ==
                                        null) {
                                      return;
                                    }

                                    setState(
                                      () {
                                        _roomId =
                                            value;
                                      },
                                    );

                                    await _loadSelectedDay();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            LayoutBuilder(
                              builder:
                                  (
                                BuildContext
                                    context,
                                BoxConstraints
                                    constraints,
                              ) {
                                final Widget
                                    fromBox =
                                    _dateBox(
                                  label: 'From',
                                  value:
                                      _dateText(
                                    _from,
                                  ),
                                  onTap:
                                      _pickFrom,
                                );

                                final Widget
                                    toBox =
                                    _dateBox(
                                  label: 'To',
                                  value:
                                      _dateText(
                                    _to,
                                  ),
                                  onTap:
                                      _pickTo,
                                );

                                if (constraints
                                        .maxWidth >=
                                    520) {
                                  return Row(
                                    children: <
                                        Widget>[
                                      Expanded(
                                        child:
                                            fromBox,
                                      ),
                                      const SizedBox(
                                        width:
                                            9,
                                      ),
                                      Expanded(
                                        child:
                                            toBox,
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: <
                                      Widget>[
                                    fromBox,
                                    const SizedBox(
                                      height:
                                          9,
                                    ),
                                    toBox,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            SwitchListTile(
                              contentPadding:
                                  EdgeInsets.zero,
                              value: _isOpen,
                              title: const Text(
                                'Open for Booking',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                              subtitle: Text(
                                _isOpen
                                    ? 'Customers may request rooms.'
                                    : 'Closed for selected dates.',
                              ),
                              onChanged:
                                  (bool value) {
                                setState(() {
                                  _isOpen =
                                      value;
                                });
                              },
                            ),
                            Row(
                              children: <Widget>[
                                const Expanded(
                                  child: Text(
                                    'Blocked Rooms',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      _blockedRooms >
                                              0
                                          ? () =>
                                              setState(
                                                () {
                                                  _blockedRooms--;
                                                },
                                              )
                                          : null,
                                  icon: const Icon(
                                    Icons
                                        .remove_circle_outline_rounded,
                                  ),
                                ),
                                Text(
                                  '$_blockedRooms',
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      _blockedRooms <
                                              totalRooms
                                          ? () =>
                                              setState(
                                                () {
                                                  _blockedRooms++;
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
                            Text(
                              'Total rooms: '
                              '$totalRooms',
                              style: TextStyle(
                                color: Colors
                                    .grey
                                    .shade700,
                              ),
                            ),
                            const SizedBox(
                              height: 14,
                            ),
                            SizedBox(
                              height: 50,
                              child:
                                  FilledButton
                                      .icon(
                                onPressed:
                                    _saving
                                        ? null
                                        : () =>
                                            _applyRange(
                                              room,
                                            ),
                                icon: _saving
                                    ? const SizedBox
                                        .square(
                                        dimension:
                                            18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .calendar_month_rounded,
                                      ),
                                label:
                                    const Text(
                                  'Apply Availability',
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
                    const SizedBox(
                      height: 14,
                    ),
                    _dayPreview(
                      roomId:
                          selected.id,
                      totalRooms:
                          totalRooms,
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
