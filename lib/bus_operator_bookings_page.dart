import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusOperatorBookingsPage extends StatefulWidget {
  const BusOperatorBookingsPage({super.key});

  @override
  State<BusOperatorBookingsPage> createState() =>
      _BusOperatorBookingsPageState();
}

class _BusOperatorBookingsPageState
    extends State<BusOperatorBookingsPage> {
  String _filter = 'all';

  String _lockId(String scheduleId, String seat) {
    return sha256
        .convert(
          utf8.encode('$scheduleId|$seat'),
        )
        .toString();
  }

  String _verificationToken(String bookingId) {
    final Random random = Random.secure();
    final String raw =
        '$bookingId|${DateTime.now().microsecondsSinceEpoch}|'
        '${random.nextInt(1 << 32)}|${random.nextInt(1 << 32)}';

    return sha256
        .convert(utf8.encode(raw))
        .toString()
        .substring(0, 32)
        .toUpperCase();
  }

  Future<void> _verifyAndLock(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> booking,
    String operatorId,
  ) async {
    if (booking['operatorId']?.toString() !=
        operatorId) {
      _message('You can manage only your own booking.');
      return;
    }

    final String scheduleId =
        booking['scheduleId']?.toString() ?? '';

    final List<String> seats =
        (booking['selectedSeats'] is List
                ? booking['selectedSeats']
                    as List<dynamic>
                : <dynamic>[])
            .map((dynamic value) => value.toString())
            .toList();

    if (scheduleId.isEmpty || seats.isEmpty) {
      _message(
        'Schedule or selected seat data is missing.',
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final List<
                  DocumentReference<Map<String, dynamic>>>
              lockRefs =
              <DocumentReference<Map<String, dynamic>>>[];

          for (final String seat in seats) {
            lockRefs.add(
              FirebaseFirestore.instance
                  .collection('bus_seat_locks')
                  .doc(_lockId(scheduleId, seat)),
            );
          }

          final List<
                  DocumentSnapshot<Map<String, dynamic>>>
              lockDocs =
              <DocumentSnapshot<Map<String, dynamic>>>[];

          // Firestore requires all reads before any write.
          for (final DocumentReference<
                  Map<String, dynamic>>
              lockRef in lockRefs) {
            lockDocs.add(
              await transaction.get(lockRef),
            );
          }

          for (int index = 0;
              index < seats.length;
              index++) {
            final DocumentSnapshot<Map<String, dynamic>>
                lockDoc = lockDocs[index];

            if (lockDoc.exists &&
                lockDoc.data()?['active'] == true &&
                lockDoc.data()?['bookingId'] != ref.id) {
              throw StateError(
                'Seat ${seats[index]} is already locked by another booking.',
              );
            }
          }

          for (int index = 0;
              index < seats.length;
              index++) {
            final DocumentReference<Map<String, dynamic>>
                lockRef = lockRefs[index];

            transaction.set(
              lockRef,
              <String, dynamic>{
                'lockId': lockRef.id,
                'operatorId': operatorId,
                'scheduleId': scheduleId,
                'bookingId': ref.id,
                'seat': seats[index],
                'active': true,
                'lockedAt':
                    FieldValue.serverTimestamp(),
              },
            );
          }

          transaction.update(
            ref,
            <String, dynamic>{
              'operatorVerified': true,
              'seatLockStatus': 'locked',
              'bookingStatus': 'confirmed',
              'operatorVerifiedAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      _message('Booking verified and seats locked.');
    } catch (error) {
      _message('Could not lock seats: $error');
    }
  }

  Future<void> _collectPayOnBus(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> booking,
    String operatorId,
  ) async {
    if (booking['operatorId']?.toString() !=
        operatorId) {
      _message('You can manage only your own booking.');
      return;
    }

    if (booking['paymentOption'] != 'pay_on_bus') {
      _message(
        'Online payment must be verified by RD/Admin.',
      );
      return;
    }

    if (booking['seatLockStatus'] != 'locked' ||
        booking['operatorVerified'] != true) {
      _message(
        'Verify and lock the seats before collecting payment.',
      );
      return;
    }

    try {
      await ref.update(
        <String, dynamic>{
          'paymentStatus': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      _message('Pay on Bus amount marked collected.');
    } on FirebaseException catch (error) {
      _message(
        'Could not update payment: '
        '${error.message ?? error.code}',
      );
    }
  }

  Future<void> _issueTicket(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> booking,
    String operatorId,
  ) async {
    if (booking['operatorId']?.toString() !=
        operatorId) {
      _message('You can manage only your own booking.');
      return;
    }

    if (booking['operatorVerified'] != true ||
        booking['seatLockStatus'] != 'locked' ||
        booking['paymentStatus'] != 'paid') {
      _message(
        'Seat must be locked and payment must be Paid before issuing.',
      );
      return;
    }

    final String token =
        _verificationToken(ref.id);

    try {
      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>>
              bookingDoc =
              await transaction.get(ref);

          if (!bookingDoc.exists) {
            throw StateError('Booking not found.');
          }

          final Map<String, dynamic> live =
              bookingDoc.data()!;

          if (live['operatorId']?.toString() !=
                  operatorId ||
              live['operatorVerified'] != true ||
              live['seatLockStatus'] != 'locked' ||
              live['paymentStatus'] != 'paid') {
            throw StateError(
              'Booking is not ready for ticket issuance.',
            );
          }

          final DocumentReference<Map<String, dynamic>>
              verifyRef =
              FirebaseFirestore.instance
                  .collection(
                    'bus_ticket_public_verify',
                  )
                  .doc(token);

          transaction.update(
            ref,
            <String, dynamic>{
              'bookingStatus': 'issued',
              'ticketStatus': 'issued',
              'qrVerificationToken': token,
              'issuedAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );

          transaction.set(
            verifyRef,
            <String, dynamic>{
              'verificationToken': token,
              'bookingId': ref.id,
              'operatorId': operatorId,
              'bookingCode':
                  live['bookingCode']?.toString() ?? '',
              'status': 'issued',
              'from': live['from']?.toString() ?? '',
              'to': live['to']?.toString() ?? '',
              'operatorName':
                  live['operatorName']?.toString() ?? '',
              'busNumber':
                  live['busNumber']?.toString() ?? '',
              'departureAt': live['departureAt'],
              'seats':
                  live['selectedSeats'] ?? <dynamic>[],
              'issuedAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      _message('Ticket issued successfully.');
    } catch (error) {
      _message('Could not issue ticket: $error');
    }
  }

  Future<void> _cancelBooking(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> booking,
    String operatorId,
  ) async {
    if (booking['operatorId']?.toString() !=
        operatorId) {
      _message('You can manage only your own booking.');
      return;
    }

    final String scheduleId =
        booking['scheduleId']?.toString() ?? '';
    final String token =
        booking['qrVerificationToken']?.toString() ??
            '';

    final List<String> seats =
        (booking['selectedSeats'] is List
                ? booking['selectedSeats']
                    as List<dynamic>
                : <dynamic>[])
            .map((dynamic value) => value.toString())
            .toList();

    try {
      final WriteBatch batch =
          FirebaseFirestore.instance.batch();

      for (final String seat in seats) {
        if (scheduleId.isEmpty) {
          continue;
        }

        batch.delete(
          FirebaseFirestore.instance
              .collection('bus_seat_locks')
              .doc(
                _lockId(scheduleId, seat),
              ),
        );
      }

      batch.update(
        ref,
        <String, dynamic>{
          'bookingStatus': 'cancelled',
          'ticketStatus': 'cancelled',
          'seatLockStatus': 'released',
          'paymentStatus':
              booking['paymentStatus'] == 'paid'
                  ? 'refund_pending'
                  : booking['paymentStatus'],
          'cancelReason':
              'Cancelled by Bus Operator',
          'cancelledAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      if (token.isNotEmpty) {
        batch.set(
          FirebaseFirestore.instance
              .collection(
                'bus_ticket_public_verify',
              )
              .doc(token),
          <String, dynamic>{
            'status': 'cancelled',
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      _message(
        'Booking cancelled and seats released.',
      );
    } on FirebaseException catch (error) {
      _message(
        'Could not cancel booking: '
        '${error.message ?? error.code}',
      );
    }
  }

  bool _matchesFilter(
    Map<String, dynamic> booking,
  ) {
    final String status =
        booking['bookingStatus']?.toString() ?? '';

    return _filter == 'all' ||
        (_filter == 'request' &&
            status == 'request_submitted') ||
        (_filter == 'confirmed' &&
            status == 'confirmed') ||
        (_filter == 'issued' &&
            status == 'issued') ||
        (_filter == 'cancelled' &&
            status == 'cancelled');
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text('Bus Operator login required.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'My Bus Bookings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_ticket_bookings')
            .where(
              'operatorId',
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
                  'Could not load your bookings.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              docs = <QueryDocumentSnapshot<
                  Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ].where(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  doc,
            ) =>
                _matchesFilter(doc.data()),
          ).toList();

          return Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <String>[
                    'all',
                    'request',
                    'confirmed',
                    'issued',
                    'cancelled',
                  ]
                      .map(
                        (String value) => Padding(
                          padding:
                              const EdgeInsets.only(
                            right: 8,
                          ),
                          child: ChoiceChip(
                            label: Text(
                              value.toUpperCase(),
                            ),
                            selected:
                                _filter == value,
                            onSelected: (_) {
                              setState(() {
                                _filter = value;
                              });
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text(
                          'No bookings in this filter.',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (
                          BuildContext context,
                          int index,
                        ) {
                          final QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              doc = docs[index];

                          return _bookingCard(
                            doc,
                            user.uid,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bookingCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String operatorId,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final List<dynamic> names =
        data['passengerNames'] is List
            ? data['passengerNames']
                as List<dynamic>
            : <dynamic>[];

    final List<dynamic> phones =
        data['passengerPhones'] is List
            ? data['passengerPhones']
                as List<dynamic>
            : <dynamic>[];

    final List<dynamic> seats =
        data['selectedSeats'] is List
            ? data['selectedSeats']
                as List<dynamic>
            : <dynamic>[];

    final String paymentOption =
        data['paymentOption']?.toString() ??
            'pay_on_bus';
    final String paymentStatus =
        data['paymentStatus']?.toString() ??
            '';
    final String ticketStatus =
        data['ticketStatus']?.toString() ??
            '';
    final String bookingStatus =
        data['bookingStatus']?.toString() ??
            '';

    final bool verified =
        data['operatorVerified'] == true;
    final bool locked =
        data['seatLockStatus'] == 'locked';
    final bool paid =
        paymentStatus == 'paid';
    final bool issued =
        ticketStatus == 'issued';
    final bool cancelled =
        bookingStatus == 'cancelled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${data['bookingCode'] ?? doc.id}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${data['from'] ?? ''} → ${data['to'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${data['busName'] ?? ''} • ${data['busNumber'] ?? ''}',
            ),
            Text('Seats: ${seats.join(', ')}'),
            const SizedBox(height: 7),
            for (int index = 0;
                index < names.length;
                index++)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 3),
                child: Text(
                  'Passenger ${index + 1}: '
                  '${names[index]}'
                  '${index < phones.length ? ' • ${phones[index]}' : ''}',
                ),
              ),
            const SizedBox(height: 7),
            Text(
              'Payment Option: '
              '${paymentOption == 'online' ? 'Online' : 'Pay on Bus'}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Payment Method: '
              '${data['paymentMethod'] ?? ''}',
            ),
            Text(
              'Payment Status: $paymentStatus',
            ),
            Text(
              'Seat: ${data['seatLockStatus'] ?? ''} • '
              'Ticket: $ticketStatus',
            ),
            Text(
              'Total: Rs. ${data['totalFare'] ?? 0}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (!verified || !locked)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _verifyAndLock(
                      doc.reference,
                      data,
                      operatorId,
                    ),
                    icon: const Icon(Icons.lock_rounded),
                    label:
                        const Text('Verify & Lock'),
                  ),
                if (paymentOption == 'pay_on_bus' &&
                    locked &&
                    !paid &&
                    !cancelled)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _collectPayOnBus(
                      doc.reference,
                      data,
                      operatorId,
                    ),
                    icon: const Icon(
                      Icons.payments_rounded,
                    ),
                    label: const Text(
                      'Collected on Bus',
                    ),
                  ),
                if (paymentOption == 'online' &&
                    !paid &&
                    !cancelled)
                  const Chip(
                    avatar: Icon(
                      Icons.hourglass_top_rounded,
                      size: 18,
                    ),
                    label: Text(
                      'Waiting RD Online Payment Verification',
                    ),
                  ),
                if (verified &&
                    locked &&
                    paid &&
                    !issued &&
                    !cancelled)
                  FilledButton.icon(
                    onPressed: () =>
                        _issueTicket(
                      doc.reference,
                      data,
                      operatorId,
                    ),
                    icon: const Icon(
                      Icons
                          .confirmation_number_rounded,
                    ),
                    label:
                        const Text('Issue Ticket'),
                  ),
                if (!cancelled)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _cancelBooking(
                      doc.reference,
                      data,
                      operatorId,
                    ),
                    icon:
                        const Icon(Icons.cancel_rounded),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
