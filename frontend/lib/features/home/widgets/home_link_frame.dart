import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const double _hoverBorder = 1.5;
const Duration _fade = Duration(milliseconds: 150);

// What on the home leads elsewhere: the pointer's hand and, under it, the gold frame of the notices' lines.
// Without [onTap] the child stands alone. [outset]: how far the frame runs past the child, nothing moving.
class HomeLinkFrame extends StatefulWidget
{
  final VoidCallback? onTap;

  final double radius;
  final EdgeInsets outset;

  final Widget child;

  const HomeLinkFrame({
    super.key,
    required this.onTap,
    required this.radius,
    required this.child,
    this.outset = EdgeInsets.zero,
  });

  @override
  State<HomeLinkFrame> createState() => _HomeLinkFrameState();
}

class _HomeLinkFrameState extends State<HomeLinkFrame>
{
  bool _hover = false;

  void _point(bool hover)
  {
    setState(() => _hover = hover);
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? onTap = widget.onTap;

    if (onTap == null)
    {
      return widget.child;
    }

    final EdgeInsets outset = widget.outset;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _point(true),
      onExit: (_) => _point(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned(
              left: -outset.left,
              top: -outset.top,
              right: -outset.right,
              bottom: -outset.bottom,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _hover ? 1 : 0),
                  duration: _fade,
                  curve: Curves.easeOut,
                  // Gold kept at full colour, only its alpha fading: no dark tint midway.
                  builder: (context, lit, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
                      border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _hoverBorder),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
