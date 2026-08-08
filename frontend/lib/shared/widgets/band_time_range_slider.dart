import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import 'app_range_slider.dart';
import 'app_segmented_switch.dart';


// One band of a day, set by dragging its two ends along the band's own window.
//
// It replaces two dropdowns of quarter hours — twenty-eight of them for the
// morning alone — which asked for one interval in two separate hunts through a
// list and never showed how long the opening was or where it fell in the day.
// Here the track is the band: the morning runs from six to one, and what is
// picked out of it is the opening.
//
// The switch is what says whether the band is open at all. Two empty fields
// used to mean that, which is a thing that cannot be told from not having got
// round to filling them in yet.
class BandTimeRangeSlider extends StatelessWidget
{
  final TimeBucket bucket;

  // Both null when the band is closed. They are never one and not the other:
  // that is what the switch is for.
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  final void Function(TimeOfDay? start, TimeOfDay? end) onChanged;

  /// Narrows the track to a window inside the band. The association's own hours
  /// use the whole band, since that is what they are setting; a teacher's
  /// availability is offered inside what the association has open, so it passes
  /// those two ends and cannot be dragged outside them.
  final int? windowStartMinutes;
  final int? windowEndMinutes;

  // How far this band can be dragged, where that is not the whole track. The
  // track is the band, the same for every stretch inside it; the drag limit is
  // what the neighbouring stretches leave free. Keeping the two apart is what
  // stops each stretch from being drawn on a scale of its own.
  final int? dragMinMinutes;
  final int? dragMaxMinutes;

  // How short the stretch may be. An opening can be given in quarter hours, a
  // presence cannot: under half an hour is a pupil arriving and leaving.
  final int minimumMinutes;

  /// Off where the answer cannot be given at all — the association is shut in
  /// this band. The row stays, greyed, saying so, because a band that vanished
  /// would leave the day looking shorter than it is.
  final bool enabled;

  /// What the row says in place of its hours where the question cannot be
  /// answered at all — the association is shut in this band.
  final String disabledLabel;

  /// And what it says where it can be answered and has not been. The two are
  /// the same thing for the association's own hours, which is why it says
  /// "Chiuso" either way; for a teacher's availability they are not: a band the
  /// association opens and the teacher did not take is not a closed band.
  final String offLabel;

  /// The two sides of the switch. The association's hours are open or closed; a
  /// teacher's availability is given or not.
  final String trueLabel;
  final String falseLabel;

  /// What the row is called. Left out, it is the name of the band — which is
  /// what a band answered once wants. A band made of several stretches names
  /// itself on the first of them and passes an empty string to the rest: they
  /// are the same band, and repeating "Pomeriggio" down the card would read as
  /// three afternoons.
  final String? nameOverride;

  /// Put where the switch would be. One stretch among several is taken away on
  /// its own rather than by turning the whole band off, so it carries a trash
  /// there instead.
  final Widget? trailing;

  const BandTimeRangeSlider({
    super.key,
    required this.bucket,
    required this.startTime,
    required this.endTime,
    required this.onChanged,
    this.minimumMinutes = kQuarterHour,
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

  // How far the thumbs may reach: what the neighbouring stretches leave free,
  // or the whole track where there is nobody alongside.
  double get _dragStart => (dragMinMinutes?.toDouble() ?? _bandStart).clamp(_bandStart, _bandEnd);

  double get _dragEnd => (dragMaxMinutes?.toDouble() ?? _bandEnd).clamp(_dragStart, _bandEnd);

  // A band being opened starts as the whole window. It is one drag away from
  // anything else, and it is the only default that is never a guess about what
  // this association's morning looks like.
  void _toggle(bool open)
  {
    // Choosing the side already chosen changes nothing. Without this, tapping
    // "Aperta" on a band that is open threw away the hours set on it and put
    // the whole band back.
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
      // The name of a band is one word and never wraps: broken over two lines
      // beside the switch it reads as two bands.
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
        // The name, the hours and the switch want about 350 between them. Under
        // that the hours drop to a line of their own rather than being squeezed
        // between the other two, which is where a range would have started
        // ellipsising away.
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

  Widget _buildTrack(BuildContext context)
  {
    // Held inside the track whatever comes in. A range slider cannot draw a
    // handle outside its own two ends and asserts rather than trying, and the
    // hours handed to it can legitimately fall outside: an availability given
    // when the association opened at nine, read back on a day it now opens at
    // ten, is exactly that. What is drawn is what the window can hold; the form
    // above puts the same clamp on what it will save.
    final start = (_isOpen ? minutesOfTimeOfDay(startTime!).toDouble() : _bandStart)
        .clamp(_bandStart, _bandEnd);
    final end = (_isOpen ? minutesOfTimeOfDay(endTime!).toDouble() : _bandEnd)
        .clamp(start, _bandEnd);

    return AppRangeSlider(
      dimsWhenDisabled: true,
      values: RangeValues(start, end),
      min: _bandStart,
      max: _bandEnd,
      // One stop every quarter of an hour, which is the step the hours are
      // stored at: the handles cannot land anywhere the backend could not
      // keep.
      divisions: ((_bandEnd - _bandStart) / kQuarterHour).round(),
      labels: RangeLabels(
        formatTimeOfDayShort(timeOfDayFromMinutes(start.toInt())),
        formatTimeOfDayShort(timeOfDayFromMinutes(end.toInt())),
      ),
      // Closed bands keep their track on screen, greyed: it says the band
      // exists and is shut, rather than leaving a hole where it was.
      onChanged: _isOpen && enabled ? (values) => _report(values, start, end) : null,
    );
  }

  // A band cannot begin and end at the same minute: dragged onto the other end,
  // a handle stops one stop short of it. RangeSlider stops the two from crossing
  // on its own but is happy to let them meet, and an opening from nine to nine
  // is not an opening.
  void _report(RangeValues values, double previousStart, double previousEnd)
  {
    // Stopped where the free space ends. The slider would let them go — the
    // track is the whole band — but only what does not tread on the neighbouring
    // stretch is accepted, and a thumb that is not accepted stays where it was.
    var startMinutes = values.start.round().clamp(_dragStart.round(), _dragEnd.round());
    var endMinutes = values.end.round().clamp(_dragStart.round(), _dragEnd.round());

    if (endMinutes - startMinutes < minimumMinutes)
    {
      // Whichever one moved is the one being dragged, and the one that gives
      // way is the other.
      if (startMinutes != previousStart.round())
      {
        startMinutes = endMinutes - minimumMinutes;
      }
      else
      {
        endMinutes = startMinutes + minimumMinutes;
      }
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
      // Lined up with the ends of the track, which start half a thumb in.
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
    // A band that cannot be answered is a line and nothing more. The track
    // under it would be a control that refuses every hand laid on it, and the
    // two hours written under its ends would be the hours of an opening that
    // is not there.
    if (!enabled)
    {
      return _buildHeader();
    }

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
