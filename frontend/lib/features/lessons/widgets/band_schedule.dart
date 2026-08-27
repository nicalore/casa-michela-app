import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/band_time_range_slider.dart';
import '../../../shared/widgets/shared_components.dart';
import '../utils/opening_window.dart';

class BandStretch<T>
{
  TimeOfDay startTime;
  TimeOfDay endTime;

  // The stored row backing this stretch; null when never saved.
  T? existing;

  BandStretch({required this.startTime, required this.endTime, this.existing});

  int get startMinutes => minutesOfTimeOfDay(startTime);

  int get endMinutes => minutesOfTimeOfDay(endTime);

  int get minutes => endMinutes - startMinutes;
}

class BandSchedule<T>
{
  final Map<TimeBucket, List<BandStretch<T>>> _byBucket = {
    for (final bucket in TimeBucket.values) bucket: <BandStretch<T>>[],
  };

  // Stored rows no longer given; deleted when the editing window is saved.
  final List<T> dropped = [];

  List<BandStretch<T>> of(TimeBucket bucket) => _byBucket[bucket]!;

  // Copy in clock order; the real list keeps insertion order, which is what is shown.
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

  Iterable<BandStretch<T>> get all sync*
  {
    for (final bucket in TimeBucket.values)
    {
      yield* of(bucket);
    }
  }

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

  void _drop(BandStretch<T> stretch)
  {
    final existing = stretch.existing;

    if (existing != null)
    {
      dropped.add(existing);
      stretch.existing = null;
    }
  }

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

  void move(TimeBucket bucket, int index, TimeOfDay start, TimeOfDay end)
  {
    of(bucket)[index]
      ..startTime = start
      ..endTime = end;
  }

  void addStretch(TimeBucket bucket, OpeningWindow window)
  {
    final gap = firstGap(bucket, window);

    if (gap == null)
    {
      return;
    }

    // Appended, not inserted in clock order: reordering would move the row under the user.
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

  // Drag bounds keeping stretches from overlapping; neighbours are read off
  // the clock, not the list order.
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

  // First free gap of at least a quarter hour, or null when the window is full.
  (int, int)? firstGap(TimeBucket bucket, OpeningWindow window)
  {
    var cursor = window.startMinutes;

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

  // Merges touching/overlapping stretches within a band (14-15 + 15-17 becomes
  // 14-17). The survivor adopts a departing stretch's stored row when it has none.
  void fuse()
  {
    for (final bucket in TimeBucket.values)
    {
      final gone = Set<BandStretch<T>>.identity();

      BandStretch<T>? open;

      for (final stretch in _inTimeOrder(bucket))
      {
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

  // Clamps every stretch back inside the (possibly narrowed) opening windows.
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

      final gone = Set<BandStretch<T>>.identity();
      var cursor = window.startMinutes;

      for (final stretch in _inTimeOrder(bucket))
      {
        final start = stretch.startMinutes.clamp(cursor, window.endMinutes);
        final end = stretch.endMinutes.clamp(start, window.endMinutes);

        if (end - start < kQuarterHour)
        {
          // A band's only stretch squeezed to nothing becomes the whole opening.
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

// Mutates the schedule it is handed and reports through [onChanged].
class BandScheduleField<T> extends StatelessWidget
{
  final BandSchedule<T> schedule;

  // Null where the association is shut in that band.
  final OpeningWindow? Function(TimeBucket bucket) windowFor;

  // disabledLabel: association shut; offLabel: open but unanswered.
  final String disabledLabel;
  final String offLabel;

  final String addLabel;

  final VoidCallback onChanged;

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

  Widget _buildBand(TimeBucket bucket)
  {
    final window = windowFor(bucket);
    final stretches = window == null ? const [] : schedule.of(bucket);
    final gap = window == null || stretches.isEmpty ? null : schedule.firstGap(bucket, window);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kept as the first child so answering the band does not rebuild the
        // switch from scratch (its pill would appear instead of slide).
        _buildStretch(bucket, window, 0),
        for (var index = 1; index < stretches.length; index++) ...[
          const SizedBox(height: 14),
          _buildStretch(bucket, window, index),
        ],
        if (gap != null) ...[
          const SizedBox(height: 10),
          AppAddRowButton(
            label: addLabel,
            dense: true,
            onTap: () => _report(() => schedule.addStretch(bucket, window!)),
          ),
        ],
      ],
    );
  }

  Widget _buildStretch(TimeBucket bucket, OpeningWindow? window, int index)
  {
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
        trueLabel: 'Sì',
        falseLabel: 'No',
        onChanged: (start, end) => _report(() => schedule.toggle(bucket, start, end)),
      );
    }

    final bounds = schedule.boundsAt(bucket, window, index);

    return BandTimeRangeSlider(
      minimumMinutes: minimumMinutes,
      bucket: bucket,
      // Band named on the first stretch only.
      nameOverride: index == 0 ? null : '',
      startTime: stretches[index].startTime,
      endTime: stretches[index].endTime,
      windowStartMinutes: window.startMinutes,
      windowEndMinutes: window.endMinutes,
      dragMinMinutes: bounds.$1,
      dragMaxMinutes: bounds.$2,
      trueLabel: 'Sì',
      falseLabel: 'No',
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
