import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerWalletPage extends StatelessWidget {
  const SellerWalletPage({super.key});

  double _money(dynamic value) {
    if (value is num) return value.toDouble();

    final String cleaned = value
            ?.toString()
            .replaceAll('Rs.', '')
            .replaceAll('Rs', '')
            .replaceAll(',', '')
            .trim() ??
        '';

    return double.tryParse(cleaned) ?? 0;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Map<String, dynamic> _settlementForSeller(
    Map<String, dynamic> order,
    String sellerId,
  ) {
    final dynamic raw = order['sellerSettlements'];

    if (raw is Map && raw[sellerId] is Map) {
      return (raw[sellerId] as Map).map<String, dynamic>(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }

    return <String, dynamic>{};
  }

  double _sellerProductTotal(
    Map<String, dynamic> order,
    String sellerId,
  ) {
    final dynamic rawItems = order['items'];

    if (rawItems is! List) return 0;

    double total = 0;

    for (final dynamic rawItem in rawItems) {
      if (rawItem is! Map) continue;

      final String itemSellerId =
          rawItem['sellerId']?.toString().trim() ?? '';

      if (itemSellerId != sellerId) continue;

      final double price = _money(rawItem['price']);
      final int quantity =
          int.tryParse(rawItem['quantity']?.toString() ?? '1') ?? 1;

      total += price * quantity;
    }

    return total;
  }

  String _dateText(dynamic value) {
    if (value == null) return '';

    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    } else {
      dateTime = DateTime.tryParse(value.toString());
    }

    if (dateTime == null) {
      return value.toString().trim();
    }

    final DateTime local = dateTime.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} $hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Ready to Pay':
        return Colors.blue;
      case 'On Hold':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 20,
              child: Icon(
                icon,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Rs. ${_formatMoney(amount)}',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Wallet'),
        ),
        body: const Center(
          child: Text('Seller login required.'),
        ),
      );
    }

    final String sellerId = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seller Wallet & Earnings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('sellerIds', arrayContains: sellerId)
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Could not load seller wallet.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<Map<String, dynamic>> orders =
              (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .map(
                    (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                        <String, dynamic>{
                      ...doc.data(),
                      'id': doc.data()['id'] ?? doc.id,
                    },
                  )
                  .toList();

          orders.sort(
            (Map<String, dynamic> a, Map<String, dynamic> b) {
              final String aDate =
                  (a['orderDateTime'] ?? a['createdAt'] ?? '').toString();
              final String bDate =
                  (b['orderDateTime'] ?? b['createdAt'] ?? '').toString();
              return bDate.compareTo(aDate);
            },
          );

          double totalSales = 0;
          double pending = 0;
          double readyToPay = 0;
          double totalPaid = 0;

          final List<Map<String, dynamic>> history =
              <Map<String, dynamic>>[];

          for (final Map<String, dynamic> order in orders) {
            final double sellerTotal =
                _sellerProductTotal(order, sellerId);

            totalSales += sellerTotal;

            final Map<String, dynamic> settlement =
                _settlementForSeller(order, sellerId);

            final String status =
                settlement['status']?.toString().trim().isNotEmpty == true
                    ? settlement['status'].toString().trim()
                    : 'Pending';

            final double settlementAmount =
                settlement['amount'] != null
                    ? _money(settlement['amount'])
                    : sellerTotal;

            switch (status) {
              case 'Paid':
                totalPaid += settlementAmount;
                break;
              case 'Ready to Pay':
                readyToPay += settlementAmount;
                break;
              case 'Pending':
              case 'On Hold':
              default:
                pending += settlementAmount;
                break;
            }

            history.add(
              <String, dynamic>{
                'order': order,
                'settlement': settlement,
                'sellerTotal': sellerTotal,
                'status': status,
                'settlementAmount': settlementAmount,
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await FirebaseFirestore.instance
                  .collection('orders')
                  .where('sellerIds', arrayContains: sellerId)
                  .get();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints constraints,
                  ) {
                    final bool wide =
                        constraints.maxWidth >= 700;

                    return GridView(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: wide ? 4 : 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        mainAxisExtent: wide ? 145 : 155,
                      ),
                      children: <Widget>[
                        _summaryCard(
                          title: 'Total Sales',
                          amount: totalSales,
                          icon: Icons.shopping_bag_outlined,
                        ),
                        _summaryCard(
                          title: 'Pending',
                          amount: pending,
                          icon: Icons.schedule,
                        ),
                        _summaryCard(
                          title: 'Ready to Pay',
                          amount: readyToPay,
                          icon: Icons.payments_outlined,
                        ),
                        _summaryCard(
                          title: 'Total Paid',
                          amount: totalPaid,
                          icon:
                              Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Settlement History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No settlement history yet.'),
                    ),
                  )
                else
                  ...history.map<Widget>(
                    (Map<String, dynamic> entry) {
                      final Map<String, dynamic> order =
                          entry['order'] as Map<String, dynamic>;
                      final Map<String, dynamic> settlement =
                          entry['settlement'] as Map<String, dynamic>;

                      final String status = entry['status'].toString();
                      final double amount =
                          entry['settlementAmount'] as double;
                      final double sellerTotal =
                          entry['sellerTotal'] as double;

                      final double grossAmount =
                          settlement['grossAmount'] != null
                              ? _money(settlement['grossAmount'])
                              : sellerTotal;

                      final double commissionPercent =
                          settlement['commissionPercent'] != null
                              ? _money(settlement['commissionPercent'])
                              : 0;

                      final double commissionAmount =
                          settlement['commissionAmount'] != null
                              ? _money(settlement['commissionAmount'])
                              : grossAmount *
                                  commissionPercent /
                                  100;

                      final double sellerPayable =
                          settlement['sellerPayable'] != null
                              ? _money(settlement['sellerPayable'])
                              : grossAmount -
                                  commissionAmount;

                      final Color statusColor = _statusColor(status);

                      final String orderId =
                          order['id']?.toString() ?? '-';
                      final String method =
                          settlement['paymentMethod']?.toString().trim() ?? '';
                      final String reference =
                          settlement['referenceId']?.toString().trim() ?? '';
                      final String note =
                          settlement['note']?.toString().trim() ?? '';
                      final String date = _dateText(
                        settlement['paidAt'] ??
                            settlement['updatedAt'] ??
                            settlement['createdAt'] ??
                            order['orderDateTime'],
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Order ID: $orderId',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: statusColor,
                                      ),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(
                                    alpha: 0.06,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Gross Sale: Rs. ${_formatMoney(grossAmount)}',
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'RD Commission (${_formatMoney(commissionPercent)}%): '
                                      'Rs. ${_formatMoney(commissionAmount)}',
                                      style: const TextStyle(
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Seller Net Payable: Rs. ${_formatMoney(sellerPayable)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Divider(),
                                    Text(
                                      status == 'Paid'
                                          ? 'Paid Amount: Rs. ${_formatMoney(amount)}'
                                          : 'Settlement Amount: Rs. ${_formatMoney(amount)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (method.isNotEmpty)
                                Text('RD Paid Via: $method'),
                              if (reference.isNotEmpty)
                                SelectableText(
                                  'Reference ID: $reference',
                                ),
                              if (date.isNotEmpty)
                                Text('Date: $date'),
                              if (note.isNotEmpty)
                                Text('Admin Note: $note'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
