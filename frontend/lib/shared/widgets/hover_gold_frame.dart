import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const double _inset = 3;
const double _radius = 10;
const double _border = 1.5;
const Duration _fade = Duration(milliseconds: 150);

// Under the pointer a table row takes the gold frame; against the card's edge its corners follow the card's.
class HoverGoldFrame extends StatefulWidget
{
  final double cardRadius;
  final bool atTop;
  final bool atBottom;

  // The whole row opens it, with the pointing hand.
  final VoidCallback? onTap;

  // Kept clear on the left, as a mark the row has along its edge.
  final double leadingInset;

  final Widget child;

  const HoverGoldFrame({
    super.key,
    required this.cardRadius,
    required this.child,
    this.atTop = false,
    this.atBottom = false,
    this.onTap,
    this.leadingInset = 0,
  });

  @override
  State<HoverGoldFrame> createState() => _HoverGoldFrameState();
}

class _HoverGoldFrameState extends State<HoverGoldFrame>
{
  bool _hover = false;

  Radius _corner(bool againstTheCard) => Radius.circular(againstTheCard ? widget.cardRadius - _inset : _radius);

  @override
  Widget build(BuildContext context)
  {
    final BorderRadius corners = BorderRadius.vertical(
      top: _corner(widget.atTop),
      bottom: _corner(widget.atBottom),
    );

    final VoidCallback? onTap = widget.onTap;

    final Widget framed = Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: EdgeInsets.fromLTRB(_inset + widget.leadingInset, _inset, _inset, _inset),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _hover ? 1 : 0),
                duration: _fade,
                curve: Curves.easeOut,
                builder: (context, lit, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: corners,
                    border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _border),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: onTap == null ? framed : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: framed),
    );
  }
}
