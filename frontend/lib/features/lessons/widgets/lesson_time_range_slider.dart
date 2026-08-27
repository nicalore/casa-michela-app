import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_range_slider.dart';
import '../../../shared/widgets/shared_components.dart';

const int _defaultLengthMinutes = 60;

class LessonTimeRangeSlider extends StatelessWidget
{
  final String label;

  // Both null while the slot is unset; never one without the other.
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  final void Function(TimeOfDay start, TimeOfDay end) onChanged;

  final VoidCallback? onRemove;

  const LessonTimeRangeSlider({
    super.key,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.onChanged,
    this.onRemove,
  });

  bool get _isSet => startTime != null && endTime != null;

  double get _dayStart => kDayStartMinutes.toDouble();

  double get _dayEnd => kDayEndMinutes.toDouble();

  // Resting position for an unset slot; not reported until the track is touched.
  double get _restingStart => (_dayStart + _dayEnd) / 2;

  Widget _buildName()
  {
    return Text(
      label,
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
      _isSet ? formatTimeRange(startTime!, endTime!) : 'Da scegliere',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: _isSet ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
      ),
    );
  }

  Widget _buildHeader()
  {
    final remove = onRemove;

    return Row(
      children: [
        _buildName(),
        const SizedBox(width: 16),
        Expanded(child: _buildValue()),
        if (remove != null)
          FadeHoverIconButton(
            icon: Icons.delete_outline_rounded,
            color: AppTheme.trialDanger,
            hoverColor: AppTheme.trialGoldSurface,
            onTap: remove,
          ),
      ],
    );
  }

  // RangeSlider prevents crossing but allows the ends to meet; enforce a
  // quarter-hour minimum.
  void _report(RangeValues values, double previousStart, double previousEnd)
  {
    var startMinutes = values.start.round();
    var endMinutes = values.end.round();

    if (endMinutes - startMinutes < kQuarterHour)
    {
      // The end that moved is the one being dragged; the other gives way.
      if (startMinutes != previousStart.round())
      {
        startMinutes = endMinutes - kQuarterHour;
      }
      else
      {
        endMinutes = startMinutes + kQuarterHour;
      }
    }

    onChanged(timeOfDayFromMinutes(startMinutes), timeOfDayFromMinutes(endMinutes));
  }

  Widget _buildTrack(BuildContext context)
  {
    final start = _isSet ? minutesOfTimeOfDay(startTime!).toDouble() : _restingStart;
    final end = _isSet
        ? minutesOfTimeOfDay(endTime!).toDouble()
        : _restingStart + _defaultLengthMinutes;

    return AppRangeSlider(
      activeTrackColor: _isSet ? AppTheme.trialTealDeep : AppTheme.trialLine,
      values: RangeValues(start, end),
      min: _dayStart,
      max: _dayEnd,
      // Quarter-hour steps: the storage granularity.
      divisions: ((_dayEnd - _dayStart) / kQuarterHour).round(),
      labels: RangeLabels(
        formatTimeOfDayShort(timeOfDayFromMinutes(start.toInt())),
        formatTimeOfDayShort(timeOfDayFromMinutes(end.toInt())),
      ),
      onChanged: (values) => _report(values, start, end),
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
      // Lined up with the track ends, which start half a thumb in.
      padding: const EdgeInsets.symmetric(horizontal: kRangeSliderThumbRadius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(formatTimeOfDayShort(timeOfDayFromMinutes(kDayStartMinutes)), style: style),
          Text(formatTimeOfDayShort(timeOfDayFromMinutes(kDayEndMinutes)), style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 2),
        _buildTrack(context),
        _buildBounds(),
      ],
    );
  }
}
