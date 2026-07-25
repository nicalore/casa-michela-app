import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';

const Color _logoutColor = Color(0xFFC62828);

const double _menuWidth = 210;
const double _leadingSpace = 14;
const double _iconSize = 18;
const double _iconTextGap = 10;
const double _itemRadius = 10;
const double _hoverBarHeight = 20;

const EdgeInsets _itemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

// Keyed by the Italian labels produced by RoleLabelMapper, not by the backend
// role codes: renaming a label there silently falls back to the default icon.
const Map<String, IconData> _roleIcons = <String, IconData>{
  'AMMINISTRATORE': Icons.computer_outlined,
  'DOCENTE': Icons.school_outlined,
  'PSICOLOGO': Icons.psychology_outlined,
  'STUDENTE': Icons.menu_book_outlined,
  'CORSISTA': Icons.self_improvement_rounded,
  'GENITORE': Icons.family_restroom_outlined,
};

IconData _roleIcon(String role) => _roleIcons[role.toUpperCase()] ?? Icons.badge_outlined;

class UserMenu extends StatefulWidget
{
  final String activeRole;
  final List<String> availableRoles;
  final ValueChanged<String> onRoleSelected;
  final VoidCallback onLogout;

  const UserMenu({
    super.key,
    required this.activeRole,
    required this.availableRoles,
    required this.onRoleSelected,
    required this.onLogout,
  });

  @override
  State<UserMenu> createState() => _UserMenuState();
}

class _UserMenuState extends State<UserMenu>
{
  bool _rolesExpanded = false;

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
            _RoleSection(
              activeRole: widget.activeRole,
              availableRoles: widget.availableRoles,
              expanded: _rolesExpanded,
              onToggle: () => setState(() => _rolesExpanded = !_rolesExpanded),
              onRoleSelected: widget.onRoleSelected,
            ),
            const Divider(height: 1),
            _HoverMenuItem(
              icon: Icons.settings_outlined,
              text: 'Impostazioni',
              color: AppTheme.primary,
              onTap: () => context.go('/settings'),
            ),
            _HoverMenuItem(
              icon: Icons.logout_rounded,
              text: 'Logout',
              color: _logoutColor,
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSection extends StatelessWidget
{
  final String activeRole;
  final List<String> availableRoles;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onRoleSelected;

  const _RoleSection({
    required this.activeRole,
    required this.availableRoles,
    required this.expanded,
    required this.onToggle,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context)
  {
    // With a single role there is nothing to switch to, so the header is inert
    // and the chevron is hidden.
    final canExpand = availableRoles.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: canExpand ? onToggle : null,
          borderRadius: BorderRadius.circular(_itemRadius),
          child: Padding(
            padding: _itemPadding,
            child: Row(
              children: [
                const SizedBox(width: _leadingSpace),
                SizedBox(
                  width: _iconSize,
                  child: Icon(
                    _roleIcon(activeRole),
                    size: _iconSize,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: _iconTextGap),
                Expanded(
                  child: OverflowTooltipText(
                    text: activeRole,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                if (canExpand)
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: expanded ? _buildAlternativeRoles() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildAlternativeRoles()
  {
    return Column(
      children: availableRoles
          .where((role) => role != activeRole)
          .map((role) => _HoverMenuItem(
                icon: _roleIcon(role),
                text: role,
                color: AppTheme.primary,
                onTap: () => onRoleSelected(role),
              ))
          .toList(),
    );
  }
}

class _HoverMenuItem extends StatefulWidget
{
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _HoverMenuItem({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
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
          // The hover bar sits in a Stack under the Row rather than inside it,
          // so growing it does not shift icon and text sideways.
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 2,
                height: _hover ? _hoverBarHeight : 0,
                decoration: BoxDecoration(
                  color: widget.color,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}