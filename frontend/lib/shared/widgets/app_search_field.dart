import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';

const double _height = 50;
const double _denseHeight = 42;

const double _focusRingWidth = 4;
const double _focusRingOpacity = 0.14;

const Duration _focusFade = Duration(milliseconds: 200);

class AppSearchField extends StatefulWidget
{
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cerca...',
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField>
{
  final FocusNode _focusNode = FocusNode();

  bool _hasFocus = false;
  bool _hover = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose()
  {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged()
  {
    if (_focusNode.hasFocus != _hasFocus)
    {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  void _onTextChanged()
  {
    setState(() {});
  }

  void _clear()
  {
    widget.controller.clear();
    widget.onChanged('');
  }

  Widget _buildTrailing()
  {
    final bool hasText = widget.controller.text.isNotEmpty;

    if (!hasText)
    {
      return Icon(
        Icons.search_rounded,
        size: 28,
        color: _hasFocus ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _clear,
        behavior: HitTestBehavior.opaque,
        child: const Icon(Icons.close_rounded, size: 24, color: AppTheme.trialTealDeep),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final double height = dense ? _denseHeight : _height;
    final double fontSize = dense ? 15 : 17;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: height,
        child: AnimatedContainer(
          duration: _focusFade,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(height),
            border: Border.all(
              color: _hasFocus || _hover ? AppTheme.trialGold : AppTheme.trialLine,
              width: 1.5,
            ),
            boxShadow: [
              ...AppTheme.cardShadow,
              BoxShadow(
                color: AppTheme.trialGold.withValues(alpha: _hasFocus ? _focusRingOpacity : 0),
                spreadRadius: _hasFocus ? _focusRingWidth : 0,
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            textAlignVertical: TextAlignVertical.center,
            cursorColor: AppTheme.trialTealDeep,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialInk,
            ),
            decoration: InputDecoration(
              // The field's own least height would overflow the low box and push the text down.
              isDense: dense,
              hintText: widget.hintText,
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: AppTheme.trialMutedText,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(left: dense ? 20 : 26),
              suffixIcon: _buildTrailing(),
              suffixIconConstraints: BoxConstraints(minWidth: dense ? 52 : 60, minHeight: height),
            ),
          ),
        ),
      ),
    );
  }
}