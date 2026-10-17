import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/band_time_range_slider.dart';
import '../../../shared/widgets/desktop_tour.dart';
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

  // Overlaps counted once: rows may overlap while edited, a save refuses them.
  int minutesIn(TimeBucket bucket)
  {
    var minutes = 0;
    var cursor = 0;

    for (final stretch in _inTimeOrder(bucket))
    {
      final start = stretch.startMinutes > cursor ? stretch.startMinutes : cursor;

      if (stretch.endMinutes > start)
      {
        minutes += stretch.endMinutes - start;
        cursor = stretch.endMinutes;
      }
    }

    return minutes;
  }

  // The first band where two rows share time; rows touching end to start do not.
  TimeBucket? get overlapping
  {
    for (final bucket in TimeBucket.values)
    {
      var end = -1;

      for (final stretch in _inTimeOrder(bucket))
      {
        if (stretch.startMinutes < end)
        {
          return bucket;
        }

        if (stretch.endMinutes > end)
        {
          end = stretch.endMinutes;
        }
      }
    }

    return null;
  }

  // What a save writes, the rows shown left as they are: touching rows go as one.
  BandSchedule<T> fused()
  {
    final BandSchedule<T> copy = BandSchedule<T>()..dropped.addAll(dropped);

    for (final bucket in TimeBucket.values)
    {
      copy.of(bucket).addAll([
        for (final stretch in of(bucket))
          BandStretch<T>(startTime: stretch.startTime, endTime: stretch.endTime, existing: stretch.existing),
      ]);
    }

    return copy..fuse();
  }

  int get totalMinutes => TimeBucket.values.fold(0, (total, bucket) => total + minutesIn(bucket));

  List<TimeBucket> get bands => [for (final bucket in TimeBucket.values) if (of(bucket).isNotEmpty) bucket];

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

  // Merges touching/overlapping stretches; the survivor adopts a departing stretch's stored row.
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
// The parts a tour lights, each the first of its kind.
typedef BandScheduleTour = ({String yesNo, String hours, String add, String bin});

class BandScheduleField<T> extends StatelessWidget
{
  final BandSchedule<T> schedule;

  // Null where the association is shut in that band.
  final OpeningWindow? Function(TimeBucket bucket) windowFor;

  // disabledLabel: association shut; offLabel: open but unanswered.
  final String disabledLabel;
  final String offLabel;

  // Per-band shut wording; disabledLabel when null.
  final String Function(TimeBucket bucket)? disabledLabelFor;

  // Rows in a shut band: shown, never edited or dropped.
  final Map<TimeBucket, List<BandStretch<T>>> frozen;

  final String addLabel;

  final VoidCallback onChanged;

  final int minimumMinutes;

  // null: every band.
  final List<TimeBucket>? bands;

  // Its band chosen elsewhere, as where a lesson moves: no Sì/No.
  final bool fixed;

  final BandScheduleTour? tour;

  const BandScheduleField({
    super.key,
    required this.schedule,
    required this.windowFor,
    this.minimumMinutes = kMinimumBandMinutes,
    required this.onChanged,
    this.disabledLabel = 'Associazione chiusa',
    this.offLabel = 'Non indicato',
    this.disabledLabelFor,
    this.frozen = const {},
    this.addLabel = 'AGGIUNGI ORARIO',
    this.bands,
    this.fixed = false,
    this.tour,
  });

  void _report(void Function() change)
  {
    change();
    onChanged();
  }

  // The first open band with what the tour shows.
  TimeBucket? _firstWhere(bool Function(TimeBucket bucket, OpeningWindow window) test)
  {
    for (final bucket in bands ?? TimeBucket.values)
    {
      final OpeningWindow? window = windowFor(bucket);

      if (window != null && test(bucket, window))
      {
        return bucket;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context)
  {
    final BandScheduleTour? tour = this.tour;

    final TimeBucket? switchAt = tour == null ? null : _firstWhere((bucket, _) => schedule.of(bucket).length <= 1);
    final TimeBucket? hoursAt = tour == null ? null : _firstWhere((bucket, _) => schedule.of(bucket).isNotEmpty);
    final TimeBucket? addAt = tour == null
        ? null
        : _firstWhere((bucket, window) => schedule.of(bucket).isNotEmpty && schedule.firstGap(bucket, window) != null);
    final TimeBucket? binAt = tour == null ? null : _firstWhere((bucket, _) => schedule.of(bucket).length > 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, bucket) in (bands ?? TimeBucket.values).indexed) ...[
          if (index > 0) const Divider(height: 26, thickness: 1, color: AppTheme.trialLine),
          _buildBand(
            bucket,
            switchTour: bucket == switchAt ? tour?.yesNo : null,
            hoursTour: bucket == hoursAt ? tour?.hours : null,
            addTour: bucket == addAt ? tour?.add : null,
            binTour: bucket == binAt ? tour?.bin : null,
          ),
        ],
      ],
    );
  }

  Widget _buildBand(TimeBucket bucket, {String? switchTour, String? hoursTour, String? addTour, String? binTour})
  {
    final window = windowFor(bucket);

    if (window == null)
    {
      return _buildShut(bucket);
    }

    final stretches = schedule.of(bucket);
    final gap = stretches.isEmpty ? null : schedule.firstGap(bucket, window);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // First child: answering the band must not rebuild the switch (pill would jump, not slide).
        _buildStretch(bucket, window, 0, switchTour: switchTour, hoursTour: hoursTour, binTour: binTour),
        for (var index = 1; index < stretches.length; index++) ...[
          const SizedBox(height: 14),
          _buildStretch(bucket, window, index),
        ],
        if (gap != null) ...[
          const SizedBox(height: 10),
          AppAddRowButton(
            label: addLabel,
            dense: true,
            tour: addTour,
            onTap: () => _report(() => schedule.addStretch(bucket, window)),
          ),
        ],
      ],
    );
  }

  Widget _buildShut(TimeBucket bucket)
  {
    final held = frozen[bucket] ?? const [];

    if (held.isEmpty)
    {
      return _buildHeld(bucket, null, 0);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < held.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          _buildHeld(bucket, held[index], index),
        ],
      ],
    );
  }

  Widget _buildHeld(TimeBucket bucket, BandStretch<T>? stretch, int index)
  {
    return BandTimeRangeSlider(
      minimumMinutes: minimumMinutes,
      bucket: bucket,
      nameOverride: index == 0 ? null : '',
      startTime: stretch?.startTime,
      endTime: stretch?.endTime,
      enabled: false,
      disabledLabel: disabledLabelFor?.call(bucket) ?? disabledLabel,
      onChanged: (_, _) {},
    );
  }

  Widget _buildStretch(
    TimeBucket bucket,
    OpeningWindow window,
    int index, {
    String? switchTour,
    String? hoursTour,
    String? binTour,
  })
  {
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
        switchTour: switchTour,
        onChanged: (start, end) => _report(() => schedule.toggle(bucket, start, end)),
      );
    }

    return BandTimeRangeSlider(
      minimumMinutes: minimumMinutes,
      bucket: bucket,
      // Band named on the first stretch only.
      nameOverride: index == 0 ? null : '',
      startTime: stretches[index].startTime,
      endTime: stretches[index].endTime,
      windowStartMinutes: window.startMinutes,
      windowEndMinutes: window.endMinutes,
      trueLabel: 'Sì',
      falseLabel: 'No',
      switchTour: switchTour,
      trackTour: hoursTour,
      trailing: stretches.length == 1
          ? (fixed ? const SizedBox.shrink() : null)
          : DesktopTourTarget(
              id: binTour,
              child: FadeHoverIconButton(
                icon: Icons.delete_outline_rounded,
                color: AppTheme.trialDanger,
                hoverColor: AppTheme.trialGoldSurface,
                onTap: () => _report(() => schedule.removeAt(bucket, index)),
              ),
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
