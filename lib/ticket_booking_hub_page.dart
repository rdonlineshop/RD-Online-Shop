import 'package:flutter/material.dart';

class TicketBookingHubPage extends StatelessWidget {
  const TicketBookingHubPage({super.key});

  static const List<BookingService> _services = <BookingService>[
    BookingService(
      title: 'Flight Ticket',
      subtitle: 'Domestic and international flight booking',
      icon: Icons.flight_takeoff_rounded,
      type: BookingServiceType.ticket,
    ),
    BookingService(
      title: 'Bus Ticket',
      subtitle: 'Bus seat and route ticket booking',
      icon: Icons.directions_bus_rounded,
      type: BookingServiceType.ticket,
    ),
    BookingService(
      title: 'Micro / Hiace Ticket',
      subtitle: 'Micro and Hiace ticket booking',
      icon: Icons.airport_shuttle_rounded,
      type: BookingServiceType.ticket,
    ),
    BookingService(
      title: 'Cable Car Ticket',
      subtitle: 'Cable car ticket booking',
      icon: Icons.cable_rounded,
      type: BookingServiceType.ticket,
    ),
    BookingService(
      title: 'Hotel Booking',
      subtitle: 'Book hotels by date and location',
      icon: Icons.hotel_rounded,
      type: BookingServiceType.stay,
    ),
    BookingService(
      title: 'Resort Booking',
      subtitle: 'Reserve resorts and holiday stays',
      icon: Icons.holiday_village_rounded,
      type: BookingServiceType.stay,
    ),
    BookingService(
      title: 'Guest House / Lodge',
      subtitle: 'Guest house and lodge booking',
      icon: Icons.bed_rounded,
      type: BookingServiceType.stay,
    ),
    BookingService(
      title: 'Tour Package',
      subtitle: 'Tour and travel package booking',
      icon: Icons.travel_explore_rounded,
      type: BookingServiceType.travel,
    ),
  ];

  void _openService(
    BuildContext context,
    BookingService service,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingServicePage(
          service: service,
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
          'Ticket Booking',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
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
              columns = 4;
            } else if (width >= 760) {
              columns = 3;
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1100,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _headerCard(),
                    const SizedBox(height: 20),
                    const Text(
                      'Tickets & Booking',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose ticket, hotel, resort or travel booking service.',
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
                      itemCount: _services.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio:
                            width < 420 ? 1.14 : 1.22,
                      ),
                      itemBuilder: (
                        BuildContext context,
                        int index,
                      ) {
                        final BookingService service =
                            _services[index];

                        return _BookingServiceCard(
                          service: service,
                          onTap: () => _openService(
                            context,
                            service,
                          ),
                        );
                      },
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

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFD81B60),
            Color(0xFFFF7043),
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
              Icons.confirmation_number_rounded,
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
                  'RD Tickets & Booking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Flight, bus, cable car, hotel, resort and travel booking in one place.',
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

class BookingServicePage extends StatelessWidget {
  const BookingServicePage({
    required this.service,
    super.key,
  });

  final BookingService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          service.title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
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
                        service.icon,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      service.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _nextStepText(service.type),
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

  String _nextStepText(
    BookingServiceType type,
  ) {
    switch (type) {
      case BookingServiceType.ticket:
        return 'Next step: route/date/passenger selection, live availability, payment and booking confirmation.';
      case BookingServiceType.stay:
        return 'Next step: location/date/guest selection, room availability, payment and reservation confirmation.';
      case BookingServiceType.travel:
        return 'Next step: destination/date/package selection, availability, payment and booking confirmation.';
    }
  }
}

class _BookingServiceCard extends StatelessWidget {
  const _BookingServiceCard({
    required this.service,
    required this.onTap,
  });

  final BookingService service;
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
                  service.icon,
                  size: 27,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                service.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                service.subtitle,
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

class BookingService {
  const BookingService({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final BookingServiceType type;
}

enum BookingServiceType {
  ticket,
  stay,
  travel,
}
