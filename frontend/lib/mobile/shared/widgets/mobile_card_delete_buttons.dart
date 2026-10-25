import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_button_label.dart';

const double _circle = 34;
const double _circleAlpha = 0.07;
const double _binSize = 19;

const double _height = 42;
const double _radius = 14;
const double _groundAlpha = 0.05;
const double _fontSize = 13;
const double _iconSize = 16;

// The small labelled buttons of a list row.
const double _pillHeight = 34;
const double _pillRadius = 12;
const double _pillFontSize = 12;
const double _pillIconSize = 15;
// Above and below the pill, so the touch reaches 44.
const double _pillTouchRoom = 5;
// A gentle start: with a fast one the label crossed half the pill in a single frame.
const Duration _pillSwap = Duration(milliseconds: 320);
const Curve _pillRoll = Curves.fastOutSlowIn;

const double _binPressedScale = 0.92;
const double _pressedScale = 0.98;
const Duration _pressDuration = Duration(milliseconds: 110);

class MobileCardBinButton extends StatelessWidget
{
  final VoidCallback? onPressed;
  final double extent;

  const MobileCardBinButton({super.key, required this.onPressed, this.extent = 44});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Elimina',
      child: _Pressable(
        onTap: onPressed,
        pressedScale: _binPressedScale,
        child: SizedBox.square(
          dimension: extent,
          child: Center(
            child: Container(
              width: _circle,
              height: _circle,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.trialInk.withValues(alpha: _circleAlpha),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: _binSize, color: AppTheme.trialDanger),
            ),
          ),
        ),
      ),
    );
  }
}

class MobileCardDeleteButton extends StatelessWidget
{
  final String label;
  final VoidCallback onPressed;

  const MobileCardDeleteButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: label,
      child: _Pressable(
        onTap: onPressed,
        pressedScale: _pressedScale,
        child: Container(
          height: _height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.trialInk.withValues(alpha: _groundAlpha),
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: MobileButtonLabel(
            label: label,
            icon: Icons.delete_outline_rounded,
            color: AppTheme.trialDanger,
            fontSize: _fontSize,
            iconSize: _iconSize,
          ),
        ),
      ),
    );
  }
}

// Inside a list row; a new label rolls up into place, the pill keeping one width.
class MobileCardPillButton extends StatelessWidget
{
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  // Every label it may show: the pill keeps the widest one's width.
  final List<String> labels;

  const MobileCardPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.labels = const [],
  });

  // Old and new travel as one strip a pill tall: the leaving one runs the curve flipped, so they never overlap.
  static Widget _roll(Widget child, Animation<double> animation, Key current)
  {
    final Animation<Offset> offset = Tween<Offset>(
      begin: Offset(0, child.key == current ? 1 : -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: _pillRoll, reverseCurve: _pillRoll.flipped));

    return SlideTransition(position: offset, child: child);
  }

  Widget _face(String text)
  {
    return MobileButtonLabel(
      label: text,
      icon: icon,
      color: color,
      fontSize: _pillFontSize,
      iconSize: _pillIconSize,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Key current = ValueKey<String>(label);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: _Pressable(
        onTap: onPressed,
        pressedScale: _pressedScale,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _pillTouchRoom),
          child: Container(
            height: _pillHeight,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppTheme.trialInk.withValues(alpha: _groundAlpha),
              borderRadius: BorderRadius.circular(_pillRadius),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final text in {label, ...labels}) Visibility.maintain(visible: false, child: _face(text)),
                // The roll repaints the pill alone, not the card and its shadows.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedSwitcher(
                      duration: _pillSwap,
                      transitionBuilder: (child, animation) => _roll(child, animation, current),
                      child: Center(key: current, child: _face(label)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget
{
  final VoidCallback? onTap;
  final double pressedScale;
  final Widget child;

  const _Pressable({required this.onTap, required this.pressedScale, required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
{
  bool _pressed = false;

  void _setPressed(bool value)
  {
    if (_pressed != value)
    {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool enabled = widget.onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: _pressDuration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
