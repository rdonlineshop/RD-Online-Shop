import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRideHistoryPage extends StatefulWidget {
  const AdminRideHistoryPage({super.key});

  @override
  State<AdminRideHistoryPage> createState() => _AdminRideHistoryPageState();
}

class _AdminRideHistoryPageState extends State<AdminRideHistoryPage> {
  static const Color _rdBlue = Color(0xFF1565C0);

  String _filter = 'all';

  String _text(Map<String, dynamic> data, String key, [String fallback = '']) {
    final String value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().trim() ?? '');
  }

  int _createdAtMillis(Map<String, dynamic> data) {
    final dynamic value = data['createdAt'];
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    return 0;
  }

  String _dateText(dynamic value) {
    if (value is! Timestamp) {
      return '--';
    }

    final DateTime date = value.toDate().toLocal();
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  String _status(Map<String, dynamic> data) {
    return _text(data, 'status', 'pending').toLowerCase();
  }

  bool _matchesFilter(String status) {
    switch (_filter) {
      case 'cancelled':
        return status == 'cancelled';
      case 'completed':
        return status == 'completed';
      case 'active':
        return status == 'pending' ||
            status == 'accepted' ||
            status == 'arrived' ||
            status == 'started' ||
            status == 'in_progress';
      case 'all':
      default:
        return true;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'accepted':
        return Colors.teal;
      case 'arrived':
        return Colors.deepOrange;
      case 'started':
      case 'in_progress':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
      case 'started':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      case 'rejected':
        return 'REJECTED';
      case 'accepted':
        return 'ACCEPTED';
      case 'arrived':
        return 'ARRIVED';
      case 'pending':
      default:
        return 'PENDING';
    }
  }

  String _cancelledBy(Map<String, dynamic> data) {
    final String raw = _text(data, 'cancelledBy').toLowerCase();
    if (raw == 'customer') return 'Customer';
    if (raw == 'driver') return 'Driver';
    if (raw == 'admin') return 'Admin';
    return raw.isEmpty ? 'Not available' : raw;
  }

  String _fareText(Map<String, dynamic> data, String status) {
    final String currency = _text(data, 'currency', 'Rs.');
    final double? estimatedFare = _toDouble(data['estimatedFare']);
    final double? liveFare = _toDouble(data['liveFare']);
    final double? finalFare = _toDouble(data['finalFare']);

    final double? shownFare = status == 'completed'
        ? finalFare ?? liveFare ?? estimatedFare
        : (status == 'in_progress' || status == 'started')
            ? liveFare ?? estimatedFare
            : estimatedFare;

    return shownFare == null
        ? '--'
        : '$currency ${shownFare.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Ride History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ride_requests')
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _message(
                icon: Icons.error_outline_rounded,
                title: 'Could not load rides',
                message: snapshot.error.toString(),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> rides =
                <QueryDocumentSnapshot<Map<String, dynamic>>>[
              ...?snapshot.data?.docs,
            ];

            rides.sort((
              QueryDocumentSnapshot<Map<String, dynamic>> first,
              QueryDocumentSnapshot<Map<String, dynamic>> second,
            ) {
              return _createdAtMillis(second.data()).compareTo(
                _createdAtMillis(first.data()),
              );
            });

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered =
                rides.where((ride) => _matchesFilter(_status(ride.data()))).toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _filterCard(rides),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      _messageCard(
                        icon: Icons.route_outlined,
                        title: 'No rides found',
                        message: 'There are no rides in this filter yet.',
                      )
                    else
                      ...filtered.map(
                        (QueryDocumentSnapshot<Map<String, dynamic>> ride) =>
                            Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _rideCard(ride),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filterCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rides,
  ) {
    int cancelled = 0;
    int completed = 0;
    int active = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> ride in rides) {
      final String status = _status(ride.data());
      if (status == 'cancelled') cancelled++;
      if (status == 'completed') completed++;
      if (status == 'pending' ||
          status == 'accepted' ||
          status == 'arrived' ||
          status == 'started' ||
          status == 'in_progress') {
        active++;
      }
    }

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'RD Ride Monitoring',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${rides.length} total • $active active • $completed completed • $cancelled cancelled',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _filter,
              decoration: const InputDecoration(
                labelText: 'Filter rides',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_alt_outlined),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'all', child: Text('All rides')),
                DropdownMenuItem(value: 'active', child: Text('Active rides')),
                DropdownMenuItem(
                  value: 'cancelled',
                  child: Text('Cancelled rides'),
                ),
                DropdownMenuItem(
                  value: 'completed',
                  child: Text('Completed rides'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null) return;
                setState(() => _filter = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rideCard(
    QueryDocumentSnapshot<Map<String, dynamic>> ride,
  ) {
    final Map<String, dynamic> data = ride.data();
    final String status = _status(data);
    final Color statusColor = _statusColor(status);
    final String customerName = _text(data, 'customerName', 'Customer');
    final String customerPhone = _text(data, 'customerPhone', '--');
    final String driverName = _text(data, 'driverName', 'Ride Driver');
    final String driverPhone = _text(data, 'driverPhone', '--');
    final String vehicleType = _text(data, 'vehicleType', 'RD Ride');
    final String pickup = _text(data, 'pickupAddress', 'Not available');
    final String destination =
        _text(data, 'destinationAddress', 'Not available');

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: _rdBlue.withValues(alpha: 0.10),
                  child: const Icon(
                    Icons.local_taxi_rounded,
                    color: _rdBlue,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$vehicleType • $driverName',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Customer: $customerName',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_dateText(data['createdAt'])} • ${ride.id}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _detailLine('Customer phone', customerPhone),
            _detailLine('Driver phone', driverPhone),
            _detailLine('Ride fare', _fareText(data, status)),
            const Divider(height: 22),
            _detailLine('Pickup', pickup),
            _detailLine('Destination', destination),
            if (status == 'cancelled') ...<Widget>[
              const SizedBox(height: 8),
              _cancellationCard(data),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cancellationCard(Map<String, dynamic> data) {
    final String reason =
        _text(data, 'cancellationReason', 'Not available');
    final String previousStatus =
        _text(data, 'cancellationPreviousStatus', '--');
    final String currency = _text(
      data,
      'cancellationCurrency',
      _text(data, 'currency', 'Rs.'),
    );
    final double fee = _toDouble(data['cancellationFee']) ?? 0.0;
    final String feeStatus =
        _text(data, 'cancellationFeeStatus', 'not_required');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Cancellation Details',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _detailLine('Cancelled by', _cancelledBy(data)),
          _detailLine('Reason', reason),
          _detailLine('Previous status', previousStatus),
          _detailLine(
            'Cancellation fee',
            fee > 0
                ? '$currency ${fee.toStringAsFixed(0)} • ${feeStatus.toUpperCase()}'
                : 'No cancellation fee',
          ),
          _detailLine('Cancelled at', _dateText(data['cancelledAt'])),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 126,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _messageCard(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: _rdBlue),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
