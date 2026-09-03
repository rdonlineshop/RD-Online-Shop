import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RideDriverReactivationPage extends StatefulWidget {
  const RideDriverReactivationPage({
    required this.driverId,
    super.key,
  });

  final String driverId;

  @override
  State<RideDriverReactivationPage> createState() =>
      _RideDriverReactivationPageState();
}

class _RideDriverReactivationPageState
    extends State<RideDriverReactivationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _paymentMethod = 'Bank Transfer';
  bool _submitting = false;
  bool _amountInitialized = false;

  String get _driverId => widget.driverId.trim();

  DocumentReference<Map<String, dynamic>> get _driverRef =>
      FirebaseFirestore.instance.collection('ride_drivers').doc(_driverId);

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(String currency, double amount) {
    final String cleanCurrency = currency.trim().isEmpty ? 'Rs.' : currency.trim();
    return '$cleanCurrency ${amount.toStringAsFixed(2)}';
  }

  Future<void> _submitRequest(
    Map<String, dynamic> data,
  ) async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String approvalStatus =
        data['approvalStatus']?.toString().trim().toLowerCase() ?? '';
    final bool isApproved = data['isApproved'] == true;
    final bool isActive = data['isActive'] == true;

    if (!isApproved || isActive || approvalStatus != 'suspended') {
      _message('This driver account is not currently suspended.');
      return;
    }

    final double totalDue = _number(data['suspensionTotalDue']);
    final double amount =
        double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (amount + 0.0001 < totalDue) {
      _message(
        'Payment amount must cover the full amount due: '
        '${_money(data['suspensionCurrency']?.toString() ?? 'Rs.', totalDue)}',
      );
      return;
    }

    final String existingStatus =
        data['reactivationStatus']?.toString().trim().toLowerCase() ?? '';
    if (existingStatus == 'pending_admin_review') {
      _message('Your reactivation request is already waiting for Admin review.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _driverRef.update(
        <String, dynamic>{
          'reactivationStatus': 'pending_admin_review',
          'reactivationPaymentMethod': _paymentMethod,
          'reactivationPaymentAmount': amount,
          'reactivationPaymentReference': _referenceController.text.trim(),
          'reactivationPaymentNote': _noteController.text.trim(),
          'reactivationRequestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      _message('Payment submitted. Reactivation is waiting for Admin approval.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _message('Could not submit reactivation request: $error');
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

  Widget _amountRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: strong ? null : Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Reactivate Driver Account',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _driverId.isEmpty
            ? const Center(child: Text('Driver ID is not available.'))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _driverRef.snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load driver account: ${snapshot.error}'),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final DocumentSnapshot<Map<String, dynamic>> document =
                      snapshot.data!;
                  if (!document.exists) {
                    return const Center(child: Text('Driver account was not found.'));
                  }

                  final Map<String, dynamic> data =
                      document.data() ?? <String, dynamic>{};
                  final bool isActive = data['isActive'] == true;
                  final bool isApproved = data['isApproved'] == true;
                  final String approvalStatus =
                      data['approvalStatus']?.toString().trim().toLowerCase() ?? '';
                  final bool suspended =
                      isApproved && !isActive && approvalStatus == 'suspended';
                  final String reactivationStatus =
                      data['reactivationStatus']?.toString().trim().toLowerCase() ?? '';
                  final String currency =
                      data['suspensionCurrency']?.toString().trim().isNotEmpty == true
                          ? data['suspensionCurrency'].toString().trim()
                          : 'Rs.';
                  final double commissionDue =
                      _number(data['outstandingRdCommission']);
                  final double fine = _number(data['suspensionFine']);
                  final double totalDue = _number(data['suspensionTotalDue']);
                  final String reason =
                      data['suspensionReason']?.toString().trim() ?? '';

                  if (!_amountInitialized) {
                    _amountInitialized = true;
                    _amountController.text = totalDue.toStringAsFixed(2);
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          Card(
                            elevation: 1.5,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      CircleAvatar(
                                        backgroundColor: (suspended
                                                ? Colors.red
                                                : Colors.green)
                                            .withValues(alpha: 0.12),
                                        child: Icon(
                                          suspended
                                              ? Icons.block_rounded
                                              : Icons.verified_rounded,
                                          color: suspended
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          suspended
                                              ? 'ACCOUNT SUSPENDED'
                                              : 'ACCOUNT ACTIVE',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (reason.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 12),
                                    Text(
                                      reason,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  _amountRow(
                                    'Outstanding RD Commission',
                                    _money(currency, commissionDue),
                                  ),
                                  _amountRow(
                                    'Late Fine',
                                    _money(currency, fine),
                                  ),
                                  const Divider(height: 20),
                                  _amountRow(
                                    'Total Amount Due',
                                    _money(currency, totalDue),
                                    strong: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (!suspended)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Your driver account is active. No reactivation request is required.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else if (reactivationStatus == 'pending_admin_review')
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.hourglass_top_rounded,
                                      size: 42,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'REACTIVATION PENDING',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Your payment details were submitted. Admin must verify and approve them before you can go online again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 12),
                                    _amountRow(
                                      'Submitted Amount',
                                      _money(
                                        currency,
                                        _number(data['reactivationPaymentAmount']),
                                      ),
                                    ),
                                    _amountRow(
                                      'Payment Method',
                                      data['reactivationPaymentMethod']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                          ? data['reactivationPaymentMethod']
                                              .toString()
                                              .trim()
                                          : '-',
                                    ),
                                    _amountRow(
                                      'Reference',
                                      data['reactivationPaymentReference']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                          ? data['reactivationPaymentReference']
                                              .toString()
                                              .trim()
                                          : '-',
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...<Widget>[
                            if (reactivationStatus == 'rejected')
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'The previous reactivation request was rejected. Check the payment details and submit again.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            Card(
                              elevation: 1.5,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      const Text(
                                        'Pay & Request Reactivation',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      DropdownButtonFormField<String>(
                                        initialValue: _paymentMethod,
                                        decoration: const InputDecoration(
                                          labelText: 'Payment Method',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.payments_rounded),
                                        ),
                                        items: const <String>[
                                          'Bank Transfer',
                                          'Cash',
                                          'eSewa',
                                          'Khalti',
                                          'Other',
                                        ]
                                            .map(
                                              (String item) =>
                                                  DropdownMenuItem<String>(
                                                value: item,
                                                child: Text(item),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _submitting
                                            ? null
                                            : (String? value) {
                                                if (value != null) {
                                                  setState(() {
                                                    _paymentMethod = value;
                                                  });
                                                }
                                              },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _amountController,
                                        enabled: !_submitting,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Amount Paid ($currency)',
                                          border: const OutlineInputBorder(),
                                          prefixIcon:
                                              const Icon(Icons.account_balance_wallet_rounded),
                                        ),
                                        validator: (String? value) {
                                          final double? amount =
                                              double.tryParse(value?.trim() ?? '');
                                          if (amount == null || amount < 0) {
                                            return 'Enter a valid payment amount';
                                          }
                                          if (amount + 0.0001 < totalDue) {
                                            return 'Full amount due must be paid';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _referenceController,
                                        enabled: !_submitting,
                                        maxLength: 120,
                                        decoration: const InputDecoration(
                                          labelText: 'Payment Reference / Transaction ID',
                                          hintText: 'Optional for Cash',
                                          counterText: '',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.receipt_long_rounded),
                                        ),
                                        validator: (String? value) {
                                          if (_paymentMethod != 'Cash' &&
                                              (value == null ||
                                                  value.trim().isEmpty)) {
                                            return 'Enter payment reference';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _noteController,
                                        enabled: !_submitting,
                                        maxLines: 3,
                                        maxLength: 300,
                                        decoration: const InputDecoration(
                                          labelText: 'Note (optional)',
                                          counterText: '',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: _submitting
                                            ? null
                                            : () => _submitRequest(data),
                                        icon: _submitting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.send_rounded),
                                        label: Text(
                                          _submitting
                                              ? 'Submitting...'
                                              : 'Submit Payment & Request Reactivation',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
