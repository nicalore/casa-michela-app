import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import 'app_range_slider.dart';
import 'app_segmented_switch.dart';

// One band of a day, set by dragging its two ends along the band's own window:
// the track is the band, and what is picked out of it is the opening.
//
// The switch says whether the band is open at all, which two empty fields
// cannot: those are indistinguishable from not having filled them in yet.
class BandTimeRangeSlider extends StatelessWidget
{
  final TimeBucket bucket;

  // Both null when the band is closed, never one and not the other.
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  final void Function(TimeOfDay? start, TimeOfDay? end) onChanged;

  // Narrows the track to a window inside the band. The association's own hours
  // use the whole band, since that is what they are setting; a teacher's
  // availability is offered inside what the association has open, so it passes
  // those two ends and cannot be dragged outside them.
  final int? windowStartMinutes;
  final int? windowEndMinutes;

  // What the neighbouring stretches leave free. Kept apart from the track,
  // which is the band, or each stretch would be drawn on a scale of its own.
  final int? dragMinMinutes;
  final int? dragMaxMinutes;

  // An opening can be given in quarter hours, a presence cannot.
  final int minimumMinutes;

  // Where there is a ceiling: a lesson has the minutes left of what was asked
  // for. Held like the minimum, so the hours follow the hand.
  final int? maximumMinutes;

  // Off where the association is shut in this band. The row stays greyed: one
  // that vanished would leave the day looking shorter than it is.
  final bool enabled;

  // What the row says in place of its hours where the question cannot be
  // answered at all — the association is shut in this band.
  final String disabledLabel;

  // And where it can be answered and has not been. The same thing for the
  // association's own hours, not for a teacher's: a band the association opens
  // and the teacher did not take is not a closed band.
  final String offLabel;

  // The two sides of the switch. The association's hours are open or closed; a
  // teacher's availability is given or not.
  final String trueLabel;
  final String falseLabel;

  // Left out, the name of the band. A band of several stretches names itself on
  // the first and passes an empty string to the rest: repeating "Pomeriggio"
  // down the card would read as three afternoons.
  final String? nameOverride;

  // Put where the switch would be: one stretch among several carries a trash
  // instead, since it is dropped on its own.
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

  // What the neighbours leave free, or the whole track where there is nobody.
  double get _dragStart => (dragMinMinutes?.toDouble() ?? _bandStart).clamp(_bandStart, _bandEnd);

  double get _dragEnd => (dragMaxMinutes?.toDouble() ?? _bandEnd).clamp(_dragStart, _bandEnd);

  // A band being opened starts as the whole window: one drag from anything
  // else, and the only default that is not a guess.
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
      // One word, never wrapped: over two lines it reads as two bands.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.trialOcean,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  // The value in words, rather than left to the two ends of the track.
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
        // Under about 350 the hours drop to a line of their own rather than
        // ellipsising between the other two.
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
    // Held inside the track: a RangeSlider asserts on a handle outside its own
    // ends, and the hours can legitimately fall outside — an availability given
    // when the place opened at nine, read on a day it opens at ten.
    final start = (_isOpen ? minutesOfTimeOfDay(startTime!).toDouble() : _bandStart)
        .clamp(_bandStart, _bandEnd);
    final end = (_isOpen ? minutesOfTimeOfDay(endTime!).toDouble() : _bandEnd)
        .clamp(start, _bandEnd);

    return AppRangeSlider(
      dimsWhenDisabled: true,
      values: RangeValues(start, end),
      min: _bandStart,
      max: _bandEnd,
      // One stop per quarter hour, the step the hours are stored at.
      divisions: ((_bandEnd - _bandStart) / kQuarterHour).round(),
      labels: RangeLabels(
        formatTimeOfDayShort(timeOfDayFromMinutes(start.toInt())),
        formatTimeOfDayShort(timeOfDayFromMinutes(end.toInt())),
      ),
      // A closed band keeps its track, greyed, rather than leaving a hole.
      onChanged: _isOpen && enabled ? (values) => _report(values, start) : null,
    );
  }

  // Pinned to exactly [length], giving way at the end nobody is dragging:
  // whichever thumb has left [previousStart] is the one under the hand.
  (int, int) _heldAt(int startMinutes, int endMinutes, int length, double previousStart)
  {
    return startMinutes != previousStart.round()
        ? (endMinutes - length, endMinutes)
        : (startMinutes, startMinutes + length);
  }

  // RangeSlider stops the thumbs from crossing but lets them meet, and an
  // opening from nine to nine is not an opening.
  void _report(RangeValues values, double previousStart)
  {
    // The track is the whole band, but only what does not tread on the
    // neighbouring stretch is accepted.
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
      // The track starts half a thumb in.
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
    // A band that cannot be answered is a line and nothing more: the track
    // would refuse every hand, over the hours of an opening that is not there.
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
