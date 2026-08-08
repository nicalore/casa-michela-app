import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double _height = 50;

// The same gold the password field takes when it is focused, and for the same
// reason: gold is where the attention is, and a field being typed into is the
// one place on the page that is listening.
const double _focusRingWidth = 4;
const double _focusRingOpacity = 0.14;

const Duration _focusFade = Duration(milliseconds: 200);

// The search box at the head of a list. A pill rather than the rounded box the
// inputs in the dialogs wear: it belongs to the furniture of the page, next to
// the top bar and the rail, and those are all cut from circles.
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

  // Only the trailing control depends on it, but it has to be watched: the
  // glass turns into a cross the moment there is something to clear.
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: _focusFade,
        curve: Curves.easeOut,
        height: _height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_height),
          // Gold as soon as the pointer arrives, gold with the ring as soon as
          // it listens: the two answers every field of the app gives, and that
          // this bar did not.
          border: Border.all(
            color: _hasFocus || _hover ? AppTheme.trialGold : AppTheme.trialLine,
            width: 1.5,
          ),
          boxShadow: [
            ...AppTheme.cardShadow,
            // The ring belongs to focus alone: it says the field is listening,
            // which is a different statement from saying it can be pressed.
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
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppTheme.trialInk,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.only(left: 26),
            suffixIcon: _buildTrailing(),
            suffixIconConstraints: const BoxConstraints(minWidth: 60, minHeight: _height),
          ),
        ),
      ),
    );
  }
}