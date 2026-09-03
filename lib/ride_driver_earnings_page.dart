import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


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
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No completed rides yet. Earnings will appear after a trip is completed.',
                          textAlign: TextAlign.center,
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
