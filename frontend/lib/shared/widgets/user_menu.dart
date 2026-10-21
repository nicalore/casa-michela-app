import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_menu.dart';
import 'app_top_nav.dart';
import 'overflow_tooltip_text.dart';

const Color _logoutColor = AppTheme.trialDanger;

const double _menuWidth = 210;
const double _headedMenuWidth = 230;

class UserMenu extends StatelessWidget
{
  final MenuDestinations destinations;

  final bool canChangeRole;

  final ValueChanged<String> onGo;
  final VoidCallback onChangeRole;
  final VoidCallback onLogout;

  // The reports still unread, beside their entry.
  final ValueListenable<int>? unreadReports;

  // Given where the bar has no room to write the role: the menu heads with it.
  final String? role;

  final bool dense;

  // The entries alone, for a menu that holds them under its own.
  final bool bare;

  const UserMenu({
    super.key,
    required this.destinations,
    required this.canChangeRole,
    required this.onGo,
    required this.onChangeRole,
    required this.onLogout,
    this.unreadReports,
    this.role,
    this.dense = false,
    this.bare = false,
  });

  Widget _buildReports(AppDestination destination)
  {
    final ValueListenable<int> unread = unreadReports ?? ValueNotifier<int>(0);

    return ValueListenableBuilder<int>(
      valueListenable: unread,
      builder: (context, count, _) => AppMenuItem(
        icon: Icons.flag_rounded,
        text: destination.label,
        marked: count > 0,
        trailing: count > 0 ? _CountBadge(count) : null,
        dense: dense,
        onTap: () => onGo(destination.route!),
      ),
    );
  }

  // Reports and updates share a group: no line between them.
  List<Widget> _buildManagement()
  {
    final AppDestination? reports = destinations.reports;
    final AppDestination? updates = destinations.updates;

    if (reports == null && updates == null)
    {
      return const [];
    }

    return [
      if (reports != null) _buildReports(reports),
      if (updates != null) _buildDestination(Icons.update_rounded, updates),
      const Divider(height: 1),
    ];
  }

  Widget _buildDestination(IconData icon, AppDestination destination)
  {
    return AppMenuItem(
      icon: icon,
      text: destination.label,
      dense: dense,
      onTap: () => onGo(destination.route!),
    );
  }

  Widget _buildHead(String role)
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEI AUTENTICATO COME',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              height: 1.2,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 2),
          OverflowTooltipText(
            text: role,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String? role = this.role;

    final List<Widget> entries = [
      if (role != null) ...[
        _buildHead(role),
        const Divider(height: 1),
      ],
      _buildDestination(Icons.person_rounded, destinations.ownPage),
      _buildDestination(Icons.settings_rounded, destinations.settings),
      const Divider(height: 1),
      ..._buildManagement(),
      if (canChangeRole) ...[
        AppMenuItem(
          icon: Icons.swap_horiz_rounded,
          text: 'Cambia ruolo',
          dense: dense,
          onTap: onChangeRole,
        ),
        const Divider(height: 1),
      ],
      AppMenuItem(
        icon: Icons.logout_rounded,
        text: 'Logout',
        color: _logoutColor,
        dense: dense,
        onTap: onLogout,
      ),
    ];

    if (bare)
    {
      return Column(mainAxisSize: MainAxisSize.min, children: entries);
    }

    return AppMenuCard(width: role != null ? _headedMenuWidth : _menuWidth, children: entries);
  }
}

class _CountBadge extends StatelessWidget
{
  final int count;

  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context)
  {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(color: AppTheme.trialGold, borderRadius: BorderRadius.circular(11)),
      child: Center(
        widthFactor: 1,
        child: Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }
}
