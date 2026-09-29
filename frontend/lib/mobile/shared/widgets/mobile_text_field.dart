import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';

const double _height = 58;
const double _radius = 18;

const double _linesPadding = 16;

const double _restBorder = 1;
const double _focusBorder = 2;
const double _sidePadding = 18;

const double _restAlpha = 0.55;
const double _focusAlpha = 0.8;

const double _focusRingAlpha = 0.2;
const double _focusRingWidth = 4;

// The toggle's tap area is wider than its glyph; this matches the leading icon's inset.
const double _toggleShift = 9;

const Duration _focusFade = Duration(milliseconds: 160);

// Same counter rules as the desktop field.
const int _shortestCountedLimit = 50;
const double _counterAlwaysShownFrom = 0.9;

// Meant to sit on a MobileGlassPanel, whose tint the white fill adds to.
class MobileTextField extends StatefulWidget
{
  final TextEditingController controller;
  final String label;
  final IconData? icon;

  final String? hintText;

  final bool obscure;

  final TextInputType? keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  final int minLines;
  final int maxLines;

  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  const MobileTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hintText,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters = const [],
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints,
    this.focusNode,
  });

  @override
  State<MobileTextField> createState() => _MobileTextFieldState();
}

class _MobileTextFieldState extends State<MobileTextField>
{
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  bool _focused = false;
  late bool _obscured = widget.obscure;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose()
  {
    _focusNode.removeListener(_onFocusChange);

    if (widget.focusNode == null)
    {
      _focusNode.dispose();
    }

    super.dispose();
  }

  bool get _multiline => widget.maxLines > 1;

  void _onFocusChange()
  {
    if (_focused != _focusNode.hasFocus)
    {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  Widget _buildVisibilityToggle()
  {
    return Transform.translate(
      offset: const Offset(_toggleShift, 0),
      child: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          size: 22,
          color: MobilePalette.mutedText.withValues(alpha: 0.8),
        ),
        tooltip: _obscured ? 'Mostra password' : 'Nascondi password',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
    );
  }

  Widget _buildCounter(int limit)
  {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _)
      {
        final int written = value.text.characters.length;
        final bool full = written >= limit;
        final bool shown = _focused || written >= limit * _counterAlwaysShownFrom;

        final Color color = full ? AppTheme.trialDanger : MobilePalette.mutedText;

        return AnimatedDefaultTextStyle(
          duration: _focusFade,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: shown ? color : color.withValues(alpha: 0),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Text('$written/$limit'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double border = _focused ? _focusBorder : _restBorder;
    final int? limit = widget.maxLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppTheme.trialInk.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (limit != null && limit >= _shortestCountedLimit) _buildCounter(limit),
            ],
          ),
        ),
        // The whole box focuses, not just the text line inside it.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: AnimatedContainer(
            duration: _focusFade,
            curve: Curves.easeOut,
            height: _multiline ? null : _height,
            // Thicker border, thinner padding: the text never shifts.
            padding: EdgeInsets.symmetric(
              horizontal: _sidePadding + _restBorder - border,
              vertical: _multiline ? _linesPadding + _restBorder - border : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _focused ? _focusAlpha : _restAlpha),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: _focused ? AppTheme.trialGold : AppTheme.trialOcean.withValues(alpha: 0.14),
                width: border,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.trialGold.withValues(alpha: _focused ? _focusRingAlpha : 0),
                  spreadRadius: _focused ? _focusRingWidth : 0,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: _multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                if (widget.icon case final IconData icon) ...[
                  Icon(icon, size: 22, color: AppTheme.trialTealDeep),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: _obscured,
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    autocorrect: _multiline,
                    enableSuggestions: !widget.obscure,
                    keyboardType: _multiline ? TextInputType.multiline : widget.keyboardType,
                    textCapitalization: widget.textCapitalization,
                    inputFormatters: [
                      ...widget.inputFormatters,
                      if (widget.maxLength case final int length) LengthLimitingTextInputFormatter(length),
                    ],
                    textInputAction: _multiline ? TextInputAction.newline : widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    onSubmitted: widget.onSubmitted,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.28,
                      color: AppTheme.trialInk,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: widget.hintText,
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                        color: MobilePalette.mutedText.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                if (widget.obscure) _buildVisibilityToggle(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
