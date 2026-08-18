import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/band_time_range_slider.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../people/edit/widgets/person_edit_guide.dart';
import '../models/availability_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/schedulable_booking.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'calendar_lesson_block.dart';
import 'person_avatar.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;
const double _stepWidth = 560;

// A wider foot than the standard pair, because the command at the left of it is
// a sentence and not a word. "RIMUOVI DAL CALENDARIO" is two hundred and
// twenty-four pixels of letters at this size, and two hundred and forty-seven
// with the glyph and the gap before it. Half of the standard five hundred and
// twenty is two hundred and fifty-two, four of which the outline takes, and the
// label was being written over two lines: a button that takes two lines to name
// one action reads as two of them.
//
// Three hundred and twelve apiece, which leaves the longer of the two thirty
// pixels of air at either end. The row inside a button is shrink-wrapped and
// centred, so it is this width and not the padding below that the air is made
// of: wider, and the sentence sat in the middle of a button with nothing else
// in it.
const double _dialogFooterWidth = 640;

// Less than a button standing on its own in a form takes. Not what the ends are
// made of — see above — but the floor the label is held to, and at the default
// thirty the sentence would meet it before it met the button.
const double _dialogButtonPadding = 18;

// Wide enough for the card *and* its two arrows: under this the frame drops them
// underneath, which is the phone layout and reads as a different window. The
// spare sixty-four is the stack's own margin, the same sum the booking wizard
// is built with.
const double _dialogWidth = _stepWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

// Under this the eyebrow gives up the step count and keeps only the name. The
// head spends about a hundred and forty on the face and its padding before a
// letter is drawn, and "PASSO 1 DI 2 · " is another hundred and ten.
//
// The count goes and not the name: the name is the only thing on the line that
// says whose hours these are, while the step is already said by the arrows.
const double _stepCountMin = 560;

// The quarter of an hour every duration in this app is given in.
const int _step = kQuarterHour;

// One stretch a teacher offered, cut to the band, the pupil's hours and the row
// itself. The row and not the merged picture the track draws: a lesson has to
// fall inside one row, so a teacher there twice is offered twice.
class _Slot
{
  final TeacherLane lane;
  final AvailabilityItem availability;
  final int windowStart;
  final int windowEnd;

  const _Slot({
    required this.lane,
    required this.availability,
    required this.windowStart,
    required this.windowEnd,
  });

  String get teacherTaxCode => lane.teacherTaxCode;

  String get label => '${lane.teacher.fullName} · ${formatMinutesRange(windowStart, windowEnd)}';
}

// A part of the request as it is being designed. The design is not the
// calendar: an existing part carries its hour's id so confirming rewrites it,
// and a removed part is an hour to delete — but not until the last button.
class _Part
{
  // The hour this part already is, where it is one.
  final int? lessonId;

  // Its band has been published: nothing about it may be touched.
  final bool isPublished;

  Set<int> disciplineIds;

  // Which stretch it takes, by the id of the availability row. Null where the
  // day has none that could hold it, which the window says rather than hides.
  int? availabilityId;

  int startMinutes;
  int endMinutes;

  _Part({
    this.lessonId,
    this.isPublished = false,
    required this.disciplineIds,
    required this.availabilityId,
    required this.startMinutes,
    required this.endMinutes,
  });

  int get minutes => endMinutes - startMinutes;

  bool get isPlanned => lessonId != null;
}

// Everything one request can be turned into: the pupil, the materia, how it is
// divided, and who takes each piece and when.
//
// One window per request and not per hour, since an hour is one part of a
// materia and the division only makes sense against the whole of what was
// asked. That is also why there is no second window for an hour.
//
// Nothing is written until the last button: the steps build a drawing, and
// confirming makes the calendar match it.
class LessonPlanWizard extends StatefulWidget
{
  final SchedulableBooking entry;
  final CalendarDayIndex index;
  final List<MinistrySubjectItem> ministrySubjects;

  final Future<LessonItem?> Function({
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
  })? onCreate;

  final Future<LessonItem?> Function({
    required LessonItem existing,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
  })? onUpdate;

  final Future<bool> Function(int id, Function(String) onError)? onDelete;

  const LessonPlanWizard({
    super.key,
    required this.entry,
    required this.index,
    required this.ministrySubjects,
    this.onCreate,
    this.onUpdate,
    this.onDelete,
  });

  @override
  State<LessonPlanWizard> createState() => _LessonPlanWizardState();
}

class _LessonPlanWizardState extends State<LessonPlanWizard>
{
  // The drawing being made. Built from the calendar every time the window
  // opens and never carried over from the last one: an hour deleted between two
  // openings has to be gone from here as well, and a window that remembered
  // what was chosen before would be offering to write it again.
  late final List<_Part> _parts = _initialParts();

  int _stepIndex = 0;
  bool _movingForward = true;

  bool _isSaving = false;

  CalendarDayIndex get _index => widget.index;

  SchedulableBooking get _entry => widget.entry;

  BookingSummaryItem get _booking => _entry.booking;

  // --- what was asked for ---------------------------------------------------

  // What the request is called: a ministry subject by its own name, a lone
  // discipline and a service by theirs.
  String get _requestName
  {
    return switch (_booking.kind)
    {
      BookingRequestKind.ministrySubject => widget.ministrySubjects
              .where((subject) => subject.id == _booking.ministrySubjectId)
              .map((subject) => subject.name)
              .firstOrNull ??
          'Materia',
      BookingRequestKind.associationSubject => _booking.associationSubject?.name ?? 'Disciplina',
      BookingRequestKind.service => _booking.serviceName ?? 'Servizio',
    };
  }

  List<int> get _requestedDisciplines => _entry.requestedDisciplineIds.toList()..sort();

  bool get _isLocked => _entry.isLocked;

  // --- the drawing ----------------------------------------------------------

  List<_Part> _initialParts()
  {
    final requested = widget.entry.requestedDisciplineIds;

    final parts = [
      for (final lesson in widget.entry.parts)
        _Part(
          lessonId: lesson.id,
          isPublished: lesson.isPublished,
          // What of the request this hour covers. An hour may carry a discipline
          // the request never asked for — it cannot, in fact, but reading it
          // this way means the drawing can only ever say what was asked.
          disciplineIds: lesson.disciplineIds.intersection(requested).toSet(),
          availabilityId: lesson.availabilityId,
          startMinutes: lesson.startMinutes,
          endMinutes: lesson.endMinutes,
        ),
    ];

    if (parts.isEmpty)
    {
      final draft = _draft(requested.toSet(), widget.entry.remainingMinutes, parts);

      return [?draft];
    }

    // Planned, but not all of it: the part that would finish it is drawn in
    // already, because that is what the window was opened to do.
    final uncovered = widget.entry.uncoveredDisciplineIds;

    if (uncovered.isNotEmpty &&
        parts.length < kMaxLessonParts &&
        widget.entry.remainingMinutes >= kMinimumBandMinutes)
    {
      final draft = _draft(uncovered.toSet(), widget.entry.remainingMinutes, parts);

      if (draft != null)
      {
        parts.add(draft);
      }
    }

    return parts;
  }

  // A part not yet on the calendar, put in the first stretch that would take
  // it. Where none would, it is drawn all the same, without a stretch: the
  // window then says who could have taken it, which is the useful half of the
  // answer.
  _Part? _draft(Set<int> disciplineIds, int wanted, List<_Part> siblings)
  {
    final length = wanted < kMinimumBandMinutes ? kMinimumBandMinutes : wanted;

    for (final slot in _slotsFor(disciplineIds))
    {
      final start = _firstValidStart(
        slot: slot,
        disciplineIds: disciplineIds,
        length: length,
        siblings: siblings,
      );

      if (start != null)
      {
        return _Part(
          disciplineIds: disciplineIds,
          availabilityId: slot.availability.id,
          startMinutes: start,
          endMinutes: start + length,
        );
      }
    }

    return _Part(
      disciplineIds: disciplineIds,
      availabilityId: null,
      startMinutes: _index.bandStart,
      endMinutes: _index.bandStart + kMinimumBandMinutes,
    );
  }

  // --- what the day can take ------------------------------------------------

  // Every stretch that could hold a part on [disciplineIds]. Judged at the
  // shortest a lesson can be and not at the length currently chosen, so the
  // list does not empty itself while the hours are being stretched.
  List<_Slot> _slotsFor(Set<int> disciplineIds, {List<_Part> siblings = const [], int? lessonId, int? keep})
  {
    final presence = _entry.presence;

    // Keyed by the teacher and the two ends, so a teacher who offered the same
    // stretch twice — in the building *and* from home, both of which can take a
    // pupil at a screen — is one entry and not two identical ones. Two stretches
    // that differ stay two: that is a teacher there twice in the band, and both
    // are worth offering.
    final slots = <(String, int, int), _Slot>{};

    for (final lane in _index.lanes)
    {
      for (final availability in lane.availabilitiesTaking(presence.mode))
      {
        final inBand = intersectSpan(
          minutesOfTimeOfDay(availability.startTime),
          minutesOfTimeOfDay(availability.endTime),
          _index.bandStart,
          _index.bandEnd,
        );

        final window = inBand == null
            ? null
            : intersectSpan(
                inBand.$1,
                inBand.$2,
                minutesOfTimeOfDay(presence.startTime),
                minutesOfTimeOfDay(presence.endTime),
              );

        if (window == null || window.$2 - window.$1 < kMinimumBandMinutes)
        {
          continue;
        }

        final slot = _Slot(
          lane: lane,
          availability: availability,
          windowStart: window.$1,
          windowEnd: window.$2,
        );

        if (_firstValidStart(
              slot: slot,
              disciplineIds: disciplineIds,
              length: kMinimumBandMinutes,
              siblings: siblings,
              // The hour this part already **is** cannot be what stands in its
              // own way: left in, its minutes are counted as spent and its own
              // place on the track as taken, and every stretch of the day comes
              // back refused — including the one the lesson is sitting in.
              lessonId: lessonId,
            ) ==
            null)
        {
          continue;
        }

        final key = (lane.teacherTaxCode, window.$1, window.$2);
        final current = slots[key];

        if (current == null || _preferred(slot, current, keep))
        {
          slots[key] = slot;
        }
      }
    }

    return slots.values.toList();
  }

  // Which of two rows for the same stretch to offer: the one a part is already
  // written on, or else the one in the building, which is what
  // [resolveAvailability] picks at the drop.
  bool _preferred(_Slot candidate, _Slot current, int? keep)
  {
    if (candidate.availability.id == keep)
    {
      return true;
    }

    if (current.availability.id == keep)
    {
      return false;
    }

    return candidate.availability.mode == kPresenceMode && current.availability.mode != kPresenceMode;
  }

  // The first quarter of an hour inside [slot] where a part of [length] on
  // those disciplines would be taken, or null where none would.
  //
  // Asked of the same judge the drop asks rather than of a copy of its rules:
  // there is one place in this app that decides whether an hour may be written.
  int? _firstValidStart({
    required _Slot slot,
    required Set<int> disciplineIds,
    required int length,
    required List<_Part> siblings,
    int? lessonId,
  })
  {
    for (var start = snapToQuarter(slot.windowStart); start + length <= slot.windowEnd; start += _step)
    {
      final refusal = _judge(
        teacherTaxCode: slot.teacherTaxCode,
        startMinutes: start,
        endMinutes: start + length,
        disciplineIds: disciplineIds,
        lessonId: lessonId,
        siblings: siblings,
      );

      if (refusal == null)
      {
        return start;
      }
    }

    return null;
  }

  // Why the calendar would refuse this piece of the drawing.
  // [validatePlacement] cannot see the other part as it is being designed, so
  // both hours are taken out of its sight and judged here: two parts that
  // overlap are one pupil in two hours at once.
  String? _judge({
    required String teacherTaxCode,
    required int startMinutes,
    required int endMinutes,
    required Set<int> disciplineIds,
    required List<_Part> siblings,
    int? lessonId,
  })
  {
    final placement = validatePlacement(
      index: _index,
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      bookings: [_entry],
      disciplineIds: disciplineIds,
      lessonId: lessonId,
      deleteLessonId: siblings.map((part) => part.lessonId).whereType<int>().firstOrNull,
    );

    if (!placement.isValid)
    {
      return placement.refusal ?? kOutsideAvailabilityRefusal;
    }

    var total = endMinutes - startMinutes;

    for (final sibling in siblings)
    {
      if (spansOverlap(startMinutes, endMinutes, sibling.startMinutes, sibling.endMinutes))
      {
        return 'Due lezioni dello stesso alunno si sovrappongono.';
      }

      total += sibling.minutes;
    }

    if (total > _booking.duration)
    {
      return 'Le lezioni coprono ${formatMinutes(total)} delle ${formatMinutes(_booking.duration)} '
          'richieste.';
    }

    return null;
  }

  List<_Part> _siblingsOf(_Part part) => [for (final other in _parts) if (!identical(other, part)) other];

  String? _refusalFor(_Part part)
  {
    final slot = _slotOf(part);

    if (slot == null)
    {
      return noTeacherReason(_index, _entry, part.disciplineIds);
    }

    return _judge(
      teacherTaxCode: slot.teacherTaxCode,
      startMinutes: part.startMinutes,
      endMinutes: part.endMinutes,
      disciplineIds: part.disciplineIds,
      lessonId: part.lessonId,
      siblings: _siblingsOf(part),
    );
  }

  _Slot? _slotOf(_Part part)
  {
    if (part.availabilityId == null)
    {
      return null;
    }

    return _slotsFor(
      part.disciplineIds,
      siblings: _siblingsOf(part),
      lessonId: part.lessonId,
      keep: part.availabilityId,
    ).where((slot) => slot.availability.id == part.availabilityId).firstOrNull;
  }

  // The longest a part may be: what is left of the request once the other part
  // has taken its own, less the half hour a discipline left out of both will
  // need.
  int _ceilingFor(_Part part)
  {
    final others = _siblingsOf(part).fold(0, (total, sibling) => total + sibling.minutes);

    var ceiling = _booking.duration - others;

    final covered = {for (final other in _parts) ...other.disciplineIds};
    final leftOut = _entry.requestedDisciplineIds.difference(covered);

    if (leftOut.isNotEmpty && _parts.length < kMaxLessonParts)
    {
      ceiling -= kMinimumBandMinutes;
    }

    return ceiling < kMinimumBandMinutes ? kMinimumBandMinutes : ceiling;
  }

  // --- the drawing being changed --------------------------------------------

  // Puts a part inside a stretch, keeping the hours it has where they still
  // fit and finding it a place where they do not.
  void _place(_Part part, _Slot slot, {int? wanted})
  {
    final room = slot.windowEnd - slot.windowStart;
    final ceiling = _ceilingFor(part);
    final asked = wanted ?? part.minutes;

    final length = asked.clamp(kMinimumBandMinutes, room < ceiling ? room : ceiling);

    final keeps = part.startMinutes >= slot.windowStart && part.startMinutes + length <= slot.windowEnd;

    final start = keeps
        ? part.startMinutes
        : _firstValidStart(
              slot: slot,
              disciplineIds: part.disciplineIds,
              length: length,
              siblings: _siblingsOf(part),
              lessonId: part.lessonId,
            ) ??
            slot.windowStart;

    part.availabilityId = slot.availability.id;
    part.startMinutes = start;
    part.endMinutes = start + length;
  }

  // Puts every part back in a state it can be used in after the division has
  // changed: a discipline moved from one part to the other can cost a teacher
  // their competence for it, and it moves the ceilings with it.
  void _reconcile()
  {
    for (final part in _parts)
    {
      if (part.isPublished)
      {
        continue;
      }

      final slots = _slotsFor(
        part.disciplineIds,
        siblings: _siblingsOf(part),
        lessonId: part.lessonId,
        keep: part.availabilityId,
      );

      final slot = slots.where((entry) => entry.availability.id == part.availabilityId).firstOrNull ?? slots.firstOrNull;

      if (slot == null)
      {
        part.availabilityId = null;

        continue;
      }

      _place(part, slot);
    }
  }

  void _setPartCount(int count)
  {
    setState(()
    {
      if (count == 1 && _parts.length > 1)
      {
        // The two put back into one: the first keeps the whole materia, and the
        // second stops being part of the drawing — which is what deletes its
        // hour when the window is confirmed.
        final first = _parts.first;

        first.disciplineIds = {..._entry.requestedDisciplineIds};
        _parts.removeRange(1, _parts.length);
      }

      if (count == 2 && _parts.length == 1)
      {
        final first = _parts.first;
        final ordered = _requestedDisciplines;

        // Split down the middle as a starting point: something in each part is
        // what makes the two rows readable. One discipline goes in both, since
        // an hour with nothing in it is not an hour.
        final cut = (ordered.length / 2).ceil();

        first.disciplineIds = ordered.take(cut).toSet();

        final rest = ordered.skip(cut).toSet();

        // What the second hour is about. A service has nothing to share out —
        // it is not made of disciplines — and asking a list with nothing in it
        // for its last element is what stopped a service from being divided at
        // all. A single discipline goes in both hours instead: two teachers
        // taking turns on it.
        final second = ordered.isEmpty
            ? const <int>{}
            : rest.isEmpty
                ? {ordered.last}
                : rest;
        // The first hour gives its half back before the second looks for a
        // place: asked while the first still held every minute, the second was
        // refused everywhere.
        final total = _booking.duration;
        final half = snapQuarterDown(total ~/ 2).clamp(kMinimumBandMinutes, total - kMinimumBandMinutes);

        first.endMinutes = first.startMinutes + half;

        final draft = _draft(second, total - half, _parts);

        if (draft != null)
        {
          _parts.add(draft);
        }
      }

      _reconcile();
    });
  }

  // Puts a discipline into one of the hours, or takes it out. An hour about
  // nothing is not a lesson, so the last discipline of a part does not answer.
  void _setDisciplineIn(int partIndex, int disciplineId, bool selected)
  {
    final part = _parts[partIndex];

    if (!selected && part.disciplineIds.length <= 1)
    {
      return;
    }

    setState(()
    {
      part.disciplineIds = {...part.disciplineIds};

      if (selected)
      {
        part.disciplineIds.add(disciplineId);
      }
      else
      {
        part.disciplineIds.remove(disciplineId);
      }

      // Moving a discipline can cost the chosen teacher their competence for the
      // hour it lands in, and it moves the ceilings with it.
      _reconcile();
    });
  }

  void _unplanEverything()
  {
    setState(()
    {
      _parts.clear();
    });
  }

  // --- writing --------------------------------------------------------------

  // What confirming would do, in a forced order: deletions, then rewritings,
  // then new hours. An hour has to give its minutes back before another asks
  // for them, and leave before anything is written over its place.
  Future<void> _confirm() async
  {
    if (_isSaving)
    {
      return;
    }

    // Pressed with something in the way: the button says what it is rather than
    // doing nothing, which is what it did before and reads as a broken button.
    final obstacle = _obstacle;

    if (obstacle != null)
    {
      CustomSnackBar.show(context: context, message: obstacle, isError: true);

      return;
    }

    final drawn = {for (final part in _parts) if (part.lessonId != null) part.lessonId!};
    final removed = [for (final lesson in _entry.parts) if (!drawn.contains(lesson.id)) lesson];

    setState(() => _isSaving = true);

    var failure = false;

    void report(String message)
    {
      failure = true;

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    }

    for (final lesson in removed)
    {
      final delete = widget.onDelete;

      if (delete == null || failure)
      {
        break;
      }

      await delete(lesson.id, report);
    }

    for (final part in _parts.where((part) => part.isPlanned))
    {
      final update = widget.onUpdate;
      final existing = _entry.parts.where((lesson) => lesson.id == part.lessonId).firstOrNull;

      if (update == null || existing == null || failure || !_hasChanged(part, existing))
      {
        continue;
      }

      await update(
        existing: existing,
        availabilityId: _slotOf(part)!.availability.id,
        bookingIds: [_entry.id],
        associationSubjectIds: part.disciplineIds.toList()..sort(),
        startTime: timeOfDayFromMinutes(part.startMinutes),
        endTime: timeOfDayFromMinutes(part.endMinutes),
        onError: report,
      );
    }

    for (final part in _parts.where((part) => !part.isPlanned))
    {
      final create = widget.onCreate;

      if (create == null || failure)
      {
        break;
      }

      await create(
        availabilityId: _slotOf(part)!.availability.id,
        bookingIds: [_entry.id],
        associationSubjectIds: part.disciplineIds.toList()..sort(),
        startTime: timeOfDayFromMinutes(part.startMinutes),
        endTime: timeOfDayFromMinutes(part.endMinutes),
        onError: report,
      );
    }

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (!failure)
    {
      Navigator.pop(context);
    }
  }

  bool _hasChanged(_Part part, LessonItem existing)
  {
    final same = part.disciplineIds.length == existing.disciplineIds.length &&
        part.disciplineIds.every(existing.disciplineIds.contains);

    return part.startMinutes != existing.startMinutes ||
        part.endMinutes != existing.endMinutes ||
        part.availabilityId != existing.availabilityId ||
        !same;
  }

  // --- the two steps --------------------------------------------------------

  // The name of one field over the one datum under it, spaced the way every
  // field of the booking wizard is spaced.
  Widget _label(String text, {bool first = true})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  TextStyle get _valueStyle => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppTheme.trialInk,
      );

  TextStyle get _noteStyle => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        fontStyle: FontStyle.italic,
        color: AppTheme.trialMutedText,
      );

  String _partName(int index) => index == 0 ? 'Prima parte' : 'Seconda parte';

  // Whether the materia can be asked for in two hours. The disciplines have
  // nothing to do with it: one discipline in two hours is two teachers taking
  // turns.
  //
  // Measured on the whole request and not on what is unplanned: this window
  // redraws existing hours as readily as it writes new ones, and read the other
  // way a fully planned materia answered "less than an hour left" about
  // itself.
  bool get _canSplit => _booking.duration >= 2 * kMinimumBandMinutes;

  Widget _buildDivision()
  {
    final disciplines = _requestedDisciplines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Measured from the two words in it rather than stretched to the card:
        // a yes-or-no two syllables wide, sitting at one end of a piece the
        // width of the window, reads as a field with something missing beside
        // it. See AppSegmentedTabs.hugContent, which is there for this.
        Center(
          child: AppDialogPill(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // The question is asked once, in the guide above, and this is
              // where it is answered: a label and a sentence here would be the
              // same two lines a hand's breadth apart.
              children: [
                AppSegmentedTabs(
                  labels: const ['Una', 'Due'],
                  selectedIndex: _parts.length > 1 ? 1 : 0,
                  // The tab answers with its own index; what is being chosen is
                  // a number of hours, and the two are one apart.
                  onSelected: _canSplit && !_isLocked ? (index) => _setPartCount(index + 1) : (_) {},
                  height: 38,
                  fontSize: 13,
                  padding: EdgeInsets.zero,
                  hugContent: true,
                ),
                // Only where one of the two answers is not available: that is
                // not the question said again, it is why it cannot be answered.
                if (!_canSplit) ...[
                  const SizedBox(height: 10),
                  Text(
                    'È stata prenotata meno di un\'ora: non è possibile dividere la materia in due '
                        'lezioni poiché ogni lezione deve durare almeno mezz\'ora.',
                    style: _noteStyle,
                  ),
                ],
              ],
            ),
          ),
        ),
        // Only where there is something to assign. One discipline in two hours
        // is in both of them, and a table asking which of the two would be a
        // question with one wrong answer.
        if (_parts.length > 1 && disciplines.length > 1) ...[
          const SizedBox(height: 14),
          AppDialogPill(
            expand: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Discipline e ore'),
                for (final id in disciplines) _buildDisciplineRow(id),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Two switches and not a choice between two: a discipline can be in both —
  // two teachers taking turns — and in neither, which leaves it for another
  // time. A row forcing a pick could not draw what is already on the track.
  Widget _buildDisciplineRow(int id)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(child: Text(_index.nameOf(id), style: _valueStyle)),
          const SizedBox(width: 12),
          for (var part = 0; part < _parts.length; part++) ...[
            if (part > 0) const SizedBox(width: 8),
            AppSelectableChip(
              label: '${part + 1}ª lezione',
              selected: _parts[part].disciplineIds.contains(id),
              onSelected: _isLocked ? (_) {} : (selected) => _setDisciplineIn(part, id, selected),
            ),
          ],
        ],
      ),
    );
  }

  // Three cases, none readable off the digits: assegnata un'ora, assegnate due
  // ore, assegnati quaranta minuti. An hour and a half takes the singular.
  String _assignedWord(int minutes)
  {
    final hours = minutes ~/ 60;

    if (hours == 0)
    {
      return 'Assegnati';
    }

    return hours == 1 ? 'Assegnata' : 'Assegnate';
  }

  // What the drawing adds up to, under the hours it is made of.
  //
  // It belongs here and not on a step of its own: the sliders above are what
  // set the minutes, and a page that asked for them first only to let them be
  // dragged about afterwards was asking the same question twice.
  Widget _buildTotals()
  {
    final assigned = _parts.fold(0, (total, part) => total + part.minutes);
    final left = _booking.duration - assigned;

    return AppDialogPill(
      expand: true,
      // The sum, as a sum: two numbers and the word between them. A sentence is
      // read once and skipped after that, and this line changes under the hand
      // at every drag of the sliders above it.
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_assignedWord(assigned)} ${formatMinutes(assigned)} di ${formatMinutes(_booking.duration)}',
              style: _valueStyle,
            ),
          ),
          if (left > 0)
            Text(
              '${formatMinutes(left)} da pianificare successivamente',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppTheme.modifiedAccent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSchedule()
  {
    if (_parts.isEmpty)
    {
      return AppDialogPill(
        expand: true,
        child: Text(
          'Confermando, la materia verrà tolta dal calendario e dovrà essere nuovamente pianificata.',
          style: _valueStyle,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _parts.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          _buildPartSchedule(index),
        ],
        const SizedBox(height: 14),
        _buildTotals(),
      ],
    );
  }

  Widget _buildPartSchedule(int index)
  {
    final part = _parts[index];
    final slots = _slotsFor(
      part.disciplineIds,
      siblings: _siblingsOf(part),
      lessonId: part.lessonId,
      keep: part.availabilityId,
    );

    final slot = _slotOf(part);
    final refusal = _refusalFor(part);

    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_parts.length > 1) ...[
            Text(_partName(index), style: _valueStyle),
            const SizedBox(height: 2),
            Text(
              _index.namesOf(part.disciplineIds).join(', '),
              style: _noteStyle.copyWith(fontStyle: FontStyle.normal, fontSize: 13),
            ),
            const SizedBox(height: 14),
          ],
          _label('Docente e ore libere'),
          if (part.isPublished)
            Text(
              'Pubblicata: ${formatMinutesRange(part.startMinutes, part.endMinutes)}. Non può '
                  'essere modificata.',
              style: _valueStyle,
            )
          else if (slot == null)
            Text(refusal ?? noTeacherReason(_index, _entry, part.disciplineIds), style: _valueStyle.copyWith(color: AppTheme.trialDanger))
          else ...[
            AppDropdownField<int>(
              hint: 'Scegli il docente',
              value: slot.availability.id,
              options: [
                for (final offered in slots)
                  AppDropdownOption(value: offered.availability.id, label: offered.label),
              ],
              onChanged: (id)
              {
                final chosen = slots.where((offered) => offered.availability.id == id).firstOrNull;

                if (chosen != null)
                {
                  setState(()
                  {
                    _place(part, chosen);
                  });
                }
              },
            ),
            _label('Quando', first: false),
            BandTimeRangeSlider(
              bucket: _index.band,
              startTime: timeOfDayFromMinutes(part.startMinutes),
              endTime: timeOfDayFromMinutes(part.endMinutes),
              onChanged: (start, end)
              {
                if (start == null || end == null)
                {
                  return;
                }

                setState(()
                {
                  part.startMinutes = minutesOfTimeOfDay(start);
                  part.endMinutes = minutesOfTimeOfDay(end);
                });
              },
              minimumMinutes: kMinimumBandMinutes,
              maximumMinutes: _ceilingFor(part),
              windowStartMinutes: slot.windowStart,
              windowEndMinutes: slot.windowEnd,
              nameOverride: '',
              // The slider writes the hours itself, large, above its own track:
              // a line saying them again over it was the same range twice. What
              // it does not say is how long they are, and that goes in the slot
              // the open/closed switch leaves empty here.
              trailing: Text(formatMinutes(part.minutes), style: _valueStyle),
            ),
            if (refusal != null) ...[
              const SizedBox(height: 12),
              _buildMessage(refusal, isRefusal: true),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(String message, {required bool isRefusal})
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isRefusal ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
          size: 20,
          color: isRefusal ? AppTheme.trialDanger : AppTheme.modifiedAccent,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: isRefusal ? AppTheme.trialDanger : AppTheme.modifiedAccent,
            ),
          ),
        ),
      ],
    );
  }

  // The two quantities the window is bounded by: how long the materia was asked
  // for, and how long the pupil is here. An hour and a half inside five hours is
  // a different problem from one inside two, so it is read with the title.
  Widget _buildFacts()
  {
    final presence = _entry.presence;
    final mode = presence.mode;
    final presenceMinutes = minutesOfTimeOfDay(presence.endTime) - minutesOfTimeOfDay(presence.startTime);

    Widget fact(IconData icon, Color accent, String text)
    {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          // Flexible: a Wrap hands its children a bounded width, but a Row of
          // minimum size would pass the text an unbounded one and let it run out
          // of the window — and this line is wider than a phone's whole dialog.
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      );
    }

    // The name is dropped rather than the clock, which is the part being read:
    // the name is already the title, the face and the eyebrow.
    //
    // Not "Presente" for both — a pupil at a screen is not present anywhere.
    final presenceLabel = mode == kOnlineMode ? 'Online' : 'Presente';

    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        fact(Icons.schedule_rounded, AppTheme.trialTealDeep, '${formatMinutes(_booking.duration)} da pianificare'),
        fact(
          lessonModeIcon(mode),
          lessonAccent(mode),
          '$presenceLabel ${formatMinutes(presenceMinutes)} · '
          '${formatTimeRange(presence.startTime, presence.endTime)}',
        ),
      ],
    );
  }

  // The one thing in the way: the band being published, or the first part the
  // calendar would refuse. Not drawn anywhere — every part says its own refusal
  // under its own fields — but answered with by the confirm, in a banner.
  String? get _obstacle
  {
    if (_isLocked)
    {
      return kPublishedRefusal;
    }

    for (final part in _parts)
    {
      final refusal = _refusalFor(part);

      if (refusal != null)
      {
        return refusal;
      }
    }

    return null;
  }

  // The two quantities the window is bounded by. Not the materia's name, which
  // titles the window: what belongs here is what the steps below are spending.
  String? get _blockedReason
  {
    // Only where there are disciplines to put anywhere: a service is not made of
    // them, and an hour of it with none is the only shape it has.
    if (_requestedDisciplines.isNotEmpty && _parts.any((part) => part.disciplineIds.isEmpty))
    {
      return 'Ogni lezione deve avere almeno una disciplina.';
    }

    return null;
  }

  // The three questions in the order they can be answered: in how many hours,
  // how long each is, and who takes them when. Three and not two — the minutes
  // are what the request is made of, and belong to a question of their own.
  ({String question, String hint}) get _guide
  {
    return switch (_stepIndex)
    {
      0 => (
        question: 'In quante lezioni deve essere svolta la materia?',
        hint: 'Una materia può essere divisa in due lezioni diverse e le discipline possono essere '
            'spartite liberamente tra esse.',
      ),
      _ => (
        question: 'Chi svolge le lezioni?',
        hint: 'Scegli il docente o i docenti che devono effettuare le lezioni.',
      ),
    };
  }

  Widget _buildStep()
  {
    return switch (_stepIndex)
    {
      0 => _buildDivision(),
      _ => _buildSchedule(),
    };
  }

  void _goTo(int step)
  {
    setState(()
    {
      _movingForward = step > _stepIndex;
      _stepIndex = step.clamp(0, 1);
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final guide = _guide;
    final name = _entry.presence.student.fullName;
    final hasRoomForStep = MediaQuery.sizeOf(context).width >= _stepCountMin;

    return AppDialogStack(
      eyebrow: hasRoomForStep ? 'Passo ${_stepIndex + 1} di 2 · $name' : name,
      title: _requestName,
      leading: PersonAvatar(person: _entry.presence.student, size: PersonAvatar.titleSize),
      subtitle: _buildFacts(),
      maxWidth: _dialogWidth,
      // The two answers side by side, and the one that takes something away
      // dressed as such: it is where every other window of the app puts the
      // command that deletes, and it only exists while there is something on the
      // calendar to take off.
      footer: _entry.parts.isEmpty || _isLocked
          ? AppDialogFooter.single(
              maxWidth: _dialogFooterWidth,
              AppGradientButton(
                label: 'CONFERMA',
                icon: Icons.check_rounded,
                busy: _isSaving,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                horizontalPadding: _dialogButtonPadding,
                onPressed: _confirm,
              ),
            )
          : AppDialogFooter(
              maxWidth: _dialogFooterWidth,
              secondary: AppGradientButton(
                label: 'RIMUOVI DAL CALENDARIO',
                icon: Icons.delete_outline_rounded,
                gradient: AppTheme.dangerGradient,
                accent: AppTheme.trialDanger,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                horizontalPadding: _dialogButtonPadding,
                onPressed: _unplanEverything,
              ),
              primary: AppGradientButton(
                label: 'CONFERMA',
                icon: Icons.check_rounded,
                busy: _isSaving,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                horizontalPadding: _dialogButtonPadding,
                onPressed: _confirm,
              ),
            ),
      children: [
        AppCarouselFrame(
          index: _stepIndex,
          movingForward: _movingForward,
          maxContentWidth: _stepWidth,
          canGoBack: _stepIndex > 0,
          canGoForward: _stepIndex < 1,
          forwardBlockedReason: _blockedReason,
          onBack: () => _goTo(_stepIndex - 1),
          onForward: () => _goTo(_stepIndex + 1),
          header: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _stepWidth),
              child: AppDialogPill(
                expand: true,
                child: PersonEditGuide(question: guide.question, hint: guide.hint),
              ),
            ),
          ),
          child: _buildStep(),
        ),
      ],
    );
  }
}

// Opens the window on one request, whichever way it was reached: the card in
// the panel and the hour on the track are two views of the same materia.
Future<void> showLessonPlanWizard({
  required BuildContext context,
  required SchedulableBooking entry,
  required CalendarDayIndex index,
  required List<MinistrySubjectItem> ministrySubjects,
  Future<LessonItem?> Function({
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
  })? onCreate,
  Future<LessonItem?> Function({
    required LessonItem existing,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
  })? onUpdate,
  Future<bool> Function(int id, Function(String) onError)? onDelete,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'Pianifica una materia',
    builder: (dialogContext) => LessonPlanWizard(
      entry: entry,
      index: index,
      ministrySubjects: ministrySubjects,
      onCreate: onCreate,
      onUpdate: onUpdate,
      onDelete: onDelete,
    ),
  );
}
