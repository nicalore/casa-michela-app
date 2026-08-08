import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// Exposed so callers can leave as much room at either end of the slider as a
// thumb takes up.
const double kRangeSliderTrackHeight = 8;
const double kRangeSliderThumbRadius = 11;

// A two-handle slider, as this app draws them: green track on a pale rail,
// white thumbs that stand off the track instead of vanishing into it, gold under
// the pointer, and the value on a blue tag while dragging.
//
// A widget and not just a theme because the slider also has something to *do*,
// and for as long as that was left to each caller to remember it was forgotten:
// see [_letGo].
class AppRangeSlider extends StatelessWidget
{
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final RangeLabels? labels;

  // Null where the slider is off — a closed band, which keeps its rail on
  // screen instead of leaving a hole where it was.
  final ValueChanged<RangeValues>? onChanged;

  // Pale until the band has actually been chosen: saying it in the brand green
  // would read as already decided.
  final Color activeTrackColor;

  // Disabled, it keeps the pale rail instead of the heavy grey Material gives a
  // disabled control: it is not broken, it is closed.
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

  // Flutter gives keyboard focus to the thumb being dragged and paints the
  // overlay at full strength for as long as it holds it, so a released thumb
  // keeps its halo and reads as a control still under the hand. Focus is what a
  // keyboard user takes by tabbing to it; a hand that has just finished dragging
  // is not asking for it.
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
      // The tick marks are there, they are simply not drawn: dozens of marks
      // along a day read as a fence rather than a scale, and the thumbs still
      // snap to them.
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
      // The page's paper and not the grey the other disabled surfaces take: the
      // thumb sits on top of the track, which is already darker than it, so
      // darkening it too would sink it into the rail instead of standing it off.
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
