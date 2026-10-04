import 'package:flutter/material.dart';

import 'property_my_property_page.dart';
import 'property_partner_profile_page.dart';

class PropertyPartnerDashboardPage extends StatelessWidget {
  const PropertyPartnerDashboardPage({super.key});

  static const List<_PartnerMenuItem> _items =
      <_PartnerMenuItem>[
    _PartnerMenuItem(
      title: 'My Property',
      subtitle: 'Add, view, edit, sold/rented, archive and delete',
      icon: Icons.home_work_rounded,
    ),
    _PartnerMenuItem(
      title: 'My Earnings',
      subtitle: 'Earnings, NRD commission, due and payment history',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _PartnerMenuItem(
      title: 'My Profile',
      subtitle: 'Owner, agent or office profile and contact details',
      icon: Icons.person_rounded,
    ),
    _PartnerMenuItem(
      title: 'Verification & Documents',
      subtitle: 'ID, office and property verification status',
      icon: Icons.verified_user_rounded,
    ),
    _PartnerMenuItem(
      title: 'Notifications',
      subtitle: 'Listing, enquiry and commission updates',
      icon: Icons.notifications_active_rounded,
    ),
    _PartnerMenuItem(
      title: 'Help & Support',
      subtitle: 'Property Partner help and NRD support',
      icon: Icons.support_agent_rounded,
    ),
  ];

  void _showComingSoon(
    BuildContext context,
    String title,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be connected in the next Property Partner step.',
        ),
      ),
    );
  }

  Widget _partnerHeader(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0x14795548),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.real_estate_agent_rounded,
                size: 38,
                color: Color(0xFF795548),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Property Partner',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Property Partner ID will be linked to the verified Partner account.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const PropertyPartnerProfilePage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.manage_accounts_rounded,
              ),
              label: const Text('Profile'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Property Partner',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final int columns =
              constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _partnerHeader(context),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    primary: false,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent:
                          columns == 1 ? 190 : null,
                      childAspectRatio:
                          columns == 1 ? 1.0 : 1.35,
                    ),
                    itemBuilder: (
                      BuildContext context,
                      int index,
                    ) {
                      final _PartnerMenuItem item =
                          _items[index];

                      return Card(
                        elevation: 3,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            if (item.title == 'My Property') {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const PropertyMyPropertyPage(),
                                ),
                              );
                              return;
                            }

                            if (item.title == 'My Profile') {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const PropertyPartnerProfilePage(),
                                ),
                              );
                              return;
                            }

                            _showComingSoon(
                              context,
                              item.title,
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration:
                                      const BoxDecoration(
                                    color:
                                        Color(0x14795548),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment:
                                      Alignment.center,
                                  child: Icon(
                                    item.icon,
                                    size: 34,
                                    color: const Color(
                                      0xFF795548,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.title,
                                  textAlign:
                                      TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.subtitle,
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const Card(
                    color: Color(0xFFFFF8E1),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Security rule: a Property Partner will only be able to edit, archive or delete listings that belong to their own Partner ID. Admin will manage all partners and listings separately.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PartnerMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PartnerMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
