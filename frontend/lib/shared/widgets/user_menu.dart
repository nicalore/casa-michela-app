import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_top_nav.dart';
import 'overflow_tooltip_text.dart';

const Color _logoutColor = AppTheme.trialDanger;

const double _menuWidth = 210;
const double _leadingSpace = 14;
const double _iconSize = 18;
const double _iconTextGap = 10;
const double _itemRadius = 10;
const double _hoverBarHeight = 20;

const EdgeInsets _itemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

class UserMenu extends StatelessWidget
{
  final MenuDestinations destinations;

  final bool canChangeRole;

  final ValueChanged<String> onGo;
  final VoidCallback onChangeRole;
  final VoidCallback onLogout;

  // The reports still unread, beside their entry.
  final ValueListenable<int>? unreadReports;

  const UserMenu({
    super.key,
    required this.destinations,
    required this.canChangeRole,
    required this.onGo,
    required this.onChangeRole,
    required this.onLogout,
    this.unreadReports,
  });

  Widget _buildReports(AppDestination destination)
  {
    final ValueListenable<int> unread = unreadReports ?? ValueNotifier<int>(0);

    return ValueListenableBuilder<int>(
      valueListenable: unread,
      builder: (context, count, _) => _HoverMenuItem(
        icon: Icons.flag_rounded,
        text: destination.label,
        color: AppTheme.trialTealDeep,
        marked: count > 0,
        trailing: count > 0 ? _CountBadge(count) : null,
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
    return _HoverMenuItem(
      icon: icon,
      text: destination.label,
      color: AppTheme.trialTealDeep,
      onTap: () => onGo(destination.route!),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _menuWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDestination(Icons.person_rounded, destinations.ownPage),
            _buildDestination(Icons.settings_rounded, destinations.settings),
            const Divider(height: 1),
            ..._buildManagement(),
            if (canChangeRole) ...[
              _HoverMenuItem(
                icon: Icons.swap_horiz_rounded,
                text: 'Cambia ruolo',
                color: AppTheme.trialTealDeep,
                onTap: onChangeRole,
              ),
              const Divider(height: 1),
            ],
            _HoverMenuItem(
              icon: Icons.logout_rounded,
              text: 'Logout',
              color: _logoutColor,
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverMenuItem extends StatefulWidget
{
  final IconData icon;
  final String text;
  final Color color;

  final VoidCallback onTap;

  // The gold bar stays without the pointer: something there is waiting.
  final bool marked;

  final Widget? trailing;

  const _HoverMenuItem({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
    this.marked = false,
    this.trailing,
  });

  @override
  State<_HoverMenuItem> createState() => _HoverMenuItemState();
}

class _HoverMenuItemState extends State<_HoverMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(_itemRadius),
        child: Padding(
          padding: _itemPadding,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 2,
                height: _hover || widget.marked ? _hoverBarHeight : 0,
                decoration: BoxDecoration(
                  color: AppTheme.trialGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: _leadingSpace),
                  SizedBox(
                    width: _iconSize,
                    child: Icon(widget.icon, size: _iconSize, color: widget.color),
                  ),
                  const SizedBox(width: _iconTextGap),
                  Expanded(
                    child: OverflowTooltipText(
                      text: widget.text,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.color,
                      ),
                    ),
                  ),
                  if (widget.trailing case final Widget trailing) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
