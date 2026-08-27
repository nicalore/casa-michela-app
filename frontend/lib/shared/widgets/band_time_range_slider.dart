import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import 'app_range_slider.dart';
import 'app_segmented_switch.dart';

class BandTimeRangeSlider extends StatelessWidget
{
  final TimeBucket bucket;

  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  final void Function(TimeOfDay? start, TimeOfDay? end) onChanged;

  final int? windowStartMinutes;
  final int? windowEndMinutes;

  final int? dragMinMinutes;
  final int? dragMaxMinutes;

  final int minimumMinutes;

  final int? maximumMinutes;

  final bool enabled;

  final String disabledLabel;

  final String offLabel;

  final String trueLabel;
  final String falseLabel;

  final String? nameOverride;

  final Widget? trailing;

  const BandTimeRangeSlider({
    super.key,
    required this.bucket,
    required this.startTime,
    required this.endTime,
    required this.onChanged,
    this.minimumMinutes = kQuarterHour,
    this.maximumMinutes,
    this.windowStartMinutes,
    this.windowEndMinutes,
    this.dragMinMinutes,
    this.dragMaxMinutes,
    this.enabled = true,
    this.disabledLabel = 'Chiuso',
    this.offLabel = 'Chiuso',
    this.trueLabel = 'Aperta',
    this.falseLabel = 'Chiusa',
    this.nameOverride,
    this.trailing,
  });

  bool get _isOpen => startTime != null && endTime != null;

  double get _bandStart => (windowStartMinutes ?? bandStartMinutes(bucket)).toDouble();

  double get _bandEnd => (windowEndMinutes ?? bandEndMinutes(bucket)).toDouble();

  double get _dragStart => (dragMinMinutes?.toDouble() ?? _bandStart).clamp(_bandStart, _bandEnd);

  double get _dragEnd => (dragMaxMinutes?.toDouble() ?? _bandEnd).clamp(_dragStart, _bandEnd);

  void _toggle(bool open)
  {
    // Without this, tapping "Aperta" on an open band threw away its hours.
    if (open == _isOpen)
    {
      return;
    }

    if (!open)
    {
      onChanged(null, null);

      return;
    }

    onChanged(
      timeOfDayFromMinutes(_bandStart.toInt()),
      timeOfDayFromMinutes(_bandEnd.toInt()),
    );
  }

  Widget _buildName()
  {
    return Text(
      nameOverride ?? bandLabel(bucket),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.trialOcean,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _buildValue()
  {
    return Text(
      _isOpen ? formatTimeRange(startTime!, endTime!) : (enabled ? offLabel : disabledLabel),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: _isOpen ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
      ),
    );
  }

  Widget _buildSwitch()
  {
    final replacement = trailing;

    if (replacement != null)
    {
      return replacement;
    }

    return AppSegmentedSwitch(
      value: _isOpen,
      trueLabel: trueLabel,
      falseLabel: falseLabel,
      onChanged: _toggle,
    );
  }

  Widget _buildHeader()
  {
    if (!enabled)
    {
      return Row(
        children: [
          Expanded(child: _buildName()),
          _buildValue(),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < 350)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildName()),
                  _buildSwitch(),
                ],
              ),
              const SizedBox(height: 4),
              _buildValue(),
            ],
          );
        }

        return Row(
          children: [
            _buildName(),
            const SizedBox(width: 16),
            Expanded(child: _buildValue()),
            _buildSwitch(),
          ],
        );
      },
    );
  }

  Widget _buildTrack()
  {
    // Held inside the track: RangeSlider asserts on a handle outside its ends,
    // and stored hours can legitimately fall outside the current window.
    final start = (_isOpen ? minutesOfTimeOfDay(startTime!).toDouble() : _bandStart)
        .clamp(_bandStart, _bandEnd);
    final end = (_isOpen ? minutesOfTimeOfDay(endTime!).toDouble() : _bandEnd)
        .clamp(start, _bandEnd);

    return AppRangeSlider(
      dimsWhenDisabled: true,
      values: RangeValues(start, end),
      min: _bandStart,
      max: _bandEnd,
      divisions: ((_bandEnd - _bandStart) / kQuarterHour).round(),
      labels: RangeLabels(
        formatTimeOfDayShort(timeOfDayFromMinutes(start.toInt())),
        formatTimeOfDayShort(timeOfDayFromMinutes(end.toInt())),
      ),
      onChanged: _isOpen && enabled ? (values) => _report(values, start) : null,
    );
  }

  (int, int) _heldAt(int startMinutes, int endMinutes, int length, double previousStart)
  {
    return startMinutes != previousStart.round()
        ? (endMinutes - length, endMinutes)
        : (startMinutes, startMinutes + length);
  }

  // RangeSlider lets the thumbs meet; a zero-length opening is not an opening.
  void _report(RangeValues values, double previousStart)
  {
    var startMinutes = values.start.round().clamp(_dragStart.round(), _dragEnd.round());
    var endMinutes = values.end.round().clamp(_dragStart.round(), _dragEnd.round());

    if (endMinutes - startMinutes < minimumMinutes)
    {
      (startMinutes, endMinutes) = _heldAt(startMinutes, endMinutes, minimumMinutes, previousStart);
    }

    final ceiling = maximumMinutes;

    if (ceiling != null && endMinutes - startMinutes > ceiling)
    {
      (startMinutes, endMinutes) = _heldAt(startMinutes, endMinutes, ceiling, previousStart);
    }

    onChanged(
      timeOfDayFromMinutes(startMinutes),
      timeOfDayFromMinutes(endMinutes),
    );
  }

  Widget _buildBounds()
  {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kRangeSliderThumbRadius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(formatTimeOfDayShort(timeOfDayFromMinutes(_bandStart.toInt())), style: style),
          Text(formatTimeOfDayShort(timeOfDayFromMinutes(_bandEnd.toInt())), style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (!enabled)
    {
      return _buildHeader();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 2),
        _buildTrack(),
        _buildBounds(),
      ],
    );
  }
}
