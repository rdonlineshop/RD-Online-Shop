import 'package:flutter/material.dart';

import 'property_listing_page.dart';
import 'property_partner_dashboard_page.dart';

class PropertyMarketplacePage extends StatelessWidget {
  const PropertyMarketplacePage({super.key});

  static const List<_PropertyCategory> _saleCategories =
      <_PropertyCategory>[
    _PropertyCategory(
      title: 'House for Sale',
      subtitle: 'Buy residential houses',
      icon: Icons.home_rounded,
    ),
    _PropertyCategory(
      title: 'Land for Sale',
      subtitle: 'Residential and commercial land',
      icon: Icons.landscape_rounded,
    ),
  ];

  static const List<_PropertyCategory> _rentCategories =
      <_PropertyCategory>[
    _PropertyCategory(
      title: 'House for Rent',
      subtitle: 'Find houses for rent',
      icon: Icons.home_work_rounded,
    ),
    _PropertyCategory(
      title: 'Flat / Apartment Rent',
      subtitle: 'Flats and apartments for rent',
      icon: Icons.apartment_rounded,
    ),
    _PropertyCategory(
      title: 'Shop for Rent',
      subtitle: 'Commercial shop spaces',
      icon: Icons.storefront_rounded,
    ),
    _PropertyCategory(
      title: 'Office for Rent',
      subtitle: 'Office and business spaces',
      icon: Icons.business_rounded,
    ),
    _PropertyCategory(
      title: 'Room for Rent',
      subtitle: 'Single and shared rooms',
      icon: Icons.bed_rounded,
    ),
  ];

  static const _PropertyCategory _agentCategory =
      _PropertyCategory(
    title: 'Real Estate Agent',
    subtitle: 'Agents and property dealers',
    icon: Icons.real_estate_agent_rounded,
  );

  void _openCategory(
    BuildContext context,
    _PropertyCategory item,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PropertyListingPage(
          category: item.title,
        ),
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    _PropertyCategory item,
  ) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCategory(
          context,
          item,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF795548)
                      .withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  item.icon,
                  size: 36,
                  color: const Color(0xFF795548),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 10,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0x14795548),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFF795548),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _columnsForWidth(double width) {
    if (width >= 1100) {
      return 4;
    }

    if (width >= 700) {
      return 3;
    }

    return 2;
  }

  Widget _categoryGrid(
    BuildContext context,
    BoxConstraints constraints,
    List<_PropertyCategory> items,
  ) {
    final int columns =
        _columnsForWidth(
      constraints.maxWidth,
    );

    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio:
            constraints.maxWidth >= 700
                ? 1.2
                : 0.95,
      ),
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        return _categoryCard(
          context,
          items[index],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Property & Rent',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Property Partner',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const PropertyPartnerDashboardPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.account_circle_rounded,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1250,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _sectionTitle(
                      'For Sale',
                      'Properties available for purchase',
                      Icons.sell_rounded,
                    ),
                    _categoryGrid(
                      context,
                      constraints,
                      _saleCategories,
                    ),
                    const SizedBox(height: 26),
                    _sectionTitle(
                      'For Rent',
                      'Rental homes, rooms and commercial spaces',
                      Icons.key_rounded,
                    ),
                    _categoryGrid(
                      context,
                      constraints,
                      _rentCategories,
                    ),
                    const SizedBox(height: 26),
                    _sectionTitle(
                      'Real Estate Services',
                      'Find agents and property dealers',
                      Icons
                          .real_estate_agent_rounded,
                    ),
                    SizedBox(
                      height:
                          constraints.maxWidth >= 700
                              ? 190
                              : 210,
                      child: _categoryCard(
                        context,
                        _agentCategory,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PropertyCategory {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PropertyCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
