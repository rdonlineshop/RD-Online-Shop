import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ride_customer_tracking_page.dart';

class RideMyRidesPage extends StatelessWidget {
  const RideMyRidesPage({super.key});

  static const Color _rdBlue = Color(0xFF1565C0);

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return int.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  String _status(Map<String, dynamic> data) {
    return data['status']?.toString().trim().toLowerCase() ?? 'pending';
  }

  bool _isActiveStatus(String status) {
    return status == 'pending' ||
        status == 'accepted' ||
        status == 'started' ||
        status == 'in_progress';
  }

  int _statusRank(String status) {
    if (status == 'in_progress' || status == 'started') {
      return 0;
    }
    if (status == 'accepted') {
      return 1;
    }
    if (status == 'pending') {
      return 2;
    }
    if (status == 'completed') {
      return 3;
    }
    if (status == 'cancelled') {
      return 4;
    }
    if (status == 'rejected') {
      return 5;
    }
    return 6;
  }

  int _createdAtMillis(Map<String, dynamic> data) {
    final dynamic value = data['createdAt'];

    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  String _dateText(dynamic value) {
    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate().toLocal();
    } else if (value is DateTime) {
      dateTime = value.toLocal();
    }

    if (dateTime == null) {
      return 'Time pending';
    }

    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/${dateTime.year}  $hour:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'ACCEPTED';
      case 'started':
      case 'in_progress':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'PENDING';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'started':
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _fareLabel(String status) {
    if (status == 'completed') {
      return 'Final Fare';
    }
    if (status == 'started' || status == 'in_progress') {
      return 'Live Fare';
    }
    return 'Estimated Fare';
  }

  double? _shownFare(
    Map<String, dynamic> data,
    String status,
  ) {
    final double? estimatedFare = _toDouble(data['estimatedFare']);
    final double? liveFare = _toDouble(data['liveFare']);
    final double? finalFare = _toDouble(data['finalFare']);

    if (status == 'completed') {
      return finalFare ?? liveFare ?? estimatedFare;
    }

    if (status == 'started' || status == 'in_progress') {
      return liveFare ?? estimatedFare;
    }

    return estimatedFare;
  }

  String _distanceLabel(String status) {
    if (status == 'completed') {
      return 'Final Distance';
    }
    if (status == 'started' || status == 'in_progress') {
      return 'Actual Distance • LIVE';
    }
    return 'Estimated Distance';
  }

  double? _shownDistance(
    Map<String, dynamic> data,
    String status,
  ) {
    final double? routeDistanceKm = _toDouble(data['routeDistanceKm']);
    final double? actualDistanceKm = _toDouble(data['actualDistanceKm']);
    final double? finalDistanceKm = _toDouble(data['finalDistanceKm']);

    if (status == 'completed') {
      return finalDistanceKm ?? actualDistanceKm ?? routeDistanceKm;
    }

    if (status == 'started' || status == 'in_progress') {
      return actualDistanceKm ?? 0.0;
    }

    return routeDistanceKm;
  }

  void _openRide(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> ride,
  ) {
    final Map<String, dynamic> data = ride.data();
    final String requestId =
        data['rideRequestId']?.toString().trim().isNotEmpty == true
            ? data['rideRequestId'].toString().trim()
            : ride.id;
    final String driverId = data['driverId']?.toString().trim() ?? '';

    if (requestId.isEmpty || driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ride tracking information is not available for this ride.',
          ),
        ),
      );
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RideCustomerTrackingPage(
          rideRequestId: requestId,
          driverId: driverId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'My Rides',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: user == null
            ? _message(
                icon: Icons.person_off_outlined,
                title: 'Customer session is not available',
                message:
                    'Open RD Ride from the customer account and try again.',
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ride_requests')
                    .where(
                      'customerAuthUid',
                      isEqualTo: user.uid,
                    )
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return _message(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load your rides',
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
                    final int firstRank = _statusRank(_status(first.data()));
                    final int secondRank = _statusRank(_status(second.data()));

                    if (firstRank != secondRank) {
                      return firstRank.compareTo(secondRank);
                    }

                    return _createdAtMillis(second.data()).compareTo(
                      _createdAtMillis(first.data()),
                    );
                  });

                  if (rides.isEmpty) {
                    return _message(
                      icon: Icons.route_outlined,
                      title: 'No rides yet',
                      message:
                          'Your RD Ride bookings will appear here automatically.',
                    );
                  }

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      activeRides = rides
                          .where(
                            (QueryDocumentSnapshot<Map<String, dynamic>> ride) =>
                                _isActiveStatus(_status(ride.data())),
                          )
                          .toList();
                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      rideHistory = rides
                          .where(
                            (QueryDocumentSnapshot<Map<String, dynamic>> ride) =>
                                !_isActiveStatus(_status(ride.data())),
                          )
                          .toList();

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          _summaryCard(
                            activeCount: activeRides.length,
                            historyCount: rideHistory.length,
                          ),
                          if (activeRides.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 18),
                            _sectionTitle(
                              icon: Icons.radar_rounded,
                              title: 'Current Ride',
                              subtitle:
                                  'Live distance and live fare update automatically.',
                            ),
                            const SizedBox(height: 10),
                            ...activeRides.map(
                              (QueryDocumentSnapshot<Map<String, dynamic>> ride) =>
                                  Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _rideCard(
                                  context: context,
                                  ride: ride,
                                ),
                              ),
                            ),
                          ],
                          if (rideHistory.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 18),
                            _sectionTitle(
                              icon: Icons.history_rounded,
                              title: 'Ride History',
                              subtitle:
                                  'Completed, cancelled and rejected rides.',
                            ),
                            const SizedBox(height: 10),
                            ...rideHistory.map(
                              (QueryDocumentSnapshot<Map<String, dynamic>> ride) =>
                                  Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _rideCard(
                                  context: context,
                                  ride: ride,
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

  Widget _summaryCard({
    required int activeCount,
    required int historyCount,
  }) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(
                Icons.route_rounded,
                color: _rdBlue,
                size: 29,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'RD Ride',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$activeCount current • $historyCount history',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: _rdBlue,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rideCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> ride,
  }) {
    final Map<String, dynamic> data = ride.data();
    final String status = _status(data);
    final Color statusColor = _statusColor(status);

    final String vehicleType =
        data['vehicleType']?.toString().trim().isNotEmpty == true
            ? data['vehicleType'].toString().trim()
            : 'RD Ride';
    final String driverName =
        data['driverName']?.toString().trim().isNotEmpty == true
            ? data['driverName'].toString().trim()
            : 'Ride Driver';
    final String pickup = data['pickupAddress']?.toString().trim() ?? '';
    final String destination =
        data['destinationAddress']?.toString().trim() ?? '';
    final String currency =
        data['currency']?.toString().trim().isNotEmpty == true
            ? data['currency'].toString().trim()
            : 'Rs.';
    final int? estimatedMinutes = _toInt(data['routeDurationMinutes']);
    final double? fare = _shownFare(data, status);
    final double? distance = _shownDistance(data, status);
    final String driverId = data['driverId']?.toString().trim() ?? '';
    final bool canTrack = driverId.isNotEmpty &&
        status != 'cancelled' &&
        status != 'rejected';

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
                    Icons.directions_car_rounded,
                    color: _rdBlue,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        vehicleType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        driverName,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dateText(data['createdAt']),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
            _infoRow(
              icon: Icons.my_location_rounded,
              label: 'Pickup',
              value: pickup,
            ),
            const Divider(height: 22),
            _infoRow(
              icon: Icons.location_on_rounded,
              label: 'Destination',
              value: destination,
            ),
            const Divider(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: _metric(
                    icon: Icons.route_rounded,
                    label: _distanceLabel(status),
                    value: distance == null
                        ? '--'
                        : '${distance.toStringAsFixed(status == 'completed' || status == 'in_progress' || status == 'started' ? 2 : 1)} km',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metric(
                    icon: Icons.payments_outlined,
                    label: _fareLabel(status),
                    value: fare == null
                        ? '--'
                        : '$currency ${fare.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            if (estimatedMinutes != null &&
                status != 'completed' &&
                status != 'cancelled' &&
                status != 'rejected') ...<Widget>[
              const SizedBox(height: 12),
              _metric(
                icon: Icons.timer_outlined,
                label: 'Estimated Time',
                value: '$estimatedMinutes min',
              ),
            ],
            if (canTrack) ...<Widget>[
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _openRide(context, ride),
                  icon: Icon(
                    status == 'completed'
                        ? Icons.receipt_long_rounded
                        : Icons.navigation_rounded,
                  ),
                  label: Text(
                    status == 'completed' ? 'View Ride' : 'Track Ride',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: _rdBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: _rdBlue,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not available' : value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 68,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
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
