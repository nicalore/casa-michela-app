import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const Color _idleBorder = Color(0xFFC7CDD4);
const Color _inputText = Color(0xFF1A1A1A);
const Color _iconColor = Color(0xFF6B7280);

const String _fontFamily = 'Plus Jakarta Sans';

class LoginTextField extends StatefulWidget
{
  final TextEditingController controller;
  final bool obscureText;

  const LoginTextField({
    super.key,
    required this.controller,
    this.obscureText = false,
  });

  @override
  State<LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<LoginTextField>
{
  final FocusNode _focusNode = FocusNode();

  bool _isFocused = false;
  bool _showPassword = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose()
  {
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged()
  {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  // The four transparent overlay colours suppress the default IconButton
  // ripple, which would clash with the flat border animation.
  Widget _buildVisibilityToggle()
  {
    return IconButton(
      onPressed: () => setState(() => _showPassword = !_showPassword),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      icon: Icon(
        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 28,
        color: _iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final isObscured = widget.obscureText && !_showPassword;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused ? AppTheme.primary : _idleBorder,
          width: _isFocused ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: isObscured,
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: _inputText,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          suffixIcon: widget.obscureText ? _buildVisibilityToggle() : null,
        ),
      ),
    );
  }
}