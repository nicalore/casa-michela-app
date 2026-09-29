import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_button_label.dart';

const double _height = 58;
const double _radius = 18;

const double _pressedScale = 0.98;
const Duration _pressDuration = Duration(milliseconds: 110);

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x4D6C3F95), offset: Offset(0, 10), blurRadius: 22),
];

class MobileDismissButton extends StatefulWidget
{
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const MobileDismissButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<MobileDismissButton> createState() => _MobileDismissButtonState();
}

class _MobileDismissButtonState extends State<MobileDismissButton>
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
              gradient: AppTheme.dismissGradient,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: _shadow,
            ),
            child: MobileButtonLabel(
              label: widget.label,
              icon: widget.icon,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
