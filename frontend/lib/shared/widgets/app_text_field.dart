import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// The ground of an input. Not white: on a white card a white field has only its
// border to say where it begins, and the mockup gives it this barely-there green
// instead so the field reads as a hollow in the paper.
const Color _fieldSurface = Color(0xFFFBFDFC);

const double _fieldRadius = 14;
const double _borderWidth = 2;

// Gold, where the mockup uses its turquoise. On a page already built out of two
// greens a third one had nothing to push against, while gold is the colour this
// app keeps for wherever the attention is — the mark under the destination you
// are on, the outline of the card under the pointer — and a focused field is
// exactly that: the one place on the page that is listening to you.
const Color _focusAccent = AppTheme.trialGold;

// The ring the mockup opens around a focused field (0 0 0 4px at 15%). It is a
// shadow with no blur, which is what makes it a ring and not a glow, and it sits
// outside the border rather than replacing it.
const double _focusRingWidth = 4;
const double _focusRingOpacity = 0.15;

const Duration _focusFade = Duration(milliseconds: 180);

// A labelled input. Every field in the app is one of these, so the label, the
// box, the ring that opens when it is focused and the way it answers are decided
// once here rather than field by field.
class AppTextField extends StatefulWidget
{
  final TextEditingController controller;
  final String label;
  final String hintText;

  // Supplied when something outside has to move the focus into the field, as an
  // autocomplete does; left out the field keeps one of its own.
  final FocusNode? focusNode;

  final bool obscureText;
  final int? maxLength;

  // A description is written in sentences, not in a line: given these the box
  // grows with what is typed into it, between the two bounds.
  final int? maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  // Sits inside the box at its right end: a visibility toggle, a unit, a hint.
  final Widget? suffix;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.focusNode,
    this.obscureText = false,
    this.maxLength,
    this.maxLines,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
{
  FocusNode? _ownedNode;

  bool _hasFocus = false;

  FocusNode get _focusNode => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.focusNode != widget.focusNode)
    {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose()
  {
    _focusNode.removeListener(_onFocusChanged);
    // Only the one this field made itself: a node handed in from outside belongs
    // to whoever handed it over.
    _ownedNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged()
  {
    if (_focusNode.hasFocus != _hasFocus)
    {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 16),
          child: Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.trialOcean,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        AnimatedContainer(
          duration: _focusFade,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _fieldSurface,
            borderRadius: BorderRadius.circular(_fieldRadius),
            border: Border.all(
              color: _hasFocus ? _focusAccent : AppTheme.trialLine,
              width: _borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: _focusAccent.withValues(alpha: _hasFocus ? _focusRingOpacity : 0),
                spreadRadius: _hasFocus ? _focusRingWidth : 0,
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            maxLength: widget.maxLength,
            maxLines: widget.obscureText ? 1 : (widget.maxLines ?? 1),
            minLines: widget.minLines,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            cursorColor: AppTheme.trialTealDeep,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              color: AppTheme.trialInk,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              // The box is drawn by the container around it, so the field itself
              // brings no line of its own.
              border: InputBorder.none,
              isDense: true,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: widget.hintText,
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                color: AppTheme.trialMutedText,
                fontWeight: FontWeight.w500,
              ),
              suffixIcon: widget.suffix,
              suffixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 40),
            ),
          ),
        ),
      ],
    );
  }
}
