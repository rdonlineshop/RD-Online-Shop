import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HotelPartnerBookingsPage
    extends StatefulWidget {
  const HotelPartnerBookingsPage({
    super.key,
  });

  @override
  State<HotelPartnerBookingsPage>
      createState() =>
          _HotelPartnerBookingsPageState();
}

class _HotelPartnerBookingsPageState
    extends State<HotelPartnerBookingsPage> {
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);
  static const Color _rdBlue =
      Color(0xFF1565C0);

  String _filter = 'all';

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

  String _dateValue(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }

    final DateTime date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ?? 0;

    return 'Rs. '
        '${amount.toStringAsFixed(0)}';
  }

  List<DateTime> _stayDates(
    DateTime checkIn,
    DateTime checkOut,
  ) {
    final DateTime start =
        _day(checkIn);
    final DateTime end =
        _day(checkOut);

    final int nights =
        end.difference(start).inDays;

    if (nights < 1) {
      return <DateTime>[];
    }

    return List<DateTime>.generate(
      nights,
      (int index) =>
          start.add(
        Duration(days: index),
      ),
    );
  }

  Future<void> _confirm(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) async {
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              fresh =
              await transaction.get(
            doc.reference,
          );

          final Map<String, dynamic>
              booking =
              fresh.data() ??
                  <String, dynamic>{};

          if (!fresh.exists ||
              booking['bookingStatus'] !=
                  'request_submitted') {
            throw StateError(
              'Booking is no longer waiting '
              'for confirmation.',
            );
          }

          if (booking['partnerId'] !=
              user.uid) {
            throw StateError(
              'This booking does not belong '
              'to this Hotel Partner.',
            );
          }

          final String roomId =
              booking['roomId']
                      ?.toString() ??
                  '';

          final int roomCount =
              (booking['roomCount'] as num?)
                      ?.toInt() ??
                  0;

          final Timestamp? checkInStamp =
              booking['checkIn']
                  as Timestamp?;

          final Timestamp? checkOutStamp =
              booking['checkOut']
                  as Timestamp?;

          if (roomId.isEmpty ||
              roomCount < 1 ||
              checkInStamp == null ||
              checkOutStamp == null) {
            throw StateError(
              'Booking data is incomplete.',
            );
          }

          final DocumentReference<
                  Map<String, dynamic>>
              roomRef =
              FirebaseFirestore.instance
                  .collection('hotel_rooms')
                  .doc(roomId);

          final DocumentSnapshot<
                  Map<String, dynamic>>
              roomDoc =
              await transaction.get(
            roomRef,
          );

          final Map<String, dynamic> room =
              roomDoc.data() ??
                  <String, dynamic>{};

          if (!roomDoc.exists ||
              room['partnerId'] !=
                  user.uid ||
              room['isActive'] != true) {
            throw StateError(
              'Room is not active for this hotel.',
            );
          }

          final int roomTotal =
              (room['totalRooms'] as num?)
                      ?.toInt() ??
                  0;

          final List<DateTime> dates =
              _stayDates(
            checkInStamp.toDate(),
            checkOutStamp.toDate(),
          );

          if (dates.isEmpty) {
            throw StateError(
              'Stay dates are invalid.',
            );
          }

          final List<_InventoryEntry>
              inventoryEntries =
              <_InventoryEntry>[];

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
                inventory =
                await transaction.get(
              reference,
            );

            inventoryEntries.add(
              _InventoryEntry(
                reference: reference,
                snapshot: inventory,
                date: date,
              ),
            );
          }

          for (final _InventoryEntry entry
              in inventoryEntries) {
            final Map<String, dynamic> data =
                entry.snapshot.data() ??
                    <String, dynamic>{};

            final bool open =
                data.isEmpty
                    ? true
                    : data['isOpen'] !=
                        false;

            final int total =
                (data['totalRooms'] as num?)
                        ?.toInt() ??
                    roomTotal;

            final int blocked =
                (data['blockedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int booked =
                (data['bookedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int available =
                data.isEmpty
                    ? total
                    : (data['availableRooms']
                                as num?)
                            ?.toInt() ??
                        (total -
                            blocked -
                            booked);

            if (!open ||
                available < roomCount) {
              throw StateError(
                'Not enough rooms available on '
                '${entry.date.day}/'
                '${entry.date.month}/'
                '${entry.date.year}.',
              );
            }
          }

          for (final _InventoryEntry entry
              in inventoryEntries) {
            final Map<String, dynamic> data =
                entry.snapshot.data() ??
                    <String, dynamic>{};

            final int total =
                (data['totalRooms'] as num?)
                        ?.toInt() ??
                    roomTotal;

            final int blocked =
                (data['blockedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int booked =
                (data['bookedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int nextBooked =
                booked + roomCount;

            final int nextAvailable =
                total -
                    blocked -
                    nextBooked;

            final Map<String, dynamic> next =
                <String, dynamic>{
              'inventoryId':
                  entry.reference.id,
              'hotelId':
                  booking['hotelId'],
              'roomId': roomId,
              'partnerId': user.uid,
              'date':
                  Timestamp.fromDate(
                _day(entry.date),
              ),
              'totalRooms': total,
              'blockedRooms': blocked,
              'bookedRooms':
                  nextBooked,
              'availableRooms':
                  nextAvailable,
              'isOpen': true,
              'lastBookingId':
                  doc.id,
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            };

            if (entry.snapshot.exists) {
              transaction.update(
                entry.reference,
                <String, dynamic>{
                  'totalRooms': total,
                  'blockedRooms':
                      blocked,
                  'bookedRooms':
                      nextBooked,
                  'availableRooms':
                      nextAvailable,
                  'isOpen': true,
                  'lastBookingId':
                      doc.id,
                  'updatedAt':
                      FieldValue
                          .serverTimestamp(),
                },
              );
            } else {
              transaction.set(
                entry.reference,
                next,
              );
            }
          }

          transaction.update(
            doc.reference,
            <String, dynamic>{
              'bookingStatus':
                  'confirmed',
              'confirmationStatus':
                  'confirmed',
              'partnerConfirmed':
                  true,
              'confirmedAt':
                  FieldValue
                      .serverTimestamp(),
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        },
      );

      if (mounted) {
        _message(
          'Hotel booking confirmed.',
        );
      }
    } catch (error) {
      _message(
        'Could not confirm booking.\n'
        '$error',
      );
    }
  }

  Future<void> _reject(
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
          title:
              const Text('Reject Booking'),
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
                  const Text('Cancel'),
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
              child:
                  const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (result == null ||
        result.trim().isEmpty) {
      return;
    }

    try {
      await doc.reference.update(
        <String, dynamic>{
          'bookingStatus':
              'rejected',
          'confirmationStatus':
              'rejected',
          'partnerConfirmed': false,
          'rejectionReason':
              result.trim(),
          'rejectedAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (mounted) {
        _message(
          'Booking rejected.',
        );
      }
    } catch (error) {
      _message(
        'Could not reject booking.\n'
        '$error',
      );
    }
  }

  Future<void> _approveCancellation(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) async {
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              fresh =
              await transaction.get(
            doc.reference,
          );

          final Map<String, dynamic>
              booking =
              fresh.data() ??
                  <String, dynamic>{};

          if (booking['bookingStatus'] !=
              'cancel_requested') {
            throw StateError(
              'Cancellation is no longer pending.',
            );
          }

          if (booking['partnerId'] !=
              user.uid) {
            throw StateError(
              'This booking does not belong '
              'to this Hotel Partner.',
            );
          }

          final bool hadConfirmedInventory =
              booking['partnerConfirmed'] ==
                      true ||
                  booking[
                          'confirmationStatus'] ==
                      'confirmed';

          final String roomId =
              booking['roomId']
                      ?.toString() ??
                  '';

          final int roomCount =
              (booking['roomCount'] as num?)
                      ?.toInt() ??
                  0;

          final Timestamp? checkInStamp =
              booking['checkIn']
                  as Timestamp?;

          final Timestamp? checkOutStamp =
              booking['checkOut']
                  as Timestamp?;

          final List<_InventoryEntry>
              entries =
              <_InventoryEntry>[];

          if (hadConfirmedInventory &&
              roomId.isNotEmpty &&
              roomCount > 0 &&
              checkInStamp != null &&
              checkOutStamp != null) {
            final List<DateTime> dates =
                _stayDates(
              checkInStamp.toDate(),
              checkOutStamp.toDate(),
            );

            for (final DateTime date
                in dates) {
              final DocumentReference<
                      Map<String, dynamic>>
                  reference =
                  FirebaseFirestore.instance
                      .collection(
                        'hotel_room_inventory',
                      )
                      .doc(
                        '${roomId}_${_dateKey(date)}',
                      );

              final DocumentSnapshot<
                      Map<String, dynamic>>
                  inventory =
                  await transaction.get(
                reference,
              );

              entries.add(
                _InventoryEntry(
                  reference: reference,
                  snapshot: inventory,
                  date: date,
                ),
              );
            }
          }

          for (final _InventoryEntry entry
              in entries) {
            if (!entry.snapshot.exists) {
              continue;
            }

            final Map<String, dynamic> data =
                entry.snapshot.data() ??
                    <String, dynamic>{};

            final int total =
                (data['totalRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int blocked =
                (data['blockedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int booked =
                (data['bookedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int nextBooked =
                booked - roomCount < 0
                    ? 0
                    : booked -
                        roomCount;

            final bool open =
                data['isOpen'] != false;

            final int available =
                open
                    ? total -
                        blocked -
                        nextBooked
                    : 0;

            transaction.update(
              entry.reference,
              <String, dynamic>{
                'bookedRooms':
                    nextBooked,
                'availableRooms':
                    available,
                'updatedAt':
                    FieldValue
                        .serverTimestamp(),
              },
            );
          }

          transaction.update(
            doc.reference,
            <String, dynamic>{
              'bookingStatus':
                  'cancelled',
              'confirmationStatus':
                  'cancelled',
              'partnerConfirmed':
                  false,
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        },
      );

      if (mounted) {
        _message(
          'Cancellation completed.',
        );
      }
    } catch (error) {
      _message(
        'Could not complete cancellation.\n'
        '$error',
      );
    }
  }

  Future<void> _completeBooking(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) async {
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              fresh =
              await transaction.get(
            doc.reference,
          );

          if (!fresh.exists) {
            throw StateError(
              'Booking no longer exists.',
            );
          }

          final Map<String, dynamic>
              booking =
              fresh.data() ??
                  <String, dynamic>{};

          if (booking['bookingStatus'] !=
              'checked_in') {
            throw StateError(
              'Only a checked-in booking can be completed.',
            );
          }

          if (booking['partnerId'] !=
              user.uid) {
            throw StateError(
              'This booking does not belong '
              'to this Hotel Partner.',
            );
          }

          final String roomId =
              booking['roomId']
                      ?.toString() ??
                  '';

          final int roomCount =
              (booking['roomCount'] as num?)
                      ?.toInt() ??
                  0;

          final Timestamp? checkInStamp =
              booking['checkIn']
                  as Timestamp?;

          final Timestamp? checkOutStamp =
              booking['checkOut']
                  as Timestamp?;

          if (roomId.isEmpty ||
              roomCount < 1 ||
              checkInStamp == null ||
              checkOutStamp == null) {
            throw StateError(
              'Booking data is incomplete.',
            );
          }

          final List<DateTime> dates =
              _stayDates(
            checkInStamp.toDate(),
            checkOutStamp.toDate(),
          );

          if (dates.isEmpty) {
            throw StateError(
              'Stay dates are invalid.',
            );
          }

          final List<_InventoryEntry>
              entries =
              <_InventoryEntry>[];

          for (final DateTime date
              in dates) {
            final DocumentReference<
                    Map<String, dynamic>>
                reference =
                FirebaseFirestore.instance
                    .collection(
                      'hotel_room_inventory',
                    )
                    .doc(
                      '${roomId}_${_dateKey(date)}',
                    );

            final DocumentSnapshot<
                    Map<String, dynamic>>
                inventory =
                await transaction.get(
              reference,
            );

            entries.add(
              _InventoryEntry(
                reference: reference,
                snapshot: inventory,
                date: date,
              ),
            );
          }

          for (final _InventoryEntry entry
              in entries) {
            if (!entry.snapshot.exists) {
              continue;
            }

            final Map<String, dynamic> data =
                entry.snapshot.data() ??
                    <String, dynamic>{};

            final int total =
                (data['totalRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int blocked =
                (data['blockedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int booked =
                (data['bookedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int nextBooked =
                booked - roomCount < 0
                    ? 0
                    : booked -
                        roomCount;

            final bool open =
                data['isOpen'] != false;

            final int nextAvailable =
                open
                    ? total -
                        blocked -
                        nextBooked
                    : 0;

            transaction.update(
              entry.reference,
              <String, dynamic>{
                'bookedRooms':
                    nextBooked,
                'availableRooms':
                    nextAvailable,
                'updatedAt':
                    FieldValue
                        .serverTimestamp(),
              },
            );
          }

          transaction.update(
            doc.reference,
            <String, dynamic>{
              'bookingStatus':
                  'completed',
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        },
      );

      if (mounted) {
        _message(
          'Booking completed. Room availability restored automatically.',
        );
      }
    } catch (error) {
      _message(
        'Could not complete booking.\n'
        '$error',
      );
    }
  }

  Future<void> _restoreCompletedAvailability(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) async {
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return;
    }

    final bool? confirm =
        await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Restore Room Availability',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: const Text(
            'Use this only for an older COMPLETED booking '
            'that still shows as "Booked by RD".\n\n'
            'This repair will release only this booking\'s '
            'room count when it is safe to do so. '
            'It will not change payment, customer, dates '
            'or any other booking information.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              icon: const Icon(
                Icons
                    .restore_rounded,
              ),
              label: const Text(
                'Restore',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final bool restored =
          await FirebaseFirestore.instance
              .runTransaction<bool>(
        (Transaction transaction) async {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              fresh =
              await transaction.get(
            doc.reference,
          );

          if (!fresh.exists) {
            throw StateError(
              'Booking no longer exists.',
            );
          }

          final Map<String, dynamic>
              booking =
              fresh.data() ??
                  <String, dynamic>{};

          if (booking['bookingStatus'] !=
              'completed') {
            throw StateError(
              'Only a COMPLETED booking can use this repair.',
            );
          }

          if (booking['partnerId'] !=
              user.uid) {
            throw StateError(
              'This booking does not belong '
              'to this Hotel Partner.',
            );
          }

          final String roomId =
              booking['roomId']
                      ?.toString() ??
                  '';

          final int roomCount =
              (booking['roomCount'] as num?)
                      ?.toInt() ??
                  0;

          final Timestamp? checkInStamp =
              booking['checkIn']
                  as Timestamp?;

          final Timestamp? checkOutStamp =
              booking['checkOut']
                  as Timestamp?;

          if (roomId.isEmpty ||
              roomCount < 1 ||
              checkInStamp == null ||
              checkOutStamp == null) {
            throw StateError(
              'Booking data is incomplete.',
            );
          }

          final List<DateTime> dates =
              _stayDates(
            checkInStamp.toDate(),
            checkOutStamp.toDate(),
          );

          if (dates.isEmpty) {
            throw StateError(
              'Stay dates are invalid.',
            );
          }

          final List<_InventoryEntry>
              entries =
              <_InventoryEntry>[];

          for (final DateTime date
              in dates) {
            final DocumentReference<
                    Map<String, dynamic>>
                reference =
                FirebaseFirestore.instance
                    .collection(
                      'hotel_room_inventory',
                    )
                    .doc(
                      '${roomId}_${_dateKey(date)}',
                    );

            final DocumentSnapshot<
                    Map<String, dynamic>>
                inventory =
                await transaction.get(
              reference,
            );

            entries.add(
              _InventoryEntry(
                reference: reference,
                snapshot: inventory,
                date: date,
              ),
            );
          }

          bool changed = false;

          for (final _InventoryEntry entry
              in entries) {
            if (!entry.snapshot.exists) {
              continue;
            }

            final Map<String, dynamic> data =
                entry.snapshot.data() ??
                    <String, dynamic>{};

            if (data['partnerId'] !=
                    user.uid ||
                data['roomId'] !=
                    roomId) {
              throw StateError(
                'Inventory ownership mismatch on '
                '${entry.date.day}/'
                '${entry.date.month}/'
                '${entry.date.year}.',
              );
            }

            final int total =
                (data['totalRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int blocked =
                (data['blockedRooms'] as num?)
                        ?.toInt() ??
                    0;

            final int booked =
                (data['bookedRooms'] as num?)
                        ?.toInt() ??
                    0;

            if (booked <= 0) {
              continue;
            }

            final String lastBookingId =
                data['lastBookingId']
                        ?.toString()
                        .trim() ??
                    '';

            if (lastBookingId.isNotEmpty &&
                lastBookingId != doc.id) {
              throw StateError(
                'Another booking is currently recorded '
                'for ${entry.date.day}/'
                '${entry.date.month}/'
                '${entry.date.year}. '
                'Nothing was changed to protect that booking.',
              );
            }

            if (booked < roomCount) {
              throw StateError(
                'Inventory count is smaller than this '
                'booking room count on '
                '${entry.date.day}/'
                '${entry.date.month}/'
                '${entry.date.year}. '
                'Nothing was changed.',
              );
            }

            final int nextBooked =
                booked - roomCount;

            final bool open =
                data['isOpen'] != false;

            final int nextAvailable =
                open
                    ? total -
                        blocked -
                        nextBooked
                    : 0;

            if (nextAvailable < 0) {
              throw StateError(
                'Inventory values are invalid on '
                '${entry.date.day}/'
                '${entry.date.month}/'
                '${entry.date.year}.',
              );
            }

            transaction.update(
              entry.reference,
              <String, dynamic>{
                'bookedRooms':
                    nextBooked,
                'availableRooms':
                    nextAvailable,
                'updatedAt':
                    FieldValue
                        .serverTimestamp(),
              },
            );

            changed = true;
          }

          return changed;
        },
      );

      if (!mounted) {
        return;
      }

      _message(
        restored
            ? 'Old completed booking inventory repaired. Room availability restored.'
            : 'No stale booked room was found. Availability is already released.',
      );
    } catch (error) {
      _message(
        'Could not restore availability.\n'
        '$error',
      );
    }
  }

  Future<void> _setStatus(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
    String status,
  ) async {
    try {
      await doc.reference.update(
        <String, dynamic>{
          'bookingStatus': status,
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (mounted) {
        _message(
          'Booking status updated.',
        );
      }
    } catch (error) {
      _message(
        'Could not update booking status.\n'
        '$error',
      );
    }
  }

  Future<void> _markPaid(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) async {
    try {
      await doc.reference.update(
        <String, dynamic>{
          'paymentStatus': 'paid',
          'paidAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (mounted) {
        _message(
          'Payment marked paid.',
        );
      }
    } catch (error) {
      _message(
        'Could not mark payment paid.\n'
        '$error',
      );
    }
  }

  bool _matchesFilter(
    Map<String, dynamic> data,
  ) {
    final String status =
        data['bookingStatus']
                ?.toString() ??
            '';

    switch (_filter) {
      case 'requests':
        return status ==
            'request_submitted';
      case 'confirmed':
        return status ==
                'confirmed' ||
            status ==
                'checked_in';
      case 'cancel':
        return status ==
            'cancel_requested';
      case 'history':
        return <String>[
          'rejected',
          'cancelled',
          'completed',
        ].contains(status);
      case 'all':
        return true;
    }

    return true;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return _rdGreen;
      case 'rejected':
      case 'cancelled':
        return _rdRed;
      case 'cancel_requested':
        return Colors.orange;
      case 'checked_in':
        return _rdBlue;
      default:
        return Colors.grey.shade700;
    }
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
          'Hotel Bookings',
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
              .collection(
                'hotel_bookings',
              )
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
                all =
                snapshot.data?.docs ??
                    <QueryDocumentSnapshot<
                        Map<String,
                            dynamic>>>[];

            all.sort(
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

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                docs =
                all
                    .where(
                      (
                        QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>
                            doc,
                      ) =>
                          _matchesFilter(
                        doc.data(),
                      ),
                    )
                    .toList();

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1000,
                ),
                child: ListView(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  children: <Widget>[
                    SingleChildScrollView(
                      scrollDirection:
                          Axis.horizontal,
                      child: SegmentedButton<
                          String>(
                        segments: const <
                            ButtonSegment<
                                String>>[
                          ButtonSegment<String>(
                            value: 'all',
                            label: Text('All'),
                          ),
                          ButtonSegment<String>(
                            value: 'requests',
                            label:
                                Text('Requests'),
                          ),
                          ButtonSegment<String>(
                            value: 'confirmed',
                            label:
                                Text('Confirmed'),
                          ),
                          ButtonSegment<String>(
                            value: 'cancel',
                            label: Text(
                              'Cancel Requests',
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'history',
                            label:
                                Text('History'),
                          ),
                        ],
                        selected:
                            <String>{_filter},
                        onSelectionChanged:
                            (
                          Set<String> value,
                        ) {
                          setState(() {
                            _filter =
                                value.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      'Bookings '
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
                            'No hotel booking found.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...docs.map(
                        _bookingCard,
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

  Widget _bookingCard(
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

    final String paymentStatus =
        data['paymentStatus']
                ?.toString() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
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
                    data['guestName']
                            ?.toString() ??
                        'Guest',
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
                      color:
                          _statusColor(
                        status,
                      ),
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${data['hotelName'] ?? 'Hotel'} • '
              '${data['roomName'] ?? 'Room'}',
            ),
            Text(
              '${_dateValue(data['checkIn'])} → '
              '${_dateValue(data['checkOut'])}',
            ),
            Text(
              '${data['roomCount'] ?? 0} room(s) • '
              '${data['nights'] ?? 0} night(s)',
            ),
            if ((data['guestPhone']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              SelectableText(
                data['guestPhone']
                    .toString(),
              ),
            const SizedBox(height: 6),
            Text(
              'Total: '
              '${_money(data['totalAmount'])}',
              style: const TextStyle(
                color: _rdBlue,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            Text(
              'Payment: $paymentStatus',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w700,
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
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            if ((data['rejectionReason']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Rejected: '
                '${data['rejectionReason']}',
                style: const TextStyle(
                  color: _rdRed,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (status ==
                    'request_submitted')
                  FilledButton.icon(
                    onPressed: () =>
                        _confirm(doc),
                    icon: const Icon(
                      Icons
                          .verified_rounded,
                    ),
                    label: const Text(
                      'Confirm',
                    ),
                  ),
                if (status ==
                    'request_submitted')
                  OutlinedButton.icon(
                    onPressed: () =>
                        _reject(doc),
                    icon: const Icon(
                      Icons
                          .cancel_rounded,
                    ),
                    label: const Text(
                      'Reject',
                    ),
                  ),
                if (status ==
                    'cancel_requested')
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _approveCancellation(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .event_busy_rounded,
                    ),
                    label: const Text(
                      'Approve Cancel',
                    ),
                  ),
                if (status == 'confirmed')
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _setStatus(
                      doc,
                      'checked_in',
                    ),
                    icon: const Icon(
                      Icons.login_rounded,
                    ),
                    label: const Text(
                      'Check In',
                    ),
                  ),
                if (status ==
                    'checked_in')
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _completeBooking(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .task_alt_rounded,
                    ),
                    label: const Text(
                      'Complete',
                    ),
                  ),
                if (status ==
                    'completed')
                  OutlinedButton.icon(
                    onPressed: () =>
                        _restoreCompletedAvailability(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .restore_rounded,
                    ),
                    label: const Text(
                      'Restore Availability',
                    ),
                  ),
                if (paymentStatus !=
                        'paid' &&
                    status != 'rejected' &&
                    status != 'cancelled')
                  OutlinedButton.icon(
                    onPressed: () =>
                        _markPaid(doc),
                    icon: const Icon(
                      Icons
                          .payments_rounded,
                    ),
                    label: const Text(
                      'Mark Paid',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
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

class _InventoryEntry {
  const _InventoryEntry({
    required this.reference,
    required this.snapshot,
    required this.date,
  });

  final DocumentReference<
      Map<String, dynamic>> reference;

  final DocumentSnapshot<
      Map<String, dynamic>> snapshot;

  final DateTime date;
}
