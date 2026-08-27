import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_text_field.dart';

class PasswordField extends StatefulWidget
{
  final TextEditingController controller;
  final String label;
  final String hintText;

  final bool showLabel;

  final bool nothingAbove;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.showLabel = true,
    this.nothingAbove = false,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField>
{
  bool _isObscured = true;

  Widget _buildVisibilityToggle()
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        icon: Icon(
          _isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppTheme.trialMutedText,
          size: 22,
        ),
        onPressed: () => setState(() => _isObscured = !_isObscured),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        tooltip: _isObscured ? 'Mostra password' : 'Nascondi password',
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hintText: widget.hintText,
      showLabel: widget.showLabel,
      nothingAbove: widget.nothingAbove,
      obscureText: _isObscured,
      suffix: _buildVisibilityToggle(),
    );
  }
}
