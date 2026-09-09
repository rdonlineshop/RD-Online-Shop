import 'package:flutter/material.dart';

import 'bus_operator_auth_page.dart';
import 'bus_ticket_booking_page.dart';
import 'flight_ticket_booking_page.dart';

class TicketBookingHubPage extends StatelessWidget {
  const TicketBookingHubPage({super.key});

  static const List<BookingService> _services = <BookingService>[
    BookingService(
      keyName: 'flight',
      title: 'Flight Ticket',
      subtitle: 'Domestic and international flight booking',
      icon: Icons.flight_takeoff_rounded,
    ),
    BookingService(
      keyName: 'bus',
      title: 'Bus Ticket',
      subtitle: 'Bus seat and route ticket booking',
      icon: Icons.directions_bus_rounded,
    ),
    BookingService(
      keyName: 'micro_hiace',
      title: 'Micro / Hiace Ticket',
      subtitle: 'Micro and Hiace seat ticket booking',
      icon: Icons.airport_shuttle_rounded,
    ),
    BookingService(
      keyName: 'cable_car',
      title: 'Cable Car Ticket',
      subtitle: 'Cable car ticket booking',
      icon: Icons.cable_rounded,
    ),
    BookingService(
      keyName: 'movie_show',
      title: 'Movie / Show Ticket',
      subtitle: 'Cinema, movie and entertainment show tickets',
      icon: Icons.local_movies_rounded,
    ),
    BookingService(
      keyName: 'event_concert',
      title: 'Event / Concert Ticket',
      subtitle: 'Concert, music, sports and public event tickets',
      icon: Icons.event_available_rounded,
    ),
    BookingService(
      keyName: 'mahasabha_mahotsav',
      title: 'Mahasabha / Mahotsav Ticket',
      subtitle: 'Mahasabha, mahotsav and special program tickets',
      icon: Icons.confirmation_number_rounded,
    ),
  ];

  void _openService(
    BuildContext context,
    BookingService service,
  ) {
    if (service.keyName == 'flight') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const FlightTicketBookingPage(),
        ),
      );
      return;
    }

    if (service.keyName == 'bus') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const BusTicketBookingPage(),
        ),
      );
      return;
    }

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
        actions: <Widget>[
          IconButton(
            tooltip: 'Bus Operator Login',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const BusOperatorAuthPage(),
              ),
            ),
            icon: const Icon(
              Icons.directions_bus_filled_rounded,
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
              columns = 4;
            } else if (width >= 760) {
              columns = 3;
            }

            final double aspectRatio = width < 430
                ? 0.88
                : width < 760
                    ? 0.98
                    : 1.12;

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
                      'Tickets',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose the ticket service you want to book.',
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
                        childAspectRatio: aspectRatio,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'RD Tickets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Flight, bus, micro/hiace, cable car, movie, event and mahotsav tickets in one place.',
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
          constraints: const BoxConstraints(maxWidth: 700),
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
                    const Text(
                      'This ticket type is prepared in the hub. '
                      'Its complete booking workflow will be added next.',
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
          padding: const EdgeInsets.all(11),
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
              const SizedBox(height: 9),
              Text(
                service.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Flexible(
                child: Text(
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
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String keyName;
  final String title;
  final String subtitle;
  final IconData icon;
}
