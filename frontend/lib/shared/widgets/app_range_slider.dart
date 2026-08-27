import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double kRangeSliderTrackHeight = 8;
const double kRangeSliderThumbRadius = 11;

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

  // Flutter keeps keyboard focus (and a full-strength overlay) on the dragged
  // thumb after release, so it is unfocused by hand.
  void _letGo(RangeValues _) => FocusManager.instance.primaryFocus?.unfocus();

  SliderThemeData _theme(BuildContext context)
  {
    return SliderTheme.of(context).copyWith(
      trackHeight: kRangeSliderTrackHeight,
      activeTrackColor: activeTrackColor,
      inactiveTrackColor: AppTheme.trialLine,
      thumbColor: Colors.white,
      overlayColor: AppTheme.trialGold.withValues(alpha: 0.18),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      rangeThumbShape: const RoundRangeSliderThumbShape(
        enabledThumbRadius: kRangeSliderThumbRadius,
        elevation: 2,
      ),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
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

  @override
  Widget build(BuildContext context)
  {
    return SliderTheme(
      data: _theme(context),
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
