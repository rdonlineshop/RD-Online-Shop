import 'package:flutter/material.dart';

import 'ride_request_page.dart';
import 'services/ride_driver_service.dart';

class NearbyDriversPage extends StatelessWidget {
  const NearbyDriversPage({
    required this.vehicleType,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.routeDistanceKm,
    required this.routeDurationMinutes,
    required this.estimatedFare,
    required this.fareCurrency,
    required this.fareUsesRoadRoute,
    super.key,
  });

  final String vehicleType;

  final double pickupLatitude;
  final double pickupLongitude;

  final double destinationLatitude;
  final double destinationLongitude;

  final String pickupAddress;
  final String destinationAddress;

  final double routeDistanceKm;
  final int routeDurationMinutes;
  final double estimatedFare;
  final String fareCurrency;
  final bool fareUsesRoadRoute;

  @override
  Widget build(BuildContext context) {
    final RideDriverService driverService = RideDriverService();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          'Nearby $vehicleType Drivers',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
            ),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _selectedVehicleCard(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _tripCard(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    10,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _sectionHeader(),
                  ),
                ),
                StreamBuilder<List<RideDriverNearby>>(
                  stream: driverService.nearbyDriversStream(
                    vehicleType: vehicleType,
                    pickupLatitude: pickupLatitude,
                    pickupLongitude: pickupLongitude,
                    radiusKm: 10,
                  ),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<RideDriverNearby>>
                        snapshot,
                  ) {
                    if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _errorCard(
                            snapshot.error.toString(),
                          ),
                        ),
                      );
                    }

                    final List<RideDriverNearby> drivers =
                        snapshot.data ??
                            <RideDriverNearby>[];

                    if (drivers.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            24,
                          ),
                          child: _emptyCard(),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24,
                      ),
                      sliver: SliverList.separated(
                        itemCount: drivers.length,
                        separatorBuilder: (
                          BuildContext context,
                          int index,
                        ) =>
                            const SizedBox(height: 10),
                        itemBuilder: (
                          BuildContext context,
                          int index,
                        ) {
                          return _driverCard(
                            context,
                            drivers[index],
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedVehicleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0D47A1),
            Color(0xFF1976D2),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Searching only',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$vehicleType drivers',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Online • Active • Within 10 km',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.filter_alt_rounded,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _tripCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Trip',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _locationRow(
              icon: Icons.my_location_rounded,
              label: 'Pickup',
              value: pickupAddress,
            ),
            const Divider(height: 24),
            _locationRow(
              icon: Icons.location_on_rounded,
              label: 'Destination',
              value: destinationAddress,
            ),
            const Divider(height: 24),
            _tripInfoRow(
              icon: Icons.route_rounded,
              label: 'Distance',
              value:
                  '${routeDistanceKm.toStringAsFixed(1)} km${fareUsesRoadRoute ? '' : ' approx.'}',
            ),
            const Divider(height: 22),
            _tripInfoRow(
              icon: Icons.timer_outlined,
              label: 'Estimated time',
              value: '$routeDurationMinutes min',
            ),
            const Divider(height: 22),
            _tripInfoRow(
              icon: Icons.payments_outlined,
              label: 'Estimated Fare',
              value:
                  '$fareCurrency ${estimatedFare.toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
                value,
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

  Widget _tripInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Available Drivers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Nearest first',
            style: TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const CircleAvatar(
              radius: 40,
              child: Icon(
                Icons.radar_rounded,
                size: 40,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'No nearby $vehicleType driver found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only active and online $vehicleType drivers within 10 km of the pickup location are shown.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String error) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load nearby drivers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverCard(
    BuildContext context,
    RideDriverNearby driver,
  ) {
    final String distance =
        driver.distanceKm < 1
            ? '${(driver.distanceKm * 1000).round()} m'
            : '${driver.distanceKm.toStringAsFixed(1)} km';

    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => RideRequestPage(
                driver: driver,
                pickupAddress: pickupAddress,
                destinationAddress: destinationAddress,
                vehicleType: vehicleType,
                pickupLatitude: pickupLatitude,
                pickupLongitude: pickupLongitude,
                destinationLatitude:
                    destinationLatitude,
                destinationLongitude:
                    destinationLongitude,
                routeDistanceKm: routeDistanceKm,
                routeDurationMinutes: routeDurationMinutes,
                estimatedFare: estimatedFare,
                fareCurrency: fareCurrency,
                fareUsesRoadRoute: fareUsesRoadRoute,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              _driverAvatar(driver),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            driver.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green
                                .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: <Widget>[
                        _miniInfo(
                          Icons.directions_car_rounded,
                          driver.vehicleType,
                        ),
                        if (driver.vehicleNumber.isNotEmpty)
                          _miniInfo(
                            Icons.badge_outlined,
                            driver.vehicleNumber,
                          ),
                        _miniInfo(
                          Icons.near_me_rounded,
                          distance,
                        ),
                        if (driver.rating > 0)
                          _miniInfo(
                            Icons.star_rounded,
                            driver.rating
                                .toStringAsFixed(1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driverAvatar(
    RideDriverNearby driver,
  ) {
    final String photoUrl = driver.photoUrl.trim();

    if (photoUrl.isEmpty) {
      return const CircleAvatar(
        radius: 28,
        child: Icon(
          Icons.person_rounded,
          size: 30,
        ),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: NetworkImage(photoUrl),
      onBackgroundImageError: (
        Object error,
        StackTrace? stackTrace,
      ) {},
    );
  }

  Widget _miniInfo(
    IconData icon,
    String text,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 15,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
