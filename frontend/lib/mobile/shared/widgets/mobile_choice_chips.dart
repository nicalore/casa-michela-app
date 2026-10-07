import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';

const double _height = 32;
const double _gap = 8;
const double _chipPadding = 13;

// A null value is the row's "all" entry.
class MobileChoice
{
  final String? value;
  final String label;

  const MobileChoice({required this.value, required this.label});
}

class MobileChoiceChips extends StatefulWidget
{
  final List<MobileChoice> choices;
  final String? value;
  final ValueChanged<String?> onChanged;

  // The page margin, so the row can bleed past it on both sides.
  final double margin;

  // Inside a card or a sheet rather than on the sea.
  final bool onLight;

  const MobileChoiceChips({
    super.key,
    required this.choices,
    required this.value,
    required this.onChanged,
    required this.margin,
    this.onLight = false,
  });

  @override
  State<MobileChoiceChips> createState() => _MobileChoiceChipsState();
}

class _MobileChoiceChipsState extends State<MobileChoiceChips>
{
  ScrollController? _scroll;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    // Computed from the labels: chips past the edge are not built yet.
    _scroll ??= ScrollController(initialScrollOffset: _offsetOfChosen());
  }

  @override
  void dispose()
  {
    _scroll?.dispose();
    super.dispose();
  }

  double _offsetOfChosen()
  {
    final int chosen = widget.choices.indexWhere((choice) => choice.value == widget.value);

    if (chosen <= 0)
    {
      return 0;
    }

    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final List<double> widths = [
      for (final choice in widget.choices) _Chip.widthOf(choice.label, scaler),
    ];

    double start = widget.margin;

    for (var i = 0; i < chosen; i++)
    {
      start += widths[i] + _gap;
    }

    final double total = widths.fold<double>(0, (sum, width) => sum + width) +
        _gap * (widths.length - 1) +
        widget.margin * 2;
    final double viewport = MediaQuery.sizeOf(context).width;

    final double centred = start + widths[chosen] / 2 - viewport / 2;

    return centred.clamp(0.0, (total - viewport).clamp(0.0, double.infinity));
  }

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: widget.margin),
        itemCount: widget.choices.length,
        separatorBuilder: (context, index) => const SizedBox(width: _gap),
        itemBuilder: (context, index)
        {
          final MobileChoice choice = widget.choices[index];

          return _Chip(
            label: choice.label,
            selected: choice.value == widget.value,
            onLight: widget.onLight,
            onTap: () => widget.onChanged(choice.value),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget
{
  final String label;
  final bool selected;
  final bool onLight;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onLight, required this.onTap});

  static TextStyle _style(Color color)
  {
    return GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
      color: color,
    );
  }

  // Must match the chip's layout: label, padding and inner border.
  static double widthOf(String label, TextScaler scaler)
  {
    final painter = TextPainter(
      text: TextSpan(text: label.toUpperCase(), style: _style(Colors.white)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    return painter.width + _chipPadding * 2 + 2;
  }

  @override
  Widget build(BuildContext context)
  {
    final Color fill = onLight
        ? (selected ? AppTheme.trialDeepWater : AppTheme.trialOcean.withValues(alpha: 0.06))
        : Colors.white.withValues(alpha: selected ? 0.92 : 0.12);
    final Color edge = onLight
        ? AppTheme.trialOcean.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.22);
    final Color ink = onLight
        ? (selected ? Colors.white : MobilePalette.mutedText)
        : (selected ? AppTheme.trialDeepWater : Colors.white.withValues(alpha: 0.78));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _chipPadding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.transparent : edge),
        ),
        child: Text(label.toUpperCase(), style: _style(ink)),
      ),
    );
  }
}
