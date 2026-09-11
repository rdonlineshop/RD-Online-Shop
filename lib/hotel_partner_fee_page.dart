import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'hotel_cloudinary_service.dart';

class HotelPartnerFeePage extends StatefulWidget {
  const HotelPartnerFeePage({super.key});

  @override
  State<HotelPartnerFeePage> createState() =>
      _HotelPartnerFeePageState();
}

class _HotelPartnerFeePageState
    extends State<HotelPartnerFeePage> {
  static const Color _rdGreen = Color(0xFF2E7D32);
  static const Color _rdBlue = Color(0xFF1565C0);
  static const Color _rdRed = Color(0xFFD32F2F);
  static const Color _rdOrange = Color(0xFFF57C00);

  User? get _user => FirebaseAuth.instance.currentUser;

  String _money(dynamic value) {
    final double amount = (value as num?)?.toDouble() ?? 0;
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

  double _outstanding(Map<String, dynamic> invoice) {
    final double total =
        (invoice['totalDue'] as num?)?.toDouble() ?? 0;

    final double paid =
        (invoice['paidAmount'] as num?)?.toDouble() ?? 0;

    final double value = total - paid;

    return value < 0 ? 0 : value;
  }

  String _effectiveStatus(Map<String, dynamic> invoice) {
    final String stored =
        invoice['status']?.toString().toLowerCase() ?? 'unpaid';

    if (<String>['paid', 'waived'].contains(stored)) {
      return stored;
    }

    final Timestamp? dueStamp = invoice['dueDate'] as Timestamp?;

    final int graceDays =
        (invoice['graceDays'] as num?)?.toInt() ?? 0;

    if (dueStamp != null) {
      final DateTime graceEnd =
          dueStamp.toDate().add(Duration(days: graceDays));

      if (DateTime.now().isAfter(graceEnd) &&
          _outstanding(invoice) > 0) {
        return 'overdue';
      }
    }

    return stored;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return _rdGreen;
      case 'waived':
        return _rdBlue;
      case 'overdue':
        return _rdRed;
      case 'submitted':
        return Colors.purple;
      case 'rejected':
        return _rdRed;
      default:
        return _rdOrange;
    }
  }

  Future<void> _submitPayment(
    QueryDocumentSnapshot<Map<String, dynamic>> invoiceDoc,
  ) async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      _message('Hotel Partner login is required.');
      return;
    }

    final Map<String, dynamic> invoice = invoiceDoc.data();

    final double outstanding = _outstanding(invoice);

    if (outstanding <= 0) {
      _message('This invoice has no outstanding balance.');
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> existing =
          await FirebaseFirestore.instance
              .collection('hotel_fee_payments')
              .where(
                'partnerId',
                isEqualTo: user.uid,
              )
              .get();

      final bool waiting = existing.docs.any(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            doc.data()['invoiceId'] == invoiceDoc.id &&
            doc.data()['status'] == 'submitted',
      );

      if (waiting) {
        _message(
          'A payment for this invoice is already waiting for Admin verification.',
        );
        return;
      }
    } catch (_) {
      // Continue. Firestore security will still validate the new payment.
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _HotelFeePaymentDialog(
          invoiceDoc: invoiceDoc,
          outstanding: outstanding,
        );
      },
    );
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

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(
    Map<String, dynamic> settings,
  ) {
    final bool enabled = settings['enabled'] != false;

    final double monthlyFee =
        (settings['monthlyFee'] as num?)?.toDouble() ?? 0;

    final double commission =
        (settings['commissionPercent'] as num?)?.toDouble() ?? 0;

    final int dueDay =
        (settings['dueDay'] as num?)?.toInt() ?? 7;

    final int graceDays =
        (settings['graceDays'] as num?)?.toInt() ?? 3;

    final String instructions =
        settings['paymentInstructions']?.toString().trim() ?? '';

    final String bankName =
        settings['bankName']?.toString().trim() ?? '';

    final String accountName =
        settings['accountName']?.toString().trim() ?? '';

    final String accountNumber =
        settings['accountNumber']?.toString().trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'RD Hotel Fee Policy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  avatar: Icon(
                    enabled
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_rounded,
                    color: enabled ? _rdGreen : Colors.grey,
                    size: 18,
                  ),
                  label: Text(
                    enabled ? 'ACTIVE' : 'PAUSED',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('Monthly platform fee', _money(monthlyFee)),
            _row(
              'Booking commission',
              '${commission.toStringAsFixed(2)}%',
            ),
            _row('Normal due day', 'Day $dueDay of next month'),
            _row('Grace period', '$graceDays day(s)'),
            if (bankName.isNotEmpty)
              _row('Bank', bankName),
            if (accountName.isNotEmpty)
              _row('Account name', accountName),
            if (accountNumber.isNotEmpty)
              _row('Account number', accountNumber),
            if (instructions.isNotEmpty) ...<Widget>[
              const Divider(),
              Text(
                instructions,
                style: const TextStyle(
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _invoiceCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
  ) {
    final Map<String, dynamic> data = doc.data();

    final String status = _effectiveStatus(data);

    final double outstanding = _outstanding(data);

    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
        invoicePayments = payments
            .where(
              (QueryDocumentSnapshot<Map<String, dynamic>> payment) =>
                  payment.data()['invoiceId'] == doc.id,
            )
            .toList();

    invoicePayments.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>> first,
        QueryDocumentSnapshot<Map<String, dynamic>> second,
      ) {
        final Timestamp? a =
            first.data()['submittedAt'] as Timestamp?;
        final Timestamp? b =
            second.data()['submittedAt'] as Timestamp?;

        return (b?.millisecondsSinceEpoch ?? 0).compareTo(
          a?.millisecondsSinceEpoch ?? 0,
        );
      },
    );

    final bool hasSubmitted = invoicePayments.any(
      (QueryDocumentSnapshot<Map<String, dynamic>> payment) =>
          payment.data()['status'] == 'submitted',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    data['billingMonth']?.toString() ?? 'Invoice',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              data['hotelName']?.toString() ?? 'Hotel',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _row(
              'Monthly fee',
              _money(data['monthlyFee']),
            ),
            _row(
              'Commission base',
              _money(data['commissionBase']),
            ),
            _row(
              'Commission',
              '${((data['commissionPercent'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}% = '
                  '${_money(data['commissionAmount'])}',
            ),
            if (((data['adjustmentAmount'] as num?)?.toDouble() ?? 0) !=
                0)
              _row(
                'Adjustment',
                _money(data['adjustmentAmount']),
              ),
            if (((data['discountAmount'] as num?)?.toDouble() ?? 0) !=
                0)
              _row(
                'Discount',
                '- ${_money(data['discountAmount'])}',
              ),
            const Divider(),
            _row(
              'Total due',
              _money(data['totalDue']),
              strong: true,
              color: _rdBlue,
            ),
            _row(
              'Paid / verified',
              _money(data['paidAmount']),
              strong: true,
              color: _rdGreen,
            ),
            _row(
              'Outstanding',
              _money(outstanding),
              strong: true,
              color: outstanding > 0 ? _rdRed : _rdGreen,
            ),
            _row(
              'Due date',
              _date(data['dueDate']),
            ),
            _row(
              'Eligible bookings',
              '${data['bookingCount'] ?? 0}',
            ),
            if ((data['note']?.toString().trim() ?? '').isNotEmpty) ...<
                Widget>[
              const SizedBox(height: 6),
              Text(
                'Admin note: ${data['note']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (invoicePayments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                'Payment History',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              ...invoicePayments.take(3).map(
                (QueryDocumentSnapshot<Map<String, dynamic>> payment) {
                  final Map<String, dynamic> p = payment.data();

                  final String paymentStatus =
                      p['status']?.toString() ?? 'submitted';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${_money(p['amount'])} • '
                      '${p['method'] ?? ''} • '
                      '${paymentStatus.toUpperCase()}',
                      style: TextStyle(
                        color: _statusColor(paymentStatus),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ],
            if (outstanding > 0 &&
                status != 'waived' &&
                status != 'paid') ...<Widget>[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: hasSubmitted
                    ? null
                    : () => _submitPayment(doc),
                icon: Icon(
                  hasSubmitted
                      ? Icons.hourglass_top_rounded
                      : Icons.upload_file_rounded,
                ),
                label: Text(
                  hasSubmitted
                      ? 'Payment Waiting for Admin Verification'
                      : 'Submit Fee Payment',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            SelectableText(
              'Invoice ID: ${doc.id}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Hotel Partner login required.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Fees & Payments',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hotel_fee_settings')
              .doc('global')
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    DocumentSnapshot<Map<String, dynamic>>>
                settingsSnapshot,
          ) {
            final Map<String, dynamic> settings =
                settingsSnapshot.data?.data() ??
                    <String, dynamic>{
                      'enabled': true,
                      'monthlyFee': 0.0,
                      'commissionPercent': 0.0,
                      'dueDay': 7,
                      'graceDays': 3,
                    };

            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('hotel_fee_invoices')
                  .where(
                    'partnerId',
                    isEqualTo: user.uid,
                  )
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        QuerySnapshot<Map<String, dynamic>>>
                    invoiceSnapshot,
              ) {
                if (invoiceSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !invoiceSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (invoiceSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load Hotel fee invoices.\n'
                        '${invoiceSnapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('hotel_fee_payments')
                      .where(
                        'partnerId',
                        isEqualTo: user.uid,
                      )
                      .snapshots(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<
                            QuerySnapshot<Map<String, dynamic>>>
                        paymentSnapshot,
                  ) {
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

                    invoices.sort(
                      (
                        QueryDocumentSnapshot<Map<String, dynamic>>
                            first,
                        QueryDocumentSnapshot<Map<String, dynamic>>
                            second,
                      ) =>
                          (second.data()['billingMonth']
                                      ?.toString() ??
                                  '')
                              .compareTo(
                            first.data()['billingMonth']
                                    ?.toString() ??
                                '',
                          ),
                    );

                    double outstandingTotal = 0;
                    int unpaidCount = 0;
                    int paidCount = 0;

                    for (final QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        invoice in invoices) {
                      final Map<String, dynamic> data =
                          invoice.data();

                      final String status = _effectiveStatus(data);

                      final double outstanding = _outstanding(data);

                      if (status == 'paid' || status == 'waived') {
                        paidCount++;
                      } else if (outstanding > 0) {
                        unpaidCount++;
                        outstandingTotal += outstanding;
                      }
                    }

                    final int submittedCount = payments
                        .where(
                          (QueryDocumentSnapshot<Map<String, dynamic>>
                                  payment) =>
                              payment.data()['status'] == 'submitted',
                        )
                        .length;

                    return Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 900),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            _settingsCard(settings),
                            const SizedBox(height: 14),
                            GridView.count(
                              crossAxisCount:
                                  MediaQuery.sizeOf(context).width >= 760
                                      ? 4
                                      : 2,
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.35,
                              children: <Widget>[
                                _summaryCard(
                                  label: 'Outstanding',
                                  value: _money(outstandingTotal),
                                  icon: Icons
                                      .account_balance_wallet_rounded,
                                  color: _rdRed,
                                ),
                                _summaryCard(
                                  label: 'Unpaid Invoices',
                                  value: '$unpaidCount',
                                  icon:
                                      Icons.receipt_long_rounded,
                                  color: _rdOrange,
                                ),
                                _summaryCard(
                                  label: 'Paid / Waived',
                                  value: '$paidCount',
                                  icon: Icons
                                      .verified_rounded,
                                  color: _rdGreen,
                                ),
                                _summaryCard(
                                  label: 'Payments Waiting',
                                  value: '$submittedCount',
                                  icon:
                                      Icons.hourglass_top_rounded,
                                  color: Colors.purple,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Fee Invoices',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 9),
                            if (invoices.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'No Hotel fee invoice has been generated yet.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              ...invoices.map(
                                (
                                  QueryDocumentSnapshot<
                                          Map<String, dynamic>>
                                      invoice,
                                ) =>
                                    _invoiceCard(
                                  invoice,
                                  payments,
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
          },
        ),
      ),
    );
  }
}

class _HotelFeePaymentDialog extends StatefulWidget {
  const _HotelFeePaymentDialog({
    required this.invoiceDoc,
    required this.outstanding,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> invoiceDoc;
  final double outstanding;

  @override
  State<_HotelFeePaymentDialog> createState() =>
      _HotelFeePaymentDialogState();
}

class _HotelFeePaymentDialogState
    extends State<_HotelFeePaymentDialog> {
  final TextEditingController _amount =
      TextEditingController();

  final TextEditingController _reference =
      TextEditingController();

  final TextEditingController _note =
      TextEditingController();

  String _method = 'bank_transfer';

  String _proofUrl = '';

  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _amount.text =
        widget.outstanding.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _uploadProof() async {
    if (_uploading) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final String? url =
          await HotelCloudinaryService.pickAndUploadImage(
        imageQuality: 82,
      );

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        _proofUrl = url;
      });

      _message('Payment proof uploaded.');
    } catch (error) {
      _message(
        'Could not upload payment proof.\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      _message('Hotel Partner login is required.');
      return;
    }

    final double? amount =
        double.tryParse(_amount.text.trim());

    if (amount == null || amount <= 0) {
      _message('Enter a valid payment amount.');
      return;
    }

    if (amount >
        widget.outstanding + 0.01) {
      _message(
        'Payment cannot be more than the outstanding amount.',
      );
      return;
    }

    if (_method != 'other' &&
        _reference.text.trim().isEmpty) {
      _message(
        'Transaction / reference number is required.',
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final Map<String, dynamic> invoice =
          widget.invoiceDoc.data();

      final DocumentReference<Map<String, dynamic>>
          paymentRef =
          FirebaseFirestore.instance
              .collection('hotel_fee_payments')
              .doc();

      await paymentRef.set(
        <String, dynamic>{
          'paymentId': paymentRef.id,
          'invoiceId': widget.invoiceDoc.id,
          'partnerId': user.uid,
          'hotelId':
              invoice['hotelId']?.toString() ?? '',
          'hotelName':
              invoice['hotelName']?.toString() ?? 'Hotel',
          'billingMonth':
              invoice['billingMonth']?.toString() ?? '',
          'amount': amount,
          'method': _method,
          'transactionRef': _reference.text.trim(),
          'proofUrl': _proofUrl,
          'note': _note.text.trim(),
          'status': 'submitted',
          'submittedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Fee payment submitted. Admin verification is pending.',
            ),
          ),
        );
    } catch (error) {
      _message(
        'Could not submit fee payment.\n$error',
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
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Submit Hotel Fee Payment',
        style: TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Invoice: ${widget.invoiceDoc.id}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs.)',
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'bank_transfer',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'mobile_banking',
                    child: Text('Mobile Banking'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'ewallet',
                    child: Text('eWallet'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'other',
                    child: Text('Other'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _method = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText:
                      'Transaction / Reference Number',
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 10),
              if (_proofUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _proofUrl,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(
                      height: 90,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_proofUrl.isNotEmpty)
                const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed:
                    _uploading ? null : _uploadProof,
                icon: _uploading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.upload_file_rounded,
                      ),
                label: Text(
                  _proofUrl.isEmpty
                      ? 'Upload Payment Proof'
                      : 'Change Payment Proof',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                ),
          label: const Text('Submit'),
        ),
      ],
    );
  }
}
