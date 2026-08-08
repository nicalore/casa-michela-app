import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/band_time_range_slider.dart';
import '../../../shared/widgets/shared_components.dart';
import '../utils/opening_window.dart';

/// One stretch of hours inside one band, and the row it came from where it was
/// already stored.
///
/// A stretch exists because it was given: there is no such thing as one with no
/// hours on it. A band nobody answered is an empty list, not a draft holding
/// two nulls.
class BandStretch<T>
{
  TimeOfDay startTime;
  TimeOfDay endTime;

  /// The stored row this stretch is, where it is one already. Null on a stretch
  /// that has never been saved.
  T? existing;

  BandStretch({required this.startTime, required this.endTime, this.existing});

  int get startMinutes => minutesOfTimeOfDay(startTime);

  int get endMinutes => minutesOfTimeOfDay(endTime);

  int get minutes => endMinutes - startMinutes;
}

/// A day answered band by band: the three bands, each holding as many stretches
/// of hours as were given for it.
///
/// It is what a teacher's availability in one mode is made of, and what a
/// pupil's hours in one mode are made of. The two ask different questions —
/// when can you teach, when are you here — and hold the answer the same way.
class BandSchedule<T>
{
  final Map<TimeBucket, List<BandStretch<T>>> _byBucket = {
    for (final bucket in TimeBucket.values) bucket: <BandStretch<T>>[],
  };

  /// Rows that were stored and are no longer given: they go once the window
  /// they were edited in is saved.
  final List<T> dropped = [];

  List<BandStretch<T>> of(TimeBucket bucket) => _byBucket[bucket]!;

  // The same stretches read from morning to evening. A copy: the real list
  // keeps the order the stretches were given in, and that is what is shown.
  List<BandStretch<T>> _inTimeOrder(TimeBucket bucket) =>
      [...of(bucket)]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  bool get isEmpty => TimeBucket.values.every((bucket) => of(bucket).isEmpty);

  bool get isNotEmpty => !isEmpty;

  int get totalMinutes
  {
    var minutes = 0;

    for (final bucket in TimeBucket.values)
    {
      for (final stretch in of(bucket))
      {
        minutes += stretch.minutes;
      }
    }

    return minutes;
  }

  /// Every stretch given, band by band, ognuna nell'ordine in cui è stata data.
  Iterable<BandStretch<T>> get all sync*
  {
    for (final bucket in TimeBucket.values)
    {
      yield* of(bucket);
    }
  }

  // A row that was saved. Here the order of the day is the only one there is —
  // of rows read back from storage nobody knows the order they were given in —
  // and a reopened day reads from morning to evening.
  void addStored(TimeBucket bucket, BandStretch<T> stretch)
  {
    of(bucket)
      ..add(stretch)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  void clear()
  {
    for (final bucket in TimeBucket.values)
    {
      of(bucket).clear();
    }

    dropped.clear();
  }

  // A stretch that is no longer given. Where it was stored, the row goes with
  // it once the window is saved.
  void _drop(BandStretch<T> stretch)
  {
    final existing = stretch.existing;

    if (existing != null)
    {
      dropped.add(existing);
      stretch.existing = null;
    }
  }

  /// Given a band, the whole of what the association has open in it: the widest
  /// answer there is, and the one that has to be narrowed rather than built up
  /// from nothing. Taken away, the band goes back to being unanswered, with
  /// however many stretches were on it.
  void toggle(TimeBucket bucket, TimeOfDay? start, TimeOfDay? end)
  {
    final stretches = of(bucket);

    if (start == null || end == null)
    {
      for (final stretch in stretches)
      {
        _drop(stretch);
      }

      stretches.clear();

      return;
    }

    stretches.add(BandStretch<T>(startTime: start, endTime: end));
  }

  /// One stretch dragged: only its own two ends move.
  void move(TimeBucket bucket, int index, TimeOfDay start, TimeOfDay end)
  {
    of(bucket)[index]
      ..startTime = start
      ..endTime = end;
  }

  /// One more stretch in the same band, filling the first room left in it. The
  /// whole of the gap, for the same reason a band opens as the whole of its
  /// opening: it is the widest true answer, and narrowing it is one drag.
  void addStretch(TimeBucket bucket, OpeningWindow window)
  {
    final gap = firstGap(bucket, window);

    if (gap == null)
    {
      return;
    }

    // At the end, where it was asked for. The gap filled can fall before an
    // hour already given, but putting it above would push the hour being looked
    // at down a row, and the new row would appear somewhere other than where one
    // pressed. The stretches stay in the order they were given, even when that
    // is not the clock's.
    of(bucket).add(
      BandStretch<T>(
        startTime: timeOfDayFromMinutes(gap.$1),
        endTime: timeOfDayFromMinutes(gap.$2),
      ),
    );
  }

  void removeAt(TimeBucket bucket, int index)
  {
    _drop(of(bucket).removeAt(index));
  }

// What a stretch may be dragged across: the room between the one before it and
// the one after, inside the association's opening. Two stretches of the same
// band cannot be made to overlap, because neither can be dragged as far as the
// other — the rule is the shape of the control rather than a refusal at the end
// of the form.
//
// Which comes before and which after is read off the clock and not off the list:
// the stretches sit in the order they were given, so the row above may well be
// the late-afternoon one.
  (int, int) boundsAt(TimeBucket bucket, OpeningWindow window, int index)
  {
    final stretches = of(bucket);
    final self = stretches[index];

    var start = window.startMinutes;
    var end = window.endMinutes;

    for (var other = 0; other < stretches.length; other++)
    {
      if (other == index)
      {
        continue;
      }

      final neighbour = stretches[other];

      // No pair overlaps, so every other stretch lies wholly before or wholly
      // after: of the former the latest counts, of the latter the earliest.
      if (neighbour.endMinutes <= self.startMinutes)
      {
        start = neighbour.endMinutes > start ? neighbour.endMinutes : start;
      }
      else if (neighbour.startMinutes >= self.endMinutes)
      {
        end = neighbour.startMinutes < end ? neighbour.startMinutes : end;
      }
    }

    return (start, end);
  }

  /// The first stretch of the band still free, in the order of the day, or null
  /// where the opening is spoken for from end to end. A quarter of an hour is
  /// the least that can be stored, so anything narrower is not room.
  (int, int)? firstGap(TimeBucket bucket, OpeningWindow window)
  {
    var cursor = window.startMinutes;

    // The first free slot is a question about the day and not about the list:
    // finding it means walking the stretches first to last in time, an order the
    // list no longer keeps.
    for (final stretch in _inTimeOrder(bucket))
    {
      if (stretch.startMinutes - cursor >= kQuarterHour)
      {
        return (cursor, stretch.startMinutes);
      }

      cursor = stretch.endMinutes > cursor ? stretch.endMinutes : cursor;
    }

    if (window.endMinutes - cursor >= kQuarterHour)
    {
      return (cursor, window.endMinutes);
    }

    return null;
  }

  // Two stretches that read as one become one: 14-15 and 15-17 are 14-17, and
  // are saved that way instead of as two rows saying the same thing in pieces.
  //
  // Only within the same band, which is why this work happens here: the
  // stretches are already split by band, and an afternoon ending when the
  // evening begins stays two things, because the association keeps them apart.
  //
  // Of the two the first stays, where it already sits in the list: what merges
  // are the hours, not the order they were given in. If the surviving row was
  // not saved and the departing one was, it takes the saved row over and
  // stretches it, instead of deleting one to rewrite an identical other.
  void fuse()
  {
    for (final bucket in TimeBucket.values)
    {
      final gone = Set<BandStretch<T>>.identity();

      BandStretch<T>? open;

      for (final stretch in _inTimeOrder(bucket))
      {
        // Detached from the one before: it starts a stretch of its own.
        if (open == null || stretch.startMinutes > open.endMinutes)
        {
          open = stretch;

          continue;
        }

        if (stretch.endMinutes > open.endMinutes)
        {
          open.endTime = stretch.endTime;
        }

        if (open.existing == null)
        {
          open.existing = stretch.existing;
          stretch.existing = null;
        }

        _drop(stretch);
        gone.add(stretch);
      }

      of(bucket).removeWhere(gone.contains);
    }
  }

  /// What is given has to stay inside what the association has open, and what
  /// is open changes under the form: a second day added narrows every band to
  /// what the two days share, and a band the new day is shut in cannot be given
  /// at all. Rather than leaving hours nobody could save — and that the slider
  /// cannot even draw — the bands are brought back inside as soon as the window
  /// moves.
  void reconcile(OpeningWindow? Function(TimeBucket bucket) windowFor)
  {
    for (final bucket in TimeBucket.values)
    {
      final stretches = of(bucket);

      if (stretches.isEmpty)
      {
        continue;
      }

      final window = windowFor(bucket);

      if (window == null)
      {
        for (final stretch in stretches)
        {
          _drop(stretch);
        }

        stretches.clear();

        continue;
      }

      // Walked in the order of the day, each stretch held after the one before
      // it: hours squeezed by a narrower window must not end up running over
      // each other, which is exactly what clamping them one by one would do.
      //
      // Walked on the clock, though, and not on the list: what narrows are the
      // hours, while the rows stay where the user put them.
      final gone = Set<BandStretch<T>>.identity();
      var cursor = window.startMinutes;

      for (final stretch in _inTimeOrder(bucket))
      {
        final start = stretch.startMinutes.clamp(cursor, window.endMinutes);
        final end = stretch.endMinutes.clamp(start, window.endMinutes);

        if (end - start < kQuarterHour)
        {
          // The one stretch of a band squeezed to nothing becomes the whole of
          // what is left open: that is the answer the band would be given if it
          // were answered now. Where there are others, there is simply no room
          // left for this one and it goes.
          if (stretches.length == 1)
          {
            stretch
              ..startTime = window.start
              ..endTime = window.end;
          }
          else
          {
            _drop(stretch);
            gone.add(stretch);
          }

          continue;
        }

        stretch
          ..startTime = timeOfDayFromMinutes(start)
          ..endTime = timeOfDayFromMinutes(end);

        cursor = end;
      }

      stretches.removeWhere(gone.contains);
    }
  }
}

/// The three bands of a day, each with the hours given in it and the room to
/// give one more.
///
/// The field mutates the schedule it is handed and says so through [onChanged],
/// which is the form's own setState: the answer belongs to the window that
/// asked for it, not to this row of controls.
class BandScheduleField<T> extends StatelessWidget
{
  final BandSchedule<T> schedule;

  /// What the association has open in that band, or null where it is shut.
  final OpeningWindow? Function(TimeBucket bucket) windowFor;

  /// What a band says where the association is shut in it, and what it says
  /// where it is open and nobody has answered. The two are different things: a
  /// band the association opens and nobody took is not a closed band.
  final String disabledLabel;
  final String offLabel;

  final String addLabel;

  final VoidCallback onChanged;

  // The shortest stretch that can be given: half an hour, for a pupil's hours
  // as for the ones a teacher offers. Below that, it is somebody arriving and
  // leaving.
  final int minimumMinutes;

  const BandScheduleField({
    super.key,
    required this.schedule,
    required this.windowFor,
    this.minimumMinutes = kMinimumBandMinutes,
    required this.onChanged,
    this.disabledLabel = 'Associazione chiusa',
    this.offLabel = 'Non indicato',
    this.addLabel = 'AGGIUNGI ORARIO',
  });

  void _report(void Function() change)
  {
    change();
    onChanged();
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bucket in TimeBucket.values) ...[
          _buildBand(bucket),
          if (bucket != TimeBucket.values.last)
            const Divider(height: 26, thickness: 1, color: AppTheme.trialLine),
        ],
      ],
    );
  }

  // One band: the hours given in it, one track each, and the room to give one
  // more. Two stretches of the same afternoon are two stretches, not two
  // afternoons — so the band is named once, over them.
  Widget _buildBand(TimeBucket bucket)
  {
    final window = windowFor(bucket);
    final stretches = window == null ? const [] : schedule.of(bucket);
    final gap = window == null || stretches.isEmpty ? null : schedule.firstGap(bucket, window);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The band's own row is always the first child of the same column,
        // whether it is shut, unanswered or holding hours. Answering it changes
        // what stands under it — a track, a button — and if that turned the row
        // itself into a different place in the tree, the switch would be built
        // again from nothing on every answer and its pill would appear on the
        // other side rather than sliding there.
        _buildStretch(bucket, window, 0),
        for (var index = 1; index < stretches.length; index++) ...[
          const SizedBox(height: 14),
          _buildStretch(bucket, window, index),
        ],
        // Only where there is somewhere to put it: an opening taken from end to
        // end has no room for another stretch, and a button that could only
        // refuse is not a button.
        if (gap != null) ...[
          const SizedBox(height: 10),
          AppAddRowButton(
            label: addLabel,
            // Three bands to a card, each able to take another stretch: at the
            // ordinary size the buttons weighed more than the hours they add to.
            dense: true,
            onTap: () => _report(() => schedule.addStretch(bucket, window!)),
          ),
        ],
      ],
    );
  }

  // One row of a band: the association shut in it, the band open and not taken,
  // or one of the stretches of hours given for it. All three are the same
  // control saying different things, which is what lets it stay itself across
  // an answer.
  Widget _buildStretch(TimeBucket bucket, OpeningWindow? window, int index)
  {
    // Shut: a line saying so, and nothing to answer with.
    if (window == null)
    {
      return BandTimeRangeSlider(
        minimumMinutes: minimumMinutes,
        bucket: bucket,
        startTime: null,
        endTime: null,
        enabled: false,
        disabledLabel: disabledLabel,
        onChanged: (_, _) {},
      );
    }

    final stretches = schedule.of(bucket);

    // Open and not taken: the switch is the whole of the question.
    if (stretches.isEmpty)
    {
      return BandTimeRangeSlider(
        minimumMinutes: minimumMinutes,
        bucket: bucket,
        startTime: null,
        endTime: null,
        windowStartMinutes: window.startMinutes,
        windowEndMinutes: window.endMinutes,
        offLabel: offLabel,
        // The switch answers "is this band taken?", and the two words the app
        // gives a yes-or-no are the ones that fit beside the name of the band
        // and its hours.
        trueLabel: 'Sì',
        falseLabel: 'No',
        onChanged: (start, end) => _report(() => schedule.toggle(bucket, start, end)),
      );
    }

    final bounds = schedule.boundsAt(bucket, window, index);

    return BandTimeRangeSlider(
      minimumMinutes: minimumMinutes,
      bucket: bucket,
      // Named on the first alone: the ones under it are the same band, and
      // saying "Pomeriggio" three times would read as three afternoons.
      nameOverride: index == 0 ? null : '',
      startTime: stretches[index].startTime,
      endTime: stretches[index].endTime,
      // The track is the band, the same for every stretch inside it: two hours
      // of the same afternoon read one under the other on the same scale, and
      // each sits where it really sits in the day.
      //
      // Handing it the free space instead left the first stretch a track exactly
      // as long as itself — full from end to end — and gave a stretch between
      // two others one that looked like none of the rest of the same band.
      windowStartMinutes: window.startMinutes,
      windowEndMinutes: window.endMinutes,
      // The free space stays, but as the drag limit: two hours of the same band
      // still cannot overlap, because neither reaches where the other is.
      dragMinMinutes: bounds.$1,
      dragMaxMinutes: bounds.$2,
      trueLabel: 'Sì',
      falseLabel: 'No',
      // With one stretch on it, the switch takes the band away; with several,
      // each is thrown away on its own, and the last one thrown away leaves the
      // band unanswered again.
      trailing: stretches.length == 1
          ? null
          : FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDanger,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: () => _report(() => schedule.removeAt(bucket, index)),
            ),
      onChanged: (start, end)
      {
        if (start == null || end == null)
        {
          _report(() => schedule.toggle(bucket, null, null));

          return;
        }

        _report(() => schedule.move(bucket, index, start, end));
      },
    );
  }
}
