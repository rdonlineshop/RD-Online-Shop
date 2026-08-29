import 'package:flutter/material.dart';

class StayVenueBookingHubPage extends StatelessWidget {
  const StayVenueBookingHubPage({super.key});

  static const List<StayVenueCategory> _stayCategories =
      <StayVenueCategory>[
    StayVenueCategory(
      title: 'Hotel',
      subtitle: 'Book hotels by location and date',
      icon: Icons.hotel_rounded,
      type: StayVenueType.stay,
    ),
    StayVenueCategory(
      title: 'Resort',
      subtitle: 'Reserve resorts and holiday stays',
      icon: Icons.holiday_village_rounded,
      type: StayVenueType.stay,
    ),
    StayVenueCategory(
      title: 'Lodge',
      subtitle: 'Book lodges for short or long stays',
      icon: Icons.bed_rounded,
      type: StayVenueType.stay,
    ),
    StayVenueCategory(
      title: 'Guest House',
      subtitle: 'Guest house room booking',
      icon: Icons.house_rounded,
      type: StayVenueType.stay,
    ),
    StayVenueCategory(
      title: 'Homestay',
      subtitle: 'Local homestay booking',
      icon: Icons.home_work_rounded,
      type: StayVenueType.stay,
    ),
    StayVenueCategory(
      title: 'Apartment / Suite',
      subtitle: 'Apartment and suite reservation',
      icon: Icons.apartment_rounded,
      type: StayVenueType.stay,
    ),
  ];

  static const List<StayVenueCategory> _eventCategories =
      <StayVenueCategory>[
    StayVenueCategory(
      title: 'Marriage Hall',
      subtitle: 'Wedding and marriage hall booking',
      icon: Icons.favorite_rounded,
      type: StayVenueType.venue,
    ),
    StayVenueCategory(
      title: 'Party Palace',
      subtitle: 'Party palace booking for events',
      icon: Icons.celebration_rounded,
      type: StayVenueType.venue,
    ),
    StayVenueCategory(
      title: 'Banquet Hall',
      subtitle: 'Banquet hall for weddings and events',
      icon: Icons.table_restaurant_rounded,
      type: StayVenueType.venue,
    ),
    StayVenueCategory(
      title: 'Conference Hall',
      subtitle: 'Conference and meeting venue booking',
      icon: Icons.groups_rounded,
      type: StayVenueType.venue,
    ),
    StayVenueCategory(
      title: 'Event Venue',
      subtitle: 'General event venue reservation',
      icon: Icons.event_available_rounded,
      type: StayVenueType.venue,
    ),
    StayVenueCategory(
      title: 'Picnic Spot',
      subtitle: 'Reserve picnic and outdoor event spaces',
      icon: Icons.park_rounded,
      type: StayVenueType.venue,
    ),
  ];

  void _openCategory(
    BuildContext context,
    StayVenueCategory category,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StayVenueCategoryPage(
          category: category,
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
          'Hotel / Resort',
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
            if (width >= 1150) {
              columns = 5;
            } else if (width >= 850) {
              columns = 4;
            } else if (width >= 600) {
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
                    const SizedBox(height: 20),
                    _section(
                      context: context,
                      title: 'Stay Booking',
                      categories: _stayCategories,
                      columns: columns,
                      width: width,
                    ),
                    const SizedBox(height: 22),
                    _section(
                      context: context,
                      title: 'Marriage & Event Venues',
                      categories: _eventCategories,
                      columns: columns,
                      width: width,
                    ),
                    const SizedBox(height: 24),
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
            Color(0xFF7B1FA2),
            Color(0xFFE91E63),
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
              Icons.hotel_class_rounded,
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
                  'RD Stay & Venue Booking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Hotels, resorts, homestays, marriage halls and event venues in one place.',
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

  Widget _section({
    required BuildContext context,
    required String title,
    required List<StayVenueCategory> categories,
    required int columns,
    required double width,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                width < 420 ? 1.12 : 1.22,
          ),
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final StayVenueCategory category =
                categories[index];

            return StayVenueCategoryCard(
              category: category,
              onTap: () => _openCategory(
                context,
                category,
              ),
            );
          },
        ),
      ],
    );
  }
}

class StayVenueCategoryPage extends StatelessWidget {
  const StayVenueCategoryPage({
    required this.category,
    super.key,
  });

  final StayVenueCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          category.title,
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
                    Text(
                      _nextStepText(category.type),
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
    StayVenueType type,
  ) {
    switch (type) {
      case StayVenueType.stay:
        return 'Next step: location, check-in/check-out date, guests, room type, price, availability, payment and booking confirmation.';
      case StayVenueType.venue:
        return 'Next step: location, event date/time, guest capacity, hall type, price, catering, decoration, parking, availability and booking confirmation.';
    }
  }
}

class StayVenueCategoryCard extends StatelessWidget {
  const StayVenueCategoryCard({
    required this.category,
    required this.onTap,
    super.key,
  });

  final StayVenueCategory category;
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
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

class StayVenueCategory {
  const StayVenueCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final StayVenueType type;
}

enum StayVenueType {
  stay,
  venue,
}
