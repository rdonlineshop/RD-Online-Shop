import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'services/ride_commission_service.dart';

class AdminRideCommissionSettingsPage extends StatefulWidget {
  const AdminRideCommissionSettingsPage({super.key});

  @override
  State<AdminRideCommissionSettingsPage> createState() =>
      _AdminRideCommissionSettingsPageState();
}

class _AdminRideCommissionSettingsPageState
    extends State<AdminRideCommissionSettingsPage> {
  final RideCommissionService _service = RideCommissionService();
  final TextEditingController _percentController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  double _percent = RideCommissionService.fallbackPercent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _percentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final double value = await _service.loadCommissionPercent();
    if (!mounted) {
      return;
    }

    setState(() {
      _percent = value;
      _percentController.text = value.toStringAsFixed(
        value == value.roundToDouble() ? 0 : 2,
      );
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final double? value = double.tryParse(_percentController.text.trim());
    if (value == null ||
        value < 0 ||
        value > RideCommissionService.maximumPercent) {
      _message(
        'Enter a commission between 0 and '
        '${RideCommissionService.maximumPercent.toStringAsFixed(0)}%.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.saveCommissionPercent(value);
      if (!mounted) {
        return;
      }
      setState(() => _percent = value);
      _message('RD Ride commission saved successfully.');
    } catch (error) {
      _message('Could not save commission: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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
    final double sampleFare = 1000;
    final double sampleCommission = sampleFare * _percent / 100;
    final double sampleDriver = sampleFare - sampleCommission;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Commission',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _commissionControlCard(
                          sampleFare: sampleFare,
                          sampleCommission: sampleCommission,
                          sampleDriver: sampleDriver,
                        ),
                        const SizedBox(height: 16),
                        _commissionIncomeSection(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _commissionControlCard({
    required double sampleFare,
    required double sampleCommission,
    required double sampleDriver,
  }) {
    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'RD Ride Commission Control',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The percentage is snapshotted into each new ride. '
                  'Changing it later will not change old ride earnings.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _percentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'RD Commission Percent',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Commission',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Example for Rs. 1,000 ride',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 12),
                _row('Gross Fare', 'Rs. 1,000'),
                _row(
                  'RD Commission (${_percent.toStringAsFixed(1)}%)',
                  'Rs. ${sampleCommission.toStringAsFixed(2)}',
                ),
                const Divider(height: 24),
                _row(
                  'Driver Net Income',
                  'Rs. ${sampleDriver.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _commissionIncomeSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Could not load RD commission income.\n${snapshot.error}',
              ),
            ),
          );
        }

        final List<_CommissionEntry> entries = (snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map(_CommissionEntry.fromDocument)
            .where((_CommissionEntry entry) => entry.completedAt != null)
            .toList()
          ..sort(
            (_CommissionEntry first, _CommissionEntry second) =>
                second.completedAt!.compareTo(first.completedAt!),
          );

        final DateTime now = DateTime.now();
        final DateTime todayStart = DateTime(now.year, now.month, now.day);
        final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));
        final DateTime weekStart = todayStart.subtract(
          Duration(days: now.weekday - DateTime.monday),
        );
        final DateTime nextWeekStart = weekStart.add(const Duration(days: 7));
        final DateTime monthStart = DateTime(now.year, now.month);
        final DateTime nextMonthStart = now.month == 12
            ? DateTime(now.year + 1)
            : DateTime(now.year, now.month + 1);
        final DateTime yearStart = DateTime(now.year);
        final DateTime nextYearStart = DateTime(now.year + 1);

        final _CommissionSummary today = _summaryBetween(
          entries,
          todayStart,
          tomorrowStart,
        );
        final _CommissionSummary week = _summaryBetween(
          entries,
          weekStart,
          nextWeekStart,
        );
        final _CommissionSummary month = _summaryBetween(
          entries,
          monthStart,
          nextMonthStart,
        );
        final _CommissionSummary year = _summaryBetween(
          entries,
          yearStart,
          nextYearStart,
        );
        final _CommissionSummary allTime = _summary(entries);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.account_balance_wallet_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'RD Ride Commission Income',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Every completed ride is counted here regardless of '
                      'Cash, Bank Transfer, or another payment method. '
                      'The commission uses the percentage saved in that ride.',
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (
                        BuildContext context,
                        BoxConstraints constraints,
                      ) {
                        final bool wide = constraints.maxWidth >= 640;
                        final double width = wide
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            _periodCard(
                              width: width,
                              title: 'Today',
                              icon: Icons.today_rounded,
                              summary: today,
                            ),
                            _periodCard(
                              width: width,
                              title: 'This Week',
                              icon: Icons.date_range_rounded,
                              summary: week,
                            ),
                            _periodCard(
                              width: width,
                              title: 'This Month',
                              icon: Icons.calendar_month_rounded,
                              summary: month,
                            ),
                            _periodCard(
                              width: width,
                              title: 'This Year',
                              icon: Icons.calendar_today_rounded,
                              summary: year,
                            ),
                            _periodCard(
                              width: width,
                              title: 'All Time',
                              icon: Icons.all_inclusive_rounded,
                              summary: allTime,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Recent Commission Records',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Completed ride fare, RD commission, driver income and '
                      'payment method record.',
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text('No completed ride commission yet.'),
                        ),
                      )
                    else
                      ...entries.take(30).map(_commissionRecordCard),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _periodCard({
    required double width,
    required String title,
    required IconData icon,
    required _CommissionSummary summary,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _multiCurrencyRow(
              label: 'RD Commission',
              values: summary.commissionByCurrency,
              bold: true,
            ),
            _multiCurrencyRow(
              label: 'Gross Ride Fare',
              values: summary.grossByCurrency,
            ),
            const SizedBox(height: 5),
            Text(
              'Completed Rides: ${summary.rideCount}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _multiCurrencyRow({
    required String label,
    required Map<String, double> values,
    bool bold = false,
  }) {
    final List<MapEntry<String, double>> visible = values.entries
        .where((MapEntry<String, double> entry) => entry.value != 0)
        .toList();

    final List<MapEntry<String, double>> displayValues = visible.isEmpty
        ? <MapEntry<String, double>>[const MapEntry<String, double>('Rs.', 0)]
        : visible;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: displayValues
                .map(
                  (MapEntry<String, double> entry) => Text(
                    '${entry.key} ${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _commissionRecordCard(_CommissionEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  entry.driverName.isEmpty ? 'Ride Driver' : entry.driverName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                _dateText(entry.completedAt),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ride ID: ${entry.rideRequestId}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const Divider(height: 22),
          _row(
            'Gross Fare',
            '${entry.currency} ${entry.grossFare.toStringAsFixed(2)}',
          ),
          _row(
            'RD Commission (${entry.commissionPercent.toStringAsFixed(2)}%)',
            '${entry.currency} ${entry.commission.toStringAsFixed(2)}',
            bold: true,
          ),
          _row(
            'Driver Net Income',
            '${entry.currency} ${entry.driverNetIncome.toStringAsFixed(2)}',
          ),
          _row('Payment Method', entry.paymentMethod),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateText(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  _CommissionSummary _summaryBetween(
    List<_CommissionEntry> entries,
    DateTime start,
    DateTime end,
  ) {
    return _summary(
      entries.where((_CommissionEntry entry) {
        final DateTime? completedAt = entry.completedAt;
        if (completedAt == null) {
          return false;
        }
        final DateTime local = completedAt.toLocal();
        return !local.isBefore(start) && local.isBefore(end);
      }),
    );
  }

  _CommissionSummary _summary(Iterable<_CommissionEntry> entries) {
    final Map<String, double> grossByCurrency = <String, double>{};
    final Map<String, double> commissionByCurrency = <String, double>{};
    int rideCount = 0;

    for (final _CommissionEntry entry in entries) {
      rideCount += 1;
      grossByCurrency.update(
        entry.currency,
        (double value) => value + entry.grossFare,
        ifAbsent: () => entry.grossFare,
      );
      commissionByCurrency.update(
        entry.currency,
        (double value) => value + entry.commission,
        ifAbsent: () => entry.commission,
      );
    }

    return _CommissionSummary(
      grossByCurrency: grossByCurrency,
      commissionByCurrency: commissionByCurrency,
      rideCount: rideCount,
    );
  }
}

class _CommissionSummary {
  const _CommissionSummary({
    required this.grossByCurrency,
    required this.commissionByCurrency,
    required this.rideCount,
  });

  final Map<String, double> grossByCurrency;
  final Map<String, double> commissionByCurrency;
  final int rideCount;
}

class _CommissionEntry {
  const _CommissionEntry({
    required this.rideRequestId,
    required this.driverName,
    required this.currency,
    required this.grossFare,
    required this.commissionPercent,
    required this.commission,
    required this.driverNetIncome,
    required this.paymentMethod,
    required this.completedAt,
  });

  final String rideRequestId;
  final String driverName;
  final String currency;
  final double grossFare;
  final double commissionPercent;
  final double commission;
  final double driverNetIncome;
  final String paymentMethod;
  final DateTime? completedAt;

  factory _CommissionEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final double grossFare = _asDouble(data['finalFare']) ??
        _asDouble(data['liveFare']) ??
        _asDouble(data['estimatedFare']) ??
        0.0;
    final double commissionPercent =
        _asDouble(data['rdCommissionPercent']) ?? 0.0;
    final double commission = _asDouble(data['finalRdCommission']) ??
        (grossFare * commissionPercent / 100.0);
    final double driverNetIncome = _asDouble(data['driverNetIncome']) ??
        (grossFare - commission).clamp(0.0, grossFare).toDouble();

    final String paymentMethod = _firstText(
      <dynamic>[
        data['paymentMethod'],
        data['ridePaymentMethod'],
        data['paymentType'],
      ],
      fallback: 'Not recorded',
    );

    return _CommissionEntry(
      rideRequestId: _firstText(
        <dynamic>[data['rideRequestId'], document.id],
        fallback: document.id,
      ),
      driverName: _firstText(
        <dynamic>[data['driverName']],
        fallback: '',
      ),
      currency: _firstText(
        <dynamic>[data['currency']],
        fallback: 'Rs.',
      ),
      grossFare: grossFare,
      commissionPercent: commissionPercent,
      commission: commission,
      driverNetIncome: driverNetIncome,
      paymentMethod: paymentMethod,
      completedAt: _asDateTime(data['tripCompletedAt']) ??
          _asDateTime(data['updatedAt']) ??
          _asDateTime(data['createdAt']),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static String _firstText(
    List<dynamic> values, {
    required String fallback,
  }) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }
}
