import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
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
  final bool canChangeRole;

  final VoidCallback onChangeRole;
  final VoidCallback onLogout;

  const UserMenu({
    super.key,
    required this.canChangeRole,
    required this.onChangeRole,
    required this.onLogout,
  });

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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
