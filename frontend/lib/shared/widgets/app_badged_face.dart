import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const double _badgeSize = 27;
const double _badgeIconSize = 18;
const double _badgeGap = 4;

// Pair centred at the upper left of the rim.
const double _badgesAngle = 3 * math.pi / 4;

const Duration _hoverFade = Duration(milliseconds: 150);

class AppBadgedFace extends StatelessWidget
{
  // Must be round and size wide.
  final Widget face;
  final double size;

  final bool hasImage;

  // Null while a change is in flight: badges disabled.
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  const AppBadgedFace({
    super.key,
    required this.face,
    required this.size,
    required this.hasImage,
    required this.onPick,
    required this.onRemove,
  });

  // Angle measured counter-clockwise from the right.
  Offset _onRim(double angle)
  {
    final double radius = size / 2;

    return Offset(radius + radius * math.cos(angle), radius - radius * math.sin(angle));
  }

  // The badges' overhang is part of the box so they stay pressable there.
  @override
  Widget build(BuildContext context)
  {
    final double radius = size / 2;

    // A badge's width and the gap, as an angle along the rim.
    final double apart = 2 * math.asin((_badgeSize + _badgeGap) / (2 * radius));

    final Offset pencil = _onRim(_badgesAngle + (hasImage ? apart / 2 : 0));
    final Offset bin = _onRim(_badgesAngle - apart / 2);

    final double overhangLeft = math.max(0, _badgeSize / 2 - pencil.dx);
    final double overhangTop = math.max(0, _badgeSize / 2 - (hasImage ? bin : pencil).dy);

    Widget place(Offset centre, Widget badge)
    {
      return Positioned(
        left: overhangLeft + centre.dx - _badgeSize / 2,
        top: overhangTop + centre.dy - _badgeSize / 2,
        child: badge,
      );
    }

    return SizedBox(
      width: size + overhangLeft,
      height: size + overhangTop,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: overhangLeft, top: overhangTop, child: face),
          place(
            pencil,
            _Badge(
              icon: Icons.edit_outlined,
              color: AppTheme.trialTealDeep,
              tooltip: hasImage ? 'Cambia la foto' : 'Carica una foto',
              onTap: onPick,
            ),
          ),
          if (hasImage)
            place(
              bin,
              _Badge(
                icon: Icons.delete_outline_rounded,
                color: AppTheme.trialDanger,
                tooltip: 'Rimuovi la foto',
                onTap: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatefulWidget
{
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _Badge({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool enabled = widget.onTap != null;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _hoverFade,
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(
              color: _hover && enabled ? AppTheme.trialGoldSurface : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: _hover && enabled ? AppTheme.trialGold : AppTheme.trialLine,
                width: 1.5,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Icon(
              widget.icon,
              size: _badgeIconSize,
              color: enabled ? widget.color : AppTheme.trialMutedText.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
