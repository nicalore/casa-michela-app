import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double kRangeSliderTrackHeight = 8;
const double kRangeSliderThumbRadius = 11;

SliderThemeData _sliderTheme(BuildContext context, Color activeTrackColor, bool dimsWhenDisabled)
{
  return SliderTheme.of(context).copyWith(
    trackHeight: kRangeSliderTrackHeight,
    activeTrackColor: activeTrackColor,
    inactiveTrackColor: AppTheme.trialLine,
    thumbColor: Colors.white,
    overlayColor: AppTheme.trialGold.withValues(alpha: 0.18),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
    activeTickMarkColor: Colors.transparent,
    inactiveTickMarkColor: Colors.transparent,
    showValueIndicator: ShowValueIndicator.onDrag,
    valueIndicatorColor: AppTheme.trialOcean,
    valueIndicatorTextStyle: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
    disabledActiveTrackColor: dimsWhenDisabled ? AppTheme.trialLine : null,
    disabledInactiveTrackColor: dimsWhenDisabled ? AppTheme.trialLine : null,
    disabledActiveTickMarkColor: dimsWhenDisabled ? Colors.transparent : null,
    disabledInactiveTickMarkColor: dimsWhenDisabled ? Colors.transparent : null,
    disabledThumbColor: dimsWhenDisabled ? AppTheme.trialPaper : null,
  );
}

// Flutter keeps keyboard focus (and a full-strength overlay) on the dragged
// thumb after release, so it is unfocused by hand.
void _letGo(Object? _) => FocusManager.instance.primaryFocus?.unfocus();

class AppRangeSlider extends StatelessWidget
{
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final RangeLabels? labels;

  final ValueChanged<RangeValues>? onChanged;

  final Color activeTrackColor;

  final bool dimsWhenDisabled;

  const AppRangeSlider({
    super.key,
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.labels,
    this.activeTrackColor = AppTheme.trialTealDeep,
    this.dimsWhenDisabled = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return SliderTheme(
      data: _sliderTheme(context, activeTrackColor, dimsWhenDisabled).copyWith(
        rangeThumbShape: const RoundRangeSliderThumbShape(
          enabledThumbRadius: kRangeSliderThumbRadius,
          elevation: 2,
        ),
        rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      ),
      child: RangeSlider(
        values: values,
        min: min,
        max: max,
        divisions: divisions,
        labels: labels,
        onChangeEnd: _letGo,
        onChanged: onChanged,
      ),
    );
  }
}

class AppSlider extends StatelessWidget
{
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;

  final ValueChanged<double>? onChanged;

  final bool dimsWhenDisabled;

  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.label,
    this.dimsWhenDisabled = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return SliderTheme(
      data: _sliderTheme(context, AppTheme.trialTealDeep, dimsWhenDisabled).copyWith(
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: kRangeSliderThumbRadius, elevation: 2),
        trackShape: const RoundedRectSliderTrackShape(),
        valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChangeEnd: _letGo,
        onChanged: onChanged,
      ),
    );
  }
}
