import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusOperatorSchedulesPage extends StatelessWidget {
  const BusOperatorSchedulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

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
          'My Bus Schedules',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                const _BusOperatorScheduleFormPage(),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Schedule'),
      ),
      body: Column(
        children: <Widget>[
          _OperatorChargesBanner(operatorId: user.uid),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bus_schedules')
                  .where('operatorId', isEqualTo: user.uid)
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
                  'Could not load schedules.\n${snapshot.error}',
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
          ];

          docs.sort(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  a,
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  b,
            ) {
              final int am = _date(
                        a.data()['departureAt'],
                      )
                      ?.millisecondsSinceEpoch ??
                  0;
              final int bm = _date(
                        b.data()['departureAt'],
                      )
                      ?.millisecondsSinceEpoch ??
                  0;
              return bm.compareTo(am);
            },
          );

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No schedules yet.\nTap Add Schedule to publish your bus.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              14,
              14,
              14,
              90,
            ),
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
              final Map<String, dynamic> data =
                  doc.data();
              final String fareApprovalStatus =
                  data['fareApprovalStatus']?.toString() ??
                      'approved';
              final double approvedFare =
                  _number(data['farePerSeat']);
              final double pendingFare =
                  _number(data['pendingFarePerSeat']);
              final bool farePending =
                  fareApprovalStatus == 'pending';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const CircleAvatar(
                            child: Icon(
                              Icons.directions_bus_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${data['busName'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${data['busNumber'] ?? ''} • ${data['busType'] ?? ''}',
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value:
                                data['isActive'] == true,
                            onChanged:
                                data['fareEverApproved'] == false
                                    ? null
                                    : (bool value) async {
                                        try {
                                          await doc.reference.update(
                                            <String, dynamic>{
                                              'isActive': value,
                                              'requestedActive': value,
                                              'updatedAt': FieldValue
                                                  .serverTimestamp(),
                                            },
                                          );
                                        } on FirebaseException catch (e) {
                                          if (!context.mounted) {
                                            return;
                                          }

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.message ?? e.code,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      Text(
                        '${data['from'] ?? ''} → ${data['to'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Departure: ${_dateTime(_date(data['departureAt']))}',
                      ),
                      Text(
                        'Arrival: ${_dateTime(_date(data['arrivalAt']))}',
                      ),
                      Text(
                        data['fareEverApproved'] == false
                            ? 'Proposed Fare: Rs. ${pendingFare.toStringAsFixed(0)}'
                            : 'Approved Fare: Rs. ${approvedFare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (farePending)
                        Text(
                          data['fareEverApproved'] == false
                              ? 'NEW SCHEDULE • PENDING ADMIN APPROVAL'
                              : 'Requested Fare: Rs. ${pendingFare.toStringAsFixed(0)} • PENDING ADMIN APPROVAL',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      else
                        Text(
                          'Fare Approval: ${fareApprovalStatus.toUpperCase()}',
                          style: TextStyle(
                            color: fareApprovalStatus == 'rejected'
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        'Bus Staff: ${data['busStaffName'] ?? ''}'
                        ' • ${data['busStaffPhone'] ?? ''}',
                      ),
                      Text(
                        'Seats: ${data['seatLayout'] ?? '2+2'}'
                        ' • ${data['seatRows'] ?? 0} rows',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () {
                              final Map<String, dynamic>
                                  returnData =
                                  _returnTripData(data);

                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      _BusOperatorScheduleFormPage(
                                    initial: returnData,
                                    isReturnTrip: true,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                            ),
                            label: const Text(
                              'Create Return Trip',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    _BusOperatorScheduleFormPage(
                                  scheduleRef:
                                      doc.reference,
                                  initial: data,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.edit_rounded,
                            ),
                            label: const Text('Edit'),
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
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _returnTripData(
    Map<String, dynamic> data,
  ) {
    final Map<String, dynamic> reverse =
        <String, dynamic>{...data};

    reverse['from'] = data['to']?.toString() ?? '';
    reverse['to'] = data['from']?.toString() ?? '';
    reverse['boardingPoints'] =
        data['dropPoints'] ?? <String>[];
    reverse['dropPoints'] =
        data['boardingPoints'] ?? <String>[];

    // Legacy schedules created before Bus Staff fields existed
    // may not have busStaffName / busStaffPhone.
    // For Return Trip, prefill them from operator contact so
    // the form is not left blank and can still be edited.
    final String existingStaffName =
        data['busStaffName']?.toString().trim() ?? '';
    final String existingStaffPhone =
        data['busStaffPhone']?.toString().trim() ?? '';

    reverse['busStaffName'] =
        existingStaffName.isNotEmpty
            ? existingStaffName
            : (data['operatorName']?.toString().trim() ?? '');

    reverse['busStaffPhone'] =
        existingStaffPhone.isNotEmpty
            ? existingStaffPhone
            : (data['operatorPhone']?.toString().trim() ?? '');

    final DateTime now = DateTime.now();
    final DateTime? oldDeparture =
        _date(data['departureAt']);
    final DateTime? oldArrival =
        _date(data['arrivalAt']);

    Duration tripDuration =
        const Duration(hours: 6);

    if (oldDeparture != null &&
        oldArrival != null &&
        oldArrival.isAfter(oldDeparture)) {
      tripDuration =
          oldArrival.difference(oldDeparture);
    }

    DateTime returnDeparture =
        (oldArrival ??
                now.add(const Duration(days: 1)))
            .add(const Duration(hours: 1));

    if (returnDeparture.isBefore(now)) {
      returnDeparture =
          now.add(const Duration(days: 1));
    }

    final DateTime returnArrival =
        returnDeparture.add(tripDuration);

    reverse['departureAt'] =
        Timestamp.fromDate(returnDeparture);
    reverse['arrivalAt'] =
        Timestamp.fromDate(returnArrival);
    reverse['travelDate'] =
        Timestamp.fromDate(
      DateTime(
        returnDeparture.year,
        returnDeparture.month,
        returnDeparture.day,
      ),
    );

    reverse['routeDateKey'] = '';
    reverse['scheduleId'] = '';
    reverse['createdAt'] = null;
    reverse['updatedAt'] = null;

    return reverse;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    return null;
  }

  static double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  static String _two(int value) =>
      value.toString().padLeft(2, '0');

  static String _dateTime(DateTime? value) {
    if (value == null) {
      return 'Not available';
    }

    final int hour24 = value.hour;
    final int hour12 =
        hour24 == 0
            ? 12
            : (hour24 > 12
                ? hour24 - 12
                : hour24);
    final String amPm =
        hour24 >= 12 ? 'PM' : 'AM';

    return '${_two(value.day)}/${_two(value.month)}/${value.year} '
        '${_two(hour12)}:${_two(value.minute)} $amPm';
  }
}


class _OperatorChargesBanner extends StatelessWidget {
  const _OperatorChargesBanner({
    required this.operatorId,
  });

  final String operatorId;

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bus_operators')
          .doc(operatorId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};
        final double monthlyFee = _number(data['monthlyFee']);
        final double commission =
            _number(data['commissionPercent']).clamp(0, 100).toDouble();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'RD Operator Charges',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Monthly Fee: Rs. ${monthlyFee.toStringAsFixed(0)} / month',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'Commission: ${commission.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                'Only Admin can change Monthly Fee and Commission %. Fare changes are sent to Admin for approval before the new fare is used for customers.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _BusOperatorMonthlyFeePage(
                        operatorId: operatorId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Monthly Fee Payment'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _BusOperatorMonthlyFeePage extends StatefulWidget {
  const _BusOperatorMonthlyFeePage({
    required this.operatorId,
  });

  final String operatorId;

  @override
  State<_BusOperatorMonthlyFeePage> createState() =>
      _BusOperatorMonthlyFeePageState();
}

class _BusOperatorMonthlyFeePageState
    extends State<_BusOperatorMonthlyFeePage> {
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

  late int _selectedMonth;
  late int _selectedYear;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _monthKey(int year, int month) => '$year${_two(month)}';

  String _monthLabel(int year, int month) =>
      '${_monthNames[month - 1]} $year';

  String _paymentDocId() =>
      '${widget.operatorId}_${_monthKey(_selectedYear, _selectedMonth)}';

  String _statusLabel(String raw) {
    switch (raw) {
      case 'submitted':
        return 'PENDING VERIFICATION';
      case 'paid':
        return 'PAID';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'UNPAID';
    }
  }

  Color _statusColor(String raw) {
    switch (raw) {
      case 'submitted':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _submitPaymentProof(
    Map<String, dynamic> operator,
    Map<String, dynamic>? existing,
  ) async {
    final double monthlyFee = _number(operator['monthlyFee']);
    if (monthlyFee <= 0) {
      _message('No Monthly Fee is configured for this operator.');
      return;
    }

    final String currentStatus =
        existing?['paymentStatus']?.toString() ?? 'unpaid';
    if (currentStatus == 'paid') {
      _message('This month is already PAID.');
      return;
    }
    if (currentStatus == 'submitted') {
      _message('Payment proof is already waiting for Admin verification.');
      return;
    }

    String method = 'Bank';
    final TextEditingController referenceController =
        TextEditingController();

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setStateDialog,
          ) {
            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              title: const Text(
                'Submit Monthly Fee Payment',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      _monthLabel(_selectedYear, _selectedMonth),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Amount Due: Rs. ${monthlyFee.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text('Bank'),
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
                      controller: referenceController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID / Voucher No.',
                        hintText: 'Required',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'First transfer the Monthly Fee to the RD account/payment destination provided by Admin. Then submit the real transaction ID or voucher number here. Submitting proof does not mark the fee PAID until Admin confirms that RD actually received the money.',
                      style: TextStyle(height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cash payment is not submitted here. If you pay cash directly to RD, Admin records it after receiving the cash.',
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
                  onPressed: () {
                    if (referenceController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Transaction ID / Voucher No. is required.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Submit Proof'),
                ),
              ],
            );
          },
        );
      },
    );

    final String reference = referenceController.text.trim();
    referenceController.dispose();

    if (submit != true || reference.isEmpty) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final DocumentReference<Map<String, dynamic>> paymentRef =
        FirebaseFirestore.instance
            .collection('bus_operator_monthly_fee_payments')
            .doc(_paymentDocId());

    try {
      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> current =
              await transaction.get(paymentRef);

          if (current.exists) {
            final String status =
                current.data()?['paymentStatus']?.toString() ?? '';
            if (status == 'paid') {
              throw StateError('This month is already PAID.');
            }
            if (status == 'submitted') {
              throw StateError(
                'Payment proof is already waiting for Admin verification.',
              );
            }
            if (status != 'rejected') {
              throw StateError(
                'This Monthly Fee record cannot be resubmitted.',
              );
            }

            transaction.update(
              paymentRef,
              <String, dynamic>{
                'paymentStatus': 'submitted',
                'paymentMethod': method,
                'paymentReference': reference,
                'submittedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );
            return;
          }

          transaction.set(
            paymentRef,
            <String, dynamic>{
              'paymentId': paymentRef.id,
              'receiptNumber': '',
              'operatorId': widget.operatorId,
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
              'paymentStatus': 'submitted',
              'paymentMethod': method,
              'paymentReference': reference,
              'submittedByOperatorUid': widget.operatorId,
              'recordedByAdminUid': '',
              'submittedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );

      _message('Payment proof submitted. Waiting for Admin verification.');
    } on StateError catch (error) {
      _message(error.message);
    } on FirebaseException catch (error) {
      _message(
        'Could not submit payment proof: ${error.message ?? error.code}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
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
    final DocumentReference<Map<String, dynamic>> operatorRef =
        FirebaseFirestore.instance
            .collection('bus_operators')
            .doc(widget.operatorId);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'My Monthly Fee',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: operatorRef.snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> operatorSnap,
        ) {
          if (!operatorSnap.hasData &&
              operatorSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (operatorSnap.hasError) {
            return Center(
              child: Text(
                'Could not load operator charges.\n${operatorSnap.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final Map<String, dynamic> operator =
              operatorSnap.data?.data() ?? <String, dynamic>{};
          final double monthlyFee = _number(operator['monthlyFee']);
          final double commission =
              _number(operator['commissionPercent']).clamp(0, 100).toDouble();
          final DocumentReference<Map<String, dynamic>> paymentRef =
              FirebaseFirestore.instance
                  .collection('bus_operator_monthly_fee_payments')
                  .doc(_paymentDocId());

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: paymentRef.snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> paySnap,
            ) {
              final Map<String, dynamic>? payment = paySnap.data?.data();
              final String status =
                  payment?['paymentStatus']?.toString() ?? 'unpaid';
              final bool canSubmit =
                  monthlyFee > 0 && (status == 'unpaid' || status == 'rejected');

              final int nowYear = DateTime.now().year;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            operator['companyName']?.toString() ??
                                'Bus Operator',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Monthly Fee: Rs. ${monthlyFee.toStringAsFixed(0)} / month',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Commission: ${commission.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
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

                      final Widget year = DropdownButtonFormField<int>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                        ),
                        items: <int>[nowYear - 1, nowYear, nowYear + 1]
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
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  _monthLabel(_selectedYear, _selectedMonth),
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Chip(
                                avatar: Icon(
                                  status == 'paid'
                                      ? Icons.check_circle_rounded
                                      : status == 'submitted'
                                          ? Icons.hourglass_top_rounded
                                          : status == 'rejected'
                                              ? Icons.cancel_rounded
                                              : Icons.schedule_rounded,
                                  size: 17,
                                  color: _statusColor(status),
                                ),
                                label: Text(
                                  _statusLabel(status),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Amount Due: Rs. ${monthlyFee.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (payment != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              'Method: ${payment['paymentMethod'] ?? ''}',
                            ),
                            if ((payment['paymentReference']?.toString() ?? '')
                                .isNotEmpty)
                              SelectableText(
                                'Transaction / Voucher: ${payment['paymentReference']}',
                              ),
                            if (status == 'paid' &&
                                (payment['receiptNumber']?.toString() ?? '')
                                    .isNotEmpty)
                              SelectableText(
                                'RD Receipt: ${payment['receiptNumber']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if (status == 'rejected') ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                'Admin Reason: ${payment['rejectionReason'] ?? 'Payment proof was rejected.'}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 12),
                          if (monthlyFee <= 0)
                            const Text(
                              'No Monthly Fee is currently due.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            )
                          else if (status == 'submitted')
                            const Text(
                              'RD Admin must verify that the money arrived before this becomes PAID.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            )
                          else if (status == 'paid')
                            const Text(
                              'Monthly Fee payment verified by RD Admin.',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _submitting || !canSubmit
                                    ? null
                                    : () => _submitPaymentProof(
                                          operator,
                                          payment,
                                        ),
                                icon: _submitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.upload_rounded),
                                label: Text(
                                  status == 'rejected'
                                      ? 'Resubmit Payment Proof'
                                      : 'Submit Payment Proof',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Online/bank payment: transfer first, then submit the real Transaction ID / Voucher. Cash: pay RD directly; Admin records cash after receiving it. Operator cannot mark a Monthly Fee as PAID.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}


class _BusOperatorScheduleFormPage
    extends StatefulWidget {
  const _BusOperatorScheduleFormPage({
    this.scheduleRef,
    this.initial,
    this.isReturnTrip = false,
  });

  final DocumentReference<Map<String, dynamic>>?
      scheduleRef;
  final Map<String, dynamic>? initial;
  final bool isReturnTrip;

  @override
  State<_BusOperatorScheduleFormPage> createState() =>
      _BusOperatorScheduleFormPageState();
}

class _BusOperatorScheduleFormPageState
    extends State<_BusOperatorScheduleFormPage> {
  final TextEditingController _busNameController =
      TextEditingController();
  final TextEditingController _busNumberController =
      TextEditingController();
  final TextEditingController _busStaffNameController =
      TextEditingController();
  final TextEditingController _busStaffPhoneController =
      TextEditingController();
  final TextEditingController _fromController =
      TextEditingController();
  final TextEditingController _toController =
      TextEditingController();
  final TextEditingController _fareController =
      TextEditingController();
  final TextEditingController _boardingController =
      TextEditingController();
  final TextEditingController _dropController =
      TextEditingController();

  DateTime _travelDate =
      DateTime.now().add(const Duration(days: 1));
  TimeOfDay _departureTime =
      const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _arrivalTime =
      const TimeOfDay(hour: 13, minute: 0);

  String _busType = 'AC Deluxe';
  String _seatLayout = '2+2';
  int _seatRows = 8;
  bool _active = true;
  bool _saving = false;
  bool _createReturnAlso = true;

  bool get _editing => widget.scheduleRef != null;

  bool get _canCreateAutomaticReturn =>
      !_editing && !widget.isReturnTrip;

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? data =
        widget.initial;
    if (data == null) {
      return;
    }

    _busNameController.text =
        data['busName']?.toString() ?? '';
    _busNumberController.text =
        data['busNumber']?.toString() ?? '';
    _busStaffNameController.text =
        data['busStaffName']?.toString() ?? '';
    _busStaffPhoneController.text =
        data['busStaffPhone']?.toString() ?? '';
    _fromController.text =
        data['from']?.toString() ?? '';
    _toController.text =
        data['to']?.toString() ?? '';
    final dynamic pendingFare = data['pendingFarePerSeat'];
    _fareController.text =
        pendingFare is num
            ? pendingFare.toString()
            : (data['farePerSeat']?.toString() ?? '');
    _busType =
        data['busType']?.toString() ??
            'AC Deluxe';
    _seatLayout =
        data['seatLayout']?.toString() ??
            '2+2';
    _seatRows =
        data['seatRows'] is int
            ? data['seatRows'] as int
            : 8;
    _active = data['fareEverApproved'] == false
        ? data['requestedActive'] != false
        : data['isActive'] == true;
    _boardingController.text =
        _readList(
          data['boardingPoints'],
        ).join('\n');
    _dropController.text =
        _readList(
          data['dropPoints'],
        ).join('\n');

    final DateTime? departure =
        _readDate(data['departureAt']);
    final DateTime? arrival =
        _readDate(data['arrivalAt']);

    if (departure != null) {
      _travelDate = DateTime(
        departure.year,
        departure.month,
        departure.day,
      );
      _departureTime =
          TimeOfDay.fromDateTime(departure);
    }

    if (arrival != null) {
      _arrivalTime =
          TimeOfDay.fromDateTime(arrival);
    }
  }

  @override
  void dispose() {
    _busNameController.dispose();
    _busNumberController.dispose();
    _busStaffNameController.dispose();
    _busStaffPhoneController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _fareController.dispose();
    _boardingController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    return null;
  }

  static List<String> _readList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((dynamic item) => item.toString())
        .where(
          (String item) => item.trim().isNotEmpty,
        )
        .toList();
  }

  List<String> _splitLines(String value) {
    return value
        .split(RegExp(r'[\n,]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String _dateKey(DateTime date) =>
      '${date.year}${_two(date.month)}${_two(date.day)}';

  DateTime _combine(
    DateTime date,
    TimeOfDay time,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  List<String> _seatCodes() {
    final List<String> columns =
        switch (_seatLayout) {
      '2+1' => <String>['A', 'B', 'C'],
      '1+1' => <String>['A', 'B'],
      _ => <String>['A', 'B', 'C', 'D'],
    };

    final List<String> seats = <String>[];

    for (int row = 1; row <= _seatRows; row++) {
      for (final String column in columns) {
        seats.add('$row$column');
      }
    }

    return seats;
  }

  void _swapDirection() {
    final String from =
        _fromController.text;
    final String to =
        _toController.text;
    final String boarding =
        _boardingController.text;
    final String drop =
        _dropController.text;

    setState(() {
      _fromController.text = to;
      _toController.text = from;
      _boardingController.text = drop;
      _dropController.text = boarding;
    });
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: DateTime(now.year + 2, 12, 31),
    );

    if (mounted && selected != null) {
      setState(() {
        _travelDate = selected;
      });
    }
  }

  Future<void> _pickDepartureTime() async {
    final TimeOfDay? selected =
        await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );

    if (mounted && selected != null) {
      setState(() {
        _departureTime = selected;
      });
    }
  }

  Future<void> _pickArrivalTime() async {
    final TimeOfDay? selected =
        await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
    );

    if (mounted && selected != null) {
      setState(() {
        _arrivalTime = selected;
      });
    }
  }

  Future<void> _save() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      _message('Bus Operator login required.');
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>>
        operatorDocument =
        await FirebaseFirestore.instance
            .collection('bus_operators')
            .doc(user.uid)
            .get();

    final Map<String, dynamic> operator =
        operatorDocument.data() ??
            <String, dynamic>{};

    if (!operatorDocument.exists ||
        operator['role']?.toString() !=
            'busOperator' ||
        operator['isApproved'] != true ||
        operator['isActive'] != true) {
      _message(
        'Active approved Bus Operator account required.',
      );
      return;
    }

    final double commissionPercent =
        _number(operator['commissionPercent']).clamp(0, 100).toDouble();

    final String busName =
        _busNameController.text.trim();
    final String busNumber =
        _busNumberController.text.trim();
    final String busStaffName =
        _busStaffNameController.text.trim();
    final String busStaffPhone =
        _busStaffPhoneController.text.trim();
    final String from =
        _fromController.text.trim();
    final String to =
        _toController.text.trim();
    final double? fare = double.tryParse(
      _fareController.text.trim(),
    );
    final List<String> boarding =
        _splitLines(_boardingController.text);
    final List<String> drop =
        _splitLines(_dropController.text);

    if (busName.isEmpty ||
        busNumber.isEmpty ||
        busStaffName.isEmpty ||
        busStaffPhone.length < 7 ||
        busStaffPhone.length > 30 ||
        from.isEmpty ||
        to.isEmpty ||
        fare == null ||
        fare < 0 ||
        boarding.isEmpty ||
        drop.isEmpty) {
      _message(
        'Please fill all schedule fields correctly.',
      );
      return;
    }

    if (from.toLowerCase() ==
        to.toLowerCase()) {
      _message('From and To cannot be the same.');
      return;
    }

    DateTime departureAt =
        _combine(
      _travelDate,
      _departureTime,
    );

    DateTime arrivalAt =
        _combine(
      _travelDate,
      _arrivalTime,
    );

    if (!arrivalAt.isAfter(departureAt)) {
      arrivalAt =
          arrivalAt.add(const Duration(days: 1));
    }

    final String routeDateKey =
        '${from.toLowerCase()}__${to.toLowerCase()}__${_dateKey(_travelDate)}';

    final bool isNewSchedule = widget.scheduleRef == null;
    final Map<String, dynamic> initial =
        widget.initial ?? <String, dynamic>{};
    final double currentApprovedFare =
        _number(initial['farePerSeat']);
    final bool initialFareEverApproved = isNewSchedule
        ? false
        : (initial['fareEverApproved'] is bool
            ? initial['fareEverApproved'] == true
            : true);
    final bool fareNeedsApproval = isNewSchedule ||
        !initialFareEverApproved ||
        (fare - currentApprovedFare).abs() > 0.005;
    final bool fareEverApproved = initialFareEverApproved;
    final double storedFare = isNewSchedule
        ? fare
        : currentApprovedFare;
    final bool storedActive =
        (isNewSchedule || !initialFareEverApproved)
            ? false
            : _active;

    setState(() {
      _saving = true;
    });

    try {
      final CollectionReference<Map<String, dynamic>>
          schedules =
          FirebaseFirestore.instance.collection(
        'bus_schedules',
      );

      final DocumentReference<Map<String, dynamic>>
          ref = widget.scheduleRef ??
              schedules.doc();

      final Map<String, dynamic> forwardData =
          <String, dynamic>{
        'scheduleId': ref.id,
        'scheduleVersion': 1,
        'operatorId': user.uid,
        'operatorName':
            operator['companyName']?.toString() ?? '',
        'operatorPhone':
            operator['phone']?.toString() ?? '',
        'routeDateKey': routeDateKey,
        'from': from,
        'to': to,
        'travelDate': Timestamp.fromDate(
          DateTime(
            _travelDate.year,
            _travelDate.month,
            _travelDate.day,
          ),
        ),
        'busName': busName,
        'busNumber': busNumber,
        'busStaffName': busStaffName,
        'busStaffPhone': busStaffPhone,
        'busType': _busType,
        'seatLayout': _seatLayout,
        'seatRows': _seatRows,
        'seatCodes': _seatCodes(),
        'departureAt':
            Timestamp.fromDate(departureAt),
        'arrivalAt':
            Timestamp.fromDate(arrivalAt),
        'boardingPoints': boarding,
        'dropPoints': drop,
        'farePerSeat': storedFare,
        'serviceFee': 0.0,
        'commissionPercent': commissionPercent,
        'currency': 'Rs.',
        'isActive': storedActive,
        'requestedActive': _active,
        'fareApprovalStatus':
            fareNeedsApproval ? 'pending' : 'approved',
        'fareEverApproved': fareNeedsApproval
            ? fareEverApproved
            : true,
        if (fareNeedsApproval)
          'pendingFarePerSeat': fare
        else
          'pendingFarePerSeat': FieldValue.delete(),
        if (fareNeedsApproval)
          'fareChangeRequestedAt': FieldValue.serverTimestamp()
        else
          'fareChangeRequestedAt': FieldValue.delete(),
        'createdAt':
            widget.initial?['createdAt'] ??
                FieldValue.serverTimestamp(),
        'fareChangeRequestedBy': user.uid,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      if (_canCreateAutomaticReturn &&
          _createReturnAlso) {
        final Duration tripDuration =
            arrivalAt.difference(departureAt);

        final DateTime returnDeparture =
            arrivalAt.add(
          const Duration(hours: 1),
        );

        final DateTime returnArrival =
            returnDeparture.add(tripDuration);

        final DateTime returnDate = DateTime(
          returnDeparture.year,
          returnDeparture.month,
          returnDeparture.day,
        );

        final DocumentReference<Map<String, dynamic>>
            returnRef = schedules.doc();

        final String returnRouteDateKey =
            '${to.toLowerCase()}__${from.toLowerCase()}__${_dateKey(returnDate)}';

        final WriteBatch batch =
            FirebaseFirestore.instance.batch();

        batch.set(
          ref,
          forwardData,
          SetOptions(merge: true),
        );

        batch.set(
          returnRef,
          <String, dynamic>{
            ...forwardData,
            'scheduleId': returnRef.id,
            'routeDateKey': returnRouteDateKey,
            'from': to,
            'to': from,
            'travelDate':
                Timestamp.fromDate(returnDate),
            'departureAt':
                Timestamp.fromDate(returnDeparture),
            'arrivalAt':
                Timestamp.fromDate(returnArrival),
            'boardingPoints': drop,
            'dropPoints': boarding,
            'createdAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
            'returnOfScheduleId': ref.id,
          },
        );

        await batch.commit();
      } else {
        await ref.set(
          forwardData,
          SetOptions(merge: true),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } on FirebaseException catch (error) {
      _message(
        'Could not save schedule: '
        '${error.message ?? error.code}',
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit Bus Schedule'
              : (widget.isReturnTrip
                  ? 'Create Return Trip'
                  : 'Add Bus Schedule'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _field(
                _busNameController,
                'Bus Name / Model',
                Icons.directions_bus_rounded,
              ),
              _field(
                _busNumberController,
                'Bus Number',
                Icons.badge_outlined,
              ),
              _field(
                _busStaffNameController,
                'Bus Staff / Contact Person Name',
                Icons.support_agent_rounded,
              ),
              _field(
                _busStaffPhoneController,
                'Bus Staff Mobile Number',
                Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              if (widget.isReturnTrip) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue
                        .withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.swap_horiz_rounded,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Return Trip: direction has been reversed automatically. Please check the return date, departure time and arrival time before publishing.',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _field(
                _fromController,
                'From',
                Icons.trip_origin_rounded,
              ),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _swapDirection,
                  icon: const Icon(
                    Icons.swap_vert_rounded,
                  ),
                  label: const Text(
                    'Swap Direction',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _field(
                _toController,
                'To',
                Icons.location_on_outlined,
              ),
              DropdownButtonFormField<String>(
                initialValue: _busType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Bus Type',
                  prefixIcon:
                      Icon(Icons.category_rounded),
                  border: OutlineInputBorder(),
                ),
                items:
                    const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'AC Deluxe',
                    child: Text('AC Deluxe'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Sofa',
                    child: Text('Sofa'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'EV',
                    child: Text('EV'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Night Bus',
                    child: Text('Night Bus'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Local',
                    child: Text('Local'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _busType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Travel Date',
                    prefixIcon: Icon(
                      Icons.calendar_month_rounded,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_two(_travelDate.day)}/${_two(_travelDate.month)}/${_travelDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final Widget departure = InkWell(
                    onTap: _pickDepartureTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Departure',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _departureTime.format(context),
                      ),
                    ),
                  );

                  final Widget arrival = InkWell(
                    onTap: _pickArrivalTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Arrival',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _arrivalTime.format(context),
                      ),
                    ),
                  );

                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: <Widget>[
                        departure,
                        const SizedBox(height: 12),
                        arrival,
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      Expanded(child: departure),
                      const SizedBox(width: 12),
                      Expanded(child: arrival),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final Widget layout =
                      DropdownButtonFormField<String>(
                    initialValue: _seatLayout,
                    decoration: const InputDecoration(
                      labelText: 'Seat Layout',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: '2+2',
                        child: Text('2 + 2'),
                      ),
                      DropdownMenuItem<String>(
                        value: '2+1',
                        child: Text('2 + 1'),
                      ),
                      DropdownMenuItem<String>(
                        value: '1+1',
                        child: Text('1 + 1'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _seatLayout = value;
                        });
                      }
                    },
                  );

                  final Widget rows =
                      DropdownButtonFormField<int>(
                    initialValue: _seatRows,
                    decoration: const InputDecoration(
                      labelText: 'Seat Rows',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        List<DropdownMenuItem<int>>.generate(
                      10,
                      (int index) {
                        final int value = index + 5;
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                        );
                      },
                    ),
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() {
                          _seatRows = value;
                        });
                      }
                    },
                  );

                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: <Widget>[
                        layout,
                        const SizedBox(height: 12),
                        rows,
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      Expanded(child: layout),
                      const SizedBox(width: 12),
                      Expanded(child: rows),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _field(
                _fareController,
                'Fare Per Seat',
                Icons.payments_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: _boardingController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText:
                      'Boarding Points (one per line)',
                  prefixIcon:
                      Icon(Icons.directions_walk_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dropController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText:
                      'Drop Points (one per line)',
                  prefixIcon:
                      Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _active,
                title: Text(
                  _editing
                      ? 'Published / Active'
                      : 'Publish after Admin Fare Approval',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onChanged: (bool value) {
                  setState(() {
                    _active = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_canCreateAutomaticReturn) ...<Widget>[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _createReturnAlso,
                  onChanged: (bool value) {
                    setState(() {
                      _createReturnAlso = value;
                    });
                  },
                  title: const Text(
                    'Create Return Trip Also',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: const Text(
                    'Kathmandu → Pokhara बनाउँदा Pokhara → Kathmandu पनि सँगै बनाउँछ। Return departure पहिलो बस पुगेको 1 घण्टापछि auto राखिन्छ; पछि Edit गरेर exact time मिलाउन सकिन्छ.',
                  ),
                  secondary: const Icon(
                    Icons.swap_horiz_rounded,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _editing
                        ? 'Save / Submit Fare Change'
                        : (widget.isReturnTrip
                            ? 'Submit Return Trip for Approval'
                            : 'Submit Schedule for Approval'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
