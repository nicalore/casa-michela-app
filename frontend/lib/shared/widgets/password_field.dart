import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_text_field.dart';

// The app's input with the one thing a password needs on top of it: a way to
// look at what you typed. Everything else — the box, the label, the ring that
// opens when it is focused — comes from AppTextField, so a password field cannot
// drift away from every other field in the app.
class PasswordField extends StatefulWidget
{
  final TextEditingController controller;
  final String label;
  final String hintText;

  // As in AppTextField: off where the label sits alongside the box.
  final bool showLabel;

  // As in AppTextField: set where the field opens the box that holds it.
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

  // The toggle needs a cursor of its own: sitting inside the decoration of a
  // text field it inherits nothing, and came out as the plain arrow while
  // everything around it said the field could be typed into.
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
