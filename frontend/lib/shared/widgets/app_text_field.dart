import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_field_label.dart';

import '../../core/theme/app_theme.dart';

const Color _fieldSurface = Color(0xFFFBFDFC);

const double _fieldRadius = 14;
const double _borderWidth = 2;

const Color _focusAccent = AppTheme.trialGold;

const double _focusRingWidth = 4;
const double _focusRingOpacity = 0.15;

const Duration _focusFade = Duration(milliseconds: 180);

const double _labelTopGap = 16;
const double _labelBottomGap = 6;
const double _labelLineHeight = kFieldLabelLineHeight;

const double _contentPadding = 16;
const double _inputFontSize = 17;
const double _inputLineHeight = _inputFontSize * 1.28;

const double _counterFontSize = 11;
const double _labelCounterGap = 8;

const int _shortestCountedLimit = 50;

const double _counterAlwaysShownFrom = 0.9;

class AppTextField extends StatefulWidget
{
  static const double labelBlockHeight = _labelTopGap + _labelBottomGap + _labelLineHeight;
  static const double boxHeight = 2 * _borderWidth + 2 * _contentPadding + _inputLineHeight;

  final TextEditingController controller;
  final String label;

  final bool showLabel;

  final bool nothingAbove;

  final String hintText;

  final FocusNode? focusNode;

  final bool obscureText;

  final int? maxLength;

  final int? maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final Widget? suffix;

  final String? errorText;

  final TextInputType? keyboardType;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.showLabel = true,
    this.nothingAbove = false,
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

  bool get _showsCounter
  {
    final int? limit = widget.maxLength;

    return limit != null && limit >= _shortestCountedLimit;
  }

  bool get _countsUnderTheField => _showsCounter && !widget.showLabel;

  Widget _buildCounter(bool hasError)
  {
    final int limit = widget.maxLength!;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _)
      {
        final int written = value.text.characters.length;

        final bool full = written >= limit;
        final bool nearlyFull = written >= limit * _counterAlwaysShownFrom;

        return AnimatedOpacity(
          duration: _focusFade,
          curve: Curves.easeOut,
          opacity: _hasFocus || nearlyFull ? 1 : 0,
          child: Text(
            '$written/$limit',
            style: GoogleFonts.plusJakartaSans(
              fontSize: _counterFontSize,
              fontWeight: FontWeight.w600,
              color: full || hasError ? AppTheme.trialDanger : AppTheme.trialMutedText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
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
              padding: EdgeInsets.only(
                bottom: _labelBottomGap,
                top: widget.nothingAbove ? 0 : _labelTopGap,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: AppFieldLabel(widget.label)),
                  if (_showsCounter) ...[
                    const SizedBox(width: _labelCounterGap),
                    _buildCounter(error != null),
                  ],
                ],
              ),
            ),
          AnimatedContainer(
            duration: _focusFade,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _fieldSurface,
              borderRadius: BorderRadius.circular(_fieldRadius),
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
          if (error != null || _countsUnderTheField)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: error == null
                        ? const SizedBox.shrink()
                        : Text(
                            error,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.trialDanger,
                            ),
                          ),
                  ),
                  if (_countsUnderTheField) ...[
                    const SizedBox(width: _labelCounterGap),
                    _buildCounter(error != null),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
