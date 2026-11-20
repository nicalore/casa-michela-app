import 'package:flutter/material.dart';

import '../../core/language/app_language.dart';

class DashboardModule
{
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? imageAsset;
  final String? route;

  const DashboardModule({
    required this.title,
    required this.subtitle,
    this.icon,
    this.imageAsset,
    this.route,
  });
}

// Single source for both the dashboard cards and the header navigation.
List<DashboardModule> get dashboardModules => [
  DashboardModule(
    title: tr('Persone', 'People'),
    subtitle: tr('Gestisci membri e profili', 'Manage members and profiles'),
    icon: Icons.groups_outlined,
    route: '/people',
  ),
  DashboardModule(
    title: tr('Lezioni', 'Lessons'),
    subtitle: tr('Organizza richieste e lezioni', 'Organise requests and lessons'),
    icon: Icons.menu_book_rounded,
    route: '/lessons',
  ),
  DashboardModule(
    title: tr('Contabilità', 'Accounting'),
    subtitle: tr('Monitora pagamenti e ore lavorate', 'Track payments and hours worked'),
    icon: Icons.account_balance_wallet_outlined,
    route: '/accounting',
  ),
  DashboardModule(
    title: tr('Associazione', 'Association'),
    subtitle: tr('Configura regole e parametri', 'Set up rules and parameters'),
    imageAsset: 'assets/images/house_watermark_white.png',
    route: '/association',
  ),
];
