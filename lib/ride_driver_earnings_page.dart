import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'services/ride_commission_service.dart';


class _RideIncomeSummary {
  const _RideIncomeSummary({
    required this.gross,
    required this.commission,
    required this.net,
    required this.rides,
  });

  final double gross;
  final double commission;
  final double net;
  final int rides;
}

class _RideIncomeEntry {
  const _RideIncomeEntry({
    required this.id,
    required this.data,
    required this.completedAt,
    required this.gross,
    required this.commissionPercent,
    required this.commission,
    required this.net,
  });

  final String id;
  final Map<String, dynamic> data;
  final DateTime completedAt;
  final double gross;
  final double commissionPercent;
  final double commission;
  final double net;
}

class RideDriverEarningsSummaryCard extends StatelessWidget {
  const RideDriverEarningsSummaryCard({
    required this.driverId,
    required this.onViewHistory,
    super.key,
  });

  final String driverId;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final String cleanDriverId = driverId.trim();

    if (cleanDriverId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('driverId', isEqualTo: cleanDriverId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load earnings: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final List<_RideIncomeEntry> entries = _completedEntries(snapshot.data!);
        final DateTime now = DateTime.now();
        final DateTime startOfToday = DateTime(now.year, now.month, now.day);
        final DateTime startOfWeek = startOfToday.subtract(
          Duration(days: startOfToday.weekday - DateTime.monday),
        );
        final DateTime startOfMonth = DateTime(now.year, now.month);

        final _RideIncomeSummary today = _summary(
          entries.where((entry) => !entry.completedAt.isBefore(startOfToday)),
        );
        final _RideIncomeSummary week = _summary(
          entries.where((entry) => !entry.completedAt.isBefore(startOfWeek)),
        );
        final _RideIncomeSummary month = _summary(
          entries.where((entry) => !entry.completedAt.isBefore(startOfMonth)),
        );

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Driver Earnings',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                          Text('Completed rides only'),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onViewHistory,
                      child: const Text('History'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      _moneyRow('This Month Gross', month.gross),
                      _moneyRow('RD Commission', month.commission),
                      const Divider(height: 20),
                      _moneyRow(
                        'This Month Net Income',
                        month.net,
                        bold: true,
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Completed rides: ${month.rides}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _smallStat(
                        'Today',
                        today.net,
                        today.rides,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _smallStat(
                        'This Week',
                        week.net,
                        week.rides,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _smallStat(String title, double net, int rides) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${net.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '$rides rides',
            style: const TextStyle(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}



class _DriverCustomerPaymentQrCard extends StatefulWidget {
  const _DriverCustomerPaymentQrCard({
    required this.driverId,
  });

  final String driverId;

  @override
  State<_DriverCustomerPaymentQrCard> createState() =>
      _DriverCustomerPaymentQrCardState();
}

class _DriverCustomerPaymentQrCardState
    extends State<_DriverCustomerPaymentQrCard> {
  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

  bool _uploading = false;

  DocumentReference<Map<String, dynamic>> get _driverRef =>
      FirebaseFirestore.instance
          .collection('ride_drivers')
          .doc(widget.driverId.trim());

  Future<String> _uploadQrImage(XFile image) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
        ),
      );

    final http.StreamedResponse response = await request.send();
    final String body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Payment QR upload failed: $body');
    }

    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Payment QR upload response.');
    }

    final String url = decoded['secure_url']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw Exception('Payment QR image URL was not received.');
    }

    return url;
  }

  Future<void> _pickAndSaveQr() async {
    if (_uploading) {
      return;
    }

    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null || !mounted) {
      return;
    }

    setState(() => _uploading = true);
    try {
      final String url = await _uploadQrImage(image);
      await _driverRef.update(
        <String, dynamic>{
          'paymentQrUrl': url,
          'paymentQrUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Customer payment QR saved. Customers can use it at ride completion.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save Payment QR: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _removeQr() async {
    if (_uploading) {
      return;
    }

    setState(() => _uploading = true);
    try {
      await _driverRef.update(
        <String, dynamic>{
          'paymentQrUrl': '',
          'paymentQrUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove Payment QR: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _driverRef.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};
        final String qrUrl =
            data['paymentQrUrl']?.toString().trim() ?? '';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.qr_code_2_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Customer Payment QR',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'For online ride payment, the customer pays you directly. '
                  'Upload your own payment QR here. Cash payment remains available.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (qrUrl.isNotEmpty)
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 280,
                        maxHeight: 280,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.network(
                        qrUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Saved Payment QR could not be loaded.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No online payment QR saved yet. Customers can still pay cash.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _uploading ? null : _pickAndSaveQr,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_rounded),
                  label: Text(
                    _uploading
                        ? 'Saving...'
                        : qrUrl.isEmpty
                            ? 'Upload Payment QR'
                            : 'Replace Payment QR',
                  ),
                ),
                if (qrUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _removeQr,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove Payment QR'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}


class _CommissionPaymentSubmission {
  const _CommissionPaymentSubmission({
    required this.method,
    required this.reference,
    required this.note,
  });

  final String method;
  final String reference;
  final String note;
}

class _RideCommissionSettlementCard extends StatefulWidget {
  const _RideCommissionSettlementCard({
    required this.driverId,
    required this.entries,
  });

  final String driverId;
  final List<_RideIncomeEntry> entries;

  @override
  State<_RideCommissionSettlementCard> createState() =>
      _RideCommissionSettlementCardState();
}

class _RideCommissionSettlementCardState
    extends State<_RideCommissionSettlementCard> {
  final RideCommissionService _commissionService = RideCommissionService();
  bool _submitting = false;

  double _paymentAmount(Map<String, dynamic> data) {
    return _toDouble(data['amount']) ?? 0.0;
  }

  DateTime _paymentTime(Map<String, dynamic> data) {
    for (final String key in <String>[
      'createdAt',
      'reviewedAt',
      'updatedAt',
    ]) {
      final dynamic value = data[key];
      if (value is Timestamp) {
        return value.toDate().toLocal();
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _commissionPeriodBox(String label, double amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPayment(
    RideCommissionSettings settings,
    double pendingAmount,
  ) async {
    if (_submitting || pendingAmount <= 0) {
      return;
    }

    final _CommissionPaymentSubmission? submission =
        await showDialog<_CommissionPaymentSubmission>(
      context: context,
      builder: (_) => _CommissionPaymentDialog(
        settings: settings,
        amount: pendingAmount,
      ),
    );

    if (submission == null || !mounted) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final CollectionReference<Map<String, dynamic>> collection =
          FirebaseFirestore.instance.collection('ride_commission_payments');
      final DocumentReference<Map<String, dynamic>> ref = collection.doc();

      await ref.set(
        <String, dynamic>{
          'paymentId': ref.id,
          'driverId': widget.driverId.trim(),
          'amount': pendingAmount,
          'currency': 'Rs.',
          'method': submission.method,
          'reference': submission.reference,
          'note': submission.note,
          'status': 'pending_admin_review',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Commission payment submitted. Waiting for Admin verification.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit commission payment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final DateTime startOfWeek = startOfToday.subtract(
      Duration(days: startOfToday.weekday - DateTime.monday),
    );
    final DateTime startOfMonth = DateTime(now.year, now.month);

    double commissionSince(DateTime start) => widget.entries
        .where((_RideIncomeEntry entry) => !entry.completedAt.isBefore(start))
        .fold<double>(
          0.0,
          (double sum, _RideIncomeEntry entry) => sum + entry.commission,
        );

    final double todayCommission = commissionSince(startOfToday);
    final double weekCommission = commissionSince(startOfWeek);
    final double monthCommission = commissionSince(startOfMonth);
    final double totalCommission = widget.entries.fold<double>(
      0.0,
      (double sum, _RideIncomeEntry entry) => sum + entry.commission,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_commission_payments')
          .where('driverId', isEqualTo: widget.driverId.trim())
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> paymentSnapshot,
      ) {
        if (paymentSnapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load commission settlement: '
                '${paymentSnapshot.error}',
              ),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> payments =
            paymentSnapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        double approved = 0.0;
        double underReview = 0.0;

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in payments) {
          final Map<String, dynamic> data = doc.data();
          final String status =
              data['status']?.toString().trim().toLowerCase() ?? '';
          final double amount = _paymentAmount(data);

          if (status == 'approved') {
            approved += amount;
          } else if (status == 'pending_admin_review') {
            underReview += amount;
          }
        }

        final double pending =
            (totalCommission - approved).clamp(0.0, double.infinity).toDouble();

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> history =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(payments)
              ..sort(
                (
                  QueryDocumentSnapshot<Map<String, dynamic>> a,
                  QueryDocumentSnapshot<Map<String, dynamic>> b,
                ) =>
                    _paymentTime(b.data()).compareTo(_paymentTime(a.data())),
              );

        return StreamBuilder<RideCommissionSettings>(
          stream: _commissionService.watchSettings(),
          builder: (
            BuildContext context,
            AsyncSnapshot<RideCommissionSettings> settingsSnapshot,
          ) {
            final RideCommissionSettings settings =
                settingsSnapshot.data ??
                    const RideCommissionSettings(
                      commissionPercent: RideCommissionService.fallbackPercent,
                      esewaNumber: '',
                      khaltiNumber: '',
                      bankName: '',
                      bankAccountHolder: '',
                      bankAccountNumber: '',
                      paymentQrUrl: '',
                    );

            final bool canSubmit = pending > 0 &&
                underReview <= 0 &&
                settings.hasReceivingAccount &&
                !_submitting;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.percent_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'NRD Commission Settlement',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customers pay the Ride Driver directly. '
                      'Only the NRD commission is paid to Admin from here.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _commissionPeriodBox(
                            'Today Commission',
                            todayCommission,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _commissionPeriodBox(
                            'This Week',
                            weekCommission,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _commissionPeriodBox(
                            'This Month',
                            monthCommission,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _commissionPeriodBox(
                            'All-Time Commission',
                            totalCommission,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _moneyRow('Commission Approved / Paid', approved),
                    _moneyRow('Under Admin Review', underReview),
                    const Divider(height: 22),
                    _moneyRow(
                      'Total Pending Commission',
                      pending,
                      bold: true,
                    ),
                    const SizedBox(height: 14),
                    if (!settings.hasReceivingAccount)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NRD receiving account is not configured yet. '
                          'Admin must add eSewa, Khalti, Bank, or Payment QR '
                          'from Ride Commission settings.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      )
                    else if (underReview > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Rs. ${underReview.toStringAsFixed(2)} is waiting '
                          'for Admin verification. Submit another payment only '
                          'after this request is approved or rejected.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      )
                    else if (pending <= 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No pending NRD commission.',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canSubmit
                          ? () => _submitPayment(settings, pending)
                          : null,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payments_rounded),
                      label: Text(
                        _submitting
                            ? 'Submitting...'
                            : pending <= 0
                                ? 'Commission Settled'
                                : 'Pay Pending Commission to NRD',
                      ),
                    ),
                    if (history.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      const Text(
                        'Commission Payment History',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...history.take(5).map(
                        (
                          QueryDocumentSnapshot<Map<String, dynamic>> doc,
                        ) {
                          final Map<String, dynamic> data = doc.data();
                          final String status = data['status']
                                  ?.toString()
                                  .trim()
                                  .toLowerCase() ??
                              '';
                          final String method =
                              data['method']?.toString().trim() ?? '-';
                          final String reference =
                              data['reference']?.toString().trim() ?? '-';
                          final double amount = _paymentAmount(data);

                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        'Rs. ${amount.toStringAsFixed(2)} • '
                                        '$method',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      status == 'approved'
                                          ? 'PAID'
                                          : status == 'rejected'
                                              ? 'REJECTED'
                                              : 'PENDING',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: status == 'approved'
                                            ? Colors.green
                                            : status == 'rejected'
                                                ? Colors.red
                                                : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Reference: $reference'),
                                Text(_dateTimeText(_paymentTime(data))),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CommissionPaymentDialog extends StatefulWidget {
  const _CommissionPaymentDialog({
    required this.settings,
    required this.amount,
  });

  final RideCommissionSettings settings;
  final double amount;

  @override
  State<_CommissionPaymentDialog> createState() =>
      _CommissionPaymentDialogState();
}

class _CommissionPaymentDialogState extends State<_CommissionPaymentDialog> {
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _method;

  @override
  void initState() {
    super.initState();
    final List<String> methods = _methods();
    if (methods.isNotEmpty) {
      _method = methods.first;
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> _methods() {
    final List<String> result = <String>[];
    if (widget.settings.esewaNumber.trim().isNotEmpty) {
      result.add('eSewa');
    }
    if (widget.settings.khaltiNumber.trim().isNotEmpty) {
      result.add('Khalti');
    }
    if (widget.settings.bankAccountNumber.trim().isNotEmpty) {
      result.add('Bank Transfer');
    }
    if (widget.settings.paymentQrUrl.trim().isNotEmpty) {
      result.add('Payment QR');
    }
    return result;
  }

  String _methodDetails(String method) {
    switch (method) {
      case 'eSewa':
        return widget.settings.esewaNumber;
      case 'Khalti':
        return widget.settings.khaltiNumber;
      case 'Bank Transfer':
        return <String>[
          widget.settings.bankName,
          widget.settings.bankAccountHolder,
          widget.settings.bankAccountNumber,
        ].where((String value) => value.trim().isNotEmpty).join(' • ');
      case 'Payment QR':
        return 'Scan the NRD QR below and pay the exact pending amount.';
      default:
        return '';
    }
  }

  void _submit() {
    final String reference = _referenceController.text.trim();
    if ((_method ?? '').isEmpty || reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a payment method and enter the reference ID.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _CommissionPaymentSubmission(
        method: _method!,
        reference: reference,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> methods = _methods();
    final String selectedMethod = _method ?? '';

    return AlertDialog(
      title: const Text('Pay NRD Commission'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Amount to pay: Rs. ${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedMethod.isEmpty ? null : selectedMethod,
                items: methods
                    .map(
                      (String method) => DropdownMenuItem<String>(
                        value: method,
                        child: Text(method),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) => setState(() => _method = value),
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
              ),
              if (selectedMethod.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                SelectableText(
                  _methodDetails(selectedMethod),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
              if (widget.settings.paymentQrUrl.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.settings.paymentQrUrl,
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 90,
                      child: Center(
                        child: Text('Could not load NRD payment QR.'),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Transaction / Reference ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'After submission, the amount remains pending until Admin '
                'verifies the payment.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: methods.isEmpty ? null : _submit,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Submit for Verification'),
        ),
      ],
    );
  }
}


class RideDriverEarningsPage extends StatelessWidget {
  const RideDriverEarningsPage({
    required this.driverId,
    super.key,
  });

  final String driverId;

  @override
  Widget build(BuildContext context) {
    final String cleanDriverId = driverId.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Earnings History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: cleanDriverId.isEmpty
            ? const Center(child: Text('Driver ID is not available.'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ride_requests')
                    .where('driverId', isEqualTo: cleanDriverId)
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load earnings history: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<_RideIncomeEntry> entries =
                      _completedEntries(snapshot.data!);

                  if (entries.isEmpty) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            _DriverCustomerPaymentQrCard(
                              driverId: cleanDriverId,
                            ),
                            const SizedBox(height: 16),
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No completed rides yet. Earnings and NRD commission will appear after a trip is completed.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final DateTime now = DateTime.now();
                  final DateTime startOfMonth = DateTime(now.year, now.month);
                  final _RideIncomeSummary month = _summary(
                    entries.where(
                      (entry) => !entry.completedAt.isBefore(startOfMonth),
                    ),
                  );

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  const Text(
                                    'This Month',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _moneyRow('Gross Ride Fare', month.gross),
                                  _moneyRow('RD Commission', month.commission),
                                  const Divider(height: 22),
                                  _moneyRow(
                                    'Driver Net Income',
                                    month.net,
                                    bold: true,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Completed Rides: ${month.rides}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _DriverCustomerPaymentQrCard(
                            driverId: cleanDriverId,
                          ),
                          const SizedBox(height: 16),
                          _RideCommissionSettlementCard(
                            driverId: cleanDriverId,
                            entries: entries,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Completed Ride History',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...entries.map(_historyCard),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _historyCard(_RideIncomeEntry entry) {
    final String vehicle =
        entry.data['vehicleType']?.toString().trim() ?? 'Ride';
    final String currency =
        entry.data['currency']?.toString().trim().isNotEmpty == true
            ? entry.data['currency'].toString().trim()
            : 'Rs.';
    final double distance = _toDouble(entry.data['finalDistanceKm']) ??
        _toDouble(entry.data['actualDistanceKm']) ??
        _toDouble(entry.data['routeDistanceKm']) ??
        0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    vehicle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _dateTimeText(entry.completedAt),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ride ID: ${entry.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
            const Divider(height: 22),
            _labelValue(
              'Final Distance',
              '${distance.toStringAsFixed(2)} km',
            ),
            _labelValue(
              'Gross Fare',
              '$currency ${entry.gross.toStringAsFixed(2)}',
            ),
            _labelValue(
              'RD Commission (${entry.commissionPercent.toStringAsFixed(2)}%)',
              '$currency ${entry.commission.toStringAsFixed(2)}',
            ),
            _labelValue(
              'Driver Net Income',
              '$currency ${entry.net.toStringAsFixed(2)}',
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

DateTime _completedTime(Map<String, dynamic> data) {
  for (final String key in <String>[
    'tripCompletedAt',
    'completedAt',
    'updatedAt',
    'createdAt',
  ]) {
    final dynamic value = data[key];
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<_RideIncomeEntry> _completedEntries(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final List<_RideIncomeEntry> entries = <_RideIncomeEntry>[];

  for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in snapshot.docs) {
    final Map<String, dynamic> data = document.data();
    final String status =
        data['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'completed') continue;

    final double gross = _toDouble(data['finalFare']) ??
        _toDouble(data['liveFare']) ??
        _toDouble(data['estimatedFare']) ??
        0.0;
    final double commissionPercent =
        _toDouble(data['rdCommissionPercent']) ?? 0.0;
    final double commission = _toDouble(data['finalRdCommission']) ??
        (gross * commissionPercent / 100.0);
    final double net = _toDouble(data['driverNetIncome']) ??
        (gross - commission).clamp(0.0, gross).toDouble();

    entries.add(
      _RideIncomeEntry(
        id: document.id,
        data: data,
        completedAt: _completedTime(data),
        gross: gross,
        commissionPercent: commissionPercent,
        commission: commission,
        net: net,
      ),
    );
  }

  entries.sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return entries;
}

_RideIncomeSummary _summary(Iterable<_RideIncomeEntry> entries) {
  double gross = 0;
  double commission = 0;
  double net = 0;
  int rides = 0;

  for (final _RideIncomeEntry entry in entries) {
    gross += entry.gross;
    commission += entry.commission;
    net += entry.net;
    rides += 1;
  }

  return _RideIncomeSummary(
    gross: gross,
    commission: commission,
    net: net,
    rides: rides,
  );
}

Widget _moneyRow(String label, double value, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          'Rs. ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _dateTimeText(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}
