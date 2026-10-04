import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'property_partner_auth_page.dart';

class PropertyMarketplacePage extends StatefulWidget {
  const PropertyMarketplacePage({super.key});

  @override
  State<PropertyMarketplacePage> createState() =>
      _PropertyMarketplacePageState();
}

class _PropertyMarketplacePageState extends State<PropertyMarketplacePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedGroup = 'All';
  String _selectedSubcategory = 'All';

  static const List<_PropertyCategory> _saleCategories = <_PropertyCategory>[
    _PropertyCategory(
      title: 'All Sale',
      icon: Icons.grid_view_rounded,
    ),
    _PropertyCategory(
      title: 'House Sale',
      icon: Icons.home_rounded,
      assetPath: 'assets/property/house_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Land Sale',
      icon: Icons.landscape_rounded,
      assetPath: 'assets/property/land_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Plot Sale',
      icon: Icons.crop_square_rounded,
      assetPath: 'assets/property/plot_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Apartment Sale',
      icon: Icons.apartment_rounded,
      assetPath: 'assets/property/apartment_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Flat Sale',
      icon: Icons.location_city_rounded,
      assetPath: 'assets/property/flat_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Villa / Bungalow Sale',
      icon: Icons.villa_rounded,
      assetPath: 'assets/property/villa_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Commercial Building Sale',
      icon: Icons.business_rounded,
      assetPath: 'assets/property/commercial_building_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Commercial Land Sale',
      icon: Icons.map_rounded,
      assetPath: 'assets/property/commercial_land_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Office Sale',
      icon: Icons.corporate_fare_rounded,
      assetPath: 'assets/property/office_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Shop / Shutter Sale',
      icon: Icons.storefront_rounded,
      assetPath: 'assets/property/shop_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Warehouse / Godown Sale',
      icon: Icons.warehouse_rounded,
      assetPath: 'assets/property/warehouse_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Hotel / Resort Sale',
      icon: Icons.hotel_rounded,
      assetPath: 'assets/property/hotel_resort_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Restaurant Space Sale',
      icon: Icons.restaurant_rounded,
      assetPath: 'assets/property/restaurant_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Agricultural Land Sale',
      icon: Icons.agriculture_rounded,
      assetPath: 'assets/property/agricultural_land_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Industrial Property Sale',
      icon: Icons.factory_rounded,
      assetPath: 'assets/property/industrial_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Farmhouse Sale',
      icon: Icons.cottage_rounded,
      assetPath: 'assets/property/farmhouse_sale.jpg',
    ),
    _PropertyCategory(
      title: 'Other Property Sale',
      icon: Icons.real_estate_agent_rounded,
      assetPath: 'assets/property/other_sale.jpg',
    ),
  ];

  static const List<_PropertyCategory> _rentCategories = <_PropertyCategory>[
    _PropertyCategory(
      title: 'All Rent',
      icon: Icons.grid_view_rounded,
    ),
    _PropertyCategory(
      title: 'House Rent',
      icon: Icons.home_work_rounded,
      assetPath: 'assets/property/house_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Apartment Rent',
      icon: Icons.apartment_rounded,
      assetPath: 'assets/property/apartment_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Flat Rent',
      icon: Icons.location_city_rounded,
      assetPath: 'assets/property/flat_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Room Rent',
      icon: Icons.bed_rounded,
      assetPath: 'assets/property/room_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Shop / Shutter Rent',
      icon: Icons.store_rounded,
      assetPath: 'assets/property/shop_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Office Rent',
      icon: Icons.business_center_rounded,
      assetPath: 'assets/property/office_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Commercial Space Rent',
      icon: Icons.domain_rounded,
      assetPath: 'assets/property/commercial_space_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Warehouse / Godown Rent',
      icon: Icons.warehouse_rounded,
      assetPath: 'assets/property/warehouse_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Hostel / PG Rent',
      icon: Icons.bedroom_parent_rounded,
      assetPath: 'assets/property/hostel_pg_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Hotel / Resort Lease',
      icon: Icons.hotel_rounded,
      assetPath: 'assets/property/hotel_resort_lease.jpg',
    ),
    _PropertyCategory(
      title: 'Restaurant Space Rent',
      icon: Icons.restaurant_menu_rounded,
      assetPath: 'assets/property/restaurant_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Land Lease',
      icon: Icons.landscape_rounded,
      assetPath: 'assets/property/land_lease.jpg',
    ),
    _PropertyCategory(
      title: 'Industrial Space Rent',
      icon: Icons.factory_rounded,
      assetPath: 'assets/property/industrial_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Farmhouse Rent',
      icon: Icons.cottage_rounded,
      assetPath: 'assets/property/farmhouse_rent.jpg',
    ),
    _PropertyCategory(
      title: 'Other Property Rent / Lease',
      icon: Icons.real_estate_agent_rounded,
      assetPath: 'assets/property/other_rent.jpg',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  List<_PropertyCategory> get _visibleSubcategories {
    if (_selectedGroup == 'For Sale') {
      return _saleCategories;
    }
    if (_selectedGroup == 'For Rent') {
      return _rentCategories;
    }
    return const <_PropertyCategory>[];
  }

  String get _heading {
    if (_selectedGroup == 'All') {
      return 'All Properties';
    }
    if (_selectedSubcategory == 'All Sale') {
      return 'All Properties for Sale';
    }
    if (_selectedSubcategory == 'All Rent') {
      return 'All Properties for Rent';
    }
    return _selectedSubcategory;
  }

  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
      if (group == 'For Sale') {
        _selectedSubcategory = 'All Sale';
      } else if (group == 'For Rent') {
        _selectedSubcategory = 'All Rent';
      } else {
        _selectedSubcategory = 'All';
      }
    });
  }

  Widget _mainCategoryButton({
    required String title,
    required IconData icon,
  }) {
    final bool selected = _selectedGroup == title;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectGroup(title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFE3DC) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF795548) : const Color(0xFFE4DAD7),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 21,
                color: const Color(0xFF795548),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: const Color(0xFF2A1B18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryImage(_PropertyCategory item) {
    if (item.assetPath != null && item.assetPath!.trim().isNotEmpty) {
      return ClipOval(
        child: Image.asset(
          item.assetPath!,
          width: 62,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return Icon(
              item.icon,
              size: 31,
              color: const Color(0xFF795548),
            );
          },
        ),
      );
    }

    return Icon(
      item.icon,
      size: 31,
      color: const Color(0xFF795548),
    );
  }

  Widget _subcategoryItem(_PropertyCategory item) {
    final bool selected = _selectedSubcategory == item.title;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedSubcategory = item.title;
        });
      },
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFFFFE3DC)
                    : const Color(0xFFF7EBE8),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF795548)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: _categoryImage(item),
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.05,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: const Color(0xFF2A1B18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchArea() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _locationController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Location: Kathmandu, Baneshwor, Lalitpur...',
            prefixIcon: const Icon(Icons.location_on_rounded),
            suffixIcon: IconButton(
              tooltip: 'Clear location',
              onPressed: () {
                _locationController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close_rounded),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search house, land, flat, shop...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Filters',
              onPressed: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Price, bedrooms, area and advanced filters will be connected with live Property listings.',
                      ),
                    ),
                  );
              },
              icon: const Icon(Icons.tune_rounded),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _emptyListings() {
    final String location = _locationController.text.trim();
    final String search = _searchController.text.trim();

    String message = 'No published properties yet.';

    if (_selectedGroup == 'For Sale') {
      message = _selectedSubcategory == 'All Sale'
          ? 'No properties for sale yet.'
          : 'No $_selectedSubcategory listings yet.';
    } else if (_selectedGroup == 'For Rent') {
      message = _selectedSubcategory == 'All Rent'
          ? 'No properties for rent yet.'
          : 'No $_selectedSubcategory listings yet.';
    }

    if (location.isNotEmpty) {
      message += '\nLocation filter: $location';
    }

    if (search.isNotEmpty) {
      message += '\nSearch: $search';
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 42,
        ),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.real_estate_agent_rounded,
              size: 62,
              color: Color(0xFF795548),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Matching published properties will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    _searchController.clear();
    _locationController.clear();
    setState(() {
      _selectedGroup = 'All';
      _selectedSubcategory = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_PropertyCategory> subcategories = _visibleSubcategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
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
                  builder: (_) => const PropertyPartnerAuthPage(),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _searchArea(),
              const SizedBox(height: 18),
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  _mainCategoryButton(
                    title: 'All',
                    icon: Icons.grid_view_rounded,
                  ),
                  const SizedBox(width: 8),
                  _mainCategoryButton(
                    title: 'For Sale',
                    icon: Icons.sell_rounded,
                  ),
                  const SizedBox(width: 8),
                  _mainCategoryButton(
                    title: 'For Rent',
                    icon: Icons.key_rounded,
                  ),
                ],
              ),
              if (subcategories.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                SizedBox(
                  height: 112,
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: <PointerDeviceKind>{
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.invertedStylus,
                      },
                    ),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: subcategories.length,
                      separatorBuilder: (
                        BuildContext context,
                        int index,
                      ) =>
                          const SizedBox(width: 8),
                      itemBuilder: (
                        BuildContext context,
                        int index,
                      ) =>
                          _subcategoryItem(subcategories[index]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _heading,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _emptyListings(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyCategory {
  final String title;
  final IconData icon;
  final String? assetPath;

  const _PropertyCategory({
    required this.title,
    required this.icon,
    this.assetPath,
  });
}