import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/opening_day_item.dart';
import '../../lessons/models/booking_summary_item.dart';
import '../../lessons/models/presence_group.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/models/subject_request.dart';
import '../../lessons/utils/booking_window.dart';
import '../../lessons/utils/booking_wizard_strings.dart' show bandBookedOtherWay;
import '../../lessons/utils/opening_window.dart';
import '../../../core/constants/field_limits.dart';
import '../../lessons/widgets/booking_fields_section.dart' show bookingDurationOptions, maxDailyMinutesPerDiscipline;
import '../widgets/move_lesson_dialog.dart' show MoveDay, MoveOption;
import 'booking_replacement.dart' show withLeftOut;

class BookingMove
{
  final String fromMode;
  final TimeBucket fromBand;

  final List<BookingSummaryItem> bookings;
  final List<PresenceItem> leaving;

  const BookingMove({required this.fromMode, required this.fromBand, required this.bookings, required this.leaving});

  // Alone on its row, a lesson takes it if the rest still fit; a band's last lesson takes all rows.
  factory BookingMove.one(PresenceGroup group, PresenceItem from, BookingSummaryItem booking)
  {
    final TimeBucket band = bucketFor(from.startTime)!;

    if (group.requestsFor(from.mode, band: band).length == 1)
    {
      return BookingMove(fromMode: from.mode, fromBand: band, bookings: [booking], leaving: group.slotsFor(from.mode, band: band));
    }

    final int staying = group.minutesAskedFor(from.mode, band: band) - booking.duration;
    var room = 0;

    for (final row in group.slotsFor(from.mode, band: band))
    {
      if (row.id != from.id)
      {
        room += _lengthOf(row);
      }
    }

    return BookingMove(
      fromMode: from.mode,
      fromBand: band,
      bookings: [booking],
      leaving: [if (from.bookings.length == 1 && room >= staying) from],
    );
  }

  factory BookingMove.all(PresenceGroup group, String mode, TimeBucket band)
  {
    return BookingMove(
      fromMode: mode,
      fromBand: band,
      bookings: group.requestsFor(mode, band: band),
      leaving: group.slotsFor(mode, band: band),
    );
  }

  Set<int> get leavingIds => {for (final row in leaving) row.id};

  int get minutes
  {
    var total = 0;

    for (final booking in bookings)
    {
      total += booking.duration;
    }

    return total;
  }

  bool carries(BookingSummaryItem booking) => bookings.any((moving) => moving.id == booking.id);

  int minutesStayingOn(PresenceItem row)
  {
    var total = 0;

    for (final held in row.bookings)
    {
      if (!carries(held))
      {
        total += held.duration;
      }
    }

    return total;
  }

}

int _lengthOf(PresenceItem row) => minutesOfTimeOfDay(row.endTime) - minutesOfTimeOfDay(row.startTime);

const String _overTwoHours = 'Non è possibile garantire più di due ore di lezione per la stessa materia in una fascia oraria';

// A band books each subject once, whatever was asked of it.
bool _sameSubject(BookingSummaryItem a, BookingSummaryItem b)
{
  return a.kind == b.kind &&
      switch (a.kind)
      {
        BookingRequestKind.ministrySubject => a.ministrySubjectId == b.ministrySubjectId,
        BookingRequestKind.associationSubject => a.associationSubject?.id == b.associationSubject?.id,
        BookingRequestKind.service => a.serviceName == b.serviceName,
      };
}

String _joinText(String kept, String added, String separator, int limit)
{
  if (added.isEmpty || kept == added)
  {
    return kept;
  }

  final String joined = kept.isEmpty ? added : '$kept$separator$added';

  return joined.length > limit ? joined.substring(0, limit) : joined;
}

void _join(SubjectRequestDraft kept, BookingSummaryItem moved)
{
  kept.duration = (kept.duration ?? 0) + moved.duration;
  kept.associationSubjectIds.addAll(moved.associationSubjects.map((subject) => subject.id));

  for (final tag in moved.tags)
  {
    if (!kept.tags.contains(tag))
    {
      kept.tags.add(tag);
    }
  }

  for (final teacher in moved.preferredTeacherTaxCodes)
  {
    if (!kept.preferredTeacherTaxCodes.contains(teacher) &&
        kept.preferredTeacherTaxCodes.length < SubjectRequestDraft.maxPreferredTeachers)
    {
      kept.preferredTeacherTaxCodes.add(teacher);
    }
  }

  kept.topic = _joinText(kept.topic, moved.topic ?? '', ' - ', FieldLimits.topic);
  kept.notes = _joinText(kept.notes, moved.notes ?? '', '\n', FieldLimits.notes);
}

class _Block
{
  final String mode;
  final List<Map<String, dynamic>> slots = [];
  final List<SubjectRequestDraft> subjects = [];

  _Block(this.mode);

  // Touching rows go fused as the wizards send them: a run keeps its first stored row only.
  void joinTouching(TimeBucket band)
  {
    int at(Map<String, dynamic> slot, String key) => minutesOfTimeOfDay(parseTimeOfDay(slot[key]));

    final List<Map<String, dynamic>> rows = [
      for (final slot in slots)
        if (bucketFor(parseTimeOfDay(slot['start_time'])) == band) slot,
    ]..sort((a, b) => at(a, 'start_time').compareTo(at(b, 'start_time')));

    Map<String, dynamic>? open;

    for (final row in rows)
    {
      if (open == null || at(row, 'start_time') > at(open, 'end_time'))
      {
        open = row;

        continue;
      }

      if (at(row, 'end_time') > at(open, 'end_time'))
      {
        open['end_time'] = row['end_time'];
      }

      if (open['presence_id'] == null && row['presence_id'] != null)
      {
        open['presence_id'] = row['presence_id'];
        open['expected_updated_at'] = row['expected_updated_at'];
      }

      slots.remove(row);
    }
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'slots': slots,
        'subjects': [for (final subject in subjects) subject.toRequestJson()],
      };
}

Map<String, dynamic> _slotJson(TimeOfDay start, TimeOfDay end, {PresenceItem? row})
{
  return {
    'start_time': formatTimeOfDay(start),
    'end_time': formatTimeOfDay(end),
    if (row != null) ...{
      'presence_id': row.id,
      'expected_updated_at': row.updatedAt.toIso8601String(),
    },
  };
}

String _ofBand(TimeBucket band)
{
  return '${band == TimeBucket.afternoon ? 'del' : 'della'} ${bandLabel(band).toLowerCase()}';
}

String _tooLong(String mode, TimeBucket band, int needed, int free)
{
  return 'Le lezioni (${formatMinutes(needed)}) supererebbero le ore libere '
      '${modeLabel(mode).toLowerCase()} ${_ofBand(band)} (${formatMinutes(free)}).';
}

class BookingMovePlanner
{
  final List<OpeningDayItem> openingDays;
  final List<PresenceItem> presences;
  final DateTime now;

  const BookingMovePlanner({required this.openingDays, required this.presences, required this.now});

  PresenceGroup? groupOn(DateTime day, String pupilTaxCode)
  {
    final List<PresenceItem> onTheDay = presences
        .where((presence) => presence.studentTaxCode == pupilTaxCode && isSameDate(presence.date, day))
        .toList();

    if (onTheDay.isEmpty)
    {
      return null;
    }

    return groupPresences(onTheDay).single;
  }

  // Read from the rows at hand: a stale updated_at would get a 409.
  ({PresenceItem slot, BookingSummaryItem booking})? whereItHangs(BookingSummaryItem booking)
  {
    for (final slot in presences)
    {
      for (final row in slot.bookings)
      {
        if (row.id == booking.id)
        {
          return (slot: slot, booking: row);
        }
      }
    }

    return null;
  }

  // [keep]: the row being grown, not an obstacle; [gone]: rows leaving the day.
  OpeningWindow? freeWindow(
    DateTime day,
    PresenceGroup? group,
    String mode,
    TimeBucket band, {
    PresenceItem? keep,
    Set<int> gone = const {},
  })
  {
    final OpeningWindow? window = openingWindowFor(openingDays, day, mode, band);

    if (window == null)
    {
      return null;
    }

    List<(int, int)> pieces = [(window.startMinutes, window.endMinutes)];

    for (final row in group?.slots ?? const <PresenceItem>[])
    {
      if (row.id == keep?.id || gone.contains(row.id))
      {
        continue;
      }

      final int rowStart = minutesOfTimeOfDay(row.startTime);
      final int rowEnd = minutesOfTimeOfDay(row.endTime);

      pieces = [
        for (final (start, end) in pieces) ...[
          if (start < rowStart) (start, end < rowStart ? end : rowStart),
          if (end > rowEnd) (start > rowEnd ? start : rowEnd, end),
        ],
      ];
    }

    (int, int)? chosen;

    for (final piece in pieces)
    {
      if (piece.$2 <= piece.$1)
      {
        continue;
      }

      final bool holdsKept = keep != null &&
          piece.$1 <= minutesOfTimeOfDay(keep.startTime) &&
          minutesOfTimeOfDay(keep.endTime) <= piece.$2;

      if (holdsKept)
      {
        chosen = piece;

        break;
      }

      if (chosen == null || piece.$2 - piece.$1 > chosen.$2 - chosen.$1)
      {
        chosen = piece;
      }
    }

    if (chosen == null)
    {
      return null;
    }

    return OpeningWindow(startMinutes: chosen.$1, endMinutes: chosen.$2);
  }

  // [group] is null when the pupil has nothing on the day yet.
  List<MoveOption> moveOptions(DateTime day, PresenceGroup? group, BookingMove move, {required bool sameDay})
  {
    final List<MoveOption> options = [];
    final Set<int> gone = move.leavingIds;

    for (final mode in const [kPresenceMode, kOnlineMode])
    {
      final String other = mode == kPresenceMode ? kOnlineMode : kPresenceMode;

      for (final band in TimeBucket.values)
      {
        if (openingWindowFor(openingDays, day, mode, band) == null || haveBookingsClosed(day, band, now))
        {
          continue;
        }

        if (sameDay && mode == move.fromMode && band == move.fromBand)
        {
          continue;
        }

        // One mode per band, unless the other's rows all leave with the move.
        final String? takenRefusal = [
          for (final slot in group?.slotsFor(other) ?? const <PresenceItem>[])
            if (bucketFor(slot.startTime) == band && !gone.contains(slot.id)) slot,
        ].isEmpty ? null : bandBookedOtherWay(other);

        final List<PresenceItem> inBand = [
          for (final slot in group?.slotsFor(mode) ?? const <PresenceItem>[])
            if (bucketFor(slot.startTime) == band) slot,
        ];

        if (inBand.isEmpty)
        {
          final OpeningWindow? free = freeWindow(day, group, mode, band, gone: gone);
          final int needed = move.minutes;

          options.add(MoveOption(
            mode: mode,
            band: band,
            slot: null,
            window: free,
            needed: needed,
            refusal: takenRefusal ??
                (free == null || free.minutes < needed
                    ? _tooLong(mode, band, needed, free?.minutes ?? 0)
                    : ceilingRefusal(group, move, mode, band, sameDay: sameDay)),
          ));

          continue;
        }

        for (final row in inBand)
        {
          final OpeningWindow? free = freeWindow(day, group, mode, band, keep: row, gone: gone);

          // Counted per band, as the server does: the row covers what the band's other rows cannot.
          var lessons = move.minutes + move.minutesStayingOn(row);
          var elsewhere = 0;

          for (final other in inBand)
          {
            if (other.id != row.id && !gone.contains(other.id))
            {
              lessons += move.minutesStayingOn(other);
              elsewhere += _lengthOf(other);
            }
          }

          final int needed = (lessons - elsewhere).clamp(0, lessons);

          options.add(MoveOption(
            mode: mode,
            band: band,
            slot: row,
            window: free,
            needed: needed,
            refusal: takenRefusal ??
                (free == null || free.minutes < needed
                    ? _tooLong(mode, band, lessons, (free?.minutes ?? 0) + elsewhere)
                    : ceilingRefusal(group, move, mode, band, sameDay: sameDay)),
          ));
        }
      }
    }

    return options;
  }

  // Capped per band; a lesson merged into its same-subject lesson may not pass the longest choice.
  String? ceilingRefusal(PresenceGroup? group, BookingMove move, String mode, TimeBucket band, {required bool sameDay})
  {
    if (sameDay && mode == move.fromMode && band == move.fromBand)
    {
      return null;
    }

    final Map<int, int> taken = {...?group?.minutesByDiscipline(mode, band: band)};
    final List<BookingSummaryItem> staying = [
      for (final booking in group?.requestsFor(mode, band: band) ?? const <BookingSummaryItem>[])
        if (!move.carries(booking)) booking,
    ];

    for (final booking in move.bookings)
    {
      final BookingSummaryItem? same = staying.where((held) => _sameSubject(held, booking)).firstOrNull;

      if (same != null && same.duration + booking.duration > bookingDurationOptions.last)
      {
        return _overTwoHours;
      }

      for (final discipline in booking.disciplineIds)
      {
        final int total = (taken[discipline] ?? 0) + booking.duration;

        if (total > maxDailyMinutesPerDiscipline)
        {
          return _overTwoHours;
        }

        taken[discipline] = total;
      }
    }

    return null;
  }

  bool anyBandShut(DateTime day)
  {
    for (final mode in const [kPresenceMode, kOnlineMode])
    {
      for (final band in TimeBucket.values)
      {
        if (openingWindowFor(openingDays, day, mode, band) != null && haveBookingsClosed(day, band, now))
        {
          return true;
        }
      }
    }

    return false;
  }

  String shutReason(DateTime day, {required bool own})
  {
    if (own)
    {
      return anyBandShut(day) ? 'Le prenotazioni per le altre fasce orarie sono chiuse' : 'Non ci sono altre fasce orarie';
    }

    return anyBandShut(day) ? 'Prenotazioni chiuse' : 'Associazione chiusa';
  }

  MoveDay moveDay(DateTime from, DateTime day, String pupilTaxCode, BookingMove move)
  {
    final bool sameDay = isSameDate(day, from);
    final List<MoveOption> options = moveOptions(day, groupOn(day, pupilTaxCode), move, sameDay: sameDay);

    return MoveDay(
      day: day,
      options: options,
      refusal: options.isEmpty ? shutReason(day, own: sameDay) : null,
    );
  }

  List<MoveDay> moveDays(DateTime from, String pupilTaxCode, BookingMove move)
  {
    return [
      for (final day in computeAvailableDays(now)) moveDay(from, day, pupilTaxCode, move),
    ];
  }

  bool canMoveLesson(DateTime day, PresenceGroup? group, BookingSummaryItem booking)
  {
    final held = whereItHangs(booking);

    if (group == null || held == null)
    {
      return false;
    }

    return moveDays(day, group.studentTaxCode, BookingMove.one(group, held.slot, held.booking)).any((day) => day.viable);
  }

  String? blockMoveRefusal(DateTime day, PresenceGroup? group, String mode, TimeBucket band)
  {
    if (group == null)
    {
      return null;
    }

    if (haveBookingsClosed(day, band, now))
    {
      return 'Prenotazioni chiuse';
    }

    final List<MoveDay> days = moveDays(day, group.studentTaxCode, BookingMove.all(group, mode, band));

    if (days.any((option) => option.viable))
    {
      return null;
    }

    return days.every((option) => option.options.isEmpty && anyBandShut(option.day))
        ? 'Le prenotazioni per le altre fasce orarie sono chiuse'
        : "Nessun'altra fascia oraria o giornata può contenere tutte le lezioni inserite";
  }

  // Lessons keep their stored ids so the server moves them; closed bands are left out and kept.
  List<Map<String, dynamic>> moveRequest({
    required PresenceGroup from,
    required BookingMove move,
    required DateTime day,
    required MoveOption option,
    TimeOfDay? start,
    TimeOfDay? end,
  })
  {
    final PresenceGroup? there = isSameDate(day, from.date) ? from : groupOn(day, from.studentTaxCode);
    final PresenceItem? kept = option.slot;
    final Map<String, Map<String, _Block>> days = {};

    _Block blockOf(PresenceGroup? group, DateTime date, String mode)
    {
      return days.putIfAbsent(formatDateOnly(date), () => {}).putIfAbsent(mode, ()
      {
        final _Block block = _Block(mode);

        for (final row in group?.slotsFor(mode) ?? const <PresenceItem>[])
        {
          final TimeBucket band = bucketFor(row.startTime)!;

          if (haveBookingsClosed(date, band, now) || move.leavingIds.contains(row.id))
          {
            continue;
          }

          block.slots.add(
            row.id == kept?.id && start != null && end != null
                ? _slotJson(start, end, row: row)
                : _slotJson(row.startTime, row.endTime, row: row),
          );

          for (final booking in row.bookings)
          {
            if (!move.carries(booking))
            {
              block.subjects.add(SubjectRequestDraft.fromBooking(booking, band: band));
            }
          }
        }

        return block;
      });
    }

    blockOf(from, from.date, move.fromMode);

    final _Block target = blockOf(there, day, option.mode);

    if (kept == null && start != null && end != null)
    {
      target.slots.add(_slotJson(start, end));
    }

    target.joinTouching(option.band);

    // Merged into the band's same-subject lesson, the moved one is left out and deleted.
    for (final booking in move.bookings)
    {
      final SubjectRequestDraft? same = target.subjects
          .where((held) => held.band == option.band && held.existing != null && _sameSubject(held.existing!, booking))
          .firstOrNull;

      if (same != null)
      {
        _join(same, booking);

        continue;
      }

      target.subjects.add(SubjectRequestDraft.fromBooking(booking, band: option.band));
    }

    final String leaving = formatDateOnly(from.date);

    return [
      for (final entry in days.entries)
        {
          'date': entry.key,
          'modes': withLeftOut(
            [for (final block in entry.value.values) block.toJson()],
            entry.key == leaving ? from.slots : there?.slots ?? const <PresenceItem>[],
            closed: (band) => haveBookingsClosed(entry.key == leaving ? from.date : day, band, now),
          ),
        },
    ];
  }
}
