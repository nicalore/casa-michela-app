import 'package:flutter/material.dart';

import '../../../core/utils/time_bucket.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/availability/utils/availability_strings.dart';
import '../../../features/lessons/models/availability_group.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/utils/booking_window.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/lessons/widgets/band_schedule.dart';

const List<String> kAvailabilityModes = [kPresenceMode, kOnlineMode];

// Days that open alike, which therefore share their hours.
class MobileDayGroup
{
  final String key;
  final List<DateTime> days;

  const MobileDayGroup({required this.key, required this.days});
}

typedef MobileWizardStep = ({MobileDayGroup group, String mode});

// Mirrors the desktop wizard's rules for a teacher's own availability.
class MobileAvailabilityDraft
{
  final String taxCode;
  final List<AvailabilityItem> availabilities;
  final List<OpeningDayItem> openingDays;

  // Read once: the wizard is short-lived, and the server enforces the rule.
  final DateTime now;

  // Set when editing, whose day is settled.
  final DateTime? editedDay;

  final List<DateTime> availableDays;

  Set<DateTime> _days = {};

  // Keyed by opening signature, so hours survive adding or removing days.
  final Map<String, Map<String, BandSchedule<AvailabilityItem>>> _bands = {};

  // Stored hours in bands that have closed: shown, never edited or dropped.
  final Map<String, Map<TimeBucket, List<BandStretch<AvailabilityItem>>>> frozen = {
    for (final mode in kAvailabilityModes)
      mode: {for (final bucket in TimeBucket.values) bucket: <BandStretch<AvailabilityItem>>[]},
  };

  // Writes already done, skipped when a failed save is tried again.
  final Set<Object> _saved = {};

  MobileAvailabilityDraft.create({
    required this.taxCode,
    required this.availabilities,
    required this.openingDays,
    required this.now,
    required DateTime day,
  })  : editedDay = null,
        availableDays = computeAvailableDays(now)
  {
    _days = {_firstOfferedFrom(day)};
  }

  MobileAvailabilityDraft.edit({
    required this.taxCode,
    required this.availabilities,
    required this.openingDays,
    required this.now,
    required DateTime day,
  })  : editedDay = day,
        availableDays = computeAvailableDays(now)
  {
    _days = {day};

    for (final slot in availabilities)
    {
      final TimeBucket? bucket = bucketFor(slot.startTime);

      if (slot.teacherTaxCode != taxCode || !isSameDate(slot.date, day) || bucket == null)
      {
        continue;
      }

      final stretch = BandStretch<AvailabilityItem>(
        startTime: slot.startTime,
        endTime: slot.endTime,
        existing: slot,
      );

      if (isClosed(day, bucket))
      {
        frozen[slot.mode]![bucket]!.add(stretch);
      }
      else
      {
        bandsOf(groups.single)[slot.mode]!.addStored(bucket, stretch);
      }
    }

    _reconcile();
  }

  bool get isEditing => editedDay != null;

  List<DateTime> get days => _days.toList()..sort();

  bool isPicked(DateTime day) => _days.any((picked) => isSameDate(picked, day));

  bool isClosed(DateTime day, TimeBucket bucket) => haveBookingsClosed(day, bucket, now);

  // Open window per mode and band, '-' where shut or closed.
  String _signatureOf(DateTime day)
  {
    return [
      for (final mode in kAvailabilityModes)
        for (final bucket in TimeBucket.values)
          switch (isClosed(day, bucket) ? null : openingWindowFor(openingDays, day, mode, bucket))
          {
            null => '-',
            final window => '${window.startMinutes}-${window.endMinutes}',
          },
    ].join('|');
  }

  List<MobileDayGroup> get groups
  {
    final Map<String, List<DateTime>> byKey = {};

    for (final day in days)
    {
      byKey.putIfAbsent(_signatureOf(day), () => []).add(day);
    }

    return [
      for (final entry in byKey.entries) MobileDayGroup(key: entry.key, days: entry.value),
    ];
  }

  Map<String, BandSchedule<AvailabilityItem>> bandsOf(MobileDayGroup group)
  {
    return _bands.putIfAbsent(
      group.key,
      () => {for (final mode in kAvailabilityModes) mode: BandSchedule<AvailabilityItem>()},
    );
  }

  // Alike by construction; the intersection is just the safe way to read it.
  OpeningWindow? _sharedWindow(MobileDayGroup group, String mode, TimeBucket bucket)
  {
    return sharedOpeningWindow(openingDays, group.days, mode, bucket);
  }

  OpeningWindow? windowFor(MobileDayGroup group, String mode, TimeBucket bucket)
  {
    if (group.days.any((day) => isClosed(day, bucket)))
    {
      return null;
    }

    return _sharedWindow(group, mode, bucket);
  }

  String shutLabelFor(MobileDayGroup group, String mode, TimeBucket bucket)
  {
    return _sharedWindow(group, mode, bucket) == null ? kAssociationShut : kAvailabilityShut;
  }

  // A mode shut all day on every band is still asked, to say so.
  List<String> _shownModesOf(MobileDayGroup group)
  {
    final List<String> open = kAvailabilityModes
        .where((mode) => TimeBucket.values.any((bucket) => windowFor(group, mode, bucket) != null))
        .toList();

    return open.isEmpty ? kAvailabilityModes : open;
  }

  List<MobileWizardStep> get steps
  {
    return [
      for (final group in groups)
        for (final mode in _shownModesOf(group)) (group: group, mode: mode),
    ];
  }

  List<String> _openModesOn(DateTime day)
  {
    return kAvailabilityModes
        .where((mode) => TimeBucket.values.any((bucket) =>
            !isClosed(day, bucket) && openingWindowFor(openingDays, day, mode, bucket) != null))
        .toList();
  }

  bool _isTaken(DateTime day, String mode)
  {
    final DateTime? edited = editedDay;

    if (edited != null && isSameDate(day, edited))
    {
      return false;
    }

    return hasAvailabilityOn(availabilities, taxCode, day, mode);
  }

  bool isOffered(DateTime day) => _openModesOn(day).any((mode) => !_isTaken(day, mode));

  String refusalFor(DateTime day)
  {
    final bool shut = !kAvailabilityModes.any((mode) => isOpenOn(openingDays, day, mode));

    return availabilityDayRefusal(day, shut: shut, closed: !shut && _openModesOn(day).isEmpty);
  }

  DateTime _firstOfferedFrom(DateTime day)
  {
    final List<DateTime> offered = availableDays.where(isOffered).toList();

    if (offered.isEmpty)
    {
      return day;
    }

    return offered.firstWhere((candidate) => !candidate.isBefore(day), orElse: () => offered.first);
  }

  void toggle(DateTime day)
  {
    if (isPicked(day))
    {
      _days.removeWhere((picked) => isSameDate(picked, day));
    }
    else
    {
      _days.add(day);
    }

    _reconcile();
  }

  void _reconcile()
  {
    final List<MobileDayGroup> current = groups;
    final Set<String> keys = {for (final group in current) group.key};

    _bands.removeWhere((key, _) => !keys.contains(key));

    for (final group in current)
    {
      for (final mode in kAvailabilityModes)
      {
        bandsOf(group)[mode]!.reconcile((bucket) => windowFor(group, mode, bucket));
      }
    }
  }

  Iterable<BandSchedule<AvailabilityItem>> get _schedules => _bands.values.expand((byMode) => byMode.values);

  bool _hasFrozen(String mode) => frozen[mode]!.values.any((held) => held.isNotEmpty);

  bool get _hasAnyBand => _schedules.any((schedule) => schedule.isNotEmpty) || kAvailabilityModes.any(_hasFrozen);

  // Every open band answered "No": the teacher's way of deleting the day.
  bool get isClearing => isEditing && !_hasAnyBand;

  // Why saving would be refused, in the desktop's words; null when it would go.
  String? get problem
  {
    if (_days.isEmpty)
    {
      return kPickADay;
    }

    if (!_hasAnyBand && !isClearing)
    {
      return availabilityMissingHours(editing: isEditing);
    }

    for (final group in groups)
    {
      for (final day in group.days)
      {
        for (final mode in kAvailabilityModes)
        {
          if (bandsOf(group)[mode]!.isNotEmpty && _isTaken(day, mode))
          {
            return availabilityTakenWarning(day, mode);
          }
        }
      }
    }

    return null;
  }

  // Completed writes are remembered, so a retry after a failure resumes.
  Future<void> save({
    required Future<void> Function(AvailabilityItem item) delete,
    required Future<void> Function(DateTime day, String mode, TimeOfDay start, TimeOfDay end) create,
    required Future<void> Function(AvailabilityItem existing, DateTime day, String mode, TimeOfDay start, TimeOfDay end) update,
  }) async
  {
    for (final schedule in _schedules)
    {
      schedule.fuse();
    }

    for (final item in _schedules.expand((schedule) => schedule.dropped).toList())
    {
      if (_saved.contains(item))
      {
        continue;
      }

      await delete(item);
      _saved.add(item);
    }

    for (final group in groups)
    {
      for (final day in group.days)
      {
        for (final mode in kAvailabilityModes)
        {
          for (final draft in bandsOf(group)[mode]!.all.toList())
          {
            final key = (day, mode, draft);

            if (_saved.contains(key))
            {
              continue;
            }

            final AvailabilityItem? existing = draft.existing;

            if (existing != null && isSameDate(day, existing.date))
            {
              await update(existing, day, mode, draft.startTime, draft.endTime);
            }
            else
            {
              await create(day, mode, draft.startTime, draft.endTime);
            }

            _saved.add(key);
          }
        }
      }
    }
  }
}
