import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminEarningsPage extends StatelessWidget {
  const AdminEarningsPage({super.key});

  double _money(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    final String cleaned = value
        .toString()
        .replaceAll('Rs.', '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RD Earnings & Commission',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load earnings.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<_SettlementRow> rows = <_SettlementRow>[];
          double totalGross = 0;
          double totalCommission = 0;
          double totalSellerPayable = 0;
          double totalSellerPaid = 0;
          double readyToPay = 0;

          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
            final Map<String, dynamic> order = doc.data();
            final dynamic rawSettlements = order['sellerSettlements'];
            if (rawSettlements is! Map) continue;

            rawSettlements.forEach((dynamic key, dynamic rawValue) {
              if (rawValue is! Map) return;

              final Map<String, dynamic> settlement =
                  Map<String, dynamic>.from(rawValue);

              final double gross = settlement['grossAmount'] != null
                  ? _money(settlement['grossAmount'])
                  : _money(settlement['amount']);

              final double commissionPercent =
                  _money(settlement['commissionPercent']);

              final double commission = settlement['commissionAmount'] != null
                  ? _money(settlement['commissionAmount'])
                  : gross * commissionPercent / 100;

              final double payable = settlement['sellerPayable'] != null
                  ? _money(settlement['sellerPayable'])
                  : gross - commission;

              final double settlementAmount =
                  _money(settlement['amount']);

              final String status =
                  settlement['status']?.toString().trim().isNotEmpty == true
                      ? settlement['status'].toString().trim()
                      : 'Pending';

              final String sellerName =
                  settlement['sellerName']?.toString().trim().isNotEmpty == true
                      ? settlement['sellerName'].toString().trim()
                      : key.toString();

              final String paymentMethod =
                  settlement['paymentMethod']?.toString().trim() ?? '';
              final String referenceId =
                  settlement['referenceId']?.toString().trim() ?? '';
              final String updatedAt =
                  settlement['updatedAt']?.toString().trim() ?? '';

              totalGross += gross;
              totalCommission += commission;
              totalSellerPayable += payable;

              if (status == 'Paid') {
                totalSellerPaid += settlementAmount;
              } else if (status == 'Ready to Pay') {
                readyToPay += settlementAmount;
              }

              rows.add(
                _SettlementRow(
                  orderId: order['orderId']?.toString().trim().isNotEmpty == true
                      ? order['orderId'].toString().trim()
                      : doc.id,
                  sellerName: sellerName,
                  status: status,
                  gross: gross,
                  commissionPercent: commissionPercent,
                  commission: commission,
                  payable: payable,
                  settlementAmount: settlementAmount,
                  paymentMethod: paymentMethod,
                  referenceId: referenceId,
                  updatedAt: updatedAt,
                ),
              );
            });
          }

          rows.sort(
            (_SettlementRow a, _SettlementRow b) =>
                b.updatedAt.compareTo(a.updatedAt),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.delivery_dining_rounded),
                  ),
                  title: const Text(
                    'Delivery Commission Control',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Set NRD delivery commission, receiving accounts, and approve or reject Delivery Person commission payments.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const _AdminDeliveryCommissionPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final int columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                          ? 3
                          : 2;

                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: constraints.maxWidth < 380 ? 1.05 : 1.25,
                    children: <Widget>[
                      _summaryCard(
                        Icons.shopping_bag_outlined,
                        'Settlement Gross',
                        totalGross,
                      ),
                      _summaryCard(
                        Icons.percent,
                        'RD Commission',
                        totalCommission,
                      ),
                      _summaryCard(
                        Icons.account_balance_wallet_outlined,
                        'Seller Payable',
                        totalSellerPayable,
                      ),
                      _summaryCard(
                        Icons.payments_outlined,
                        'Seller Paid',
                        totalSellerPaid,
                      ),
                      _summaryCard(
                        Icons.schedule,
                        'Ready to Pay',
                        readyToPay,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Commission & Settlement History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No seller settlement records yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                ...rows.map(_historyCard),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(
    IconData icon,
    String title,
    double amount,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 34),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Rs. ${_formatMoney(amount)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(_SettlementRow row) {
    Color statusColor = Colors.orange;
    if (row.status == 'Paid') {
      statusColor = Colors.green;
    } else if (row.status == 'Ready to Pay') {
      statusColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Order ID: ${row.orderId}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    row.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Seller: ${row.sellerName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Gross Sale: Rs. ${_formatMoney(row.gross)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RD Commission (${_formatMoney(row.commissionPercent)}%): '
                    'Rs. ${_formatMoney(row.commission)}',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seller Payable: Rs. ${_formatMoney(row.payable)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Settlement Amount: Rs. '
                    '${_formatMoney(row.settlementAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (row.paymentMethod.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('RD Paid Via: ${row.paymentMethod}'),
            ],
            if (row.referenceId.isNotEmpty) ...<Widget>[
              const SizedBox(height: 3),
              Text('Reference ID: ${row.referenceId}'),
            ],
            if (row.updatedAt.isNotEmpty) ...<Widget>[
              const SizedBox(height: 3),
              Text('Updated: ${row.updatedAt}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettlementRow {
  const _SettlementRow({
    required this.orderId,
    required this.sellerName,
    required this.status,
    required this.gross,
    required this.commissionPercent,
    required this.commission,
    required this.payable,
    required this.settlementAmount,
    required this.paymentMethod,
    required this.referenceId,
    required this.updatedAt,
  });

  final String orderId;
  final String sellerName;
  final String status;
  final double gross;
  final double commissionPercent;
  final double commission;
  final double payable;
  final double settlementAmount;
  final String paymentMethod;
  final String referenceId;
  final String updatedAt;
}

class _AdminDeliveryCommissionPage extends StatelessWidget {
  const _AdminDeliveryCommissionPage();

  double _money(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return 0;
    }
    return double.tryParse(
          text.replaceAll('Rs.', '').replaceAll(',', '').trim(),
        ) ??
        0;
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    return DateTime.tryParse(value?.toString().trim() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _dateText(dynamic value) {
    final DateTime date = _date(value);
    if (date.millisecondsSinceEpoch == 0) {
      return '-';
    }
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  String _moneyText(double value) => value.toStringAsFixed(2);

  bool _isDelivered(Map<String, dynamic> order) {
    final String status =
        order['status']?.toString().trim().toLowerCase() ?? '';
    final String trackingStatus =
        order['trackingStatus']?.toString().trim().toLowerCase() ?? '';
    final String deliveredAt = order['deliveredAt']?.toString().trim() ?? '';
    return status == 'delivered' ||
        trackingStatus == 'delivered' ||
        deliveredAt.isNotEmpty;
  }

  double _deliveryFee(Map<String, dynamic> order) {
    final double value = order['delivery'] != null
        ? _money(order['delivery'])
        : order['deliveryFee'] != null
            ? _money(order['deliveryFee'])
            : order['deliveryCharge'] != null
                ? _money(order['deliveryCharge'])
                : _money(order['shippingFee']);
    return value < 0 ? 0 : value;
  }

  double _commissionPercentForOrder(
    Map<String, dynamic> order,
    double defaultPercent,
  ) {
    final dynamic saved = order['deliveryCommissionPercent'] ??
        order['nrdDeliveryCommissionPercent'];
    final double value = saved == null ? defaultPercent : _money(saved);
    return value.clamp(0.0, 50.0).toDouble();
  }

  double _commissionForOrder(
    Map<String, dynamic> order,
    double defaultPercent,
  ) {
    final dynamic saved = order['deliveryCommissionAmount'] ??
        order['nrdDeliveryCommission'];
    if (saved != null) {
      final double value = _money(saved);
      if (value >= 0) {
        return value;
      }
    }
    final double fee = _deliveryFee(order);
    final double percent = _commissionPercentForOrder(
      order,
      defaultPercent,
    );
    return fee * percent / 100.0;
  }

  String _text(
    Map<String, dynamic> data,
    String key,
  ) {
    final String value = data[key]?.toString().trim() ?? '';
    return value.toLowerCase() == 'null' ? '' : value;
  }

  String _paymentStatus(Map<String, dynamic> data) =>
      data['status']?.toString().trim().toLowerCase() ?? '';

  bool _isApproved(Map<String, dynamic> data) {
    final String status = _paymentStatus(data);
    return status == 'approved' ||
        status == 'paid' ||
        status == 'settled' ||
        status == 'completed';
  }

  bool _isPending(Map<String, dynamic> data) {
    final String status = _paymentStatus(data);
    return status == 'pending_admin_review' ||
        status == 'pending' ||
        status == 'submitted' ||
        status == 'under_review';
  }

  Widget _summaryCard(
    IconData icon,
    String title,
    double amount,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                'Rs. ${_moneyText(amount)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettingsDialog(
    BuildContext context,
    Map<String, dynamic> settings,
  ) async {
    final User? admin = FirebaseAuth.instance.currentUser;
    if (admin == null || admin.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active Admin login required.')),
      );
      return;
    }

    final TextEditingController percentController = TextEditingController(
      text: (settings['commissionPercent'] ??
              settings['deliveryCommissionPercent'] ??
              '')
          .toString(),
    );
    final TextEditingController esewaController = TextEditingController(
      text: _text(settings, 'esewa'),
    );
    final TextEditingController khaltiController = TextEditingController(
      text: _text(settings, 'khalti'),
    );
    final TextEditingController bankNameController = TextEditingController(
      text: _text(settings, 'bankName'),
    );
    final TextEditingController bankAccountNameController =
        TextEditingController(
      text: _text(settings, 'bankAccountName'),
    );
    final TextEditingController bankAccountNumberController =
        TextEditingController(
      text: _text(settings, 'bankAccountNumber'),
    );
    final TextEditingController qrController = TextEditingController(
      text: _text(settings, 'paymentQrUrl'),
    );

    bool isActive = settings['isActive'] != false;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext dialogContext,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              title: const Text('Delivery Commission Settings'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: percentController,
                        enabled: !saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'NRD Commission % (0 - 50)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Commission Collection Active'),
                        subtitle: const Text(
                          'Turn this off to pause new Delivery Person commission submissions without deleting settings.',
                        ),
                        value: isActive,
                        onChanged: saving
                            ? null
                            : (bool value) {
                                setDialogState(() {
                                  isActive = value;
                                });
                              },
                      ),
                      const Divider(height: 28),
                      TextField(
                        controller: esewaController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'NRD eSewa ID / Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: khaltiController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'NRD Khalti ID / Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bankNameController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bankAccountNameController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Bank Account Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bankAccountNumberController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Bank Account Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: qrController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Payment QR Image URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final double? percent = double.tryParse(
                            percentController.text.trim(),
                          );
                          if (percent == null ||
                              percent < 0 ||
                              percent > 50) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Commission percentage must be between 0 and 50.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await FirebaseFirestore.instance
                                .collection('delivery_business_settings')
                                .doc('main')
                                .set(
                              <String, dynamic>{
                                'schemaVersion': 1,
                                'settingsId': 'main',
                                'commissionPercent': percent,
                                'deliveryCommissionPercent': percent,
                                'currency': 'Rs.',
                                'isActive': isActive,
                                'esewa': esewaController.text.trim(),
                                'khalti': khaltiController.text.trim(),
                                'bankName': bankNameController.text.trim(),
                                'bankAccountName':
                                    bankAccountNameController.text.trim(),
                                'bankAccountNumber':
                                    bankAccountNumberController.text.trim(),
                                'paymentQrUrl': qrController.text.trim(),
                                'updatedByAdminUid': admin.uid,
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                            ).timeout(const Duration(seconds: 10));

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Delivery commission settings saved.',
                                  ),
                                ),
                              );
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                              });
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not save settings: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(saving ? 'Saving...' : 'Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );

    percentController.dispose();
    esewaController.dispose();
    khaltiController.dispose();
    bankNameController.dispose();
    bankAccountNameController.dispose();
    bankAccountNumberController.dispose();
    qrController.dispose();
  }

  Future<void> _reviewPayment(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    required bool approve,
    required double calculatedOutstanding,
  }) async {
    final User? admin = FirebaseAuth.instance.currentUser;
    if (admin == null || admin.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active Admin login required.')),
      );
      return;
    }

    final Map<String, dynamic> data = document.data();
    if (!_isPending(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This payment is already reviewed.')),
      );
      return;
    }

    final double amount = _money(data['amount']);
    if (approve &&
        (amount <= 0 || amount > calculatedOutstanding + 0.05)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approval blocked. Submitted Rs. ${_moneyText(amount)} is greater than the calculated outstanding commission Rs. ${_moneyText(calculatedOutstanding)}.',
          ),
        ),
      );
      return;
    }

    final TextEditingController noteController = TextEditingController();
    bool working = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext dialogContext,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                approve
                    ? 'Approve Delivery Commission Payment'
                    : 'Reject Delivery Commission Payment',
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Submitted: Rs. ${_moneyText(amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calculated outstanding: Rs. ${_moneyText(calculatedOutstanding)}',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      enabled: !working,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: approve
                            ? 'Admin note (optional)'
                            : 'Rejection reason (required)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      working ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: working
                      ? null
                      : () async {
                          final String note = noteController.text.trim();
                          if (!approve && note.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Rejection reason is required.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            working = true;
                          });

                          try {
                            await document.reference.update(
                              <String, dynamic>{
                                'status': approve ? 'approved' : 'rejected',
                                'reviewNote': note,
                                'reviewedByAdminUid': admin.uid,
                                'reviewedAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                            ).timeout(const Duration(seconds: 10));

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    approve
                                        ? 'Delivery commission payment approved.'
                                        : 'Delivery commission payment rejected.',
                                  ),
                                ),
                              );
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                working = false;
                              });
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not review payment: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          approve
                              ? Icons.verified_rounded
                              : Icons.cancel_rounded,
                        ),
                  label: Text(
                    working
                        ? 'Saving...'
                        : approve
                            ? 'Approve'
                            : 'Reject',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  Widget _paymentCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    required double calculatedOutstanding,
  }) {
    final Map<String, dynamic> data = document.data();
    final String status =
        data['status']?.toString().trim() ?? 'pending_admin_review';
    final String driverName =
        data['driverName']?.toString().trim().isNotEmpty == true
            ? data['driverName'].toString().trim()
            : 'Delivery Person';
    final String driverId = data['driverId']?.toString().trim() ?? '';
    final String method = data['paymentMethod']?.toString().trim() ?? '';
    final String reference =
        data['paymentReference']?.toString().trim() ?? '';
    final String paymentNote = data['paymentNote']?.toString().trim() ?? '';
    final String reviewNote = data['reviewNote']?.toString().trim() ?? '';
    final double amount = _money(data['amount']);
    final double percent = _money(data['commissionPercentSnapshot']);

    Color statusColor = Colors.orange;
    if (_isApproved(data)) {
      statusColor = Colors.green;
    } else if (status.toLowerCase() == 'rejected') {
      statusColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (driverId.isNotEmpty)
                        Text(
                          'Driver ID: $driverId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(status.replaceAll('_', ' ').toUpperCase()),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            Text(
              'Submitted Amount: Rs. ${_moneyText(amount)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (percent > 0)
              Text('Commission snapshot: ${percent.toStringAsFixed(2)}%'),
            Text(
              'Calculated Outstanding: Rs. ${_moneyText(calculatedOutstanding)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (method.isNotEmpty) Text('Method: $method'),
            if (reference.isNotEmpty) Text('Reference: $reference'),
            if (paymentNote.isNotEmpty) Text('Delivery note: $paymentNote'),
            Text('Submitted: ${_dateText(data['submittedAt'])}'),
            if (reviewNote.isNotEmpty) Text('Admin note: $reviewNote'),
            if (data['reviewedAt'] != null)
              Text('Reviewed: ${_dateText(data['reviewedAt'])}'),
            if (_isPending(data)) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewPayment(
                        context,
                        document,
                        approve: false,
                        calculatedOutstanding: calculatedOutstanding,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _reviewPayment(
                        context,
                        document,
                        approve: true,
                        calculatedOutstanding: calculatedOutstanding,
                      ),
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Commission Control',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('delivery_business_settings')
            .doc('main')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
              settingsSnapshot,
        ) {
          if (settingsSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Delivery commission settings.\n${settingsSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final Map<String, dynamic> settings =
              settingsSnapshot.data?.data() ?? <String, dynamic>{};
          final bool settingsExist = settingsSnapshot.data?.exists == true;
          final double commissionPercent = (settings['commissionPercent'] != null
                  ? _money(settings['commissionPercent'])
                  : _money(settings['deliveryCommissionPercent']))
              .clamp(0.0, 50.0)
              .toDouble();
          final bool settingsActive = settings['isActive'] != false;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> orderSnapshot,
            ) {
              if (orderSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load Delivery orders.\n${orderSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!orderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final Map<String, double> commissionByDriver =
                  <String, double>{};
              double totalDeliveryFees = 0;
              double totalCommissionAccrued = 0;

              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in orderSnapshot.data!.docs) {
                final Map<String, dynamic> order = doc.data();
                if (!_isDelivered(order)) {
                  continue;
                }
                final String driverId =
                    order['driverId']?.toString().trim() ?? '';
                if (driverId.isEmpty) {
                  continue;
                }

                final double fee = _deliveryFee(order);
                final double commission = _commissionForOrder(
                  order,
                  commissionPercent,
                );
                totalDeliveryFees += fee;
                totalCommissionAccrued += commission;
                commissionByDriver[driverId] =
                    (commissionByDriver[driverId] ?? 0) + commission;

              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('delivery_commission_payments')
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                      paymentSnapshot,
                ) {
                  if (paymentSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load Delivery commission payments.\n${paymentSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      paymentDocs = paymentSnapshot.hasData
                          ? List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                              paymentSnapshot.data!.docs,
                            )
                          : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  paymentDocs.sort((a, b) {
                    final bool aPending = _isPending(a.data());
                    final bool bPending = _isPending(b.data());
                    if (aPending != bPending) {
                      return aPending ? -1 : 1;
                    }
                    return _date(b.data()['submittedAt'])
                        .compareTo(_date(a.data()['submittedAt']));
                  });

                  final Map<String, double> approvedByDriver =
                      <String, double>{};
                  double approvedTotal = 0;
                  double underReviewTotal = 0;

                  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                      in paymentDocs) {
                    final Map<String, dynamic> data = doc.data();
                    final String driverId =
                        data['driverId']?.toString().trim() ?? '';
                    final double amount = _money(data['amount']);
                    if (_isApproved(data)) {
                      approvedTotal += amount;
                      if (driverId.isNotEmpty) {
                        approvedByDriver[driverId] =
                            (approvedByDriver[driverId] ?? 0) + amount;
                      }
                    } else if (_isPending(data)) {
                      underReviewTotal += amount;
                    }
                  }

                  final Map<String, double> outstandingByDriver =
                      <String, double>{};
                  double totalOutstanding = 0;
                  commissionByDriver.forEach((String driverId, double accrued) {
                    final double outstanding =
                        (accrued - (approvedByDriver[driverId] ?? 0))
                            .clamp(0.0, double.infinity)
                            .toDouble();
                    outstandingByDriver[driverId] = outstanding;
                    totalOutstanding += outstanding;
                  });

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const CircleAvatar(
                                    child: Icon(Icons.settings_rounded),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        const Text(
                                          'NRD Delivery Commission Settings',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          settingsExist
                                              ? '${commissionPercent.toStringAsFixed(2)}% • ${settingsActive ? 'ACTIVE' : 'PAUSED'}'
                                              : 'Not configured',
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => _openSettingsDialog(
                                      context,
                                      settings,
                                    ),
                                    icon: const Icon(Icons.edit_rounded),
                                    label: Text(
                                      settingsExist ? 'Edit' : 'Configure',
                                    ),
                                  ),
                                ],
                              ),
                              if (settingsExist) ...<Widget>[
                                const Divider(height: 24),
                                Text(
                                  'Receiving methods: '
                                  '${_text(settings, 'esewa').isNotEmpty ? 'eSewa  ' : ''}'
                                  '${_text(settings, 'khalti').isNotEmpty ? 'Khalti  ' : ''}'
                                  '${_text(settings, 'bankAccountNumber').isNotEmpty ? 'Bank  ' : ''}'
                                  '${_text(settings, 'paymentQrUrl').isNotEmpty ? 'QR' : ''}',
                                ),
                              ],
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
                          final int columns = constraints.maxWidth >= 900
                              ? 4
                              : constraints.maxWidth >= 560
                                  ? 2
                                  : 1;
                          return GridView.count(
                            crossAxisCount: columns,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: columns == 1 ? 2.4 : 1.45,
                            children: <Widget>[
                              _summaryCard(
                                Icons.local_shipping_rounded,
                                'Delivery Fees Earned',
                                totalDeliveryFees,
                              ),
                              _summaryCard(
                                Icons.percent_rounded,
                                'NRD Commission Accrued',
                                totalCommissionAccrued,
                              ),
                              _summaryCard(
                                Icons.verified_rounded,
                                'Commission Approved',
                                approvedTotal,
                              ),
                              _summaryCard(
                                Icons.pending_actions_rounded,
                                'Under Review',
                                underReviewTotal,
                              ),
                              _summaryCard(
                                Icons.account_balance_wallet_rounded,
                                'Outstanding Commission',
                                totalOutstanding,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Delivery Commission Payment Review',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Approve only after matching the actual bank/eSewa/Khalti/QR transfer reference. Rejected payments do not reduce outstanding commission.',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!paymentSnapshot.hasData)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (paymentDocs.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No Delivery Person commission payments submitted yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...paymentDocs.map(
                          (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                            final String driverId =
                                doc.data()['driverId']?.toString().trim() ?? '';
                            return _paymentCard(
                              context,
                              doc,
                              calculatedOutstanding:
                                  outstandingByDriver[driverId] ?? 0,
                            );
                          },
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

