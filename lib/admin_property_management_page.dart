import 'package:flutter/material.dart';

class AdminPropertyManagementPage extends StatelessWidget {
  const AdminPropertyManagementPage({super.key});

  static const List<_AdminPropertyModule> _modules =
      <_AdminPropertyModule>[
    _AdminPropertyModule(
      title: 'Overview',
      subtitle: 'Property & Rent summary',
      icon: Icons.dashboard_rounded,
    ),
    _AdminPropertyModule(
      title: 'Property Partners',
      subtitle: 'Owners, agents and offices',
      icon: Icons.badge_rounded,
    ),
    _AdminPropertyModule(
      title: 'Property Listings',
      subtitle: 'View all sale and rent listings',
      icon: Icons.real_estate_agent_rounded,
    ),
    _AdminPropertyModule(
      title: 'Approval Queue',
      subtitle: 'Review pending listings and partners',
      icon: Icons.fact_check_rounded,
    ),
    _AdminPropertyModule(
      title: 'Sold / Rented',
      subtitle: 'Completed and closed listings',
      icon: Icons.task_alt_rounded,
    ),
    _AdminPropertyModule(
      title: 'Earnings',
      subtitle: 'Property business earnings',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _AdminPropertyModule(
      title: 'Commission',
      subtitle: 'NRD commission settings and due amounts',
      icon: Icons.percent_rounded,
    ),
    _AdminPropertyModule(
      title: 'Commission Payments',
      subtitle: 'Pending, approved and rejected payments',
      icon: Icons.payments_rounded,
    ),
    _AdminPropertyModule(
      title: 'Reports & Complaints',
      subtitle: 'Listing and partner reports',
      icon: Icons.report_problem_rounded,
    ),
    _AdminPropertyModule(
      title: 'Deleted / Archived',
      subtitle: 'Review, restore or permanently remove records',
      icon: Icons.archive_rounded,
    ),
    _AdminPropertyModule(
      title: 'Verification Documents',
      subtitle: 'Partner and property document review',
      icon: Icons.verified_user_rounded,
    ),
    _AdminPropertyModule(
      title: 'Property Settings',
      subtitle: 'Business rules and admin controls',
      icon: Icons.settings_rounded,
    ),
  ];

  void _openComingSoon(
    BuildContext context,
    String title,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be connected to the Property Admin system next.',
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
          'Property & Rent Admin',
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
              constraints.maxWidth >= 1200
                  ? 4
                  : constraints.maxWidth >= 800
                      ? 3
                      : constraints.maxWidth >= 520
                          ? 2
                          : 1;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1300,
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: _modules.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio:
                      columns == 1 ? 2.5 : 1.25,
                ),
                itemBuilder: (
                  BuildContext context,
                  int index,
                ) {
                  final _AdminPropertyModule item =
                      _modules[index];

                  return Card(
                    elevation: 3,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openComingSoon(
                        context,
                        item.title,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                color: Color(0x14795548),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                item.icon,
                                size: 34,
                                color:
                                    const Color(0xFF795548),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.subtitle,
                              textAlign: TextAlign.center,
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
            ),
          );
        },
      ),
    );
  }
}

class _AdminPropertyModule {
  final String title;
  final String subtitle;
  final IconData icon;

  const _AdminPropertyModule({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
