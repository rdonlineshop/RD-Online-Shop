import 'package:flutter/material.dart';

import 'property_post_page.dart';

class PropertyListingPage extends StatefulWidget {
  final String category;

  const PropertyListingPage({
    super.key,
    required this.category,
  });

  @override
  State<PropertyListingPage> createState() =>
      _PropertyListingPageState();
}

class _PropertyListingPageState
    extends State<PropertyListingPage> {
  final TextEditingController _searchController =
      TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPostProperty() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PropertyPostPage(
          category: widget.category,
        ),
      ),
    );
  }

  void _showFiltersComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Property filters will be connected after the listing data fields are finalized.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop =
        MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          widget.category,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Post Property',
            onPressed: _openPostProperty,
            icon: const Icon(
              Icons.add_business_rounded,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1200,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Material(
                  elevation: 2,
                  borderRadius:
                      BorderRadius.circular(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search ${widget.category.toLowerCase()}...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Filter',
                        onPressed:
                            _showFiltersComingSoon,
                        icon: const Icon(
                          Icons.tune_rounded,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(
                          desktop ? 40 : 24,
                        ),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.real_estate_agent_rounded,
                              size: 64,
                              color: Color(0xFF795548),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              widget.category,
                              textAlign:
                                  TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No listings have been added yet.',
                              textAlign:
                                  TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed:
                                  _openPostProperty,
                              icon: const Icon(
                                Icons.add_rounded,
                              ),
                              label: const Text(
                                'Post Property',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
