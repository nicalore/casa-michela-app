import 'package:flutter/material.dart';

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

  bool _focused = false;
  bool _showPassword = false;

  @override
  void initState()
  {
    super.initState();

    //Listen to focus changes to animate text field borders
    _focusNode.addListener(()
    {
      setState(()
      {
        _focused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose()
  {
    //Release resources
    _focusNode.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    //Calculate if text should be obscured
    final bool actuallyObscured = widget.obscureText && !_showPassword;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? const Color(0xFF003C82) : const Color(0xFFC7CDD4),
          width: _focused ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: actuallyObscured,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,

          //Toggle password visibility
          suffixIcon: widget.obscureText
              ? IconButton(
                  onPressed: ()
                  {
                    setState(()
                    {
                      _showPassword = !_showPassword;
                    });
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 28,
                    color: const Color(0xFF6B7280),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}