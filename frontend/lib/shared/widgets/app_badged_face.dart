import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_tooltip.dart';

const double kFaceBadgeSize = 27;
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

  // Smaller on a small face, so the pair still sits on the rim.
  final double badgeSize;

  const AppBadgedFace({
    super.key,
    required this.face,
    required this.size,
    required this.hasImage,
    required this.onPick,
    required this.onRemove,
    this.badgeSize = kFaceBadgeSize,
  });

  // Angle measured counter-clockwise from the right.
  static Offset _onRim(double size, double angle)
  {
    final double radius = size / 2;

    return Offset(radius + radius * math.cos(angle), radius - radius * math.sin(angle));
  }

  static ({Offset pencil, Offset bin, double left, double top}) _placesOf(double size, double badgeSize, bool hasImage)
  {
    // A badge's width and the gap, as an angle along the rim.
    final double apart = 2 * math.asin((badgeSize + _badgeGap) / size);

    final Offset pencil = _onRim(size, _badgesAngle + (hasImage ? apart / 2 : 0));
    final Offset bin = _onRim(size, _badgesAngle - apart / 2);

    return (
      pencil: pencil,
      bin: bin,
      left: math.max(0, badgeSize / 2 - pencil.dx),
      top: math.max(0, badgeSize / 2 - (hasImage ? bin : pencil).dy),
    );
  }

  // The box the face takes with its badges.
  static Size extentOf(double size, {double badgeSize = kFaceBadgeSize, required bool hasImage})
  {
    final places = _placesOf(size, badgeSize, hasImage);

    return Size(size + places.left, size + places.top);
  }

  // The badges' overhang is part of the box so they stay pressable there.
  @override
  Widget build(BuildContext context)
  {
    final places = _placesOf(size, badgeSize, hasImage);

    final Offset pencil = places.pencil;
    final Offset bin = places.bin;

    final double overhangLeft = places.left;
    final double overhangTop = places.top;

    Widget place(Offset centre, Widget badge)
    {
      return Positioned(
        left: overhangLeft + centre.dx - badgeSize / 2,
        top: overhangTop + centre.dy - badgeSize / 2,
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
              size: badgeSize,
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
                size: badgeSize,
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
  final double size;

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _Badge({
    required this.size,
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

    return AppTooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _hoverFade,
            width: widget.size,
            height: widget.size,
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
              size: widget.size * _badgeIconSize / kFaceBadgeSize,
              color: enabled ? widget.color : AppTheme.trialMutedText.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
