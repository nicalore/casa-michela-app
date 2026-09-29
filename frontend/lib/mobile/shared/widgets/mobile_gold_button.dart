import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_button_label.dart';

const double _height = 58;
const double _radius = 18;

const double _pressedScale = 0.98;
const Duration _pressDuration = Duration(milliseconds: 110);

const Color _goldLight = Color(0xFFF3C766);

const LinearGradient _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppTheme.trialGold, _goldLight],
);

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x52E3A83C), offset: Offset(0, 10), blurRadius: 22),
];

class MobileGoldButton extends StatefulWidget
{
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  final bool busy;

  const MobileGoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  @override
  State<MobileGoldButton> createState() => _MobileGoldButtonState();
}

class _MobileGoldButtonState extends State<MobileGoldButton>
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
      enabled: !widget.busy,
      label: widget.label,
      child: GestureDetector(
        onTapDown: widget.busy ? null : (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.busy ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? _pressedScale : 1,
          duration: _pressDuration,
          curve: Curves.easeOut,
          child: Container(
            height: _height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: _shadow,
            ),
            child: MobileButtonLabel(
              label: widget.label,
              icon: widget.icon,
              color: AppTheme.trialDeepWater,
              replacement: widget.busy
                  ? const CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.trialDeepWater)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
