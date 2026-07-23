import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// Labelled password input that owns its own visibility toggle, so the pages
// hosting several of these do not have to track one flag per field.
class PasswordField extends StatefulWidget
{
  final TextEditingController controller;
  final String label;
  final String hintText;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField>
{
  bool _isObscured = true;

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 16),
          child: Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        TextField(
          controller: widget.controller,
          obscureText: _isObscured,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              color: AppTheme.hint,
              fontWeight: FontWeight.w500,
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppTheme.secondaryText,
              ),
              onPressed: () => setState(() => _isObscured = !_isObscured),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}