import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_field_label.dart';

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

// The pieces the two heights above are made of, so that changing the padding or
// the type size here keeps them true.
const double _labelTopGap = 16;
const double _labelBottomGap = 6;
const double _labelLineHeight = kFieldLabelLineHeight;

const double _contentPadding = 16;
const double _inputFontSize = 17;
const double _inputLineHeight = _inputFontSize * 1.28;

// A labelled input. Every field in the app is one of these, so the label, the
// box, the ring that opens when it is focused and the way it answers are decided
// once here rather than field by field.
class AppTextField extends StatefulWidget
{
  // What the label above the box takes, and what the box itself takes. A control
  // standing beside a field — the button that removes its row — has no other way
  // to line up with the box rather than with the whole column, and guessing the
  // number puts it a dozen pixels too high.
  static const double labelBlockHeight = _labelTopGap + _labelBottomGap + _labelLineHeight;
  static const double boxHeight = 2 * _borderWidth + 2 * _contentPadding + _inputLineHeight;

  final TextEditingController controller;
  final String label;

  // The label above the box. Off where the field sits in a row with its own
  // label alongside, as on the login page: the box then starts on its own,
  // without the empty block where the label would have been.
  final bool showLabel;

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

  // What is wrong with what was typed, said under the field and repeated on its
  // outline. Null while there is nothing to say, which is most of the time.
  final String? errorText;

  final TextInputType? keyboardType;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.showLabel = true,
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
    this.errorText,
    this.keyboardType,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
{
  FocusNode? _ownedNode;

  bool _hasFocus = false;
  bool _hover = false;

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
    // An error outranks the pointer and the focus: while it stands, the outline
    // is the colour of what is wrong.
    final String? error = widget.errorText;

    final Color outline = error != null
        ? AppTheme.trialDanger
        : (_hasFocus || _hover ? _focusAccent : AppTheme.trialLine);

    final Color ring = error != null ? AppTheme.trialDanger : _focusAccent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: _labelBottomGap, top: _labelTopGap),
              child: AppFieldLabel(widget.label),
            ),
          AnimatedContainer(
            duration: _focusFade,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _fieldSurface,
              borderRadius: BorderRadius.circular(_fieldRadius),
              // Gold once the pointer is on it, and gold with the ring once it is
              // listening: a field answers the pointer the way everything else in
              // this app does, and fades between the two.
              border: Border.all(color: outline, width: _borderWidth),
              boxShadow: [
                BoxShadow(
                  color: ring.withValues(alpha: _hasFocus ? _focusRingOpacity : 0),
                  spreadRadius: _hasFocus ? _focusRingWidth : 0,
                ),
              ],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: widget.keyboardType,
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
                fontSize: _inputFontSize,
                height: 1.28,
                color: AppTheme.trialInk,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                // The box is drawn by the container around it, so the field itself
                // brings no line of its own.
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: _contentPadding,
                  vertical: _contentPadding,
                ),
                hintText: widget.hintText,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: _inputFontSize,
                  height: 1.28,
                  color: AppTheme.trialMutedText,
                  fontWeight: FontWeight.w500,
                ),
                suffixIcon: widget.suffix,
                suffixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 40),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                error,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.trialDanger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
