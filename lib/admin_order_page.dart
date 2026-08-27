import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_auth_page.dart';
import 'order_data.dart';
import 'order_details_page.dart';

class AdminOrderPage extends StatefulWidget {
  const AdminOrderPage({super.key});

  @override
  State<AdminOrderPage> createState() => _AdminOrderPageState();
}

class _AdminOrderPageState extends State<AdminOrderPage> {
  final TextEditingController searchController = TextEditingController();
  String selectedFilter = 'All';
  String submittedSearch = '';

  String selectedDateFilter = 'All Dates';
  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.green;
      case 'Processing':
        return Colors.blue;
      case 'Shipped':
        return Colors.deepPurple;
      case 'Delivered':
        return Colors.teal;
      case 'Cancelled':
        return Colors.red;
      case 'Returned':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  DateTime? _orderDate(
    Map<String, dynamic> order,
  ) {
    final List<dynamic> candidates = <dynamic>[
      order['orderDateTime'],
      order['createdAt'],
      order['orderDate'],
      order['date'],
      order['timestamp'],
    ];

    for (final dynamic value in candidates) {
      if (value == null) {
        continue;
      }

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is num) {
        final int raw = value.toInt();

        if (raw > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(raw);
        }

        if (raw > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
        }
      }

      final String raw = value.toString().trim();

      if (raw.isEmpty || raw.toLowerCase() == 'null') {
        continue;
      }

      final DateTime? parsed = DateTime.tryParse(raw);

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  DateTime _startOfDay(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  bool _matchesDateFilter(
    Map<String, dynamic> order,
  ) {
    if (selectedDateFilter == 'All Dates') {
      return true;
    }

    final DateTime? orderDate = _orderDate(order);

    if (orderDate == null) {
      return false;
    }

    final DateTime today =
        _startOfDay(DateTime.now());
    final DateTime orderDay =
        _startOfDay(orderDate);

    DateTime startDate;
    DateTime endDate;

    switch (selectedDateFilter) {
      case 'Today':
        startDate = today;
        endDate = today;
        break;

      case 'Yesterday':
        startDate =
            today.subtract(const Duration(days: 1));
        endDate = startDate;
        break;

      case 'Last 7 Days':
        startDate =
            today.subtract(const Duration(days: 6));
        endDate = today;
        break;

      case 'Last 30 Days':
        startDate =
            today.subtract(const Duration(days: 29));
        endDate = today;
        break;

      case 'This Month':
        startDate = DateTime(
          today.year,
          today.month,
          1,
        );
        endDate = today;
        break;

      case 'Custom Range':
        if (customStartDate == null ||
            customEndDate == null) {
          return true;
        }

        startDate =
            _startOfDay(customStartDate!);
        endDate =
            _startOfDay(customEndDate!);
        break;

      default:
        return true;
    }

    return !orderDay.isBefore(startDate) &&
        !orderDay.isAfter(endDate);
  }

  String _formatDate(
    DateTime date,
  ) {
    final String day =
        date.day.toString().padLeft(2, '0');
    final String month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _dateFilterLabel() {
    if (selectedDateFilter == 'Custom Range' &&
        customStartDate != null &&
        customEndDate != null) {
      return '${_formatDate(customStartDate!)} - '
          '${_formatDate(customEndDate!)}';
    }

    return selectedDateFilter;
  }

  Future<void> _pickCustomDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? picked =
        await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year + 5,
        12,
        31,
      ),
      initialDateRange:
          customStartDate != null &&
                  customEndDate != null
              ? DateTimeRange(
                  start: customStartDate!,
                  end: customEndDate!,
                )
              : null,
      helpText: 'Select Order Date Range',
      saveText: 'Apply',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      selectedDateFilter = 'Custom Range';
      customStartDate = picked.start;
      customEndDate = picked.end;
    });
  }

  void _clearDateFilter() {
    setState(() {
      selectedDateFilter = 'All Dates';
      customStartDate = null;
      customEndDate = null;
    });
  }

  Widget _dateFilterBar() {
    const List<String> dateFilters =
        <String>[
      'All Dates',
      'Today',
      'Yesterday',
      'Last 7 Days',
      'Last 30 Days',
      'This Month',
      'Custom Range',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: selectedDateFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Order Date',
                prefixIcon:
                    const Icon(Icons.date_range),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              items: dateFilters
                  .map(
                    (String value) =>
                        DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value == 'Custom Range' &&
                                selectedDateFilter ==
                                    'Custom Range' &&
                                customStartDate != null &&
                                customEndDate != null
                            ? _dateFilterLabel()
                            : value,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) async {
                if (value == null) {
                  return;
                }

                if (value == 'Custom Range') {
                  await _pickCustomDateRange();
                  return;
                }

                setState(() {
                  selectedDateFilter = value;
                  customStartDate = null;
                  customEndDate = null;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Clear Date Filter',
            onPressed:
                selectedDateFilter == 'All Dates'
                    ? null
                    : _clearDateFilter,
            icon: const Icon(
              Icons.filter_alt_off,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filtered(
    List<Map<String, dynamic>> orders,
  ) {
    final String search = submittedSearch.trim().toLowerCase();

    return orders.where((Map<String, dynamic> order) {
      final String status = order['status']?.toString() ?? 'Pending';
      final String id = order['id']?.toString().toLowerCase() ?? '';
      final String name = (order['customerName'] ?? order['name'] ?? '')
          .toString()
          .toLowerCase();
      final String phone = order['phone']?.toString().toLowerCase() ?? '';

      final bool matchesSearch = search.isEmpty ||
          id.contains(search) ||
          name.contains(search) ||
          phone.contains(search);

      final String refundStatus =
          order['refundStatus']?.toString().trim() ?? '';

      final bool matchesFilter =
          selectedFilter == 'All' ||
              status == selectedFilter ||
              (selectedFilter == 'Refund Pending' &&
                  refundStatus == 'Pending');

      final bool matchesDate =
          _matchesDateFilter(order);

      return matchesSearch &&
          matchesFilter &&
          matchesDate;
    }).toList();
  }

  int _countStatus(List<Map<String, dynamic>> orders, String status) {
    return orders
        .where((Map<String, dynamic> order) =>
            (order['status'] ?? 'Pending').toString() == status)
        .length;
  }

  Future<void> _changeStatus(String orderId, String newStatus) async {
    try {
      await updateOrderStatus(orderId, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status changed to $newStatus')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update order: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }


  String _generateDeviceRestoreCode() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random.secure();

    return List<String>.generate(
      12,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  String _displayDeviceRestoreCode(String code) {
    if (code.length != 12) {
      return code;
    }

    return '${code.substring(0, 4)}-'
        '${code.substring(4, 8)}-'
        '${code.substring(8, 12)}';
  }

  Future<String> _createAdminDeviceRestoreCode(
    String customerId,
  ) async {
    final String cleanCustomerId = customerId.trim();

    if (cleanCustomerId.isEmpty) {
      throw StateError(
        'This order does not have a customer ID to restore.',
      );
    }

    final User? adminUser = FirebaseAuth.instance.currentUser;

    if (adminUser == null) {
      throw StateError('Admin session is not available.');
    }

    final CollectionReference<Map<String, dynamic>> links =
        FirebaseFirestore.instance.collection(
      'customer_device_links',
    );

    final DateTime expiresAt =
        DateTime.now().toUtc().add(const Duration(minutes: 10));

    for (int attempt = 0; attempt < 5; attempt++) {
      final String code = _generateDeviceRestoreCode();
      final DocumentReference<Map<String, dynamic>> linkRef =
          links.doc(code);

      final DocumentSnapshot<Map<String, dynamic>> existing =
          await linkRef.get();

      if (existing.exists) {
        continue;
      }

      await linkRef.set(
        <String, dynamic>{
          'customerId': cleanCustomerId,
          'createdByUid': adminUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'used': false,
        },
      );

      return _displayDeviceRestoreCode(code);
    }

    throw StateError(
      'Could not create a restore code. Please try again.',
    );
  }

  Future<void> _showCustomerDeviceRestoreCode(
    Map<String, dynamic> order,
  ) async {
    final String customerId =
        order['customerId']?.toString().trim() ?? '';
    final String orderId =
        order['id']?.toString().trim() ?? '-';

    if (customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This order does not have a customer ID to restore.',
          ),
        ),
      );
      return;
    }

    try {
      final String code =
          await _createAdminDeviceRestoreCode(customerId);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text(
              'Customer Device Restore Code',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Order ID: $orderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use this code on the customer device that should regain this customer\'s My Orders.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The code works once and expires in 10 minutes.',
                    style: TextStyle(
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.deepPurple,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create restore code: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }


  double _parseMoney(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final String cleaned = value
            ?.toString()
            .replaceAll('Rs.', '')
            .replaceAll('Rs', '')
            .replaceAll(',', '')
            .trim() ??
        '';

    return double.tryParse(cleaned) ?? 0;
  }

  Map<String, double> _sellerOrderAmounts(
    Map<String, dynamic> order,
  ) {
    final Map<String, double> totals = <String, double>{};
    final dynamic rawItems = order['items'];

    if (rawItems is! List) {
      return totals;
    }

    for (final dynamic rawItem in rawItems) {
      if (rawItem is! Map) {
        continue;
      }

      final String sellerId =
          rawItem['sellerId']?.toString().trim() ?? '';

      if (sellerId.isEmpty) {
        continue;
      }

      final double price = _parseMoney(rawItem['price']);
      final int quantity =
          int.tryParse(rawItem['quantity']?.toString() ?? '1') ?? 1;

      totals[sellerId] =
          (totals[sellerId] ?? 0) + (price * quantity);
    }

    return totals;
  }

  Map<String, dynamic> _sellerSettlement(
    Map<String, dynamic> order,
    String sellerId,
  ) {
    final dynamic rawSettlements =
        order['sellerSettlements'];

    if (rawSettlements is Map) {
      final dynamic raw = rawSettlements[sellerId];

      if (raw is Map) {
        return raw.map<String, dynamic>(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(
            key.toString(),
            value,
          ),
        );
      }
    }

    return <String, dynamic>{};
  }

  Future<void> _openSellerSettlement(
    Map<String, dynamic> order,
  ) async {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      return;
    }

    final Map<String, double> sellerAmounts =
        _sellerOrderAmounts(order);

    if (sellerAmounts.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seller information is missing from this order.',
          ),
        ),
      );
      return;
    }

    final List<Map<String, dynamic>> sellers =
        <Map<String, dynamic>>[];

    for (final MapEntry<String, double> entry
        in sellerAmounts.entries) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> sellerDoc =
            await FirebaseFirestore.instance
                .collection('sellers')
                .doc(entry.key)
                .get();

        sellers.add(
          <String, dynamic>{
            'sellerId': entry.key,
            'grossAmount': entry.value,
            ...?sellerDoc.data(),
          },
        );
      } catch (_) {
        sellers.add(
          <String, dynamic>{
            'sellerId': entry.key,
            'grossAmount': entry.value,
          },
        );
      }
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.88,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                4,
                16,
                24,
              ),
              children: <Widget>[
                const Text(
                  'Seller Settlement',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Order ID: $orderId',
                ),
                const SizedBox(height: 6),
                const Text(
                  'This records RD → Seller payout. It does not automatically transfer money through eSewa, Khalti, or a bank.',
                  style: TextStyle(
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                ...sellers.map<Widget>(
                  (Map<String, dynamic> seller) {
                    return _sellerSettlementCard(
                      sheetContext: sheetContext,
                      order: order,
                      seller: seller,
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

  Widget _sellerSettlementCard({
    required BuildContext sheetContext,
    required Map<String, dynamic> order,
    required Map<String, dynamic> seller,
  }) {
    final String sellerId =
        seller['sellerId']?.toString().trim() ?? '';

    final String shopName =
        seller['shopName']?.toString().trim().isNotEmpty == true
            ? seller['shopName'].toString().trim()
            : 'Seller';

    final double grossAmount =
        _parseMoney(seller['grossAmount']);

    final double commissionPercent =
        _parseMoney(seller['commissionPercent']);
    final double commissionAmount =
        grossAmount * commissionPercent / 100;
    final double sellerPayable =
        grossAmount - commissionAmount;

    final bool paymentVerified =
        seller['paymentVerified'] == true;

    final String esewa =
        seller['esewaNumber']?.toString().trim() ?? '';
    final String khalti =
        seller['khaltiNumber']?.toString().trim() ?? '';
    final String bankName =
        seller['bankName']?.toString().trim() ?? '';
    final String accountHolder =
        seller['bankAccountHolder']?.toString().trim() ?? '';
    final String accountNumber =
        seller['bankAccountNumber']?.toString().trim() ?? '';
    final String qrUrl =
        seller['paymentQrUrl']?.toString().trim() ?? '';

    final Map<String, dynamic> settlement =
        _sellerSettlement(order, sellerId);

    final String settlementStatus =
        settlement['status']?.toString().trim().isNotEmpty == true
            ? settlement['status'].toString().trim()
            : 'Pending';

    final String reference =
        settlement['referenceId']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    shopName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(settlementStatus),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Seller ID: $sellerId',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seller product total: Rs. ${grossAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'RD Commission (${commissionPercent.toStringAsFixed(commissionPercent == commissionPercent.roundToDouble() ? 0 : 2)}%): '
              'Rs. ${commissionAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Seller Payable: Rs. ${sellerPayable.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  paymentVerified
                      ? Icons.verified
                      : Icons.gpp_maybe_outlined,
                  color: paymentVerified
                      ? Colors.green
                      : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    paymentVerified
                        ? 'Seller payment details verified'
                        : 'Seller payment details not verified',
                  ),
                ),
              ],
            ),
            if (esewa.isNotEmpty)
              Text('eSewa: $esewa'),
            if (khalti.isNotEmpty)
              Text('Khalti: $khalti'),
            if (bankName.isNotEmpty)
              Text('Bank: $bankName'),
            if (accountHolder.isNotEmpty)
              Text('Account Holder: $accountHolder'),
            if (accountNumber.isNotEmpty)
              Text('Account Number: $accountNumber'),
            if (qrUrl.startsWith('http://') ||
                qrUrl.startsWith('https://')) ...<Widget>[
              const SizedBox(height: 10),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    qrUrl,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ],
            if (reference.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Reference ID: $reference',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _showSettlementEditor(
                    sheetContext: sheetContext,
                    order: order,
                    seller: seller,
                  );
                },
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  settlementStatus == 'Paid'
                      ? 'View / Update Settlement'
                      : 'Settle Seller',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettlementEditor({
    required BuildContext sheetContext,
    required Map<String, dynamic> order,
    required Map<String, dynamic> seller,
  }) async {
    final String orderId =
        order['id']?.toString().trim() ?? '';
    final String sellerId =
        seller['sellerId']?.toString().trim() ?? '';
    final String shopName =
        seller['shopName']?.toString().trim().isNotEmpty == true
            ? seller['shopName'].toString().trim()
            : 'Seller';

    final double grossAmount =
        _parseMoney(seller['grossAmount']);

    final double commissionPercent =
        _parseMoney(seller['commissionPercent']);
    final double commissionAmount =
        grossAmount * commissionPercent / 100;
    final double sellerPayable =
        grossAmount - commissionAmount;

    final Map<String, dynamic> existing =
        _sellerSettlement(order, sellerId);

    final TextEditingController amountController =
        TextEditingController(
      text: existing['amount'] != null
          ? _parseMoney(existing['amount']).toStringAsFixed(0)
          : sellerPayable.toStringAsFixed(0),
    );

    final TextEditingController referenceController =
        TextEditingController(
      text: existing['referenceId']?.toString() ?? '',
    );

    final TextEditingController noteController =
        TextEditingController(
      text: existing['note']?.toString() ?? '',
    );

    String status =
        existing['status']?.toString().trim().isNotEmpty == true
            ? existing['status'].toString().trim()
            : 'Ready to Pay';

    String paymentMethod =
        existing['paymentMethod']?.toString().trim().isNotEmpty == true
            ? existing['paymentMethod'].toString().trim()
            : '';

    bool saving = false;

    try {
      await showDialog<void>(
        context: sheetContext,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (
              BuildContext context,
              StateSetter setDialogState,
            ) {
              Future<void> save() async {
                if (saving) {
                  return;
                }

                final double? amount =
                    double.tryParse(
                  amountController.text.trim(),
                );

                if (amount == null || amount < 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a valid settlement amount.',
                      ),
                    ),
                  );
                  return;
                }

                if (status == 'Paid' &&
                    paymentMethod.trim().isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Select how RD paid the seller.',
                      ),
                    ),
                  );
                  return;
                }

                if (status == 'Paid' &&
                    referenceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Transaction / Reference ID is required for Paid status.',
                      ),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                try {
                  await updateSellerSettlement(
                    orderId: orderId,
                    sellerId: sellerId,
                    sellerName: shopName,
                    amount: amount,
                    status: status,
                    grossAmount: grossAmount,
                    commissionPercent: commissionPercent,
                    commissionAmount: commissionAmount,
                    sellerPayable: sellerPayable,
                    paymentMethod: paymentMethod,
                    referenceId:
                        referenceController.text.trim(),
                    note: noteController.text.trim(),
                  );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                  Navigator.pop(sheetContext);

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        status == 'Paid'
                            ? '$shopName marked as paid.'
                            : '$shopName settlement updated.',
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not save settlement: '
                        '${error.toString().replaceFirst('Exception: ', '')}',
                      ),
                    ),
                  );

                  if (dialogContext.mounted) {
                    setDialogState(() {
                      saving = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(
                  'Seller Settlement - $shopName',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Seller Product Total: Rs. ${grossAmount.toStringAsFixed(0)}',
                            ),
                            Text(
                              'RD Commission (${commissionPercent.toStringAsFixed(commissionPercent == commissionPercent.roundToDouble() ? 0 : 2)}%): '
                              'Rs. ${commissionAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.deepOrange,
                              ),
                            ),
                            const Divider(),
                            Text(
                              'Seller Payable: Rs. ${sellerPayable.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Settlement Amount',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Settlement Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const <String>[
                          'Pending',
                          'Ready to Pay',
                          'Paid',
                          'On Hold',
                        ].map(
                          (String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          },
                        ).toList(),
                        onChanged: saving
                            ? null
                            : (String? value) {
                                if (value == null) {
                                  return;
                                }

                                setDialogState(() {
                                  status = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            paymentMethod.isEmpty
                                ? null
                                : paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'RD Paid Via',
                          border: OutlineInputBorder(),
                        ),
                        items: const <String>[
                          'eSewa',
                          'Khalti',
                          'Bank Transfer',
                          'Cash',
                          'Other',
                        ].map(
                          (String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          },
                        ).toList(),
                        onChanged: saving
                            ? null
                            : (String? value) {
                                setDialogState(() {
                                  paymentMethod = value ?? '';
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: referenceController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText:
                              'Transaction / Reference ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        enabled: !saving,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Admin Note (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      saving ? 'Saving...' : 'Save Settlement',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      amountController.dispose();
      referenceController.dispose();
      noteController.dispose();
    }
  }

  String _refundText(
    Map<String, dynamic> order,
    String key,
  ) {
    return order[key]?.toString().trim() ?? '';
  }

  Color _refundColor(
    String status,
  ) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Refunded':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Not Required':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  int _refundPendingCount(
    List<Map<String, dynamic>> orders,
  ) {
    return orders
        .where(
          (Map<String, dynamic> order) =>
              _refundText(
                order,
                'refundStatus',
              ) ==
              'Pending',
        )
        .length;
  }

  double _paidSellerSettlementTotal(
    Map<String, dynamic> order,
  ) {
    final dynamic rawSettlements =
        order['sellerSettlements'];

    if (rawSettlements is! Map) {
      return 0;
    }

    double total = 0;

    for (final dynamic rawValue
        in rawSettlements.values) {
      if (rawValue is! Map) {
        continue;
      }

      final String status =
          rawValue['status']?.toString().trim() ?? '';

      if (status != 'Paid') {
        continue;
      }

      total += _parseMoney(
        rawValue['amount'] ??
            rawValue['sellerPayable'],
      );
    }

    return total;
  }

  bool _sellerWasAlreadyPaid(
    Map<String, dynamic> order,
  ) {
    return _paidSellerSettlementTotal(order) > 0;
  }

  Future<void> _showRefundEditor(
    Map<String, dynamic> order,
  ) async {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      return;
    }

    final double orderAmount =
        _parseMoney(order['amount']);

    double refundAmount =
        _parseMoney(order['refundAmount']);

    if (refundAmount <= 0) {
      refundAmount = orderAmount;
    }

    String refundStatus =
        _refundText(
      order,
      'refundStatus',
    );

    if (refundStatus.isEmpty ||
        refundStatus == 'Not Required') {
      refundStatus = 'Pending';
    }

    String refundMethod =
        _refundText(
      order,
      'refundMethod',
    );

    String refundReference =
        _refundText(
      order,
      'refundReference',
    );

    String refundNote =
        _refundText(
      order,
      'refundNote',
    );

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        BuildContext dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            Future<void> save() async {
              if (saving) {
                return;
              }

              if (refundAmount <= 0) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Refund amount must be greater than 0.',
                    ),
                  ),
                );
                return;
              }

              if (orderAmount > 0 &&
                  refundAmount > orderAmount) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Refund amount cannot be greater than the order total.',
                    ),
                  ),
                );
                return;
              }

              if (refundStatus == 'Refunded' &&
                  refundMethod.trim().isEmpty) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Select the refund payment method.',
                    ),
                  ),
                );
                return;
              }

              if (refundStatus == 'Refunded' &&
                  refundReference.trim().isEmpty) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Transaction / Reference ID is required before marking Refunded.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                final String now =
                    DateTime.now()
                        .toIso8601String();

                final User? adminUser =
                    FirebaseAuth
                        .instance
                        .currentUser;

                final Map<String, dynamic>
                    update =
                    <String, dynamic>{
                  'refundStatus':
                      refundStatus,
                  'refundAmount':
                      refundAmount,
                  'refundMethod':
                      refundMethod.trim(),
                  'refundReference':
                      refundReference.trim(),
                  'refundNote':
                      refundNote.trim(),
                  'refundUpdatedAt':
                      now,
                  'refundProcessedBy':
                      adminUser?.uid ?? '',
                };

                if (refundStatus ==
                    'Processing') {
                  update['refundProcessingAt'] =
                      now;
                }

                if (refundStatus ==
                    'Rejected') {
                  update['refundRejectedAt'] =
                      now;
                }

                if (refundStatus ==
                    'Refunded') {
                  update['refundedAt'] =
                      now;

                  final double paidSellerAmount =
                      _paidSellerSettlementTotal(
                    order,
                  );

                  final String existingAdjustmentStatus =
                      _refundText(
                    order,
                    'sellerAdjustmentStatus',
                  );

                  final String existingResolvedAt =
                      _refundText(
                    order,
                    'sellerAdjustmentResolvedAt',
                  );

                  final bool adjustmentAlreadyResolved =
                      existingAdjustmentStatus == 'Recovered' ||
                          existingAdjustmentStatus ==
                              'Deducted from Next Settlement' ||
                          existingResolvedAt.isNotEmpty;

                  if (paidSellerAmount > 0 &&
                      !adjustmentAlreadyResolved) {
                    update.addAll(
                      <String, dynamic>{
                        'sellerAdjustmentRequired':
                            true,
                        'sellerAdjustmentStatus':
                            'Pending',
                        'sellerAdjustmentAmount':
                            paidSellerAmount,
                        'sellerAdjustmentReason':
                            'Customer refund completed after seller settlement had already been paid.',
                        'sellerAdjustmentCreatedAt':
                            now,
                      },
                    );
                  }

                  final String source =
                      _refundText(
                    order,
                    'refundSource',
                  );

                  if (source == 'Return') {
                    update['status'] =
                        'Returned';
                    update['trackingStatus'] =
                        'Returned';
                    update['trackingEnabled'] =
                        false;
                    update['returnedAt'] =
                        now;
                  }
                }

                await updateOrderTrackingFields(
                  orderId,
                  update,
                );

                if (!mounted ||
                    !dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      refundStatus ==
                              'Refunded'
                          ? 'Refund completed successfully.'
                          : 'Refund status updated to $refundStatus.',
                    ),
                  ),
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not update refund: '
                      '${error.toString().replaceFirst('Exception: ', '')}',
                    ),
                  ),
                );

                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title:
                  const Text(
                'Process Customer Refund',
              ),
              content: SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.82,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Order ID: $orderId',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      'Order Total: Rs. ${orderAmount.toStringAsFixed(0)}',
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextFormField(
                      initialValue:
                          refundAmount
                              .toStringAsFixed(
                                0,
                              ),
                      enabled:
                          !saving,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Refund Amount',
                        prefixText:
                            'Rs. ',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (String value) {
                        refundAmount =
                            double.tryParse(
                                  value
                                      .trim(),
                                ) ??
                                0;
                      },
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    DropdownButtonFormField<
                        String>(
                      isExpanded: true,
                      initialValue:
                          refundStatus,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Refund Status',
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          const <String>[
                        'Pending',
                        'Processing',
                        'Refunded',
                        'Rejected',
                      ].map(
                        (
                          String value,
                        ) {
                          return DropdownMenuItem<
                              String>(
                            value:
                                value,
                            child:
                                Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          saving
                              ? null
                              : (
                                  String?
                                      value,
                                ) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setDialogState(
                                    () {
                                      refundStatus =
                                          value;
                                    },
                                  );
                                },
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          refundMethod
                                  .isEmpty
                              ? null
                              : refundMethod,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Refund Via',
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          const <String>[
                        'Original Payment Method',
                        'eSewa',
                        'Khalti',
                        'Bank Transfer',
                        'Cash',
                        'Other',
                      ].map(
                        (
                          String value,
                        ) {
                          return DropdownMenuItem<
                              String>(
                            value:
                                value,
                            child:
                                Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          saving
                              ? null
                              : (
                                  String?
                                      value,
                                ) {
                                  refundMethod =
                                      value ??
                                          '';
                                },
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextFormField(
                      initialValue:
                          refundReference,
                      enabled:
                          !saving,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Transaction / Reference ID',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (String value) {
                        refundReference =
                            value;
                      },
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextFormField(
                      initialValue:
                          refundNote,
                      enabled:
                          !saving,
                      minLines:
                          2,
                      maxLines:
                          4,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Admin Note (optional)',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (String value) {
                        refundNote =
                            value;
                      },
                    ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      saving
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      saving
                          ? null
                          : save,
                  icon: saving
                      ? const SizedBox(
                          width:
                              18,
                          height:
                              18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .payments_outlined,
                        ),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : 'Save Refund',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _refundCard(
    Map<String, dynamic> order,
  ) {
    final String status =
        _refundText(
      order,
      'refundStatus',
    );

    if (status.isEmpty) {
      return const SizedBox.shrink();
    }

    final String source =
        _refundText(
      order,
      'refundSource',
    );

    final String reason =
        _refundText(
      order,
      'refundReason',
    );

    final String method =
        _refundText(
      order,
      'refundMethod',
    );

    final String reference =
        _refundText(
      order,
      'refundReference',
    );

    final String note =
        _refundText(
      order,
      'refundNote',
    );

    final double amount =
        _parseMoney(
      order['refundAmount'],
    );

    final Color color =
        _refundColor(
      status,
    );

    final bool canProcess =
        status == 'Pending' ||
            status == 'Processing';

    return Card(
      margin:
          EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons
                      .currency_exchange,
                  color:
                      Colors.deepPurple,
                ),
                const SizedBox(
                  width:
                      8,
                ),
                const Expanded(
                  child: Text(
                    'Customer Refund',
                    style:
                        TextStyle(
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
                Chip(
                  label:
                      Text(status),
                  backgroundColor:
                      color.withValues(
                    alpha:
                        0.12,
                  ),
                  side:
                      BorderSide(
                    color:
                        color,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height:
                  8,
            ),
            if (source.isNotEmpty)
              Text(
                'Source: $source',
              ),
            if (reason.isNotEmpty)
              Text(
                'Reason: $reason',
              ),
            if (amount > 0)
              Text(
                'Refund Amount: Rs. ${amount.toStringAsFixed(0)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            if (method.isNotEmpty)
              Text(
                'Refund Via: $method',
              ),
            if (reference.isNotEmpty)
              SelectableText(
                'Transaction / Reference ID: $reference',
              ),
            if (note.isNotEmpty)
              Text(
                'Admin Note: $note',
              ),
            if (canProcess) ...<Widget>[
              const SizedBox(
                height:
                    12,
              ),
              SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      () {
                    _showRefundEditor(
                      order,
                    );
                  },
                  icon:
                      const Icon(
                    Icons
                        .payments_outlined,
                  ),
                  label:
                      const Text(
                    'Process Refund',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _effectiveSellerAdjustmentStatus(
    Map<String, dynamic> order,
  ) {
    final String savedStatus =
        _refundText(
      order,
      'sellerAdjustmentStatus',
    );

    if (savedStatus == 'Recovered' ||
        savedStatus == 'Deducted from Next Settlement') {
      return savedStatus;
    }

    final String resolvedAt =
        _refundText(
      order,
      'sellerAdjustmentResolvedAt',
    );

    if (resolvedAt.isNotEmpty) {
      final String method =
          _refundText(
        order,
        'sellerAdjustmentMethod',
      );

      if (method == 'Deducted from Seller Payout') {
        return 'Deducted from Next Settlement';
      }

      return 'Recovered';
    }

    return savedStatus.isEmpty ? 'Pending' : savedStatus;
  }

  Future<void> _showSellerAdjustmentEditor(
    Map<String, dynamic> order,
  ) async {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      return;
    }

    final double paidSellerAmount =
        _paidSellerSettlementTotal(order);

    final double storedAmount =
        _parseMoney(
      order['sellerAdjustmentAmount'],
    );

    final double adjustmentAmount =
        storedAmount > 0
            ? storedAmount
            : paidSellerAmount;

    String status =
        _effectiveSellerAdjustmentStatus(
      order,
    );

    String method =
        _refundText(
      order,
      'sellerAdjustmentMethod',
    );

    String reference =
        _refundText(
      order,
      'sellerAdjustmentReference',
    );

    String note =
        _refundText(
      order,
      'sellerAdjustmentNote',
    );

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        BuildContext dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            Future<void> save() async {
              if (saving) {
                return;
              }

              if (adjustmentAmount <= 0) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Seller adjustment amount is not available.',
                    ),
                  ),
                );
                return;
              }

              if (status == 'Recovered' &&
                  method.trim().isEmpty) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Select how RD recovered the amount from the seller.',
                    ),
                  ),
                );
                return;
              }

              if (status == 'Recovered' &&
                  reference.trim().isEmpty) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Reference ID is required for a recovered adjustment.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                final String now =
                    DateTime.now()
                        .toIso8601String();

                final User? adminUser =
                    FirebaseAuth
                        .instance
                        .currentUser;

                final bool resolved =
                    status == 'Recovered' ||
                        status ==
                            'Deducted from Next Settlement';

                await updateOrderTrackingFields(
                  orderId,
                  <String, dynamic>{
                    'sellerAdjustmentRequired':
                        !resolved,
                    'sellerAdjustmentStatus':
                        status,
                    'sellerAdjustmentAmount':
                        adjustmentAmount,
                    'sellerAdjustmentMethod':
                        method.trim(),
                    'sellerAdjustmentReference':
                        reference.trim(),
                    'sellerAdjustmentNote':
                        note.trim(),
                    'sellerAdjustmentUpdatedAt':
                        now,
                    'sellerAdjustmentUpdatedBy':
                        adminUser?.uid ?? '',
                    'sellerAdjustmentResolvedAt':
                        resolved ? now : '',
                  },
                );

                if (!mounted ||
                    !dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      status == 'Recovered'
                          ? 'Seller adjustment marked Recovered.'
                          : status ==
                                  'Deducted from Next Settlement'
                              ? 'Seller adjustment marked as deducted from the next settlement.'
                              : 'Seller adjustment kept Pending.',
                    ),
                  ),
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not update seller adjustment: '
                      '${error.toString().replaceFirst('Exception: ', '')}',
                    ),
                  ),
                );

                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                  });
                }
              }
            }

            final double dialogWidth =
                MediaQuery.of(dialogContext).size.width;

            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              title:
                  const Text(
                'Seller Adjustment',
              ),
              content: SizedBox(
                width: dialogWidth < 700
                    ? dialogWidth - 72
                    : 560,
                child:
                    SingleChildScrollView(
                  child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Order ID: $orderId',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      'Adjustment Amount: Rs. '
                      '${adjustmentAmount.toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        color:
                            Colors.red,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    DropdownButtonFormField<
                        String>(
                      isExpanded: true,
                      initialValue:
                          <String>[
                        'Pending',
                        'Recovered',
                        'Deducted from Next Settlement',
                      ].contains(status)
                              ? status
                              : 'Pending',
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Adjustment Status',
                        border:
                            OutlineInputBorder(),
                      ),
                      selectedItemBuilder:
                          (BuildContext context) {
                        return const <String>[
                          'Pending',
                          'Recovered',
                          'Deducted from Next Settlement',
                        ].map<Widget>(
                          (String value) {
                            return Align(
                              alignment:
                                  Alignment.centerLeft,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ).toList();
                      },
                      items:
                          const <String>[
                        'Pending',
                        'Recovered',
                        'Deducted from Next Settlement',
                      ].map(
                        (
                          String value,
                        ) {
                          return DropdownMenuItem<
                              String>(
                            value:
                                value,
                            child:
                                Text(
                              value,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          saving
                              ? null
                              : (
                                  String?
                                      value,
                                ) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setDialogState(
                                    () {
                                      status =
                                          value;
                                    },
                                  );
                                },
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    DropdownButtonFormField<
                        String>(
                      isExpanded: true,
                      initialValue:
                          method.isEmpty
                              ? null
                              : method,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Recovery / Deduction Method',
                        border:
                            OutlineInputBorder(),
                      ),
                      selectedItemBuilder:
                          (BuildContext context) {
                        return const <String>[
                          'eSewa',
                          'Khalti',
                          'Bank Transfer',
                          'Cash',
                          'Deducted from Seller Payout',
                          'Other',
                        ].map<Widget>(
                          (String value) {
                            return Align(
                              alignment:
                                  Alignment.centerLeft,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ).toList();
                      },
                      items:
                          const <String>[
                        'eSewa',
                        'Khalti',
                        'Bank Transfer',
                        'Cash',
                        'Deducted from Seller Payout',
                        'Other',
                      ].map(
                        (
                          String value,
                        ) {
                          return DropdownMenuItem<
                              String>(
                            value:
                                value,
                            child:
                                Text(
                              value,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          saving
                              ? null
                              : (
                                  String?
                                      value,
                                ) {
                                  method =
                                      value ??
                                          '';
                                },
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextFormField(
                      initialValue:
                          reference,
                      enabled:
                          !saving,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Transaction / Reference ID',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (String value) {
                        reference =
                            value;
                      },
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextFormField(
                      initialValue:
                          note,
                      enabled:
                          !saving,
                      minLines:
                          2,
                      maxLines:
                          4,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Admin Note (optional)',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (String value) {
                        note =
                            value;
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      status ==
                              'Deducted from Next Settlement'
                          ? 'Use this status only after the amount has actually been deducted from a later seller payout.'
                          : 'Recovered means RD has actually received the amount back from the seller.',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        color:
                            Colors.grey.shade700,
                      ),
                    ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      saving
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      saving
                          ? null
                          : save,
                  icon: saving
                      ? const SizedBox(
                          width:
                              18,
                          height:
                              18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .check_circle_outline,
                        ),
                  label:
                      Text(
                    saving
                        ? 'Saving...'
                        : 'Save Adjustment',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sellerAdjustmentCard(
    Map<String, dynamic> order,
  ) {
    final double paidSellerAmount =
        _paidSellerSettlementTotal(order);

    final bool storedRequired =
        order['sellerAdjustmentRequired'] == true;

    final bool logicallyRequired =
        paidSellerAmount > 0 &&
            (order['status']?.toString().trim() ==
                    'Cancelled' ||
                order['status']?.toString().trim() ==
                    'Returned' ||
                _refundText(
                      order,
                      'refundStatus',
                    ) ==
                    'Pending' ||
                _refundText(
                      order,
                      'refundStatus',
                    ) ==
                    'Processing' ||
                _refundText(
                      order,
                      'refundStatus',
                    ) ==
                    'Refunded');

    if (!storedRequired &&
        !logicallyRequired) {
      return const SizedBox.shrink();
    }

    final String adjustmentStatus =
        _effectiveSellerAdjustmentStatus(
      order,
    );

    final double storedAmount =
        _parseMoney(
      order['sellerAdjustmentAmount'],
    );

    final double amount =
        storedAmount > 0
            ? storedAmount
            : paidSellerAmount;

    final String reason =
        _refundText(
      order,
      'sellerAdjustmentReason',
    );

    final String method =
        _refundText(
      order,
      'sellerAdjustmentMethod',
    );

    final String reference =
        _refundText(
      order,
      'sellerAdjustmentReference',
    );

    final String note =
        _refundText(
      order,
      'sellerAdjustmentNote',
    );

    final bool adjustmentResolved =
        adjustmentStatus == 'Recovered' ||
            adjustmentStatus ==
                'Deducted from Next Settlement';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  adjustmentResolved
                      ? Icons.check_circle_outline
                      : Icons.sync_problem_outlined,
                  color: adjustmentResolved
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(
                  width:
                      8,
                ),
                Expanded(
                  child: Text(
                    adjustmentResolved
                        ? 'Seller Adjustment Resolved'
                        : 'Seller Adjustment Required',
                    style:
                        const TextStyle(
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              adjustmentResolved
                  ? 'Seller adjustment has already been completed.'
                  : 'Seller was already paid before this cancellation / return.',
              style:
                  TextStyle(
                color: adjustmentResolved
                    ? Colors.green
                    : Colors.red,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            if (amount > 0)
              Text(
                'Amount to recover / deduct: Rs. '
                '${amount.toStringAsFixed(0)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            Text(
              'Adjustment Status: '
              '${adjustmentStatus.isEmpty ? 'Pending' : adjustmentStatus}',
            ),
            if (reason.isNotEmpty)
              Text(
                reason,
                style:
                    TextStyle(
                  fontSize:
                      12,
                  color:
                      Colors.grey.shade700,
                ),
              ),
            if (method.isNotEmpty)
              Text(
                'Method: $method',
              ),
            if (reference.isNotEmpty)
              SelectableText(
                'Reference: $reference',
              ),
            if (note.isNotEmpty)
              Text(
                'Admin Note: $note',
              ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              adjustmentResolved
                  ? 'This seller adjustment has been resolved.'
                  : 'Do not pay this seller settlement again. Recover this amount from the seller or deduct it from a future seller payout.',
              style:
                  const TextStyle(
                fontSize:
                    12,
              ),
            ),
            const SizedBox(
              height:
                  10,
            ),
            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed:
                    () {
                  _showSellerAdjustmentEditor(
                    order,
                  );
                },
                icon:
                    const Icon(
                  Icons
                      .sync_alt_outlined,
                ),
                label:
                    Text(
                  adjustmentResolved
                      ? 'View / Update Adjustment'
                      : 'Process Seller Adjustment',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _refundPendingChip(
    List<Map<String, dynamic>>
        orders,
  ) {
    final bool selected =
        selectedFilter ==
            'Refund Pending';

    return ChoiceChip(
      selected:
          selected,
      onSelected:
          (_) {
        setState(() {
          selectedFilter =
              selected
                  ? 'All'
                  : 'Refund Pending';
        });
      },
      avatar:
          const Icon(
        Icons
            .currency_exchange,
        size:
            18,
        color:
            Colors.orange,
      ),
      label:
          Text(
        'Refund Pending (${_refundPendingCount(orders)})',
      ),
    );
  }

  Widget _statusChip(
    List<Map<String, dynamic>> orders,
    String status,
    IconData icon,
  ) {
    final Color color = _statusColor(status);
    final int count = _countStatus(orders, status);
    final bool selected = selectedFilter == status;

    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        setState(() {
          selectedFilter = selected ? 'All' : status;
        });
      },
      avatar: Icon(icon, size: 18, color: color),
      label: Text('$status ($count)'),
    );
  }

  Future<bool> _hasAdminAccess() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();

    if (!doc.exists) {
      return false;
    }

    final Map<String, dynamic> data =
        doc.data() ?? <String, dynamic>{};
    final String role = data['role']?.toString().trim() ?? '';

    return data['isActive'] == true &&
        (role == 'admin' || role == 'superAdmin');
  }

  Widget _adminLoginRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 72,
              color: Colors.orange,
            ),
            const SizedBox(height: 14),
            const Text(
              'Admin login required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please login with an active RD Online Shop Admin account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminAuthPage(),
                  ),
                );

                if (mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Admin Login'),
            ),
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
          'Order Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (
          BuildContext context,
          AsyncSnapshot<User?> authSnapshot,
        ) {
          final User? user = authSnapshot.data;

          if (user == null || user.isAnonymous) {
            return _adminLoginRequired(context);
          }

          return FutureBuilder<bool>(
            future: _hasAdminAccess(),
            builder: (
              BuildContext context,
              AsyncSnapshot<bool> accessSnapshot,
            ) {
              if (accessSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (accessSnapshot.hasError || accessSnapshot.data != true) {
                return _adminLoginRequired(context);
              }

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: adminOrdersStream(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Could not load all orders.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<Map<String, dynamic>> allOrders =
              snapshot.data ?? <Map<String, dynamic>>[];
          final List<Map<String, dynamic>> orders = _filtered(allOrders);

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (String value) {
                    if (value.trim().isEmpty && submittedSearch.isNotEmpty) {
                      setState(() {
                        submittedSearch = '';
                      });
                    }
                  },
                  onSubmitted: (String value) {
                    setState(() {
                      submittedSearch = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Order ID, Customer or Mobile',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Clear Search',
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          submittedSearch = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    ChoiceChip(
                      selected: selectedFilter == 'All',
                      onSelected: (_) {
                        setState(() => selectedFilter = 'All');
                      },
                      avatar: const Icon(Icons.list_alt, size: 18),
                      label: Text('All (${allOrders.length})'),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Pending', Icons.pending_actions),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Confirmed', Icons.check_circle),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Processing', Icons.sync),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Shipped', Icons.local_shipping),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Delivered', Icons.inventory_2),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Cancelled', Icons.cancel_outlined),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Returned', Icons.assignment_return_outlined),
                    const SizedBox(width: 8),
                    _refundPendingChip(allOrders),
                  ],
                ),
              ),
              _dateFilterBar(),
              const SizedBox(height: 4),
              Expanded(
                child: allOrders.isEmpty
                    ? const Center(child: Text('No Orders Yet'))
                    : orders.isEmpty
                        ? const Center(child: Text('No matching orders'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: orders.length,
                            itemBuilder: (BuildContext context, int index) {
                              final Map<String, dynamic> order = orders[index];
                              final String status =
                                  order['status']?.toString() ?? 'Pending';
                              final Color color = _statusColor(status);
                              final List<String> availableStatuses =
                                  <String>[...orderStatuses];

                              if (!availableStatuses.contains(status)) {
                                availableStatuses.add(status);
                              }

                              final bool closedOrder =
                                  status == 'Cancelled' ||
                                      status == 'Returned';
                              final String customerName =
                                  (order['customerName'] ??
                                          order['name'] ??
                                          'Customer')
                                      .toString();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Order ID: ${order['id'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Customer: $customerName'),
                                      Text('Mobile: ${order['phone'] ?? '-'}'),
                                      SelectableText(
                                        'Customer ID: ${order['customerId'] ?? '-'}',
                                      ),
                                      if (_orderDate(order) != null)
                                        Text(
                                          'Order Date: '
                                          '${_formatDate(_orderDate(order)!)}',
                                        ),
                                      Text('Amount: Rs. ${order['amount'] ?? '0'}'),
                                      Text('Payment: ${order['payment'] ?? '-'}'),
                                      Text(
                                        'Address: ${order['address'] ?? 'Address not available'}',
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: color),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: color.withValues(alpha: 0.08),
                                        ),
                                        child: Text(
                                          'Current Status: $status',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        key: ValueKey<String>(
                                          '${order['id']}_$status',
                                        ),
                                        initialValue:
                                            availableStatuses.contains(status)
                                                ? status
                                                : 'Pending',
                                        decoration: const InputDecoration(
                                          labelText: 'Change Order Status',
                                          border: OutlineInputBorder(),
                                          prefixIcon:
                                              Icon(Icons.local_shipping),
                                        ),
                                        items: availableStatuses
                                            .map(
                                              (String item) =>
                                                  DropdownMenuItem<String>(
                                                value: item,
                                                child: Text(item),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: closedOrder
                                            ? null
                                            : (String? value) {
                                                if (value == null ||
                                                    value == status) {
                                                  return;
                                                }
                                                _changeStatus(
                                                  order['id'].toString(),
                                                  value,
                                                );
                                              },
                                      ),
                                      const SizedBox(height: 10),
                                      _refundCard(
                                        order,
                                      ),
                                      if (_refundText(
                                        order,
                                        'refundStatus',
                                      ).isNotEmpty)
                                        const SizedBox(height: 10),
                                      _sellerAdjustmentCard(
                                        order,
                                      ),
                                      if (_sellerWasAlreadyPaid(
                                            order,
                                          ) &&
                                          (status == 'Cancelled' ||
                                              status == 'Returned' ||
                                              _refundText(
                                                    order,
                                                    'refundStatus',
                                                  ) ==
                                                  'Pending' ||
                                              _refundText(
                                                    order,
                                                    'refundStatus',
                                                  ) ==
                                                  'Processing' ||
                                              _refundText(
                                                    order,
                                                    'refundStatus',
                                                  ) ==
                                                  'Refunded'))
                                        const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            final String refundStatus =
                                                _refundText(
                                              order,
                                              'refundStatus',
                                            );

                                            final bool sellerAlreadyPaid =
                                                _sellerWasAlreadyPaid(
                                              order,
                                            );

                                            if (sellerAlreadyPaid &&
                                                (status == 'Cancelled' ||
                                                    status == 'Returned' ||
                                                    refundStatus == 'Pending' ||
                                                    refundStatus == 'Processing' ||
                                                    refundStatus == 'Refunded')) {
                                              final double paidAmount =
                                                  _paidSellerSettlementTotal(
                                                order,
                                              );

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Seller was already paid Rs. '
                                                    '${paidAmount.toStringAsFixed(0)}. '
                                                    'This amount must be recovered or deducted from a future payout.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            if (status == 'Cancelled' ||
                                                status == 'Returned' ||
                                                refundStatus == 'Pending' ||
                                                refundStatus == 'Processing') {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Seller settlement is on hold while cancellation / return / refund is being handled.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            _openSellerSettlement(
                                              order,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.account_balance_wallet_outlined,
                                          ),
                                          label: Text(
                                            _sellerWasAlreadyPaid(order) &&
                                                    (status == 'Cancelled' ||
                                                        status == 'Returned' ||
                                                        _refundText(
                                                              order,
                                                              'refundStatus',
                                                            ) ==
                                                            'Pending' ||
                                                        _refundText(
                                                              order,
                                                              'refundStatus',
                                                            ) ==
                                                            'Processing' ||
                                                        _refundText(
                                                              order,
                                                              'refundStatus',
                                                            ) ==
                                                            'Refunded')
                                                ? 'Seller Adjustment Required'
                                                : status == 'Cancelled' ||
                                                        status == 'Returned' ||
                                                        _refundText(
                                                              order,
                                                              'refundStatus',
                                                            ) ==
                                                            'Pending' ||
                                                        _refundText(
                                                              order,
                                                              'refundStatus',
                                                            ) ==
                                                            'Processing'
                                                    ? 'Seller Settlement On Hold'
                                                    : 'Seller Settlement',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              (order['customerId']
                                                              ?.toString()
                                                              .trim() ??
                                                          '')
                                                      .isEmpty
                                                  ? null
                                                  : () {
                                                      _showCustomerDeviceRestoreCode(
                                                        order,
                                                      );
                                                    },
                                          icon: const Icon(
                                            Icons.phonelink_lock_outlined,
                                          ),
                                          label: const Text(
                                            'Generate Device Restore Code',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push<void>(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    OrderDetailsPage(
                                                  order: order,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility),
                                          label:
                                              const Text('View Order Details'),
                                        ),
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
              );
            },
          );
        },
      ),
    );
  }
}
