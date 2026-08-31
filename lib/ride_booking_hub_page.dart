import 'package:flutter/material.dart';

import 'ride_booking_page.dart';
import 'ride_driver_auth_page.dart';

class RideBookingHubPage extends StatelessWidget {
  const RideBookingHubPage({super.key});

  static const List<RideCategory> _categories = <RideCategory>[
    RideCategory(
      title: 'Bike',
      subtitle: 'Quick two-wheeler ride',
      icon: Icons.two_wheeler_rounded,
    ),
    RideCategory(
      title: 'Auto',
      subtitle: 'Auto rickshaw / tempo',
      icon: Icons.electric_rickshaw_rounded,
    ),
    RideCategory(
      title: 'Taxi',
      subtitle: 'Nearby taxi service',
      icon: Icons.local_taxi_rounded,
    ),
    RideCategory(
      title: 'Car',
      subtitle: 'Private car ride',
      icon: Icons.directions_car_rounded,
    ),
    RideCategory(
      title: 'Jeep / SUV',
      subtitle: 'Jeep and SUV ride',
      icon: Icons.directions_car_filled_rounded,
    ),
    RideCategory(
      title: 'Van / Hiace',
      subtitle: 'Van and Hiace booking',
      icon: Icons.airport_shuttle_rounded,
    ),
    RideCategory(
      title: 'Microbus',
      subtitle: 'Micro booking',
      icon: Icons.directions_bus_filled_rounded,
    ),
    RideCategory(
      title: 'Mini Bus',
      subtitle: 'Mini bus booking',
      icon: Icons.directions_bus_rounded,
    ),
    RideCategory(
      title: 'Bus',
      subtitle: 'Large bus booking',
      icon: Icons.directions_bus_filled_outlined,
    ),
    RideCategory(
      title: 'Ambulance',
      subtitle: 'Nearby ambulance service',
      icon: Icons.emergency_rounded,
    ),
    RideCategory(
      title: 'Pickup',
      subtitle: 'Pickup / small goods vehicle',
      icon: Icons.local_shipping_outlined,
    ),
    RideCategory(
      title: 'Truck',
      subtitle: 'Goods and cargo transport',
      icon: Icons.local_shipping_rounded,
    ),
    RideCategory(
      title: 'Vehicle Reserve',
      subtitle: 'Reserve by date and time',
      icon: Icons.event_available_rounded,
    ),
  ];

  void _openCategory(
    BuildContext context,
    RideCategory category,
  ) {
    if (category.title == 'Vehicle Reserve') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RideCategoryPage(
            category: category,
          ),
        ),
      );
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RideBookingPage(
          vehicleType: category.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'RD Ride',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Ride Driver',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const RideDriverAuthPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.drive_eta_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final double width = constraints.maxWidth;

            int columns = 2;
            if (width >= 1100) {
              columns = 5;
            } else if (width >= 800) {
              columns = 4;
            } else if (width >= 560) {
              columns = 3;
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1200,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _headerCard(),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 1.2,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const RideDriverAuthPage(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Row(
                            children: <Widget>[
                              CircleAvatar(
                                child: Icon(
                                  Icons
                                      .drive_eta_rounded,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: <Widget>[
                                    Text(
                                      'Ride Driver',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight
                                                .w900,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Driver register, login and ride requests',
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons
                                    .chevron_right_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Choose a service',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select one vehicle type. Later, only nearby matching vehicles will appear on the map.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: _categories.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: width < 420
                            ? 1.15
                            : 1.22,
                      ),
                      itemBuilder: (
                        BuildContext context,
                        int index,
                      ) {
                        final RideCategory category =
                            _categories[index];

                        return _CategoryCard(
                          category: category,
                          onTap: () => _openCategory(
                            context,
                            category,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1565C0),
            Color(0xFF42A5F5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.route_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'RD Ride & Vehicle Booking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ride, emergency, reserve and transport services in one place.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RideCategoryPage extends StatelessWidget {
  const RideCategoryPage({
    required this.category,
    super.key,
  });

  final RideCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          category.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 700,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 38,
                      child: Icon(
                        category.icon,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      category.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Next step: turn on location and show only nearby vehicles from this selected category.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final RideCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 27,
                child: Icon(
                  category.icon,
                  size: 27,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                category.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RideCategory {
  const RideCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
