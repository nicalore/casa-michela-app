import 'package:flutter/material.dart' show TimeOfDay;


import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/ministry_subject_item.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/bookings/utils/booking_replacement.dart' show withLeftOut;
import '../../../features/lessons/models/band_offer.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/models/subject_request.dart';
import '../../../features/lessons/utils/booking_window.dart';
import '../../../features/lessons/utils/booking_wizard_strings.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/lessons/widgets/band_schedule.dart';
import '../../../features/lessons/widgets/booking_fields_section.dart' show maxDailyMinutesPerDiscipline;
import '../../../features/lessons/widgets/subject_request_tile.dart' show ministrySubjectName;
import '../../../features/people/models/person_item.dart';

// Days whose openings match, asked together.
class MobileBookingGroup
{
  final String key;
  final List<DateTime> days;

  const MobileBookingGroup({required this.key, required this.days});
}

enum MobileBookingStepKind { days, hours, subjects }

// Subjects are asked band by band: [band] is set on those steps only.
typedef MobileBookingStep = ({MobileBookingStepKind kind, MobileBookingGroup? group, TimeBucket? band});

// Mirrors the desktop presence wizard's rules, without UI.
class MobileBookingDraft
{
  final PersonItem pupil;
  final String mode;

  final bool isSelf;

  final bool hoursOnly;

  final bool subjectsOnly;

  // Bands the wizard may touch; null means every band.
  late final Set<TimeBucket>? scope;

  // Open bands outside [scope], sent back unchanged so the server keeps them.
  final List<PresenceItem> held = [];

  final List<PresenceItem> presences;
  final List<OpeningDayItem> openingDays;
  final List<MinistrySubjectItem> ministrySubjects;

  // Read once: the wizard is short-lived, and the server enforces the rule.
  final DateTime now;

  final List<DateTime> availableDays;

  // Set when the day has a row: the day is then edited, never created.
  final PresenceItem? existing;

  Set<DateTime> _days = {};

  // Keyed by opening signature, so answers survive adding or removing days.
  final Map<String, BandSchedule<PresenceItem>> _hours = {};
  final Map<String, List<SubjectRequestDraft>> _requests = {};

  // Closed bands: the server refuses changes, so shown, never edited.
  final Map<TimeBucket, List<BandStretch<PresenceItem>>> frozen = {
    for (final bucket in TimeBucket.values) bucket: <BandStretch<PresenceItem>>[],
  };

  final List<SubjectRequestDraft> frozenRequests = [];

  // Days already written, skipped when a failed save is tried again.
  final Set<DateTime> _saved = {};

  // Set once a save is tried: the page may be stale even if the wizard is then abandoned.
  bool triedToSave = false;

  MobileBookingDraft({
    required this.pupil,
    required this.mode,
    required this.presences,
    required this.openingDays,
    required this.ministrySubjects,
    required this.now,
    required DateTime day,
    this.existing,
    this.isSelf = false,
    this.hoursOnly = false,
    this.subjectsOnly = false,
    TimeBucket? band,
    bool onlyFreeBands = false,
  }) : availableDays = computeAvailableDays(now)
  {
    final PresenceItem? edited = existing;

    scope = band != null ? {band} : (onlyFreeBands && edited != null ? _freeBandsOn(edited.date) : null);

    if (edited == null)
    {
      _days = {_firstOfferedFrom(day)};

      return;
    }

    _days = {edited.date};

    final MobileBookingGroup group = groups.single;

    for (final presence in presences)
    {
      if (presence.studentTaxCode != pupil.fiscalCode || !isSameDate(presence.date, edited.date) || presence.mode != mode)
      {
        continue;
      }

      final TimeBucket? bucket = bucketFor(presence.startTime);
      final bool closed = bucket != null && isClosed(edited.date, bucket);

      if (!closed && bucket != null && !inScope(bucket))
      {
        held.add(presence);

        continue;
      }

      if (bucket != null)
      {
        final stretch = BandStretch<PresenceItem>(
          startTime: presence.startTime,
          endTime: presence.endTime,
          existing: presence,
        );

        if (closed)
        {
          frozen[bucket]!.add(stretch);
        }
        else
        {
          hoursOf(group).addStored(bucket, stretch);
        }
      }

      for (final booking in presence.bookings)
      {
        (closed ? frozenRequests : requestsOf(group)).add(SubjectRequestDraft.fromBooking(
          booking,
          ministrySubjectName: ministrySubjectName(ministrySubjects, booking.ministrySubjectId, fallback: ''),
          band: bucket,
        ));
      }
    }

    _reconcile();
  }

  bool get isEditing => existing != null;

  bool inScope(TimeBucket band) => scope?.contains(band) ?? true;

  List<TimeBucket> get bands => [for (final band in TimeBucket.values) if (inScope(band)) band];

  // Open and still bookable, with no hours of the pupil's in either mode.
  Set<TimeBucket> _freeBandsOn(DateTime day)
  {
    return {
      for (final band in TimeBucket.values)
        if (!isClosed(day, band) &&
            openingWindowFor(openingDays, day, mode, band) != null &&
            !presences.any((presence) =>
                presence.studentTaxCode == pupil.fiscalCode &&
                isSameDate(presence.date, day) &&
                bucketFor(presence.startTime) == band))
          band,
    };
  }

  List<DateTime> get days => _days.toList()..sort();

  bool isPicked(DateTime day) => _days.any((picked) => isSameDate(picked, day));

  bool isClosed(DateTime day, TimeBucket bucket) => haveBookingsClosed(day, bucket, now);

  String get _whose => 'di ${pupil.firstName}';

  // Bands of [day] the pupil has booked the other way.
  Set<TimeBucket> _takenOn(DateTime day)
  {
    return {
      for (final presence in presences)
        if (presence.mode == _otherMode && presence.studentTaxCode == pupil.fiscalCode && isSameDate(presence.date, day))
          ?bucketFor(presence.startTime),
    };
  }

  // Per mode and band: the window, '-' shut or closed, 'x' taken the other way.
  String _signatureOf(DateTime day)
  {
    final Set<TimeBucket> taken = _takenOn(day);

    return [
      for (final mode in const [kPresenceMode, kOnlineMode])
        for (final bucket in TimeBucket.values)
          switch (isClosed(day, bucket) ? null : openingWindowFor(openingDays, day, mode, bucket))
          {
            null => '-',
            _ when mode == this.mode && taken.contains(bucket) => 'x',
            final window => '${window.startMinutes}-${window.endMinutes}',
          },
    ].join('|');
  }

  List<MobileBookingGroup> get groups
  {
    final Map<String, List<DateTime>> byKey = {};

    for (final day in days)
    {
      byKey.putIfAbsent(_signatureOf(day), () => []).add(day);
    }

    return [
      for (final entry in byKey.entries) MobileBookingGroup(key: entry.key, days: entry.value),
    ];
  }

  BandSchedule<PresenceItem> hoursOf(MobileBookingGroup group) => _hours.putIfAbsent(group.key, BandSchedule.new);

  List<SubjectRequestDraft> requestsOf(MobileBookingGroup group) => _requests.putIfAbsent(group.key, () => []);

  OpeningWindow? _openWindowFor(MobileBookingGroup group, TimeBucket bucket)
  {
    if (group.days.any((day) => isClosed(day, bucket)))
    {
      return null;
    }

    return sharedOpeningWindow(openingDays, group.days, mode, bucket);
  }

  String get _otherMode => mode == kPresenceMode ? kOnlineMode : kPresenceMode;

  // One mode per band: the bands booked the other way on these days.
  Set<TimeBucket> _takenElsewhere(MobileBookingGroup group)
  {
    return {
      for (final presence in presences)
        if (presence.mode == _otherMode &&
            presence.studentTaxCode == pupil.fiscalCode &&
            group.days.any((day) => isSameDate(day, presence.date)))
          ?bucketFor(presence.startTime),
    };
  }

  OpeningWindow? windowFor(MobileBookingGroup group, TimeBucket bucket)
  {
    if (!inScope(bucket))
    {
      return null;
    }

    if (_takenElsewhere(group).contains(bucket))
    {
      return null;
    }

    return _openWindowFor(group, bucket);
  }

  String shutLabelFor(MobileBookingGroup group, TimeBucket bucket)
  {
    if (_takenElsewhere(group).contains(bucket))
    {
      return takenByOtherMode(_otherMode);
    }

    return sharedOpeningWindow(openingDays, group.days, mode, bucket) == null ? kAssociationShutBand : kBookingsShutBand;
  }

  bool _opensIn(MobileBookingGroup group) => bands.any((bucket) => _openWindowFor(group, bucket) != null);

  List<MobileBookingStep> get steps
  {
    return [
      if (!isEditing) (kind: MobileBookingStepKind.days, group: null, band: null),
      for (final group in groups)
        if (_opensIn(group)) ...[
          if (!subjectsOnly) (kind: MobileBookingStepKind.hours, group: group, band: null),
          if (!hoursOnly)
            for (final band in hoursOf(group).bands) (kind: MobileBookingStepKind.subjects, group: group, band: band),
        ],
    ];
  }

  bool _bookedOn(DateTime day)
  {
    return !isEditing &&
        presences.any((presence) =>
            presence.studentTaxCode == pupil.fiscalCode && presence.mode == mode && isSameDate(presence.date, day));
  }

  bool isOffered(DateTime day)
  {
    final Set<TimeBucket> taken = _takenOn(day);

    return !_bookedOn(day) &&
        TimeBucket.values.any((bucket) =>
            !isClosed(day, bucket) && !taken.contains(bucket) && openingWindowFor(openingDays, day, mode, bucket) != null);
  }

  String refusalFor(DateTime day)
  {
    if (_bookedOn(day))
    {
      return takenByOtherMode(mode);
    }

    if (!const [kPresenceMode, kOnlineMode].any((mode) => isOpenOn(openingDays, day, mode)))
    {
      return bookingDayRefusal(day, shut: true);
    }

    if (!isOpenOn(openingDays, day, mode))
    {
      return modeShutAllDay(mode);
    }

    final Set<TimeBucket> taken = _takenOn(day);

    if (TimeBucket.values.any((bucket) =>
        !isClosed(day, bucket) && taken.contains(bucket) && openingWindowFor(openingDays, day, mode, bucket) != null))
    {
      return takenByOtherMode(_otherMode);
    }

    return bookingDayRefusal(day, shut: false);
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
    final List<MobileBookingGroup> current = groups;
    final Set<String> keys = {for (final group in current) group.key};

    _hours.removeWhere((key, _) => !keys.contains(key));
    _requests.removeWhere((key, _) => !keys.contains(key));

    for (final group in current)
    {
      hoursOf(group).reconcile((bucket) => windowFor(group, bucket));
    }
  }

  void dropRequestsWithoutHours()
  {
    for (final group in groups)
    {
      final List<TimeBucket> bands = hoursOf(group).bands;

      requestsOf(group).removeWhere((request) => !bands.contains(request.band));
    }
  }

  void dropRequest(MobileBookingGroup group, int index)
  {
    requestsOf(group).removeAt(index);
  }

  void keepRequest(MobileBookingGroup group, SubjectRequestDraft saved, {SubjectRequestDraft? replacing})
  {
    final List<SubjectRequestDraft> requests = requestsOf(group);
    final int at = replacing == null ? -1 : requests.indexOf(replacing);

    if (at >= 0)
    {
      requests[at] = saved;

      return;
    }

    requests.add(saved);
  }

  int minutesAsked(MobileBookingGroup group, {TimeBucket? band, SubjectRequestDraft? skip})
  {
    var minutes = 0;

    for (final request in requestsOf(group))
    {
      if (!identical(request, skip) && (band == null || request.band == band))
      {
        minutes += request.duration ?? 0;
      }
    }

    return minutes;
  }

  List<BandOffer> bandOffers(MobileBookingGroup group, {SubjectRequestDraft? skip})
  {
    final BandSchedule<PresenceItem> hours = hoursOf(group);

    return [
      for (final band in hours.bands)
          BandOffer(
            band: band,
            hours: [
              for (final stretch in [...hours.of(band)]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)))
                formatTimeRange(stretch.startTime, stretch.endTime),
            ].join(' · '),
            minutes: hours.minutesIn(band),
            takenByOthers: minutesAsked(group, band: band, skip: skip),
          ),
    ];
  }

  // Per band, as the server caps it: [band] null sums the whole mode.
  Map<int, int> minutesByDiscipline(MobileBookingGroup group, {TimeBucket? band, SubjectRequestDraft? skip})
  {
    final Map<int, int> minutes = {};

    for (final request in [...requestsOf(group), ...frozenRequests])
    {
      if (identical(request, skip) || (band != null && request.band != band))
      {
        continue;
      }

      for (final discipline in request.disciplineIds)
      {
        minutes[discipline] = (minutes[discipline] ?? 0) + (request.duration ?? 0);
      }
    }

    return minutes;
  }

  String? noTimeLeftIn(MobileBookingGroup group, TimeBucket band)
  {
    final BandOffer? offer = bandOffers(group).where((offer) => offer.band == band).firstOrNull;

    return offer != null && offer.left <= 0 ? bandTimeAllTaken(mode, band) : null;
  }

  String? blockedReason(MobileBookingStep step)
  {
    final MobileBookingGroup? group = step.group;

    return switch (step.kind)
    {
      MobileBookingStepKind.days => _days.isEmpty ? kPickDayToGoOn : null,
      MobileBookingStepKind.hours => hoursOf(group!).isEmpty
          ? hoursToGoOn(mode)
          : switch (hoursOf(group).overlapping)
            {
              final TimeBucket band => hoursOverlap(mode, band),
              null => null,
            },
      MobileBookingStepKind.subjects =>
        mode == kOnlineMode && !requestsOf(group!).any((request) => request.band == step.band) ? kPickSubjectToGoOn : null,
    };
  }

  bool get _hasFrozen => frozen.values.any((held) => held.isNotEmpty);

  // Every open stretch dropped: saving removes the mode's hours.
  bool get isClearing
  {
    if (!isEditing)
    {
      return false;
    }

    final BandSchedule<PresenceItem> hours = hoursOf(groups.single);

    return hours.isEmpty && hours.dropped.isNotEmpty;
  }

  bool get isUntouched
  {
    if (!isEditing || !_hasFrozen)
    {
      return false;
    }

    final MobileBookingGroup group = groups.single;
    final BandSchedule<PresenceItem> hours = hoursOf(group);

    return hours.isEmpty && hours.dropped.isEmpty && requestsOf(group).isEmpty;
  }

  String _daysLabel(MobileBookingGroup group)
  {
    if (groups.length == 1)
    {
      return '';
    }

    return ' (${group.days.map(formatAvailableDayShortLabel).join(', ')})';
  }

  String _disciplineName(int id, MobileBookingGroup group)
  {
    for (final subject in ministrySubjects)
    {
      for (final discipline in subject.associationSubjects)
      {
        if (discipline.id == id)
        {
          return discipline.name;
        }
      }
    }

    for (final request in requestsOf(group))
    {
      if (request.associationSubjectId == id && request.associationSubjectName != null)
      {
        return request.associationSubjectName!;
      }
    }

    return 'Una disciplina';
  }

  // The desktop's refusal message; null when saving would go.
  String? get problem
  {
    if (_days.isEmpty)
    {
      return kPickADayToSave;
    }

    final List<MobileBookingGroup> all = groups;

    if (all.every((group) => hoursOf(group).isEmpty) && !_hasFrozen && !isClearing)
    {
      return kGiveAnHour;
    }

    if (!isEditing && all.any((group) => hoursOf(group).isEmpty))
    {
      return kGiveAnHour;
    }

    for (final group in all)
    {
      final String days = _daysLabel(group);
      final String label = '${modeLabel(mode).toLowerCase()}$days';
      final BandSchedule<PresenceItem> hours = hoursOf(group);
      final List<SubjectRequestDraft> requests = requestsOf(group);

      if (hours.overlapping case final TimeBucket band)
      {
        return hoursOverlap(mode, band, days);
      }

      if (mode == kOnlineMode && hours.bands.any((band) => !requests.any((request) => request.band == band)))
      {
        return onlineSubjectMissing(days);
      }

      if (requests.isEmpty)
      {
        continue;
      }

      if (hours.isEmpty)
      {
        return subjectsWithoutHours(label);
      }

      for (final request in requests)
      {
        if (!request.isComplete)
        {
          return durationMissing(request.displayName, label);
        }

        if (request.asksForTopicAndTag && request.tags.isEmpty)
        {
          return lessonKindMissing(request.displayName, label);
        }
      }

      for (final band in hours.bands)
      {
        for (final entry in minutesByDiscipline(group, band: band).entries)
        {
          if (entry.value > maxDailyMinutesPerDiscipline)
          {
            return disciplineOverBand(
              _disciplineName(entry.key, group),
              entry.value,
              maxDailyMinutesPerDiscipline,
              '${modeLabel(mode).toLowerCase()} ${ofBandLabel(band)}$days',
            );
          }
        }
      }

      for (final band in TimeBucket.values)
      {
        if (minutesAsked(group, band: band) <= hours.minutesIn(band))
        {
          continue;
        }

        return hours.bands.length > 1
            ? bandStayExceeded(band, days, isSelf: isSelf, whose: _whose)
            : stayExceeded(days, isSelf: isSelf, whose: _whose);
      }
    }

    return null;
  }

  String get savedMessage => presenceSaved(own: true, editing: isEditing, cleared: false, days: _days.length);

  List<Map<String, dynamic>> _payloadOf(MobileBookingGroup group)
  {
    final BandSchedule<PresenceItem> hours = hoursOf(group).fused();

    if (!_opensIn(group) || hours.all.isEmpty)
    {
      return const [];
    }

    return [
      {
        'mode': mode,
        'slots': [
          for (final stretch in hours.all)
            {
              'start_time': formatTimeOfDay(stretch.startTime),
              'end_time': formatTimeOfDay(stretch.endTime),
            },
        ],
        'subjects': [for (final request in requestsOf(group)) request.toRequestJson()],
      },
    ];
  }

  // Closed bands are left out (the server keeps them); bands out of reach go back unchanged.
  List<Map<String, dynamic>> _replacementOf(MobileBookingGroup group)
  {
    final BandSchedule<PresenceItem> hours = hoursOf(group).fused();

    Map<String, dynamic> slotOf(TimeOfDay start, TimeOfDay end, PresenceItem? stored)
    {
      return {
        'start_time': formatTimeOfDay(start),
        'end_time': formatTimeOfDay(end),
        if (stored != null) ...{
          'presence_id': stored.id,
          'expected_updated_at': stored.updatedAt.toIso8601String(),
        },
      };
    }

    return [
      {
        'mode': mode,
        'slots': [
          for (final stretch in hours.all) slotOf(stretch.startTime, stretch.endTime, stretch.existing),
          for (final row in held) slotOf(row.startTime, row.endTime, row),
        ],
        'subjects': [
          for (final request in requestsOf(group)) request.toRequestJson(),
          for (final row in held)
            for (final booking in row.bookings)
              SubjectRequestDraft.fromBooking(booking, band: bucketFor(row.startTime)).toRequestJson(),
        ],
      },
    ];
  }

  Future<void> save({
    required Future<void> Function(DateTime day, List<Map<String, dynamic>> modes) createRequest,
    required Future<void> Function(DateTime day, List<Map<String, dynamic>> modes) replaceRequest,
  }) async
  {
    triedToSave = true;

    for (final group in groups)
    {
      for (final day in group.days)
      {
        if (_saved.contains(day))
        {
          continue;
        }

        if (isEditing)
        {
          await replaceRequest(
            day,
            withLeftOut(
              _replacementOf(group),
              presences.where((presence) => presence.studentTaxCode == pupil.fiscalCode && isSameDate(presence.date, day)),
              closed: (band) => isClosed(day, band),
            ),
          );
        }
        else
        {
          await createRequest(day, _payloadOf(group));
        }

        _saved.add(day);
      }
    }
  }
}
