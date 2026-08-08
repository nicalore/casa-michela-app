import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_range_slider.dart';
import '../../../shared/widgets/shared_components.dart';


// How long a slot lasts when it is first put on the track. An hour is the
// commonest lesson there is, and it is one drag from anything else.
const int _defaultLengthMinutes = 60;

// One slot of a day, set by dragging its two ends along the day itself.
//
// The same control the association sets its opening bands with, over a wider
// window: there the track is one band of the day, here it is the whole of it,
// from the hour the morning opens to the hour the evening shuts. It replaces
// two searchable dropdowns of quarter hours, which asked for one interval in
// two separate hunts through a list and never showed how long the slot was or
// where it fell in the day.
class LessonTimeRangeSlider extends StatelessWidget
{
  // What the slot is called on the row: "Orario" alone, or numbered where there
  // are several of them.
  final String label;

  // Both null while the slot has not been set yet. They are never one and not
  // the other: the track puts both ends down together.
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  final void Function(TimeOfDay start, TimeOfDay end) onChanged;

  // Null on the row that cannot be taken away — the only one there is, or the
  // one being edited.
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

  // Where an unset slot shows its handles: the afternoon, which is when this
  // association actually teaches. Nothing is reported until the track is
  // touched, so this is a starting position and not a value.
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

  // The value, read out in words rather than left to the two ends of the track.
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
        // The trash every removable row of the app carries: a rounded square
        // that fills with the pale gold under the pointer.
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

  // A slot cannot begin and end at the same minute: dragged onto the other end,
  // a handle stops one stop short of it. RangeSlider stops the two from
  // crossing on its own but is happy to let them meet, and a lesson from three
  // to three is not a lesson.
  void _report(RangeValues values, double previousStart, double previousEnd)
  {
    var startMinutes = values.start.round();
    var endMinutes = values.end.round();

    if (endMinutes - startMinutes < kQuarterHour)
    {
      // Whichever one moved is the one being dragged, and the one that gives
      // way is the other.
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
      // A slot not yet touched keeps the pale rail: it has not been chosen, and
      // saying so in the brand green would read as already decided.
      activeTrackColor: _isSet ? AppTheme.trialTealDeep : AppTheme.trialLine,
      values: RangeValues(start, end),
      min: _dayStart,
      max: _dayEnd,
      // One stop every quarter of an hour, which is the step the hours are
      // stored at: the handles cannot land anywhere the backend could not
      // keep.
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
      // Lined up with the ends of the track, which start half a thumb in.
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
