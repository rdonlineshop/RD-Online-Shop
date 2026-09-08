import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminBusTicketManagementPage extends StatefulWidget {
  const AdminBusTicketManagementPage({super.key});

  @override
  State<AdminBusTicketManagementPage> createState() =>
      _AdminBusTicketManagementPageState();
}

class _AdminBusTicketManagementPageState
    extends State<AdminBusTicketManagementPage> {
  String _filter = 'all';

  String _lockId(String scheduleId, String seat) {
    return sha256.convert(utf8.encode('$scheduleId|$seat')).toString();
  }

  String _token(String bookingId) {
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

  Future<void> _lockSeats(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final String scheduleId =
        data['scheduleId']?.toString() ?? '';

    final List<String> seats =
        (data['selectedSeats'] is List
                ? data['selectedSeats'] as List<dynamic>
                : <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList();

    if (scheduleId.isEmpty || seats.isEmpty) {
      _message('Schedule or seat information is missing.');
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

          // Firestore transactions require every read to happen
          // before the first write.
          final List<
                  DocumentSnapshot<Map<String, dynamic>>>
              lockDocs =
              <DocumentSnapshot<Map<String, dynamic>>>[];

          for (final DocumentReference<Map<String, dynamic>>
              lockRef in lockRefs) {
            lockDocs.add(
              await transaction.get(lockRef),
            );
          }

          // Validate every seat after all reads are finished.
          for (int index = 0;
              index < seats.length;
              index++) {
            final String seat = seats[index];
            final DocumentSnapshot<Map<String, dynamic>>
                lockDoc = lockDocs[index];

            if (lockDoc.exists &&
                lockDoc.data()?['active'] == true &&
                lockDoc.data()?['bookingId'] != ref.id) {
              throw StateError(
                'Seat $seat is already locked by another booking.',
              );
            }
          }

          // Only now perform writes.
          for (int index = 0;
              index < seats.length;
              index++) {
            final String seat = seats[index];
            final DocumentReference<Map<String, dynamic>>
                lockRef = lockRefs[index];

            transaction.set(
              lockRef,
              <String, dynamic>{
                'lockId': lockRef.id,
                'operatorId':
                    data['operatorId']?.toString() ?? '',
                'scheduleId': scheduleId,
                'bookingId': ref.id,
                'seat': seat,
                'active': true,
                'lockedAt': FieldValue.serverTimestamp(),
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
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );

      _message('Seats verified and locked.');
    } catch (error) {
      _message('Could not lock seats: $error');
    }
  }

  Future<void> _markPaid(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    String method = 'Cash';
    final TextEditingController reference =
        TextEditingController();

    final Map<String, String>? payment =
        await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setStateDialog,
          ) {
            return AlertDialog(
              title: const Text(
                'Confirm Payment',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'Cash',
                        child: Text('Cash'),
                      ),
                      DropdownMenuItem(
                        value: 'eSewa',
                        child: Text('eSewa'),
                      ),
                      DropdownMenuItem(
                        value: 'Khalti',
                        child: Text('Khalti'),
                      ),
                      DropdownMenuItem(
                        value: 'connectIPS',
                        child: Text('connectIPS'),
                      ),
                      DropdownMenuItem(
                        value: 'Pay on Bus',
                        child: Text('Pay on Bus'),
                      ),
                      DropdownMenuItem(
                        value: 'Bank',
                        child: Text('Bank'),
                      ),
                      DropdownMenuItem(
                        value: 'Card',
                        child: Text('Card'),
                      ),
                      DropdownMenuItem(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setStateDialog(() {
                          method = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Payment Reference (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    <String, String>{
                      'method': method,
                      'reference': reference.text.trim(),
                    },
                  ),
                  child: const Text('Mark Paid'),
                ),
              ],
            );
          },
        );
      },
    );

    reference.dispose();

    if (payment == null) {
      return;
    }

    await ref.update(
      <String, dynamic>{
        'paymentStatus': 'paid',
        'paymentMethod': payment['method'] ?? '',
        'paymentReference': payment['reference'] ?? '',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    _message('Payment marked as paid.');
  }

  Future<void> _issue(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    if (data['operatorVerified'] != true ||
        data['seatLockStatus'] != 'locked' ||
        data['paymentStatus'] != 'paid') {
      _message(
        'First Verify & Lock seats, then Mark Paid.',
      );
      return;
    }

    final String token = _token(ref.id);

    await FirebaseFirestore.instance.runTransaction(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> current =
            await transaction.get(ref);

        if (!current.exists) {
          throw StateError('Booking not found.');
        }

        final Map<String, dynamic> live = current.data()!;

        if (live['operatorVerified'] != true ||
            live['seatLockStatus'] != 'locked' ||
            live['paymentStatus'] != 'paid') {
          throw StateError(
            'Booking is not ready for issuance.',
          );
        }

        final DocumentReference<Map<String, dynamic>>
            verifyRef = FirebaseFirestore.instance
                .collection('bus_ticket_public_verify')
                .doc(token);

        transaction.update(
          ref,
          <String, dynamic>{
            'bookingStatus': 'issued',
            'ticketStatus': 'issued',
            'qrVerificationToken': token,
            'issuedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          verifyRef,
          <String, dynamic>{
            'verificationToken': token,
            'bookingId': ref.id,
            'bookingCode':
                live['bookingCode']?.toString() ?? '',
            'operatorId':
                live['operatorId']?.toString() ?? '',
            'status': 'issued',
            'boardingStatus': 'not_confirmed',
            'from': live['from']?.toString() ?? '',
            'to': live['to']?.toString() ?? '',
            'operatorName':
                live['operatorName']?.toString() ?? '',
            'busNumber':
                live['busNumber']?.toString() ?? '',
            'departureAt': live['departureAt'],
            'seats': live['selectedSeats'] ?? <dynamic>[],
            'issuedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );

    _message('Ticket issued with verification token.');
  }

  Future<void> _cancel(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final String scheduleId =
        data['scheduleId']?.toString() ?? '';
    final String token =
        data['qrVerificationToken']?.toString() ?? '';

    final List<String> seats =
        (data['selectedSeats'] is List
                ? data['selectedSeats'] as List<dynamic>
                : <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList();

    final WriteBatch batch =
        FirebaseFirestore.instance.batch();

    for (final String seat in seats) {
      if (scheduleId.isEmpty) {
        continue;
      }

      batch.delete(
        FirebaseFirestore.instance
            .collection('bus_seat_locks')
            .doc(_lockId(scheduleId, seat)),
      );
    }

    batch.update(
      ref,
      <String, dynamic>{
        'bookingStatus': 'cancelled',
        'ticketStatus': 'cancelled',
        'seatLockStatus': 'released',
        'paymentStatus': data['paymentStatus'] == 'paid'
            ? 'refund_pending'
            : data['paymentStatus'],
        'cancelReason': 'Cancelled by Admin',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    if (token.isNotEmpty) {
      batch.set(
        FirebaseFirestore.instance
            .collection('bus_ticket_public_verify')
            .doc(token),
        <String, dynamic>{
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    _message('Booking cancelled and seats released.');
  }

  Future<void> _markRefunded(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await ref.update(
      <String, dynamic>{
        'paymentStatus': 'refunded',
        'refundedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    _message('Refund marked complete.');
  }

  bool _show(Map<String, dynamic> data) {
    final String status =
        data['bookingStatus']?.toString() ?? '';

    return _filter == 'all' ||
        (_filter == 'requests' &&
            status == 'request_submitted') ||
        (_filter == 'confirmed' &&
            status == 'confirmed') ||
        (_filter == 'issued' && status == 'issued') ||
        (_filter == 'cancelled' &&
            status == 'cancelled');
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Ticket Management',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Fare Approvals',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _AdminBusFareApprovalPage(),
                ),
              );
            },
            icon: const Icon(Icons.price_check_rounded),
          ),
          IconButton(
            tooltip: 'Monthly Fee Payment Board',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _AdminBusMonthlyFeeBoardPage(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: 'Commission Board',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _AdminBusCommissionBoardPage(),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart_rounded),
          ),
          IconButton(
            tooltip: 'Monthly Fee & Commission',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _AdminBusOperatorChargesPage(),
                ),
              );
            },
            icon: const Icon(Icons.percent_rounded),
          ),
        ],
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_ticket_bookings')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  QuerySnapshot<Map<String, dynamic>>>
              snapshot,
        ) {
          if (!snapshot.hasData &&
              snapshot.connectionState ==
                  ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load bus bookings.\n${snapshot.error}',
                textAlign: TextAlign.center,
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
                _show(doc.data()),
          ).toList();

          return Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <String>[
                    'all',
                    'requests',
                    'confirmed',
                    'issued',
                    'cancelled',
                  ]
                      .map(
                        (String value) => Padding(
                          padding:
                              const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value.toUpperCase()),
                            selected: _filter == value,
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
                          'No bus bookings in this filter.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (
                          BuildContext context,
                          int index,
                        ) {
                          final doc = docs[index];
                          final data = doc.data();

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

                          final bool verified =
                              data['operatorVerified'] == true;
                          final bool locked =
                              data['seatLockStatus'] ==
                                  'locked';
                          final bool paid =
                              data['paymentStatus'] == 'paid';
                          final bool issued =
                              data['ticketStatus'] == 'issued';
                          final bool cancelled =
                              data['bookingStatus'] ==
                                  'cancelled';

                          return Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    '${data['bookingCode'] ?? doc.id}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${data['from'] ?? ''} → ${data['to'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${data['operatorName'] ?? ''} • '
                                    '${data['busName'] ?? ''}',
                                  ),
                                  Text(
                                    'Seats: ${seats.join(', ')}',
                                  ),
                                  const SizedBox(height: 6),
                                  for (int i = 0;
                                      i < names.length;
                                      i++)
                                    Text(
                                      'Passenger ${i + 1}: ${names[i]}'
                                      '${i < phones.length ? ' • ${phones[i]}' : ''}',
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Verified: ${verified ? 'YES' : 'NO'} • '
                                    'Seat: ${locked ? 'LOCKED' : '${data['seatLockStatus'] ?? ''}'}',
                                  ),
                                  Text(
                                    'Payment: ${data['paymentStatus'] ?? ''} • '
                                    'Ticket: ${data['ticketStatus'] ?? ''}',
                                  ),
                                  Text(
                                    'Total: Rs. ${data['totalFare'] ?? 0}',
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'RD Commission: ${data['commissionPercent'] ?? 0}% • '
                                    'Rs. ${data['rdCommissionAmount'] ?? 0}',
                                  ),
                                  Text(
                                    'Operator Net: Rs. ${data['operatorNetAmount'] ?? data['baseFare'] ?? 0}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
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
                                              _lockSeats(
                                            doc.reference,
                                            data,
                                          ),
                                          icon: const Icon(
                                            Icons.lock_rounded,
                                          ),
                                          label: const Text(
                                            'Verify & Lock',
                                          ),
                                        ),
                                      if (locked && !paid)
                                        FilledButton.tonalIcon(
                                          onPressed: () =>
                                              _markPaid(
                                            doc.reference,
                                          ),
                                          icon: const Icon(
                                            Icons
                                                .payments_rounded,
                                          ),
                                          label: const Text(
                                            'Mark Paid',
                                          ),
                                        ),
                                      if (verified &&
                                          locked &&
                                          paid &&
                                          !issued)
                                        FilledButton.icon(
                                          onPressed: () =>
                                              _issue(
                                            doc.reference,
                                            data,
                                          ),
                                          icon: const Icon(
                                            Icons
                                                .confirmation_number_rounded,
                                          ),
                                          label: const Text(
                                            'Issue Ticket',
                                          ),
                                        ),
                                      if (!cancelled)
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _cancel(
                                            doc.reference,
                                            data,
                                          ),
                                          icon: const Icon(
                                            Icons.cancel_rounded,
                                          ),
                                          label: const Text(
                                            'Cancel',
                                          ),
                                        ),
                                      if (data['paymentStatus'] ==
                                          'refund_pending')
                                        FilledButton.tonalIcon(
                                          onPressed: () =>
                                              _markRefunded(
                                            doc.reference,
                                          ),
                                          icon: const Icon(
                                            Icons
                                                .currency_exchange_rounded,
                                          ),
                                          label: const Text(
                                            'Mark Refunded',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
}

class _AdminBusFareApprovalPage extends StatefulWidget {
  const _AdminBusFareApprovalPage();

  @override
  State<_AdminBusFareApprovalPage> createState() =>
      _AdminBusFareApprovalPageState();
}

class _AdminBusFareApprovalPageState
    extends State<_AdminBusFareApprovalPage> {
  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _approve(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final double pending = _number(data['pendingFarePerSeat']);
    if (pending < 0) {
      _message('Requested fare is invalid.');
      return;
    }

    final String operatorId = data['operatorId']?.toString() ?? '';
    double commissionPercent = _number(data['commissionPercent']);
    if (operatorId.isNotEmpty) {
      final DocumentSnapshot<Map<String, dynamic>> operatorDoc =
          await FirebaseFirestore.instance
              .collection('bus_operators')
              .doc(operatorId)
              .get();
      commissionPercent = _number(
        operatorDoc.data()?['commissionPercent'],
      ).clamp(0, 100).toDouble();
    }

    final bool firstApproval = data['fareEverApproved'] == false;
    final bool requestedActive = data['requestedActive'] != false;
    final String adminUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    await doc.reference.update(<String, dynamic>{
      'farePerSeat': pending,
      'serviceFee': 0.0,
      'commissionPercent': commissionPercent,
      'fareApprovalStatus': 'approved',
      'fareEverApproved': true,
      'pendingFarePerSeat': FieldValue.delete(),
      'fareChangeRequestedAt': FieldValue.delete(),
      'fareApprovedAt': FieldValue.serverTimestamp(),
      'fareApprovedBy': adminUid,
      'fareRejectedAt': FieldValue.delete(),
      'fareRejectedBy': FieldValue.delete(),
      if (firstApproval) 'isActive': requestedActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _message('Fare approved. Customer fare is now updated.');
  }

  Future<void> _reject(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final double rejectedFare = _number(data['pendingFarePerSeat']);
    final bool firstApproval = data['fareEverApproved'] == false;
    final String adminUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    await doc.reference.update(<String, dynamic>{
      'fareApprovalStatus': 'rejected',
      'lastRejectedFare': rejectedFare,
      'pendingFarePerSeat': FieldValue.delete(),
      'fareChangeRequestedAt': FieldValue.delete(),
      'fareRejectedAt': FieldValue.serverTimestamp(),
      'fareRejectedBy': adminUid,
      if (firstApproval) 'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _message('Fare request rejected. Previous approved fare remains.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Fare Approvals',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_schedules')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load fare requests.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ].where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            return doc.data()['fareApprovalStatus'] == 'pending' &&
                doc.data()['pendingFarePerSeat'] is num;
          }).toList();

          docs.sort((a, b) {
            final Timestamp? at = a.data()['fareChangeRequestedAt'] is Timestamp
                ? a.data()['fareChangeRequestedAt'] as Timestamp
                : null;
            final Timestamp? bt = b.data()['fareChangeRequestedAt'] is Timestamp
                ? b.data()['fareChangeRequestedAt'] as Timestamp
                : null;
            return (bt?.millisecondsSinceEpoch ?? 0)
                .compareTo(at?.millisecondsSinceEpoch ?? 0);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No pending fare approvals.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                  docs[index];
              final Map<String, dynamic> data = doc.data();
              final double oldFare = _number(data['farePerSeat']);
              final double requested = _number(data['pendingFarePerSeat']);
              final bool newSchedule = data['fareEverApproved'] == false;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '${data['operatorName'] ?? 'Bus Operator'} • ${data['busName'] ?? 'Bus'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data['from'] ?? ''} → ${data['to'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        newSchedule
                            ? 'New Schedule Fare: Rs. ${requested.toStringAsFixed(0)}'
                            : 'Approved Fare: Rs. ${oldFare.toStringAsFixed(0)}',
                      ),
                      if (!newSchedule)
                        Text(
                          'Requested New Fare: Rs. ${requested.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      Text(
                        'Commission: ${_number(data['commissionPercent']).toStringAsFixed(2)}%',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: () => _approve(doc),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve Fare'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _reject(doc),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminBusOperatorChargesPage extends StatefulWidget {
  const _AdminBusOperatorChargesPage();

  @override
  State<_AdminBusOperatorChargesPage> createState() =>
      _AdminBusOperatorChargesPageState();
}

class _AdminBusOperatorChargesPageState
    extends State<_AdminBusOperatorChargesPage> {
  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _syncCommissionToSchedules(
    String operatorId,
    double commissionPercent,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('bus_schedules')
            .where('operatorId', isEqualTo: operatorId)
            .get();

    const int batchSize = 400;
    for (int start = 0; start < snapshot.docs.length; start += batchSize) {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final int end = (start + batchSize < snapshot.docs.length)
          ? start + batchSize
          : snapshot.docs.length;
      for (int index = start; index < end; index++) {
        batch.update(
          snapshot.docs[index].reference,
          <String, dynamic>{
            'commissionPercent': commissionPercent,
            'serviceFee': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();
    }
  }

  Future<void> _editCharges(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final TextEditingController monthlyController = TextEditingController(
      text: _number(data['monthlyFee']).toStringAsFixed(0),
    );
    final TextEditingController commissionController = TextEditingController(
      text: _number(data['commissionPercent']).toString(),
    );

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Monthly Fee & Commission',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: monthlyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly Fee (Rs.)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commissionController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Commission (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'These are the only two RD Bus Operator charges. No separate booking/service fee is added to the customer fare.',
                style: TextStyle(height: 1.3),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (save != true) {
      monthlyController.dispose();
      commissionController.dispose();
      return;
    }

    final double? monthly = double.tryParse(monthlyController.text.trim());
    final double? commission =
        double.tryParse(commissionController.text.trim());
    monthlyController.dispose();
    commissionController.dispose();

    if (monthly == null || monthly < 0) {
      _message('Monthly Fee must be 0 or more.');
      return;
    }
    if (commission == null || commission < 0 || commission > 100) {
      _message('Commission must be between 0% and 100%.');
      return;
    }

    await doc.reference.update(<String, dynamic>{
      'monthlyFee': monthly,
      'commissionPercent': commission,
      'chargesUpdatedAt': FieldValue.serverTimestamp(),
      'chargesUpdatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncCommissionToSchedules(doc.id, commission);
    _message('Monthly Fee and Commission saved.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Operator Charges',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Monthly Fee Payment Board',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _AdminBusMonthlyFeeBoardPage(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_operators')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load Bus Operators.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ];
          docs.sort((a, b) {
            return (a.data()['companyName']?.toString() ?? '')
                .toLowerCase()
                .compareTo(
                  (b.data()['companyName']?.toString() ?? '').toLowerCase(),
                );
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No Bus Operators found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                  docs[index];
              final Map<String, dynamic> data = doc.data();
              final double monthly = _number(data['monthlyFee']);
              final double commission =
                  _number(data['commissionPercent']).clamp(0, 100).toDouble();

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.directions_bus_rounded),
                  ),
                  title: Text(
                    data['companyName']?.toString() ?? 'Bus Operator',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Monthly Fee: Rs. ${monthly.toStringAsFixed(0)} / month\n'
                    'Commission: ${commission.toStringAsFixed(2)}%\n'
                    'Status: ${data['isApproved'] == true ? 'APPROVED' : 'PENDING'} • ${data['isActive'] == true ? 'ACTIVE' : 'INACTIVE'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit Monthly Fee & Commission',
                    onPressed: () => _editCharges(doc),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}



class _AdminBusMonthlyFeeBoardPage extends StatefulWidget {
  const _AdminBusMonthlyFeeBoardPage();

  @override
  State<_AdminBusMonthlyFeeBoardPage> createState() =>
      _AdminBusMonthlyFeeBoardPageState();
}

class _AdminBusMonthlyFeeBoardPageState
    extends State<_AdminBusMonthlyFeeBoardPage> {
  String _period = 'month';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    return null;
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _monthKey(int year, int month) => '$year${_two(month)}';

  String _monthLabel(int year, int month) =>
      '${_monthNames[month - 1]} $year';

  String _dateTimeText(DateTime? value) {
    if (value == null) {
      return 'Pending server time';
    }
    final int hour24 = value.hour;
    final int hour12 =
        hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final String amPm = hour24 >= 12 ? 'PM' : 'AM';
    return '${_two(value.day)}/${_two(value.month)}/${value.year} '
        '${_two(hour12)}:${_two(value.minute)} $amPm';
  }

  String _money(double value) => 'Rs. ${value.toStringAsFixed(0)}';

  bool _activeApproved(Map<String, dynamic> data) {
    return data['role']?.toString() == 'busOperator' &&
        data['isApproved'] == true &&
        data['isActive'] == true;
  }

  bool _paymentMatches(Map<String, dynamic> data) {
    if (data['paymentStatus']?.toString() != 'paid') {
      return false;
    }
    final int year = data['year'] is int
        ? data['year'] as int
        : int.tryParse(data['year']?.toString() ?? '') ?? 0;
    final int month = data['month'] is int
        ? data['month'] as int
        : int.tryParse(data['month']?.toString() ?? '') ?? 0;

    if (_period == 'month') {
      return year == _selectedYear && month == _selectedMonth;
    }
    if (_period == 'year') {
      return year == _selectedYear;
    }
    return true;
  }

  String _paymentDocId(String operatorId, int year, int month) =>
      '${operatorId}_${_monthKey(year, month)}';

  String _receiptNumber(String operatorId, int year, int month) {
    final String compact = operatorId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final String suffix = compact.substring(0, min(6, compact.length));
    return 'RDMF-${_monthKey(year, month)}-$suffix';
  }

  Future<void> _recordCashPayment(
    QueryDocumentSnapshot<Map<String, dynamic>> operatorDoc,
  ) async {
    final Map<String, dynamic> operator = operatorDoc.data();
    final double monthlyFee = _number(operator['monthlyFee']);

    if (monthlyFee <= 0) {
      _message('This operator has no Monthly Fee configured.');
      return;
    }

    final DocumentReference<Map<String, dynamic>> paymentRef =
        FirebaseFirestore.instance
            .collection('bus_operator_monthly_fee_payments')
            .doc(
              _paymentDocId(
                operatorDoc.id,
                _selectedYear,
                _selectedMonth,
              ),
            );

    final DocumentSnapshot<Map<String, dynamic>> existing =
        await paymentRef.get();

    if (!mounted) {
      return;
    }

    final String existingStatus =
        existing.data()?['paymentStatus']?.toString() ?? '';
    if (existingStatus == 'paid') {
      _message('Monthly Fee is already PAID for this month.');
      return;
    }
    if (existingStatus == 'submitted') {
      _message(
        'Operator already submitted payment proof. Use Confirm Received or Reject.',
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Record Cash Received',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  operator['companyName']?.toString() ?? 'Bus Operator',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_monthLabel(_selectedYear, _selectedMonth)),
                const SizedBox(height: 10),
                Text(
                  'Cash Received: ${_money(monthlyFee)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use this only when RD has physically received the full Monthly Fee in cash. Bank/eSewa/Khalti/connectIPS proof must be submitted by the Bus Operator and verified by Admin.',
                  style: TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Confirm Cash Received'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final String adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String receiptNumber = _receiptNumber(
      operatorDoc.id,
      _selectedYear,
      _selectedMonth,
    );

    try {
      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> current =
              await transaction.get(paymentRef);
          final String status =
              current.data()?['paymentStatus']?.toString() ?? '';

          if (status == 'paid') {
            throw StateError(
              'Monthly Fee is already PAID for this month.',
            );
          }
          if (status == 'submitted') {
            throw StateError(
              'Operator submitted payment proof. Verify or reject that submission first.',
            );
          }

          final Map<String, dynamic> paidData = <String, dynamic>{
            'paymentId': paymentRef.id,
            'receiptNumber': receiptNumber,
            'operatorId': operatorDoc.id,
            'operatorName':
                operator['companyName']?.toString() ?? 'Bus Operator',
            'operatorPhone': operator['phone']?.toString() ?? '',
            'monthKey': _monthKey(_selectedYear, _selectedMonth),
            'monthLabel': _monthLabel(_selectedYear, _selectedMonth),
            'year': _selectedYear,
            'month': _selectedMonth,
            'monthlyFeeAmount': monthlyFee,
            'commissionPercentSnapshot':
                _number(operator['commissionPercent']),
            'paymentStatus': 'paid',
            'paymentMethod': 'Cash',
            'paymentReference': '',
            'recordedByAdminUid': adminUid,
            'paidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (current.exists) {
            transaction.update(paymentRef, paidData);
          } else {
            transaction.set(
              paymentRef,
              <String, dynamic>{
                ...paidData,
                'submittedByOperatorUid': '',
                'createdAt': FieldValue.serverTimestamp(),
              },
            );
          }
        },
      );
      _message('Cash Monthly Fee marked PAID. Receipt: $receiptNumber');
    } on StateError catch (error) {
      _message(error.message);
    } on FirebaseException catch (error) {
      _message(
        'Could not record cash Monthly Fee: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _confirmSubmittedPayment(
    DocumentReference<Map<String, dynamic>> paymentRef,
    Map<String, dynamic> payment,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Confirm Money Received',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  payment['operatorName']?.toString() ?? 'Bus Operator',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(payment['monthLabel']?.toString() ?? ''),
                const SizedBox(height: 10),
                Text(
                  'Amount: ${_money(_number(payment['monthlyFeeAmount']))}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('Method: ${payment['paymentMethod'] ?? ''}'),
                SelectableText(
                  'Transaction / Voucher: ${payment['paymentReference'] ?? ''}',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Confirm only after checking the RD bank/wallet/payment account and verifying that this exact payment actually arrived.',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Confirm Received'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final String operatorId = payment['operatorId']?.toString() ?? '';
    final int year = payment['year'] is int
        ? payment['year'] as int
        : int.tryParse(payment['year']?.toString() ?? '') ?? 0;
    final int month = payment['month'] is int
        ? payment['month'] as int
        : int.tryParse(payment['month']?.toString() ?? '') ?? 0;
    final String receiptNumber = _receiptNumber(operatorId, year, month);
    final String adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> current =
              await transaction.get(paymentRef);
          if (!current.exists ||
              current.data()?['paymentStatus']?.toString() != 'submitted') {
            throw StateError(
              'This payment is no longer waiting for verification.',
            );
          }

          transaction.update(
            paymentRef,
            <String, dynamic>{
              'paymentStatus': 'paid',
              'receiptNumber': receiptNumber,
              'recordedByAdminUid': adminUid,
              'verifiedByAdminUid': adminUid,
              'verifiedAt': FieldValue.serverTimestamp(),
              'paidAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );
      _message('Monthly Fee verified and marked PAID.');
    } on StateError catch (error) {
      _message(error.message);
    } on FirebaseException catch (error) {
      _message(
        'Could not verify Monthly Fee: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _rejectSubmittedPayment(
    DocumentReference<Map<String, dynamic>> paymentRef,
    Map<String, dynamic> payment,
  ) async {
    final TextEditingController reasonController = TextEditingController();

    final bool? reject = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          title: const Text(
            'Reject Payment Proof',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  payment['operatorName']?.toString() ?? 'Bus Operator',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(payment['monthLabel']?.toString() ?? ''),
                const SizedBox(height: 10),
                SelectableText(
                  'Transaction / Voucher: ${payment['paymentReference'] ?? ''}',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for rejection',
                    hintText: 'Example: Transaction not found in RD account',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a rejection reason.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.cancel_rounded),
              label: const Text('Reject'),
            ),
          ],
        );
      },
    );

    final String reason = reasonController.text.trim();
    reasonController.dispose();

    if (reject != true || reason.isEmpty) {
      return;
    }

    final String adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> current =
              await transaction.get(paymentRef);
          if (!current.exists ||
              current.data()?['paymentStatus']?.toString() != 'submitted') {
            throw StateError(
              'This payment is no longer waiting for verification.',
            );
          }

          transaction.update(
            paymentRef,
            <String, dynamic>{
              'paymentStatus': 'rejected',
              'rejectionReason': reason,
              'rejectedByAdminUid': adminUid,
              'rejectedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );
      _message('Payment proof rejected. Operator can resubmit.');
    } on StateError catch (error) {
      _message(error.message);
    } on FirebaseException catch (error) {
      _message(
        'Could not reject Monthly Fee proof: ${error.message ?? error.code}',
      );
    }
  }

  void _showReceipt(Map<String, dynamic> data) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'RD Monthly Fee Receipt',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SelectableText(
                  'Receipt: ${data['receiptNumber'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text('Operator: ${data['operatorName'] ?? ''}'),
                Text('Month: ${data['monthLabel'] ?? ''}'),
                Text(
                  'Amount: ${_money(_number(data['monthlyFeeAmount']))}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('Method: ${data['paymentMethod'] ?? ''}'),
                if ((data['paymentReference']?.toString().trim() ?? '')
                    .isNotEmpty)
                  SelectableText(
                    'Reference: ${data['paymentReference']}',
                  ),
                Text('Paid: ${_dateTimeText(_date(data['paidAt']))}'),
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 205,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: <Widget>[
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodControls() {
    final int currentYear = DateTime.now().year;
    final List<int> years = <int>[
      for (int year = currentYear - 5; year <= currentYear + 2; year++) year,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <String>['month', 'year', 'all'].map((String value) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(value.toUpperCase()),
                  selected: _period == value,
                  onSelected: (_) {
                    setState(() {
                      _period = value;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        if (_period != 'all')
          LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final Widget year = DropdownButtonFormField<int>(
                initialValue: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                items: years
                    .map(
                      (int value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedYear = value;
                    });
                  }
                },
              );

              final Widget month = DropdownButtonFormField<int>(
                initialValue: _selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                ),
                items: List<DropdownMenuItem<int>>.generate(
                  12,
                  (int index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(_monthNames[index]),
                  ),
                ),
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedMonth = value;
                    });
                  }
                },
              );

              if (_period == 'year') {
                return year;
              }

              if (constraints.maxWidth < 520) {
                return Column(
                  children: <Widget>[
                    month,
                    const SizedBox(height: 10),
                    year,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: month),
                  const SizedBox(width: 10),
                  Expanded(child: year),
                ],
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Monthly Fee Board',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_operators')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> operatorSnapshot,
        ) {
          if (!operatorSnapshot.hasData &&
              operatorSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (operatorSnapshot.hasError) {
            return Center(
              child: Text(
                'Could not load Bus Operators.\n${operatorSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bus_operator_monthly_fee_payments')
                .snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> paymentSnapshot,
            ) {
              if (!paymentSnapshot.hasData &&
                  paymentSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (paymentSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load Monthly Fee payments.\n${paymentSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  operators = <QueryDocumentSnapshot<Map<String, dynamic>>>[
                ...?operatorSnapshot.data?.docs,
              ];
              operators.sort((a, b) {
                return (a.data()['companyName']?.toString() ?? '')
                    .toLowerCase()
                    .compareTo(
                      (b.data()['companyName']?.toString() ?? '')
                          .toLowerCase(),
                    );
              });

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  allPayments = <QueryDocumentSnapshot<Map<String, dynamic>>>[
                ...?paymentSnapshot.data?.docs,
              ];

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  filteredPayments = allPayments
                      .where(
                        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                            _paymentMatches(doc.data()),
                      )
                      .toList();
              filteredPayments.sort((a, b) {
                final int aMs =
                    _date(a.data()['paidAt'])?.millisecondsSinceEpoch ?? 0;
                final int bMs =
                    _date(b.data()['paidAt'])?.millisecondsSinceEpoch ?? 0;
                return bMs.compareTo(aMs);
              });

              if (_period != 'month') {
                final double collected = filteredPayments.fold<double>(
                  0,
                  (double sum,
                          QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      sum + _number(doc.data()['monthlyFeeAmount']),
                );
                final Set<String> paidOperators = filteredPayments
                    .map(
                      (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                          doc.data()['operatorId']?.toString() ?? '',
                    )
                    .where((String value) => value.isNotEmpty)
                    .toSet();

                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _periodControls(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _metricCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Payments',
                          value: '${filteredPayments.length}',
                        ),
                        _metricCard(
                          icon: Icons.payments_rounded,
                          label: 'Collected',
                          value: _money(collected),
                        ),
                        _metricCard(
                          icon: Icons.directions_bus_rounded,
                          label: 'Operators Paid',
                          value: '${paidOperators.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _period == 'year'
                          ? 'Monthly Fee History • $_selectedYear'
                          : 'All Monthly Fee History',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (filteredPayments.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'No Monthly Fee payments found for this period.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...filteredPayments.map(
                        (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                          final Map<String, dynamic> data = doc.data();
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.receipt_rounded),
                              ),
                              title: Text(
                                data['operatorName']?.toString() ??
                                    'Bus Operator',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${data['monthLabel'] ?? ''}\n'
                                '${_money(_number(data['monthlyFeeAmount']))} • '
                                '${data['paymentMethod'] ?? ''}\n'
                                '${_dateTimeText(_date(data['paidAt']))}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'View Receipt',
                                onPressed: () => _showReceipt(data),
                                icon: const Icon(Icons.visibility_rounded),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              }

              final String selectedKey =
                  _monthKey(_selectedYear, _selectedMonth);
              final Map<String, Map<String, dynamic>> paymentByOperator =
                  <String, Map<String, dynamic>>{};
              final Map<String, DocumentReference<Map<String, dynamic>>>
                  paymentRefByOperator =
                  <String, DocumentReference<Map<String, dynamic>>>{};
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in allPayments) {
                final Map<String, dynamic> data = doc.data();
                if (data['monthKey']?.toString() == selectedKey) {
                  final String operatorId =
                      data['operatorId']?.toString() ?? '';
                  if (operatorId.isNotEmpty) {
                    paymentByOperator[operatorId] = data;
                    paymentRefByOperator[operatorId] = doc.reference;
                  }
                }
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  dueOperators = operators
                      .where(
                        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                            _activeApproved(doc.data()),
                      )
                      .toList();

              double expected = 0;
              double collected = 0;
              double pending = 0;
              int paidCount = 0;
              int unpaidCount = 0;
              int submittedCount = 0;
              int noFeeCount = 0;

              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in dueOperators) {
                final double monthlyFee = _number(doc.data()['monthlyFee']);
                if (monthlyFee <= 0) {
                  noFeeCount += 1;
                  continue;
                }
                expected += monthlyFee;
                final Map<String, dynamic>? payment =
                    paymentByOperator[doc.id];
                final String status =
                    payment?['paymentStatus']?.toString() ?? 'unpaid';
                if (status == 'paid') {
                  collected += _number(payment?['monthlyFeeAmount']);
                  paidCount += 1;
                } else {
                  pending += monthlyFee;
                  unpaidCount += 1;
                  if (status == 'submitted') {
                    submittedCount += 1;
                  }
                }
              }

              return ListView(
                padding: const EdgeInsets.all(14),
                children: <Widget>[
                  _periodControls(),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.calendar_month_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _monthLabel(_selectedYear, _selectedMonth),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _metricCard(
                        icon: Icons.request_quote_rounded,
                        label: 'Expected',
                        value: _money(expected),
                      ),
                      _metricCard(
                        icon: Icons.check_circle_rounded,
                        label: 'Collected',
                        value: _money(collected),
                      ),
                      _metricCard(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pending',
                        value: _money(pending),
                      ),
                      _metricCard(
                        icon: Icons.directions_bus_rounded,
                        label: 'Paid / Unpaid',
                        value: '$paidCount / $unpaidCount',
                      ),
                      _metricCard(
                        icon: Icons.fact_check_rounded,
                        label: 'Awaiting Verify',
                        value: '$submittedCount',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Operator Monthly Fee Status',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (dueOperators.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No active approved Bus Operators found.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...dueOperators.map(
                      (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                        final Map<String, dynamic> operator = doc.data();
                        final double monthlyFee =
                            _number(operator['monthlyFee']);
                        final Map<String, dynamic>? payment =
                            paymentByOperator[doc.id];
                        final DocumentReference<Map<String, dynamic>>?
                            paymentRef = paymentRefByOperator[doc.id];
                        final String paymentStatus =
                            payment?['paymentStatus']?.toString() ?? 'unpaid';
                        final bool paid = paymentStatus == 'paid';
                        final bool submitted = paymentStatus == 'submitted';
                        final bool rejected = paymentStatus == 'rejected';
                        final bool noFee = monthlyFee <= 0;
                        final String status = noFee
                            ? 'NO FEE'
                            : paid
                                ? 'PAID'
                                : submitted
                                    ? 'SUBMITTED'
                                    : rejected
                                        ? 'REJECTED'
                                        : 'UNPAID';

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    const CircleAvatar(
                                      child: Icon(Icons.directions_bus_rounded),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            operator['companyName']
                                                    ?.toString() ??
                                                'Bus Operator',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            'Monthly Fee: ${_money(monthlyFee)}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      avatar: Icon(
                                        noFee
                                            ? Icons.remove_circle_outline
                                            : paid
                                                ? Icons.check_circle_rounded
                                                : submitted
                                                    ? Icons.hourglass_top_rounded
                                                    : rejected
                                                        ? Icons.cancel_rounded
                                                        : Icons.schedule_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        status,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (paid && payment != null) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Paid Amount: ${_money(_number(payment['monthlyFeeAmount']))}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Method: ${payment['paymentMethod'] ?? ''}',
                                  ),
                                  if ((payment['paymentReference']?.toString() ?? '')
                                      .isNotEmpty)
                                    SelectableText(
                                      'Transaction / Voucher: ${payment['paymentReference']}',
                                    ),
                                  Text(
                                    'Paid Date: ${_dateTimeText(_date(payment['paidAt']))}',
                                  ),
                                  SelectableText(
                                    'Receipt: ${payment['receiptNumber'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showReceipt(payment),
                                      icon: const Icon(Icons.receipt_rounded),
                                      label: const Text('View Receipt'),
                                    ),
                                  ),
                                ] else if (submitted &&
                                    payment != null &&
                                    paymentRef != null) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Submitted Amount: ${_money(_number(payment['monthlyFeeAmount']))}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Method: ${payment['paymentMethod'] ?? ''}',
                                  ),
                                  SelectableText(
                                    'Transaction / Voucher: ${payment['paymentReference'] ?? ''}',
                                  ),
                                  Text(
                                    'Submitted: ${_dateTimeText(_date(payment['submittedAt']))}',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _rejectSubmittedPayment(
                                          paymentRef,
                                          payment,
                                        ),
                                        icon: const Icon(Icons.cancel_rounded),
                                        label: const Text('Reject'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () =>
                                            _confirmSubmittedPayment(
                                          paymentRef,
                                          payment,
                                        ),
                                        icon: const Icon(Icons.verified_rounded),
                                        label: const Text('Confirm Received'),
                                      ),
                                    ],
                                  ),
                                ] else if (rejected && payment != null) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Rejected: ${payment['rejectionReason'] ?? 'Payment proof rejected.'}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _recordCashPayment(doc),
                                      icon: const Icon(Icons.payments_rounded),
                                      label: const Text('Record Cash Received'),
                                    ),
                                  ),
                                ] else if (!noFee) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _recordCashPayment(doc),
                                      icon: const Icon(Icons.payments_rounded),
                                      label: const Text('Record Cash Received'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Expected/Pending totals use currently APPROVED + ACTIVE operators. Online/bank proof is submitted by the Bus Operator and stays SUBMITTED until Admin verifies that RD actually received the money. Admin can reject incorrect proof. Cash is recorded by Admin only after physical cash receipt. PAID records keep receipt, method, reference and paid date.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (noFeeCount > 0) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'No-fee operators this month: $noFeeCount',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminBusCommissionBoardPage extends StatefulWidget {
  const _AdminBusCommissionBoardPage();

  @override
  State<_AdminBusCommissionBoardPage> createState() =>
      _AdminBusCommissionBoardPageState();
}

class _AdminBusCommissionBoardPageState
    extends State<_AdminBusCommissionBoardPage> {
  String _period = 'today';
  DateTime _customDate = DateTime.now();

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    return null;
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _dateText(DateTime value) =>
      '${_two(value.day)}/${_two(value.month)}/${value.year}';

  String _dateTimeText(DateTime? value) {
    if (value == null) {
      return 'Date not available';
    }
    final int hour24 = value.hour;
    final int hour12 =
        hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final String amPm = hour24 >= 12 ? 'PM' : 'AM';
    return '${_dateText(value)} ${_two(hour12)}:${_two(value.minute)} $amPm';
  }

  DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  DateTime? _bookingDate(Map<String, dynamic> data) {
    return _date(data['paidAt']) ??
        _date(data['issuedAt']) ??
        _date(data['createdAt']);
  }

  bool _periodMatches(Map<String, dynamic> data) {
    if (_period == 'all') {
      return true;
    }

    final DateTime? value = _bookingDate(data);
    if (value == null) {
      return false;
    }

    final DateTime now = DateTime.now();

    if (_period == 'today') {
      return _sameDay(value, now);
    }

    if (_period == 'week') {
      final DateTime today = _dayStart(now);
      final DateTime start =
          today.subtract(Duration(days: today.weekday - 1));
      final DateTime end = start.add(const Duration(days: 7));
      return !value.isBefore(start) && value.isBefore(end);
    }

    if (_period == 'month') {
      return value.year == now.year && value.month == now.month;
    }

    if (_period == 'year') {
      return value.year == now.year;
    }

    if (_period == 'date') {
      return _sameDay(value, _customDate);
    }

    return true;
  }

  bool _eligible(Map<String, dynamic> data) {
    final String paymentStatus =
        data['paymentStatus']?.toString().toLowerCase() ?? '';
    final String bookingStatus =
        data['bookingStatus']?.toString().toLowerCase() ?? '';
    final String ticketStatus =
        data['ticketStatus']?.toString().toLowerCase() ?? '';

    return paymentStatus == 'paid' &&
        bookingStatus != 'cancelled' &&
        ticketStatus != 'cancelled';
  }

  double _gross(Map<String, dynamic> data) {
    final double base = _number(data['baseFare']);
    if (base > 0) {
      return base;
    }
    return _number(data['totalFare']);
  }

  double _commissionPercent(Map<String, dynamic> data) {
    return _number(data['commissionPercent']).clamp(0, 100).toDouble();
  }

  double _commissionAmount(Map<String, dynamic> data) {
    final dynamic saved = data['rdCommissionAmount'];
    if (saved is num) {
      return saved.toDouble();
    }
    final double gross = _gross(data);
    return gross * _commissionPercent(data) / 100;
  }

  double _operatorNet(Map<String, dynamic> data) {
    final dynamic saved = data['operatorNetAmount'];
    if (saved is num) {
      return saved.toDouble();
    }
    return _gross(data) - _commissionAmount(data);
  }

  String _money(double value) => 'Rs. ${value.toStringAsFixed(0)}';

  String _periodTitle() {
    final DateTime now = DateTime.now();
    switch (_period) {
      case 'today':
        return 'Today • ${_dateText(now)}';
      case 'week':
        final DateTime today = _dayStart(now);
        final DateTime start =
            today.subtract(Duration(days: today.weekday - 1));
        final DateTime end = start.add(const Duration(days: 6));
        return 'This Week • ${_dateText(start)} - ${_dateText(end)}';
      case 'month':
        return 'This Month • ${_two(now.month)}/${now.year}';
      case 'year':
        return 'This Year • ${now.year}';
      case 'date':
        return 'Selected Date • ${_dateText(_customDate)}';
      case 'all':
      default:
        return 'All Paid Bus Tickets';
    }
  }

  Future<void> _pickCustomDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _customDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 3, 12, 31),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _customDate = selected;
      _period = 'date';
    });
  }

  void _selectPeriod(String value) {
    if (value == 'date') {
      _pickCustomDate();
      return;
    }
    setState(() {
      _period = value;
    });
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Commission Board',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Choose Date',
            onPressed: _pickCustomDate,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_ticket_bookings')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load commission report.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ].where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            return _eligible(data) && _periodMatches(data);
          }).toList();

          docs.sort((a, b) {
            final int am =
                _bookingDate(a.data())?.millisecondsSinceEpoch ?? 0;
            final int bm =
                _bookingDate(b.data())?.millisecondsSinceEpoch ?? 0;
            return bm.compareTo(am);
          });

          double grossTotal = 0;
          double commissionTotal = 0;
          double operatorNetTotal = 0;
          final Map<String, _BusCommissionOperatorTotals> operatorTotals =
              <String, _BusCommissionOperatorTotals>{};

          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
            final Map<String, dynamic> data = doc.data();
            final double gross = _gross(data);
            final double commission = _commissionAmount(data);
            final double net = _operatorNet(data);
            grossTotal += gross;
            commissionTotal += commission;
            operatorNetTotal += net;

            final String operatorId =
                data['operatorId']?.toString().trim() ?? '';
            final String operatorName =
                data['operatorName']?.toString().trim() ?? 'Bus Operator';
            final String key = operatorId.isNotEmpty ? operatorId : operatorName;
            final _BusCommissionOperatorTotals totals =
                operatorTotals.putIfAbsent(
              key,
              () => _BusCommissionOperatorTotals(operatorName: operatorName),
            );
            totals.ticketCount += 1;
            totals.gross += gross;
            totals.commission += commission;
            totals.operatorNet += net;
          }

          final List<_BusCommissionOperatorTotals> operatorList =
              operatorTotals.values.toList()
                ..sort((a, b) => b.commission.compareTo(a.commission));

          return ListView(
            padding: const EdgeInsets.all(14),
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <String>[
                    'today',
                    'week',
                    'month',
                    'year',
                    'date',
                    'all',
                  ].map((String value) {
                    final String label = switch (value) {
                      'today' => 'TODAY',
                      'week' => 'WEEK',
                      'month' => 'MONTH',
                      'year' => 'YEAR',
                      'date' => 'DATE',
                      _ => 'ALL',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _period == value,
                        onSelected: (_) => _selectPeriod(value),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.date_range_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _periodTitle(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (_period == 'date')
                        TextButton.icon(
                          onPressed: _pickCustomDate,
                          icon: const Icon(Icons.edit_calendar_rounded),
                          label: const Text('Change'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _metricCard(
                    icon: Icons.confirmation_number_rounded,
                    label: 'Paid Tickets',
                    value: '${docs.length}',
                  ),
                  _metricCard(
                    icon: Icons.payments_rounded,
                    label: 'Gross Fare',
                    value: _money(grossTotal),
                  ),
                  _metricCard(
                    icon: Icons.percent_rounded,
                    label: 'RD Commission',
                    value: _money(commissionTotal),
                  ),
                  _metricCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Operator Net',
                    value: _money(operatorNetTotal),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Operator Commission Summary',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (operatorList.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No paid bus-ticket commission found for this period.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                ...operatorList.map(
                  (_BusCommissionOperatorTotals item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            item.operatorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Paid Tickets: ${item.ticketCount}'),
                          Text('Gross Fare: ${_money(item.gross)}'),
                          Text(
                            'RD Commission: ${_money(item.commission)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text('Operator Net: ${_money(item.operatorNet)}'),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'Commission Transactions',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No transactions in this period.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...docs.map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                    final Map<String, dynamic> data = doc.data();
                    final double gross = _gross(data);
                    final double percent = _commissionPercent(data);
                    final double commission = _commissionAmount(data);
                    final double net = _operatorNet(data);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    data['bookingCode']?.toString() ?? doc.id,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  _dateTimeText(_bookingDate(data)),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['operatorName'] ?? 'Bus Operator'} • '
                              '${data['from'] ?? ''} → ${data['to'] ?? ''}',
                            ),
                            const SizedBox(height: 5),
                            Text('Fare: ${_money(gross)}'),
                            Text(
                              'Commission: ${percent.toStringAsFixed(2)}% • '
                              '${_money(commission)}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text('Operator Net: ${_money(net)}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              Text(
                'Commission report counts paid bookings only. Cancelled, refund-pending and refunded tickets are not counted. Monthly Fee remains separate under Bus Operator Charges.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BusCommissionOperatorTotals {
  _BusCommissionOperatorTotals({required this.operatorName});

  final String operatorName;
  int ticketCount = 0;
  double gross = 0;
  double commission = 0;
  double operatorNet = 0;
}

