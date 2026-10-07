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
