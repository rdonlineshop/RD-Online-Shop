import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminHotelFeePage extends StatefulWidget {
  const AdminHotelFeePage({super.key});

  @override
  State<AdminHotelFeePage> createState() =>
      _AdminHotelFeePageState();
}

class _AdminHotelFeePageState
    extends State<AdminHotelFeePage> {
  static const Color _rdGreen = Color(0xFF2E7D32);
  static const Color _rdBlue = Color(0xFF1565C0);
  static const Color _rdRed = Color(0xFFD32F2F);
  static const Color _rdOrange = Color(0xFFF57C00);

  final TextEditingController _monthlyFee =
      TextEditingController(text: '1000');

  final TextEditingController _commission =
      TextEditingController(text: '5');

  final TextEditingController _dueDay =
      TextEditingController(text: '7');

  final TextEditingController _graceDays =
      TextEditingController(text: '3');

  final TextEditingController _bankName =
      TextEditingController();

  final TextEditingController _accountName =
      TextEditingController();

  final TextEditingController _accountNumber =
      TextEditingController();

  final TextEditingController _instructions =
      TextEditingController();

  bool _feeEnabled = true;
  bool _settingsLoading = true;
  bool _settingsSaving = false;

  String _invoiceFilter = 'all';
  String _paymentFilter = 'submitted';

  DateTime? _earningsFrom;
  DateTime? _earningsTo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _monthlyFee.dispose();
    _commission.dispose();
    _dueDay.dispose();
    _graceDays.dispose();
    _bankName.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _instructions.dispose();
    super.dispose();
  }

  User? get _admin =>
      FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>
      get _settingsRef =>
          FirebaseFirestore.instance
              .collection('hotel_fee_settings')
              .doc('global');

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ?? 0;

    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  String _date(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }

    final DateTime date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  DateTime _monthStart(String monthKey) {
    final List<String> parts = monthKey.split('-');

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      1,
    );
  }

  DateTime _nextMonth(DateTime start) {
    if (start.month == 12) {
      return DateTime(start.year + 1, 1, 1);
    }

    return DateTime(start.year, start.month + 1, 1);
  }

  DateTime _dueDate(
    DateTime billingMonthStart,
    int dueDay,
  ) {
    final DateTime next =
        _nextMonth(billingMonthStart);

    final int safeDay =
        dueDay < 1
            ? 1
            : dueDay > 28
                ? 28
                : dueDay;

    return DateTime(
      next.year,
      next.month,
      safeDay,
      23,
      59,
      59,
    );
  }

  double _outstanding(
    Map<String, dynamic> invoice,
  ) {
    final double total =
        (invoice['totalDue'] as num?)
                ?.toDouble() ??
            0;

    final double paid =
        (invoice['paidAmount'] as num?)
                ?.toDouble() ??
            0;

    final double value = total - paid;

    return value < 0 ? 0 : value;
  }

  String _effectiveInvoiceStatus(
    Map<String, dynamic> invoice,
  ) {
    final String stored =
        invoice['status']
                ?.toString()
                .toLowerCase() ??
            'unpaid';

    if (<String>[
      'paid',
      'waived',
    ].contains(stored)) {
      return stored;
    }

    final Timestamp? dueStamp =
        invoice['dueDate'] as Timestamp?;

    final int graceDays =
        (invoice['graceDays'] as num?)
                ?.toInt() ??
            0;

    if (dueStamp != null &&
        _outstanding(invoice) > 0) {
      final DateTime graceEnd =
          dueStamp.toDate().add(
                Duration(
                  days: graceDays,
                ),
              );

      if (DateTime.now().isAfter(graceEnd)) {
        return 'overdue';
      }
    }

    return stored;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
      case 'verified':
        return _rdGreen;
      case 'waived':
        return _rdBlue;
      case 'overdue':
      case 'rejected':
        return _rdRed;
      case 'submitted':
        return Colors.purple;
      default:
        return _rdOrange;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final DocumentSnapshot<
              Map<String, dynamic>>
          doc = await _settingsRef.get();

      final Map<String, dynamic> data =
          doc.data() ??
              <String, dynamic>{};

      if (!mounted) {
        return;
      }

      setState(() {
        _feeEnabled =
            data['enabled'] != false;

        _monthlyFee.text =
            ((data['monthlyFee'] as num?)
                        ?.toDouble() ??
                    1000)
                .toStringAsFixed(0);

        _commission.text =
            ((data['commissionPercent'] as num?)
                        ?.toDouble() ??
                    5)
                .toString();

        _dueDay.text =
            ((data['dueDay'] as num?)
                        ?.toInt() ??
                    7)
                .toString();

        _graceDays.text =
            ((data['graceDays'] as num?)
                        ?.toInt() ??
                    3)
                .toString();

        _bankName.text =
            data['bankName']?.toString() ??
                '';

        _accountName.text =
            data['accountName']?.toString() ??
                '';

        _accountNumber.text =
            data['accountNumber']
                    ?.toString() ??
                '';

        _instructions.text =
            data['paymentInstructions']
                    ?.toString() ??
                '';

        _settingsLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _settingsLoading = false;
      });

      _message(
        'Could not load Hotel fee settings.\n'
        '$error',
      );
    }
  }

  Future<Map<String, dynamic>>
      _settingsData() async {
    final DocumentSnapshot<
            Map<String, dynamic>>
        doc = await _settingsRef.get();

    return doc.data() ??
        <String, dynamic>{
          'enabled': true,
          'monthlyFee': 1000.0,
          'commissionPercent': 5.0,
          'dueDay': 7,
          'graceDays': 3,
          'currency': 'Rs.',
        };
  }

  Future<void> _saveSettings() async {
    if (_settingsSaving) {
      return;
    }

    final double? monthlyFee =
        double.tryParse(
      _monthlyFee.text.trim(),
    );

    final double? commission =
        double.tryParse(
      _commission.text.trim(),
    );

    final int? dueDay =
        int.tryParse(
      _dueDay.text.trim(),
    );

    final int? graceDays =
        int.tryParse(
      _graceDays.text.trim(),
    );

    if (monthlyFee == null ||
        monthlyFee < 0) {
      _message(
        'Enter a valid monthly fee.',
      );
      return;
    }

    if (commission == null ||
        commission < 0 ||
        commission > 100) {
      _message(
        'Commission must be between 0 and 100%.',
      );
      return;
    }

    if (dueDay == null ||
        dueDay < 1 ||
        dueDay > 28) {
      _message(
        'Due day must be from 1 to 28.',
      );
      return;
    }

    if (graceDays == null ||
        graceDays < 0 ||
        graceDays > 60) {
      _message(
        'Grace days must be from 0 to 60.',
      );
      return;
    }

    setState(() {
      _settingsSaving = true;
    });

    try {
      await _settingsRef.set(
        <String, dynamic>{
          'enabled': _feeEnabled,
          'monthlyFee': monthlyFee,
          'commissionPercent':
              commission,
          'dueDay': dueDay,
          'graceDays': graceDays,
          'currency': 'Rs.',
          'bankName':
              _bankName.text.trim(),
          'accountName':
              _accountName.text.trim(),
          'accountNumber':
              _accountNumber.text.trim(),
          'paymentInstructions':
              _instructions.text.trim(),
          'updatedBy':
              _admin?.uid ?? '',
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _audit(
        action: 'fee_settings_updated',
        targetId: 'global',
        details:
            'Monthly fee $monthlyFee, commission $commission%',
      );

      if (mounted) {
        _message(
          'Hotel fee settings saved.',
        );
      }
    } catch (error) {
      _message(
        'Could not save Hotel fee settings.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _settingsSaving = false;
        });
      }
    }
  }

  Future<void> _audit({
    required String action,
    required String targetId,
    required String details,
  }) async {
    try {
      final DocumentReference<
              Map<String, dynamic>>
          ref = FirebaseFirestore.instance
              .collection(
                'hotel_fee_audit_logs',
              )
              .doc();

      await ref.set(
        <String, dynamic>{
          'logId': ref.id,
          'action': action,
          'targetId': targetId,
          'details': details,
          'adminUid':
              _admin?.uid ?? '',
          'adminEmail':
              _admin?.email ?? '',
          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // Fee operation should not fail only because an audit write failed.
    }
  }

  List<String> _billingMonths() {
    final DateTime now =
        DateTime.now();

    return List<String>.generate(
      18,
      (int index) {
        final int totalMonths =
            now.year * 12 +
                (now.month - 1) -
                index;

        final int year =
            totalMonths ~/ 12;

        final int month =
            totalMonths % 12 + 1;

        return _monthKey(
          DateTime(year, month, 1),
        );
      },
    );
  }

  Future<void> _showGenerateInvoiceDialog() async {
    try {
      final QuerySnapshot<
              Map<String, dynamic>>
          hotelSnapshot =
          await FirebaseFirestore.instance
              .collection('hotels')
              .where(
                'isApproved',
                isEqualTo: true,
              )
              .where(
                'isActive',
                isEqualTo: true,
              )
              .get();

      if (!mounted) {
        return;
      }

      if (hotelSnapshot.docs.isEmpty) {
        _message(
          'No approved active Hotel found.',
        );
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (BuildContext dialogContext) {
          return _GenerateHotelFeeInvoiceDialog(
            hotels: hotelSnapshot.docs,
            months: _billingMonths(),
            onGenerate:
                _generateInvoice,
          );
        },
      );
    } catch (error) {
      _message(
        'Could not load Hotels for invoice generation.\n'
        '$error',
      );
    }
  }

  Future<String?> _generateInvoice({
    required QueryDocumentSnapshot<
            Map<String, dynamic>>
        hotelDoc,
    required String billingMonth,
    required double adjustmentAmount,
    required double discountAmount,
    required String note,
  }) async {
    try {
      final Map<String, dynamic>
          settings =
          await _settingsData();

      final bool enabled =
          settings['enabled'] != false;

      final double monthlyFee = enabled
          ? (settings['monthlyFee']
                      as num?)
                  ?.toDouble() ??
              0
          : 0;

      final double commissionPercent =
          enabled
              ? (settings[
                              'commissionPercent']
                          as num?)
                      ?.toDouble() ??
                  0
              : 0;

      final int dueDay =
          (settings['dueDay'] as num?)
                  ?.toInt() ??
              7;

      final int graceDays =
          (settings['graceDays'] as num?)
                  ?.toInt() ??
              3;

      final Map<String, dynamic> hotel =
          hotelDoc.data();

      final String partnerId =
          hotel['partnerId']
                  ?.toString()
                  .trim() ??
              '';

      if (partnerId.isEmpty) {
        return 'Hotel Partner ID is missing.';
      }

      final DateTime periodStart =
          _monthStart(billingMonth);

      final DateTime periodEnd =
          _nextMonth(periodStart);

      final QuerySnapshot<
              Map<String, dynamic>>
          bookings =
          await FirebaseFirestore.instance
              .collection(
                'hotel_bookings',
              )
              .where(
                'partnerId',
                isEqualTo: partnerId,
              )
              .get();

      int bookingCount = 0;
      double commissionBase = 0;

      for (final QueryDocumentSnapshot<
              Map<String, dynamic>>
          bookingDoc in bookings.docs) {
        final Map<String, dynamic>
            booking =
            bookingDoc.data();

        final Timestamp? created =
            booking['createdAt']
                as Timestamp?;

        if (created == null) {
          continue;
        }

        final DateTime createdAt =
            created.toDate();

        final bool inPeriod =
            !createdAt.isBefore(
                  periodStart,
                ) &&
                createdAt.isBefore(
                  periodEnd,
                );

        if (!inPeriod) {
          continue;
        }

        final String status =
            booking['bookingStatus']
                    ?.toString() ??
                '';

        final String paymentStatus =
            booking['paymentStatus']
                    ?.toString() ??
                '';

        final bool eligibleStatus =
            <String>[
          'confirmed',
          'checked_in',
          'completed',
        ].contains(status);

        if (!eligibleStatus ||
            paymentStatus != 'paid') {
          continue;
        }

        bookingCount++;

        commissionBase +=
            (booking['totalAmount'] as num?)
                    ?.toDouble() ??
                0;
      }

      final double commissionAmount =
          commissionBase *
              commissionPercent /
              100;

      final double rawTotal =
          monthlyFee +
              commissionAmount +
              adjustmentAmount -
              discountAmount;

      final double totalDue =
          rawTotal < 0 ? 0 : rawTotal;

      final String invoiceId =
          '${partnerId}_$billingMonth';

      final DocumentReference<
              Map<String, dynamic>>
          invoiceRef =
          FirebaseFirestore.instance
              .collection(
                'hotel_fee_invoices',
              )
              .doc(invoiceId);

      final DocumentSnapshot<
              Map<String, dynamic>>
          existing =
          await invoiceRef.get();

      final Map<String, dynamic>
          existingData =
          existing.data() ??
              <String, dynamic>{};

      final String existingStatus =
          existingData['status']
                  ?.toString() ??
              '';

      final double existingPaid =
          (existingData['paidAmount']
                      as num?)
                  ?.toDouble() ??
              0;

      if (existing.exists &&
          (existingStatus == 'paid' ||
              existingStatus == 'waived' ||
              existingPaid > 0)) {
        return 'This invoice already has a payment or is closed. '
            'It was not recalculated.';
      }

      await invoiceRef.set(
        <String, dynamic>{
          'invoiceId': invoiceId,
          'partnerId': partnerId,
          'hotelId': hotelDoc.id,
          'hotelName':
              hotel['name']?.toString() ??
                  'Hotel',
          'billingMonth':
              billingMonth,
          'periodStart':
              Timestamp.fromDate(
            periodStart,
          ),
          'periodEnd':
              Timestamp.fromDate(
            periodEnd,
          ),
          'monthlyFee': monthlyFee,
          'commissionPercent':
              commissionPercent,
          'commissionBase':
              commissionBase,
          'commissionAmount':
              commissionAmount,
          'bookingCount':
              bookingCount,
          'adjustmentAmount':
              adjustmentAmount,
          'discountAmount':
              discountAmount,
          'totalDue': totalDue,
          'paidAmount': 0.0,
          'status':
              totalDue <= 0
                  ? 'waived'
                  : 'unpaid',
          'dueDate':
              Timestamp.fromDate(
            _dueDate(
              periodStart,
              dueDay,
            ),
          ),
          'graceDays': graceDays,
          'currency':
              settings['currency']
                      ?.toString() ??
                  'Rs.',
          'note': note,
          'generatedBy':
              _admin?.uid ?? '',
          'generatedAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _audit(
        action: existing.exists
            ? 'invoice_recalculated'
            : 'invoice_generated',
        targetId: invoiceId,
        details:
            '${hotel['name'] ?? 'Hotel'} $billingMonth total $totalDue',
      );

      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<void> _verifyPayment(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        paymentDoc,
  ) async {
    try {
      await FirebaseFirestore.instance
          .runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              freshPayment =
              await transaction.get(
            paymentDoc.reference,
          );

          final Map<String, dynamic>
              payment =
              freshPayment.data() ??
                  <String, dynamic>{};

          if (!freshPayment.exists ||
              payment['status'] !=
                  'submitted') {
            throw StateError(
              'Payment is no longer waiting for verification.',
            );
          }

          final String invoiceId =
              payment['invoiceId']
                      ?.toString() ??
                  '';

          final DocumentReference<
                  Map<String, dynamic>>
              invoiceRef =
              FirebaseFirestore.instance
                  .collection(
                    'hotel_fee_invoices',
                  )
                  .doc(invoiceId);

          final DocumentSnapshot<
                  Map<String, dynamic>>
              invoiceDoc =
              await transaction.get(
            invoiceRef,
          );

          if (!invoiceDoc.exists) {
            throw StateError(
              'Invoice was not found.',
            );
          }

          final Map<String, dynamic>
              invoice =
              invoiceDoc.data() ??
                  <String, dynamic>{};

          final double amount =
              (payment['amount'] as num?)
                      ?.toDouble() ??
                  0;

          final double totalDue =
              (invoice['totalDue'] as num?)
                      ?.toDouble() ??
                  0;

          final double oldPaid =
              (invoice['paidAmount'] as num?)
                      ?.toDouble() ??
                  0;

          final double nextPaid =
              oldPaid + amount;

          final bool fullyPaid =
              nextPaid + 0.01 >=
                  totalDue;

          transaction.update(
            paymentDoc.reference,
            <String, dynamic>{
              'status': 'verified',
              'verifiedBy':
                  _admin?.uid ?? '',
              'verifiedAt':
                  FieldValue
                      .serverTimestamp(),
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );

          transaction.update(
            invoiceRef,
            <String, dynamic>{
              'paidAmount':
                  nextPaid > totalDue
                      ? totalDue
                      : nextPaid,
              'status':
                  fullyPaid
                      ? 'paid'
                      : 'unpaid',
              'lastPaymentId':
                  paymentDoc.id,
              if (fullyPaid)
                'paidAt':
                    FieldValue
                        .serverTimestamp(),
              'updatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        },
      );

      await _audit(
        action: 'payment_verified',
        targetId: paymentDoc.id,
        details:
            'Hotel fee payment verified',
      );

      if (mounted) {
        _message(
          'Hotel fee payment verified.',
        );
      }
    } catch (error) {
      _message(
        'Could not verify payment.\n'
        '$error',
      );
    }
  }

  Future<void> _rejectPayment(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        paymentDoc,
  ) async {
    String reason = '';

    final String? result =
        await showDialog<String>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reject Hotel Fee Payment',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: TextField(
            maxLines: 3,
            onChanged: (String value) {
              reason = value.trim();
            },
            decoration:
                const InputDecoration(
              labelText:
                  'Rejection Reason',
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
      await paymentDoc.reference.update(
        <String, dynamic>{
          'status': 'rejected',
          'rejectionReason':
              result.trim(),
          'rejectedBy':
              _admin?.uid ?? '',
          'rejectedAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      await _audit(
        action: 'payment_rejected',
        targetId: paymentDoc.id,
        details: result.trim(),
      );

      if (mounted) {
        _message(
          'Hotel fee payment rejected.',
        );
      }
    } catch (error) {
      _message(
        'Could not reject payment.\n'
        '$error',
      );
    }
  }

  Future<void> _markCashPaid(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        invoiceDoc,
  ) async {
    final Map<String, dynamic> invoice =
        invoiceDoc.data();

    final double outstanding =
        _outstanding(invoice);

    if (outstanding <= 0) {
      _message(
        'This invoice has no outstanding balance.',
      );
      return;
    }

    final bool? confirm =
        await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Mark Cash / Office Payment',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: Text(
            'Mark ${_money(outstanding)} as '
            'received and verified for '
            '${invoice['hotelName'] ?? 'Hotel'}?',
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
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text('Mark Paid'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final DocumentReference<
              Map<String, dynamic>>
          paymentRef =
          FirebaseFirestore.instance
              .collection(
                'hotel_fee_payments',
              )
              .doc();

      final WriteBatch batch =
          FirebaseFirestore.instance.batch();

      batch.set(
        paymentRef,
        <String, dynamic>{
          'paymentId':
              paymentRef.id,
          'invoiceId':
              invoiceDoc.id,
          'partnerId':
              invoice['partnerId'],
          'hotelId':
              invoice['hotelId'],
          'hotelName':
              invoice['hotelName'],
          'billingMonth':
              invoice['billingMonth'],
          'amount':
              outstanding,
          'method': 'cash_admin',
          'transactionRef':
              'ADMIN-CASH',
          'proofUrl': '',
          'note':
              'Cash / office payment recorded by Admin.',
          'status': 'verified',
          'submittedAt':
              FieldValue
                  .serverTimestamp(),
          'verifiedBy':
              _admin?.uid ?? '',
          'verifiedAt':
              FieldValue
                  .serverTimestamp(),
          'createdAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      batch.update(
        invoiceDoc.reference,
        <String, dynamic>{
          'paidAmount':
              (invoice['totalDue']
                          as num?)
                      ?.toDouble() ??
                  outstanding,
          'status': 'paid',
          'lastPaymentId':
              paymentRef.id,
          'paidAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      await batch.commit();

      await _audit(
        action: 'cash_payment_recorded',
        targetId: invoiceDoc.id,
        details:
            'Cash payment ${_money(outstanding)}',
      );

      if (mounted) {
        _message(
          'Cash / office payment recorded.',
        );
      }
    } catch (error) {
      _message(
        'Could not record cash payment.\n'
        '$error',
      );
    }
  }

  Future<void> _waiveInvoice(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        invoiceDoc,
  ) async {
    String reason = '';

    final String? result =
        await showDialog<String>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Waive Hotel Fee Invoice',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: TextField(
            maxLines: 3,
            onChanged: (String value) {
              reason = value.trim();
            },
            decoration:
                const InputDecoration(
              labelText:
                  'Waive Reason',
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
                  const Text('Waive'),
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
      await invoiceDoc.reference.update(
        <String, dynamic>{
          'status': 'waived',
          'waiveReason':
              result.trim(),
          'waivedBy':
              _admin?.uid ?? '',
          'waivedAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      await _audit(
        action: 'invoice_waived',
        targetId: invoiceDoc.id,
        details: result.trim(),
      );

      if (mounted) {
        _message(
          'Hotel fee invoice waived.',
        );
      }
    } catch (error) {
      _message(
        'Could not waive invoice.\n'
        '$error',
      );
    }
  }

  Future<void> _reopenInvoice(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        invoiceDoc,
  ) async {
    try {
      await invoiceDoc.reference.update(
        <String, dynamic>{
          'status': 'unpaid',
          'waiveReason':
              FieldValue.delete(),
          'waivedBy':
              FieldValue.delete(),
          'waivedAt':
              FieldValue.delete(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      await _audit(
        action: 'invoice_reopened',
        targetId: invoiceDoc.id,
        details:
            'Waived invoice reopened',
      );

      if (mounted) {
        _message(
          'Invoice reopened.',
        );
      }
    } catch (error) {
      _message(
        'Could not reopen invoice.\n'
        '$error',
      );
    }
  }

  bool _invoiceMatches(
    Map<String, dynamic> data,
  ) {
    final String status =
        _effectiveInvoiceStatus(data);

    switch (_invoiceFilter) {
      case 'unpaid':
        return status == 'unpaid';
      case 'overdue':
        return status == 'overdue';
      case 'paid':
        return status == 'paid';
      case 'waived':
        return status == 'waived';
      case 'all':
        return true;
    }

    return true;
  }

  bool _paymentMatches(
    Map<String, dynamic> data,
  ) {
    final String status =
        data['status']
                ?.toString() ??
            '';

    if (_paymentFilter == 'all') {
      return true;
    }

    return status == _paymentFilter;
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      );

  DateTime _startOfWeek(DateTime value) {
    final DateTime day = _startOfDay(value);

    return day.subtract(
      Duration(
        days: day.weekday - DateTime.monday,
      ),
    );
  }

  DateTime? _verifiedPaymentDate(
    Map<String, dynamic> data,
  ) {
    final dynamic verifiedAt =
        data['verifiedAt'];

    if (verifiedAt is Timestamp) {
      return verifiedAt.toDate();
    }

    // Backward-compatible fallback for an older verified payment
    // that may not have verifiedAt saved.
    final dynamic updatedAt =
        data['updatedAt'];

    if (updatedAt is Timestamp) {
      return updatedAt.toDate();
    }

    final dynamic submittedAt =
        data['submittedAt'];

    if (submittedAt is Timestamp) {
      return submittedAt.toDate();
    }

    return null;
  }

  List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      _verifiedPayments(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        payments,
  ) {
    final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        verified =
        payments
            .where(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    doc,
              ) =>
                  doc.data()['status'] ==
                  'verified',
            )
            .toList();

    verified.sort(
      (
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            first,
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            second,
      ) {
        final DateTime? firstDate =
            _verifiedPaymentDate(
          first.data(),
        );

        final DateTime? secondDate =
            _verifiedPaymentDate(
          second.data(),
        );

        return (secondDate
                    ?.millisecondsSinceEpoch ??
                0)
            .compareTo(
          firstDate
                  ?.millisecondsSinceEpoch ??
              0,
        );
      },
    );

    return verified;
  }

  List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      _paymentsBetween(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        payments,
    DateTime start,
    DateTime endExclusive,
  ) {
    return _verifiedPayments(payments)
        .where(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                doc,
          ) {
            final DateTime? paidDate =
                _verifiedPaymentDate(
              doc.data(),
            );

            if (paidDate == null) {
              return false;
            }

            return !paidDate.isBefore(start) &&
                paidDate.isBefore(
                  endExclusive,
                );
          },
        )
        .toList();
  }

  double _paymentTotal(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        payments,
  ) {
    double total = 0;

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc in payments) {
      total +=
          (doc.data()['amount'] as num?)
                  ?.toDouble() ??
              0;
    }

    return total;
  }

  Future<void> _pickEarningsFrom() async {
    final DateTime today =
        _startOfDay(DateTime.now());

    final DateTime initial =
        _earningsFrom ?? today;

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today)
          ? today
          : initial,
      firstDate:
          DateTime(today.year - 10, 1, 1),
      lastDate: today,
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _earningsFrom =
          _startOfDay(picked);

      if (_earningsTo != null &&
          _earningsTo!.isBefore(
            _earningsFrom!,
          )) {
        _earningsTo =
            _earningsFrom;
      }
    });
  }

  Future<void> _pickEarningsTo() async {
    final DateTime today =
        _startOfDay(DateTime.now());

    final DateTime first =
        _earningsFrom ??
            DateTime(
              today.year - 10,
              1,
              1,
            );

    final DateTime initial =
        _earningsTo ??
            (_earningsFrom ?? today);

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          initial.isAfter(today)
              ? today
              : initial.isBefore(first)
                  ? first
                  : initial,
      firstDate: first,
      lastDate: today,
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _earningsTo =
          _startOfDay(picked);
    });
  }

  Widget _earningsPaymentCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final DateTime? paidDate =
        _verifiedPaymentDate(data);

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons
                .payments_rounded,
          ),
        ),
        title: Text(
          data['hotelName']
                  ?.toString() ??
              'Hotel',
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        subtitle: Text(
          'Paid: ${paidDate == null ? '-' : '${paidDate.day.toString().padLeft(2, '0')}/${paidDate.month.toString().padLeft(2, '0')}/${paidDate.year}'}\n'
          'Method: ${data['method'] ?? '-'} • Billing: ${data['billingMonth'] ?? '-'}',
        ),
        trailing: Text(
          _money(
            data['amount'],
          ),
          style: const TextStyle(
            color: _rdGreen,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _overviewTab() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(
            'hotel_fee_invoices',
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<
                    Map<String, dynamic>>>
            invoiceSnapshot,
      ) {
        return StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(
                'hotel_fee_payments',
              )
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    QuerySnapshot<
                        Map<String, dynamic>>>
                paymentSnapshot,
          ) {
            if (invoiceSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !invoiceSnapshot.hasData ||
                paymentSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !paymentSnapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (invoiceSnapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load Hotel fee invoices.\n'
                  '${invoiceSnapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              );
            }

            if (paymentSnapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load Hotel fee payments.\n'
                  '${paymentSnapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              );
            }

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                invoices =
                invoiceSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                payments =
                paymentSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

            double billed = 0;
            double paid = 0;
            double outstanding = 0;
            int overdue = 0;

            for (final QueryDocumentSnapshot<
                    Map<String, dynamic>>
                doc in invoices) {
              final Map<String, dynamic> data =
                  doc.data();

              final String status =
                  _effectiveInvoiceStatus(data);

              billed +=
                  (data['totalDue'] as num?)
                          ?.toDouble() ??
                      0;

              paid +=
                  (data['paidAmount'] as num?)
                          ?.toDouble() ??
                      0;

              if (status == 'overdue') {
                overdue++;
              }

              if (status != 'waived') {
                outstanding +=
                    _outstanding(data);
              }
            }

            final int submittedPayments =
                payments
                    .where(
                      (
                        QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>
                            doc,
                      ) =>
                          doc.data()[
                              'status'] ==
                          'submitted',
                    )
                    .length;

            final DateTime now =
                DateTime.now();

            final DateTime todayStart =
                _startOfDay(now);

            final DateTime tomorrowStart =
                todayStart.add(
              const Duration(days: 1),
            );

            final DateTime weekStart =
                _startOfWeek(now);

            final DateTime monthStart =
                DateTime(
              now.year,
              now.month,
              1,
            );

            final DateTime yearStart =
                DateTime(
              now.year,
              1,
              1,
            );

            final double todayEarnings =
                _paymentTotal(
              _paymentsBetween(
                payments,
                todayStart,
                tomorrowStart,
              ),
            );

            final double weekEarnings =
                _paymentTotal(
              _paymentsBetween(
                payments,
                weekStart,
                tomorrowStart,
              ),
            );

            final double monthEarnings =
                _paymentTotal(
              _paymentsBetween(
                payments,
                monthStart,
                tomorrowStart,
              ),
            );

            final double yearEarnings =
                _paymentTotal(
              _paymentsBetween(
                payments,
                yearStart,
                tomorrowStart,
              ),
            );

            final bool hasCustomRange =
                _earningsFrom != null &&
                    _earningsTo != null;

            final DateTime? customStart =
                _earningsFrom == null
                    ? null
                    : _startOfDay(
                        _earningsFrom!,
                      );

            final DateTime? customEndExclusive =
                _earningsTo == null
                    ? null
                    : _startOfDay(
                        _earningsTo!,
                      ).add(
                        const Duration(
                          days: 1,
                        ),
                      );

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                verifiedPayments =
                _verifiedPayments(
              payments,
            );

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                shownPaidHotels =
                hasCustomRange
                    ? _paymentsBetween(
                        payments,
                        customStart!,
                        customEndExclusive!,
                      )
                    : verifiedPayments
                        .take(10)
                        .toList();

            final double customTotal =
                hasCustomRange
                    ? _paymentTotal(
                        shownPaidHotels,
                      )
                    : 0;

            return Center(
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
                    GridView.count(
                      crossAxisCount:
                          MediaQuery.sizeOf(
                                        context,
                                      )
                                      .width >=
                                  900
                              ? 4
                              : 2,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: <Widget>[
                        _statCard(
                          'Total Billed',
                          _money(billed),
                          Icons
                              .receipt_long_rounded,
                          _rdBlue,
                        ),
                        _statCard(
                          'Verified Paid',
                          _money(paid),
                          Icons
                              .verified_rounded,
                          _rdGreen,
                        ),
                        _statCard(
                          'Outstanding',
                          _money(outstanding),
                          Icons
                              .account_balance_wallet_rounded,
                          _rdRed,
                        ),
                        _statCard(
                          'Admin Attention',
                          '$submittedPayments payment(s)\n'
                              '$overdue overdue',
                          Icons
                              .notification_important_rounded,
                          _rdOrange,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    const Text(
                      'RD Hotel Fee Earnings',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Verified Hotel fee payments received by RD.',
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    GridView.count(
                      crossAxisCount:
                          MediaQuery.sizeOf(
                                        context,
                                      )
                                      .width >=
                                  900
                              ? 4
                              : 2,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: <Widget>[
                        _statCard(
                          'Today Earnings',
                          _money(
                            todayEarnings,
                          ),
                          Icons.today_rounded,
                          _rdGreen,
                        ),
                        _statCard(
                          'This Week',
                          _money(
                            weekEarnings,
                          ),
                          Icons
                              .date_range_rounded,
                          _rdBlue,
                        ),
                        _statCard(
                          'This Month',
                          _money(
                            monthEarnings,
                          ),
                          Icons
                              .calendar_month_rounded,
                          _rdOrange,
                        ),
                        _statCard(
                          'This Year',
                          _money(
                            yearEarnings,
                          ),
                          Icons
                              .calendar_today_rounded,
                          _rdGreen,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 16,
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
                              'Earnings by Date',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            LayoutBuilder(
                              builder: (
                                BuildContext
                                    context,
                                BoxConstraints
                                    constraints,
                              ) {
                                final Widget
                                    fromButton =
                                    OutlinedButton
                                        .icon(
                                  onPressed:
                                      _pickEarningsFrom,
                                  icon: const Icon(
                                    Icons
                                        .event_rounded,
                                  ),
                                  label: Text(
                                    _earningsFrom ==
                                            null
                                        ? 'From Date'
                                        : 'From ${_earningsFrom!.day.toString().padLeft(2, '0')}/${_earningsFrom!.month.toString().padLeft(2, '0')}/${_earningsFrom!.year}',
                                  ),
                                );

                                final Widget
                                    toButton =
                                    OutlinedButton
                                        .icon(
                                  onPressed:
                                      _pickEarningsTo,
                                  icon: const Icon(
                                    Icons
                                        .event_available_rounded,
                                  ),
                                  label: Text(
                                    _earningsTo ==
                                            null
                                        ? 'To Date'
                                        : 'To ${_earningsTo!.day.toString().padLeft(2, '0')}/${_earningsTo!.month.toString().padLeft(2, '0')}/${_earningsTo!.year}',
                                  ),
                                );

                                if (constraints
                                        .maxWidth >=
                                    650) {
                                  return Row(
                                    children: <
                                        Widget>[
                                      Expanded(
                                        child:
                                            fromButton,
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Expanded(
                                        child:
                                            toButton,
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      TextButton
                                          .icon(
                                        onPressed:
                                            _earningsFrom ==
                                                        null &&
                                                    _earningsTo ==
                                                        null
                                                ? null
                                                : () {
                                                    setState(
                                                      () {
                                                        _earningsFrom =
                                                            null;
                                                        _earningsTo =
                                                            null;
                                                      },
                                                    );
                                                  },
                                        icon:
                                            const Icon(
                                          Icons
                                              .clear_rounded,
                                        ),
                                        label:
                                            const Text(
                                          'Clear',
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .stretch,
                                  children: <
                                      Widget>[
                                    fromButton,
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    toButton,
                                    Align(
                                      alignment:
                                          Alignment
                                              .centerRight,
                                      child:
                                          TextButton
                                              .icon(
                                        onPressed:
                                            _earningsFrom ==
                                                        null &&
                                                    _earningsTo ==
                                                        null
                                                ? null
                                                : () {
                                                    setState(
                                                      () {
                                                        _earningsFrom =
                                                            null;
                                                        _earningsTo =
                                                            null;
                                                      },
                                                    );
                                                  },
                                        icon:
                                            const Icon(
                                          Icons
                                              .clear_rounded,
                                        ),
                                        label:
                                            const Text(
                                          'Clear',
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (hasCustomRange) ...<
                                Widget>[
                              const Divider(),
                              _row(
                                'Selected Date Earnings',
                                _money(
                                  customTotal,
                                ),
                                strong: true,
                                color:
                                    _rdGreen,
                              ),
                              _row(
                                'Verified Payments',
                                '${shownPaidHotels.length}',
                                strong: true,
                              ),
                            ] else ...<
                                Widget>[
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                'Select From and To dates to see the exact total and paid Hotels for that period.',
                                style: TextStyle(
                                  color: Colors
                                      .grey
                                      .shade700,
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
                      height: 16,
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            hasCustomRange
                                ? 'Paid Hotels in Selected Dates'
                                : 'Recent Verified Payments',
                            style:
                                const TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                        Text(
                          '${shownPaidHotels.length}',
                          style:
                              const TextStyle(
                            color: _rdBlue,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    if (shownPaidHotels.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets
                                  .all(20),
                          child: Text(
                            'No verified Hotel fee payment found for this period.',
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                        ),
                      )
                    else
                      ...shownPaidHotels.map(
                        _earningsPaymentCard,
                      ),
                    const SizedBox(
                      height: 16,
                    ),
                    FilledButton.icon(
                      onPressed:
                          _showGenerateInvoiceDialog,
                      icon: const Icon(
                        Icons
                            .post_add_rounded,
                      ),
                      label: const Text(
                        'Generate / Recalculate Monthly Invoice',
                        style: TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Container(
                      padding:
                          const EdgeInsets
                              .all(14),
                      decoration:
                          BoxDecoration(
                        color: _rdBlue
                            .withValues(
                          alpha: 0.07,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(14),
                      ),
                      child: const Text(
                        'Fee calculation uses paid Hotel bookings created '
                        'inside the selected billing month. Monthly fee and '
                        'commission can both be set to 0 if RD wants to use '
                        'only one fee model. Payment verification, cash '
                        'collection and invoice waivers are Admin-only actions.',
                        style: TextStyle(
                          fontWeight:
                              FontWeight
                                  .w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              color.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoicesTab() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(
            'hotel_fee_invoices',
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
              'Could not load Hotel fee invoices.\n'
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
                    Map<String, dynamic>>>[];

        all.sort(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                first,
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                second,
          ) =>
              (second.data()[
                              'billingMonth']
                          ?.toString() ??
                      '')
                  .compareTo(
                first.data()[
                            'billingMonth']
                        ?.toString() ??
                    '',
              ),
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
                      _invoiceMatches(
                    doc.data(),
                  ),
                )
                .toList();

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1050,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(16),
              children: <Widget>[
                SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child:
                      SegmentedButton<
                          String>(
                    segments: const <
                        ButtonSegment<
                            String>>[
                      ButtonSegment<String>(
                        value: 'all',
                        label: Text('All'),
                      ),
                      ButtonSegment<String>(
                        value: 'unpaid',
                        label:
                            Text('Unpaid'),
                      ),
                      ButtonSegment<String>(
                        value: 'overdue',
                        label:
                            Text('Overdue'),
                      ),
                      ButtonSegment<String>(
                        value: 'paid',
                        label:
                            Text('Paid'),
                      ),
                      ButtonSegment<String>(
                        value: 'waived',
                        label:
                            Text('Waived'),
                      ),
                    ],
                    selected:
                        <String>{
                      _invoiceFilter,
                    },
                    onSelectionChanged:
                        (
                      Set<String> value,
                    ) {
                      setState(() {
                        _invoiceFilter =
                            value.first;
                      });
                    },
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Invoices (${docs.length})',
                        style:
                            const TextStyle(
                          fontSize: 21,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed:
                          _showGenerateInvoiceDialog,
                      icon: const Icon(
                        Icons.add_rounded,
                      ),
                      label:
                          const Text(
                        'Generate',
                      ),
                    ),
                  ],
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
                        'No invoice found.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...docs.map(
                    _invoiceCard,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _invoiceCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final String status =
        _effectiveInvoiceStatus(data);

    final double outstanding =
        _outstanding(data);

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
                    '${data['hotelName'] ?? 'Hotel'} • '
                    '${data['billingMonth'] ?? ''}',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status
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
            _row(
              'Monthly Fee',
              _money(
                data['monthlyFee'],
              ),
            ),
            _row(
              'Commission Base',
              _money(
                data[
                    'commissionBase'],
              ),
            ),
            _row(
              'Commission',
              '${((data['commissionPercent'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}% = '
                  '${_money(data['commissionAmount'])}',
            ),
            if (((data['adjustmentAmount']
                            as num?)
                        ?.toDouble() ??
                    0) !=
                0)
              _row(
                'Adjustment',
                _money(
                  data[
                      'adjustmentAmount'],
                ),
              ),
            if (((data['discountAmount']
                            as num?)
                        ?.toDouble() ??
                    0) !=
                0)
              _row(
                'Discount',
                '- ${_money(data['discountAmount'])}',
              ),
            const Divider(),
            _row(
              'Total Due',
              _money(
                data['totalDue'],
              ),
              strong: true,
              color: _rdBlue,
            ),
            _row(
              'Paid',
              _money(
                data['paidAmount'],
              ),
              strong: true,
              color: _rdGreen,
            ),
            _row(
              'Outstanding',
              _money(outstanding),
              strong: true,
              color: outstanding >
                      0
                  ? _rdRed
                  : _rdGreen,
            ),
            _row(
              'Due Date',
              _date(
                data['dueDate'],
              ),
            ),
            _row(
              'Eligible Bookings',
              '${data['bookingCount'] ?? 0}',
            ),
            if ((data['note']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Note: ${data['note']}',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            if ((data['waiveReason']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Waive reason: '
                '${data['waiveReason']}',
                style: const TextStyle(
                  color: _rdBlue,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            const SizedBox(
              height: 9,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (outstanding >
                        0 &&
                    status != 'waived')
                  FilledButton
                      .tonalIcon(
                    onPressed: () =>
                        _markCashPaid(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .payments_rounded,
                    ),
                    label: const Text(
                      'Mark Cash Paid',
                    ),
                  ),
                if (status !=
                        'paid' &&
                    status !=
                        'waived')
                  OutlinedButton.icon(
                    onPressed: () =>
                        _waiveInvoice(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .money_off_rounded,
                    ),
                    label: const Text(
                      'Waive',
                    ),
                  ),
                if (status ==
                    'waived')
                  OutlinedButton.icon(
                    onPressed: () =>
                        _reopenInvoice(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .restart_alt_rounded,
                    ),
                    label: const Text(
                      'Reopen',
                    ),
                  ),
              ],
            ),
            const SizedBox(
              height: 6,
            ),
            SelectableText(
              'Invoice ID: ${doc.id}\n'
              'Partner: ${data['partnerId'] ?? ''}',
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

  Widget _paymentsTab() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(
            'hotel_fee_payments',
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
              'Could not load Hotel fee payments.\n'
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
                    Map<String, dynamic>>>[];

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
                first.data()[
                    'submittedAt'] as Timestamp?;

            final Timestamp? b =
                second.data()[
                    'submittedAt'] as Timestamp?;

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
                      _paymentMatches(
                    doc.data(),
                  ),
                )
                .toList();

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1050,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(16),
              children: <Widget>[
                SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child:
                      SegmentedButton<
                          String>(
                    segments: const <
                        ButtonSegment<
                            String>>[
                      ButtonSegment<String>(
                        value:
                            'submitted',
                        label: Text(
                          'Waiting',
                        ),
                      ),
                      ButtonSegment<String>(
                        value:
                            'verified',
                        label:
                            Text('Verified'),
                      ),
                      ButtonSegment<String>(
                        value:
                            'rejected',
                        label:
                            Text('Rejected'),
                      ),
                      ButtonSegment<String>(
                        value: 'all',
                        label: Text('All'),
                      ),
                    ],
                    selected:
                        <String>{
                      _paymentFilter,
                    },
                    onSelectionChanged:
                        (
                      Set<String> value,
                    ) {
                      setState(() {
                        _paymentFilter =
                            value.first;
                      });
                    },
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                Text(
                  'Payments (${docs.length})',
                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w900,
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
                        'No Hotel fee payment found.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...docs.map(
                    _paymentCard,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _paymentCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final String status =
        data['status']
                ?.toString() ??
            'submitted';

    final String proofUrl =
        data['proofUrl']
                ?.toString()
                .trim() ??
            '';

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
                    '${data['hotelName'] ?? 'Hotel'} • '
                    '${data['billingMonth'] ?? ''}',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status
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
            _row(
              'Amount',
              _money(
                data['amount'],
              ),
              strong: true,
            ),
            _row(
              'Method',
              data['method']
                      ?.toString() ??
                  '',
            ),
            _row(
              'Reference',
              data['transactionRef']
                      ?.toString() ??
                  '',
            ),
            _row(
              'Submitted',
              _date(
                data['submittedAt'],
              ),
            ),
            if (status == 'verified')
              _row(
                'Verified / Paid Date',
                _date(
                  data['verifiedAt'] ??
                      data['updatedAt'],
                ),
                strong: true,
                color: _rdGreen,
              ),
            if ((data['note']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Note: ${data['note']}',
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
            if (proofUrl.isNotEmpty) ...<
                Widget>[
              const SizedBox(
                height: 8,
              ),
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(12),
                child: Image.network(
                  proofUrl,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) =>
                          const SizedBox(
                    height: 80,
                    child: Center(
                      child: Icon(
                        Icons
                            .image_not_supported_outlined,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (status ==
                'submitted') ...<
                Widget>[
              const SizedBox(
                height: 10,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () =>
                        _verifyPayment(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .verified_rounded,
                    ),
                    label: const Text(
                      'Verify Payment',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _rejectPayment(
                      doc,
                    ),
                    icon: const Icon(
                      Icons
                          .cancel_rounded,
                    ),
                    label: const Text(
                      'Reject',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(
              height: 6,
            ),
            SelectableText(
              'Payment ID: ${doc.id}\n'
              'Invoice: ${data['invoiceId'] ?? ''}',
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

  Widget _auditTab() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hotel_fee_audit_logs')
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
            child: Text(
              'Could not load Hotel fee audit log.\n'
              '${snapshot.error}',
              textAlign: TextAlign.center,
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
            QueryDocumentSnapshot<Map<String, dynamic>> first,
            QueryDocumentSnapshot<Map<String, dynamic>> second,
          ) {
            final Timestamp? a =
                first.data()['createdAt'] as Timestamp?;
            final Timestamp? b =
                second.data()['createdAt'] as Timestamp?;

            return (b?.millisecondsSinceEpoch ?? 0).compareTo(
              a?.millisecondsSinceEpoch ?? 0,
            );
          },
        );

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 1050),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text(
                  'Hotel Fee Audit Log',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Admin actions are recorded here for fee settings, '
                  'invoice generation, payment verification, cash collection '
                  'and invoice waivers.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No Hotel fee audit entry yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...docs.take(200).map(
                    (
                      QueryDocumentSnapshot<
                              Map<String, dynamic>>
                          doc,
                    ) {
                      final Map<String, dynamic> data =
                          doc.data();

                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: 8,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(
                              Icons.history_rounded,
                            ),
                          ),
                          title: Text(
                            (data['action']
                                        ?.toString() ??
                                    'admin_action')
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(
                            '${data['details'] ?? ''}\n'
                            'Admin: ${data['adminEmail'] ?? data['adminUid'] ?? ''} • '
                            '${_date(data['createdAt'])}',
                          ),
                          isThreeLine: true,
                          trailing: Tooltip(
                            message:
                                data['targetId']
                                        ?.toString() ??
                                    '',
                            child: const Icon(
                              Icons.info_outline_rounded,
                            ),
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
    );
  }

  Widget _settingsTab() {
    if (_settingsLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 760,
        ),
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: <Widget>[
            SwitchListTile(
              value: _feeEnabled,
              title: const Text(
                'Hotel Fee System Active',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              subtitle: const Text(
                'When disabled, newly generated invoices use 0 monthly fee and 0 commission.',
              ),
              onChanged: (bool value) {
                setState(() {
                  _feeEnabled = value;
                });
              },
            ),
            const SizedBox(height: 8),
            _numberField(
              _monthlyFee,
              'Monthly Platform Fee (Rs.)',
            ),
            const SizedBox(height: 10),
            _numberField(
              _commission,
              'Booking Commission (%)',
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _numberField(
                    _dueDay,
                    'Due Day (1-28)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numberField(
                    _graceDays,
                    'Grace Days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bankName,
              decoration:
                  const InputDecoration(
                labelText: 'Bank Name',
                border:
                    OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountName,
              decoration:
                  const InputDecoration(
                labelText:
                    'Bank Account Name',
                border:
                    OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller:
                  _accountNumber,
              decoration:
                  const InputDecoration(
                labelText:
                    'Bank Account Number',
                border:
                    OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller:
                  _instructions,
              maxLines: 4,
              decoration:
                  const InputDecoration(
                labelText:
                    'Payment Instructions',
                hintText:
                    'Bank / eWallet / office payment instructions for Hotel Partners',
                border:
                    OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child:
                  FilledButton.icon(
                onPressed:
                    _settingsSaving
                        ? null
                        : _saveSettings,
                icon: _settingsSaving
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
                            .save_rounded,
                      ),
                label: const Text(
                  'Save Hotel Fee Settings',
                  style: TextStyle(
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
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType
              .numberWithOptions(
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        border:
            const OutlineInputBorder(),
      ),
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.right,
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text(
            'Hotel Fees & Admin',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(
                icon: Icon(
                  Icons
                      .dashboard_rounded,
                ),
                text: 'Overview',
              ),
              Tab(
                icon: Icon(
                  Icons
                      .receipt_long_rounded,
                ),
                text: 'Invoices',
              ),
              Tab(
                icon: Icon(
                  Icons
                      .payments_rounded,
                ),
                text: 'Payments',
              ),
              Tab(
                icon: Icon(
                  Icons
                      .history_rounded,
                ),
                text: 'Audit',
              ),
              Tab(
                icon: Icon(
                  Icons
                      .settings_rounded,
                ),
                text: 'Settings',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _overviewTab(),
            _invoicesTab(),
            _paymentsTab(),
            _auditTab(),
            _settingsTab(),
          ],
        ),
      ),
    );
  }
}

class _GenerateHotelFeeInvoiceDialog
    extends StatefulWidget {
  const _GenerateHotelFeeInvoiceDialog({
    required this.hotels,
    required this.months,
    required this.onGenerate,
  });

  final List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>> hotels;

  final List<String> months;

  final Future<String?> Function({
    required QueryDocumentSnapshot<
            Map<String, dynamic>>
        hotelDoc,
    required String billingMonth,
    required double adjustmentAmount,
    required double discountAmount,
    required String note,
  }) onGenerate;

  @override
  State<_GenerateHotelFeeInvoiceDialog>
      createState() =>
          _GenerateHotelFeeInvoiceDialogState();
}

class _GenerateHotelFeeInvoiceDialogState
    extends State<
        _GenerateHotelFeeInvoiceDialog> {
  late String _hotelId;
  late String _month;

  final TextEditingController _adjustment =
      TextEditingController(
    text: '0',
  );

  final TextEditingController _discount =
      TextEditingController(
    text: '0',
  );

  final TextEditingController _note =
      TextEditingController();

  bool _working = false;

  @override
  void initState() {
    super.initState();

    _hotelId =
        widget.hotels.first.id;

    _month =
        widget.months.first;
  }

  @override
  void dispose() {
    _adjustment.dispose();
    _discount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_working) {
      return;
    }

    final double? adjustment =
        double.tryParse(
      _adjustment.text.trim(),
    );

    final double? discount =
        double.tryParse(
      _discount.text.trim(),
    );

    if (adjustment == null ||
        discount == null ||
        discount < 0) {
      _message(
        'Enter valid adjustment and discount values.',
      );
      return;
    }

    final QueryDocumentSnapshot<
            Map<String, dynamic>>
        hotelDoc =
        widget.hotels.firstWhere(
      (
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            doc,
      ) =>
          doc.id == _hotelId,
    );

    setState(() {
      _working = true;
    });

    final String? error =
        await widget.onGenerate(
      hotelDoc: hotelDoc,
      billingMonth: _month,
      adjustmentAmount:
          adjustment,
      discountAmount: discount,
      note: _note.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _working = false;
    });

    if (error != null) {
      _message(error);
      return;
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Hotel fee invoice generated.',
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Generate Hotel Fee Invoice',
        style: TextStyle(
          fontWeight:
              FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<
                  String>(
                initialValue: _hotelId,
                decoration:
                    const InputDecoration(
                  labelText: 'Hotel',
                  border:
                      OutlineInputBorder(),
                ),
                items: widget.hotels
                    .map(
                      (
                        QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>
                            doc,
                      ) =>
                          DropdownMenuItem<
                              String>(
                        value: doc.id,
                        child: Text(
                          doc.data()[
                                      'name']
                                  ?.toString() ??
                              'Hotel',
                        ),
                      ),
                    )
                    .toList(),
                onChanged:
                    (String? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _hotelId = value;
                  });
                },
              ),
              const SizedBox(
                height: 10,
              ),
              DropdownButtonFormField<
                  String>(
                initialValue: _month,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Billing Month',
                  border:
                      OutlineInputBorder(),
                ),
                items: widget.months
                    .map(
                      (String value) =>
                          DropdownMenuItem<
                              String>(
                        value: value,
                        child:
                            Text(value),
                      ),
                    )
                    .toList(),
                onChanged:
                    (String? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _month = value;
                  });
                },
              ),
              const SizedBox(
                height: 10,
              ),
              TextField(
                controller:
                    _adjustment,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration:
                    const InputDecoration(
                  labelText:
                      'Adjustment (+ / - Rs.)',
                  hintText:
                      'Extra charge positive, credit negative',
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              TextField(
                controller:
                    _discount,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(
                  labelText:
                      'Discount (Rs.)',
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Admin Note (optional)',
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 9,
              ),
              const Text(
                'Commission is calculated automatically from paid '
                'Hotel bookings created in the selected month.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              _working
                  ? null
                  : () =>
                      Navigator.pop(
                        context,
                      ),
          child:
              const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              _working
                  ? null
                  : _generate,
          icon: _working
              ? const SizedBox.square(
                  dimension: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons
                      .receipt_long_rounded,
                ),
          label: const Text(
            'Generate',
          ),
        ),
      ],
    );
  }
}
