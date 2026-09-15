import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResortPartnerAvailabilityPage extends StatefulWidget {
  const ResortPartnerAvailabilityPage({super.key});

  @override
  State<ResortPartnerAvailabilityPage> createState() =>
      _ResortPartnerAvailabilityPageState();
}

class _ResortPartnerAvailabilityPageState
    extends State<ResortPartnerAvailabilityPage> {
  static const Color _rdGreen = Color(0xFF2E7D32);
  static const Color _rdBlue = Color(0xFF1565C0);

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _open = true;
  int _blocked = 0;
  String? _savingRoomId;

  User? get _user => FirebaseAuth.instance.currentUser;

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  String _key(DateTime date) =>
      '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _dates() {
    final List<DateTime> result = <DateTime>[];
    DateTime current = DateTime(
      _from.year,
      _from.month,
      _from.day,
    );
    final DateTime end = DateTime(
      _to.year,
      _to.month,
      _to.day,
    );

    while (!current.isAfter(end)) {
      result.add(current);
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  Future<void> _pickDate({required bool from}) async {
    final DateTime today = DateTime.now();
    final DateTime firstDate = DateTime(
      today.year,
      today.month,
      today.day,
    );
    final DateTime initial = from ? _from : _to;

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : initial,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (from) {
        _from = selected;
        if (_to.isBefore(_from)) {
          _to = _from;
        }
      } else {
        _to = selected;
      }
    });
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _save(
    QueryDocumentSnapshot<Map<String, dynamic>> room,
  ) async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      _message('Resort Partner login is required.');
      return;
    }

    if (_savingRoomId != null) {
      return;
    }

    final Map<String, dynamic> roomData = room.data();
    final int total =
        (roomData['totalRooms'] as num?)?.toInt() ?? 1;

    if (_blocked < 0 || _blocked > total) {
      _message(
        'Blocked rooms must be between 0 and $total for this room type.',
      );
      return;
    }

    final List<DateTime> dates = _dates();
    if (dates.isEmpty) {
      _message('Please select a valid date range.');
      return;
    }

    setState(() {
      _savingRoomId = room.id;
    });

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final List<MapEntry<
              DocumentReference<Map<String, dynamic>>,
              DocumentSnapshot<Map<String, dynamic>>>>
          entries = <MapEntry<
              DocumentReference<Map<String, dynamic>>,
              DocumentSnapshot<Map<String, dynamic>>>>[];

      for (final DateTime date in dates) {
        final DocumentReference<Map<String, dynamic>> reference =
            firestore.collection('resort_room_inventory').doc(
                  '${room.id}_${_key(date)}',
                );
        final DocumentSnapshot<Map<String, dynamic>> old =
            await reference.get();
        entries.add(MapEntry(reference, old));
      }

      WriteBatch batch = firestore.batch();
      int writes = 0;

      for (int index = 0; index < dates.length; index++) {
        final DateTime date = dates[index];
        final DocumentReference<Map<String, dynamic>> reference =
            entries[index].key;
        final DocumentSnapshot<Map<String, dynamic>> old =
            entries[index].value;
        final int booked =
            (old.data()?['bookedRooms'] as num?)?.toInt() ?? 0;

        if (_blocked + booked > total) {
          throw StateError(
            'Blocked + booked rooms cannot exceed total rooms on ${_date(date)}.',
          );
        }

        batch.set(
          reference,
          <String, dynamic>{
            'inventoryId': reference.id,
            'resortId': user.uid,
            'partnerId': user.uid,
            'roomId': room.id,
            'date': Timestamp.fromDate(
              DateTime(date.year, date.month, date.day),
            ),
            'totalRooms': total,
            'blockedRooms': _blocked,
            'bookedRooms': booked,
            'availableRooms': _open
                ? total - _blocked - booked
                : 0,
            'isOpen': _open,
            'lastBookingId':
                old.data()?['lastBookingId'] ?? '',
            'createdAt': old.data()?['createdAt'] ??
                FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        writes++;
        if (writes >= 450) {
          await batch.commit();
          batch = firestore.batch();
          writes = 0;
        }
      }

      if (writes > 0) {
        await batch.commit();
      }

      _message(
        'Availability saved for ${roomData['name'] ?? 'room'} '
        '(${_date(_from)} - ${_date(_to)}).',
      );
    } catch (error) {
      _message('Could not save availability.\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _savingRoomId = null;
        });
      }
    }
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ?? 0;
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Resort Partner login required.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Availability',
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
              .collection('resort_rooms')
              .where(
                'partnerId',
                isEqualTo: user.uid,
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
                    'Could not load room types.\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final List<QueryDocumentSnapshot<
                    Map<String, dynamic>>> rooms =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String, dynamic>>>[])
                    .where(
                      (QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              room) =>
                          room.data()['resortId'] ==
                          user.uid,
                    )
                    .toList();

            rooms.sort(
              (
                QueryDocumentSnapshot<Map<String, dynamic>> a,
                QueryDocumentSnapshot<Map<String, dynamic>> b,
              ) => (a.data()['name']?.toString() ?? '')
                  .compareTo(
                b.data()['name']?.toString() ?? '',
              ),
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 950,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _rdGreen.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Manage date-wise room availability. '
                        'Choose the date range, open/close booking, '
                        'set blocked rooms, then save for each room type.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Date Range',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final Widget fromButton =
                                    FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _pickDate(from: true),
                                  icon: const Icon(
                                    Icons.login_rounded,
                                  ),
                                  label: Text(
                                    'From  ${_date(_from)}',
                                  ),
                                );

                                final Widget toButton =
                                    FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _pickDate(from: false),
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                  ),
                                  label: Text(
                                    'To  ${_date(_to)}',
                                  ),
                                );

                                if (constraints.maxWidth >= 600) {
                                  return Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: fromButton,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: toButton,
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    fromButton,
                                    const SizedBox(height: 10),
                                    toButton,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _open,
                              title: const Text(
                                'Open for booking',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                _open
                                    ? 'Customers can book available rooms.'
                                    : 'Selected dates will be closed for booking.',
                              ),
                              onChanged: (bool value) {
                                setState(() {
                                  _open = value;
                                });
                              },
                            ),
                            const Divider(),
                            Row(
                              children: <Widget>[
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Blocked Rooms',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        'Rooms kept unavailable by the Resort Partner.',
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _blocked <= 0
                                      ? null
                                      : () {
                                          setState(() {
                                            _blocked--;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                  ),
                                ),
                                Text(
                                  '$_blocked',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _blocked++;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Room Types (${rooms.length})',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (rooms.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No room type added yet. Add room types first.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...rooms.map(
                        (
                          QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              room,
                        ) {
                          final Map<String, dynamic> data =
                              room.data();
                          final bool active =
                              data['isActive'] == true;
                          final int total =
                              (data['totalRooms'] as num?)
                                      ?.toInt() ??
                                  0;
                          final bool saving =
                              _savingRoomId == room.id;

                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 10,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: LayoutBuilder(
                                builder: (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) {
                                  final Widget details = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              data['name']
                                                      ?.toString() ??
                                                  'Room',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              active
                                                  ? 'ACTIVE'
                                                  : 'INACTIVE',
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${data['roomClass'] ?? ''} • '
                                        '${data['isAc'] == true ? 'AC' : 'Non-AC'} • '
                                        '${data['bed'] ?? ''}',
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${_money(data['pricePerNight'])} / night',
                                        style: const TextStyle(
                                          color: _rdBlue,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        'Total rooms: $total • '
                                        'Max guests: ${data['maxGuests'] ?? 0}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  );

                                  final Widget saveButton =
                                      SizedBox(
                                    width: constraints.maxWidth < 560
                                        ? double.infinity
                                        : 190,
                                    child: FilledButton.icon(
                                      onPressed: saving
                                          ? null
                                          : () => _save(room),
                                      icon: saving
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.save_rounded,
                                            ),
                                      label: const Text(
                                        'Save Availability',
                                      ),
                                    ),
                                  );

                                  if (constraints.maxWidth < 560) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        details,
                                        const SizedBox(height: 12),
                                        saveButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: <Widget>[
                                      Expanded(child: details),
                                      const SizedBox(width: 12),
                                      saveButton,
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
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

