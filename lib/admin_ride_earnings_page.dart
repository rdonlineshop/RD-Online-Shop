import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum _RideReportFilter {
  all,
  day,
  week,
  month,
  year,
  custom,
}

class AdminRideEarningsPage extends StatefulWidget {
  const AdminRideEarningsPage({super.key});

  @override
  State<AdminRideEarningsPage> createState() =>
      _AdminRideEarningsPageState();
}

class _AdminRideEarningsPageState
    extends State<AdminRideEarningsPage> {
  static const Color _rdBlue = Color(0xFF1565C0);

  _RideReportFilter _selectedFilter = _RideReportFilter.day;
  DateTimeRange? _customRange;

  double? _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text);
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return null;
  }

  String _currency(Map<String, dynamic> data) {
    final String value =
        data['currency']?.toString().trim() ?? '';
    return value.isEmpty ? 'Rs.' : value;
  }

  double _finalFare(Map<String, dynamic> data) {
    return _number(data['finalFare']) ?? 0.0;
  }

  double _rdCommission(Map<String, dynamic> data) {
    return _number(data['finalRdCommission']) ?? 0.0;
  }

  double _driverPayable(Map<String, dynamic> data) {
    return _number(data['driverNetIncome']) ?? 0.0;
  }

  bool _hasValidFinalSettlement(Map<String, dynamic> data) {
    final double? fare = _number(data['finalFare']);
    final double? commission =
        _number(data['finalRdCommission']);
    final double? driverIncome =
        _number(data['driverNetIncome']);

    if (fare == null ||
        commission == null ||
        driverIncome == null) {
      return false;
    }

    if (fare < 0 || commission < 0 || driverIncome < 0) {
      return false;
    }

    // Final fare must equal RD commission + driver net income.
    if ((fare - (commission + driverIncome)).abs() > 0.05) {
      return false;
    }

    final double? percent =
        _number(data['rdCommissionPercent']);

    if (percent != null) {
      if (percent < 0 || percent > 100) {
        return false;
      }

      final double expectedCommission =
          fare * percent / 100.0;

      // Small tolerance avoids false mismatch from decimal rounding.
      if ((commission - expectedCommission).abs() > 0.05) {
        return false;
      }
    }

    return true;
  }

  double _driverPaid(Map<String, dynamic> data) {
    final String status = data['driverSettlementStatus']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    if (status != 'paid') {
      return 0.0;
    }

    final double? paid =
        _number(data['driverPaidAmount']);

    if (paid == null || paid < 0) {
      return 0.0;
    }

    final double payable = _driverPayable(data);

    if (paid > payable) {
      return payable;
    }

    return paid;
  }

  double _readyToPay(Map<String, dynamic> data) {
    final double remaining =
        _driverPayable(data) - _driverPaid(data);

    return remaining < 0 ? 0.0 : remaining;
  }

  DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _weekStart(DateTime value) {
    final DateTime day = _dayStart(value);
    return day.subtract(
      Duration(days: day.weekday - DateTime.monday),
    );
  }

  bool _matchesPeriod(Map<String, dynamic> data) {
    if (_selectedFilter == _RideReportFilter.all) {
      return true;
    }

    // Period reports use the real trip completion time only.
    final DateTime? completedAt =
        _date(data['tripCompletedAt']);

    if (completedAt == null) {
      return false;
    }

    final DateTime now = DateTime.now();

    switch (_selectedFilter) {
      case _RideReportFilter.all:
        return true;

      case _RideReportFilter.day:
        return completedAt.year == now.year &&
            completedAt.month == now.month &&
            completedAt.day == now.day;

      case _RideReportFilter.week:
        final DateTime start = _weekStart(now);
        final DateTime end =
            start.add(const Duration(days: 7));

        return !completedAt.isBefore(start) &&
            completedAt.isBefore(end);

      case _RideReportFilter.month:
        return completedAt.year == now.year &&
            completedAt.month == now.month;

      case _RideReportFilter.year:
        return completedAt.year == now.year;

      case _RideReportFilter.custom:
        final DateTimeRange? range = _customRange;

        if (range == null) {
          return false;
        }

        final DateTime start = _dayStart(range.start);
        final DateTime end = _dayStart(range.end)
            .add(const Duration(days: 1));

        return !completedAt.isBefore(start) &&
            completedAt.isBefore(end);
    }
  }

  Map<String, double> _sumByCurrency(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> rides,
    double Function(Map<String, dynamic>) amountOf,
  ) {
    final Map<String, double> totals =
        <String, double>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>>
        ride in rides) {
      final Map<String, dynamic> data = ride.data();
      final String currency = _currency(data);
      final double amount = amountOf(data);

      totals[currency] =
          (totals[currency] ?? 0.0) + amount;
    }

    return totals;
  }

  String _money(Map<String, double> totals) {
    if (totals.isEmpty) {
      return 'Rs. 0';
    }

    final List<String> currencies =
        totals.keys.toList()..sort();

    return currencies.map((String currency) {
      final double value = totals[currency] ?? 0.0;
      final bool isWhole = value == value.roundToDouble();

      return '$currency '
          '${isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}';
    }).join('\n');
  }

  String _two(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _dateOnly(DateTime value) {
    return '${_two(value.day)}/'
        '${_two(value.month)}/${value.year}';
  }

  String _dateTimeText(DateTime? value) {
    if (value == null) {
      return 'Completion time not available';
    }

    final int hour24 = value.hour;
    final int hour12 = hour24 == 0
        ? 12
        : (hour24 > 12 ? hour24 - 12 : hour24);
    final String amPm = hour24 >= 12 ? 'PM' : 'AM';

    return '${_dateOnly(value)} • '
        '${_two(hour12)}:${_two(value.minute)} $amPm';
  }

  String _reportHeading() {
    final DateTime now = DateTime.now();

    switch (_selectedFilter) {
      case _RideReportFilter.all:
        return 'All Time';

      case _RideReportFilter.day:
        return 'Today - ${_dateOnly(now)}';

      case _RideReportFilter.week:
        final DateTime start = _weekStart(now);
        final DateTime end =
            start.add(const Duration(days: 6));

        return 'This Week - '
            '${_dateOnly(start)} to ${_dateOnly(end)}';

      case _RideReportFilter.month:
        return 'This Month - '
            '${_two(now.month)}/${now.year}';

      case _RideReportFilter.year:
        return 'This Year - ${now.year}';

      case _RideReportFilter.custom:
        final DateTimeRange? range = _customRange;

        if (range == null) {
          return 'Custom Date Range';
        }

        return 'Custom - '
            '${_dateOnly(range.start)} to '
            '${_dateOnly(range.end)}';
    }
  }

  Future<void> _selectFilter(
    _RideReportFilter filter,
  ) async {
    if (filter != _RideReportFilter.custom) {
      setState(() {
        _selectedFilter = filter;
      });
      return;
    }

    final DateTime now = DateTime.now();

    final DateTimeRange? selected =
        await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: _dayStart(now),
            end: _dayStart(now),
          ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _customRange = selected;
      _selectedFilter = _RideReportFilter.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F5),
      appBar: AppBar(
        title: const Text(
          'RD Ride Earnings & Commission',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('ride_requests')
            .where('status', isEqualTo: 'completed')
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
            return _message(
              icon: Icons.error_outline_rounded,
              title: 'Could not load ride earnings',
              message: snapshot.error.toString(),
            );
          }

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              allCompletedRides =
              <QueryDocumentSnapshot<
                  Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ];

          allCompletedRides.sort(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  first,
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  second,
            ) {
              final DateTime? firstTime =
                  _date(first.data()['tripCompletedAt']);
              final DateTime? secondTime =
                  _date(second.data()['tripCompletedAt']);

              return (secondTime
                          ?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                firstTime?.millisecondsSinceEpoch ?? 0,
              );
            },
          );

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              periodRides = allCompletedRides
                  .where(
                    (QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        ride) =>
                        _matchesPeriod(ride.data()),
                  )
                  .toList();

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              validMoneyRides = periodRides
                  .where(
                    (QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        ride) =>
                        _hasValidFinalSettlement(
                      ride.data(),
                    ),
                  )
                  .toList();

          final int invalidMoneyRideCount =
              periodRides.length -
                  validMoneyRides.length;

          final int missingCompletionTimeCount =
              _selectedFilter ==
                      _RideReportFilter.all
                  ? allCompletedRides
                      .where(
                        (QueryDocumentSnapshot<
                                Map<String, dynamic>>
                            ride) =>
                            _date(
                              ride.data()[
                                  'tripCompletedAt'],
                            ) ==
                            null,
                      )
                      .length
                  : 0;

          final Map<String, double> gross =
              _sumByCurrency(
            validMoneyRides,
            _finalFare,
          );

          final Map<String, double> commission =
              _sumByCurrency(
            validMoneyRides,
            _rdCommission,
          );

          final Map<String, double> payable =
              _sumByCurrency(
            validMoneyRides,
            _driverPayable,
          );

          final Map<String, double> paid =
              _sumByCurrency(
            validMoneyRides,
            _driverPaid,
          );

          final Map<String, double> ready =
              _sumByCurrency(
            validMoneyRides,
            _readyToPay,
          );

          return Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 1100),
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const Text(
                    'Report Filter',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _filterChip(
                          'All',
                          _RideReportFilter.all,
                        ),
                        _filterChip(
                          'Day',
                          _RideReportFilter.day,
                        ),
                        _filterChip(
                          'Week',
                          _RideReportFilter.week,
                        ),
                        _filterChip(
                          'Month',
                          _RideReportFilter.month,
                        ),
                        _filterChip(
                          'Year',
                          _RideReportFilter.year,
                        ),
                        _filterChip(
                          'Custom',
                          _RideReportFilter.custom,
                          icon:
                              Icons.calendar_month_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _reportHeading(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final bool wide =
                          constraints.maxWidth >= 760;

                      final double itemWidth = wide
                          ? (constraints.maxWidth - 24) /
                              3
                          : (constraints.maxWidth - 12) /
                              2;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          SizedBox(
                            width: itemWidth,
                            child: _summaryCard(
                              icon: Icons
                                  .shopping_bag_outlined,
                              title:
                                  'Settlement Gross',
                              value: _money(gross),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _summaryCard(
                              icon:
                                  Icons.percent_rounded,
                              title: 'RD Commission',
                              value:
                                  _money(commission),
                              emphasize: true,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _summaryCard(
                              icon: Icons
                                  .account_balance_wallet_outlined,
                              title:
                                  'Driver Payable',
                              value: _money(payable),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _summaryCard(
                              icon: Icons
                                  .payments_outlined,
                              title: 'Driver Paid',
                              value: _money(paid),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _summaryCard(
                              icon:
                                  Icons.schedule_rounded,
                              title: 'Ready to Pay',
                              value: _money(ready),
                              emphasize: true,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _summaryCard(
                              icon: Icons
                                  .directions_car_rounded,
                              title:
                                  'Completed Rides',
                              value: periodRides.length
                                  .toString(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (invalidMoneyRideCount > 0) ...<
                      Widget>[
                    const SizedBox(height: 16),
                    _warningBox(
                      '$invalidMoneyRideCount completed '
                      'ride(s) have missing or mismatched '
                      'final settlement data. They are not '
                      'included in money totals.',
                    ),
                  ],
                  if (missingCompletionTimeCount > 0) ...<
                      Widget>[
                    const SizedBox(height: 10),
                    _warningBox(
                      '$missingCompletionTimeCount completed '
                      'ride(s) have no tripCompletedAt time. '
                      'They can appear in All, but Day/Week/'
                      'Month/Year reports exclude them.',
                    ),
                  ],
                  const SizedBox(height: 26),
                  const Text(
                    'Commission & Settlement History',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Money totals use saved final ride '
                    'values only. Estimated fare is never '
                    'included.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (periodRides.isEmpty)
                    _message(
                      icon:
                          Icons.receipt_long_outlined,
                      title:
                          'No completed rides in this period',
                      message:
                          'Choose another report filter.',
                    )
                  else
                    ...periodRides.map(
                      (
                        QueryDocumentSnapshot<
                                Map<String, dynamic>>
                            ride,
                      ) =>
                          Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: _historyCard(ride),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(
    String label,
    _RideReportFilter filter, {
    IconData? icon,
  }) {
    final bool selected =
        _selectedFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: true,
        avatar: icon == null
            ? null
            : Icon(icon, size: 19),
        label: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        onSelected: (_) => _selectFilter(filter),
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    bool emphasize = false,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 20,
        ),
        child: Column(
          children: <Widget>[
            Icon(
              icon,
              size: 40,
              color: emphasize ? _rdBlue : null,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: emphasize ? _rdBlue : null,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(
    QueryDocumentSnapshot<Map<String, dynamic>> ride,
  ) {
    final Map<String, dynamic> data = ride.data();

    final String rideId =
        data['rideRequestId']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? data['rideRequestId'].toString().trim()
            : ride.id;

    final String driverName =
        data['driverName']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? data['driverName'].toString().trim()
            : 'Ride Driver';

    final String vehicleType =
        data['vehicleType']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? data['vehicleType'].toString().trim()
            : 'RD Ride';

    final String vehicleNumber =
        data['vehicleNumber']?.toString().trim() ?? '';

    final String currency = _currency(data);

    final double fare = _finalFare(data);
    final double commission = _rdCommission(data);
    final double payable = _driverPayable(data);
    final double paid = _driverPaid(data);
    final double ready = _readyToPay(data);
    final double percent =
        _number(data['rdCommissionPercent']) ?? 0.0;

    final DateTime? completedAt =
        _date(data['tripCompletedAt']);

    final bool valid =
        _hasValidFinalSettlement(data);

    final String settlementStatus =
        data['driverSettlementStatus']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        vehicleNumber.isEmpty
                            ? vehicleType
                            : '$vehicleType • '
                                '$vehicleNumber',
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dateTimeText(completedAt),
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!valid) ...<Widget>[
              const SizedBox(height: 12),
              _warningBox(
                'Settlement data incomplete or '
                'mismatched. This ride is excluded '
                'from money totals.',
              ),
            ],
            const Divider(height: 24),
            _detailRow('Ride ID', rideId),
            _detailRow(
              'Final Fare',
              '$currency ${fare.toStringAsFixed(2)}',
            ),
            _detailRow(
              'RD Commission',
              '$currency '
              '${commission.toStringAsFixed(2)} • '
              '${percent.toStringAsFixed(1)}%',
              emphasize: true,
            ),
            _detailRow(
              'Driver Payable',
              '$currency '
              '${payable.toStringAsFixed(2)}',
            ),
            _detailRow(
              'Driver Paid',
              '$currency ${paid.toStringAsFixed(2)}',
            ),
            _detailRow(
              'Ready to Pay',
              '$currency ${ready.toStringAsFixed(2)}',
              emphasize: true,
            ),
            _detailRow(
              'Settlement Status',
              settlementStatus == 'paid'
                  ? 'PAID'
                  : 'NOT PAID',
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 145,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color:
                    emphasize ? _rdBlue : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              Colors.orange.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.deepOrange,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            size: 58,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
