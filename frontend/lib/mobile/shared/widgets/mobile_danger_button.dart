import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_button_label.dart';

const double _height = 58;
const double _radius = 18;

// At 17 the bin's ink matches the gold button's arrow; 20 overran the capitals.
const double _iconSize = 17;

const double _pressedScale = 0.98;
const Duration _pressDuration = Duration(milliseconds: 110);

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x4DC1503F), offset: Offset(0, 10), blurRadius: 22),
];

class MobileDangerButton extends StatefulWidget
{
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const MobileDangerButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<MobileDangerButton> createState() => _MobileDangerButtonState();
}

class _MobileDangerButtonState extends State<MobileDangerButton>
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
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? _pressedScale : 1,
          duration: _pressDuration,
          curve: Curves.easeOut,
          child: Container(
            height: _height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTheme.dangerGradient,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: _shadow,
            ),
            child: MobileButtonLabel(
              label: widget.label,
              icon: widget.icon,
              color: Colors.white,
              iconSize: _iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
