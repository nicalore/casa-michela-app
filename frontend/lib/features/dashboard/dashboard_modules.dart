import 'package:flutter/material.dart';

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
const List<DashboardModule> dashboardModules = [
  DashboardModule(
    title: 'Persone',
    subtitle: 'Gestisci membri e profili',
    icon: Icons.groups_outlined,
    route: '/people',
  ),
  DashboardModule(
    title: 'Lezioni',
    subtitle: 'Organizza richieste e lezioni',
    icon: Icons.menu_book_rounded,
    route: '/lessons',
  ),
  DashboardModule(
    title: 'Contabilità',
    subtitle: 'Monitora pagamenti e ore lavorate',
    icon: Icons.account_balance_wallet_outlined,
  ),
  DashboardModule(
    title: 'Associazione',
    subtitle: 'Configura regole e parametri',
    imageAsset: 'assets/images/house_watermark_white.png',
    route: '/association',
  ),
];
