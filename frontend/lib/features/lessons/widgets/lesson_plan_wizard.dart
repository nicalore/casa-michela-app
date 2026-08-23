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

const double _dialogFooterWidth = 640;

const double _dialogButtonPadding = 18;

const double _dialogWidth = _stepWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

const double _stepCountMin = 560;

const int _step = kQuarterHour;

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

class _Part
{
  final int? lessonId;

  final bool isLocked;

  Set<int> disciplineIds;

  int? availabilityId;

  int startMinutes;
  int endMinutes;

  _Part({
    this.lessonId,
    this.isLocked = false,
    required this.disciplineIds,
    required this.availabilityId,
    required this.startMinutes,
    required this.endMinutes,
  });

  int get minutes => endMinutes - startMinutes;

  bool get isPlanned => lessonId != null;
}

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
  late final List<_Part> _parts = _initialParts();

  int _stepIndex = 0;
  bool _movingForward = true;

  bool _isSaving = false;

  CalendarDayIndex get _index => widget.index;

  SchedulableBooking get _entry => widget.entry;

  BookingSummaryItem get _booking => _entry.booking;

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

  List<_Part> _initialParts()
  {
    final requested = widget.entry.requestedDisciplineIds;

    final parts = [
      for (final lesson in widget.entry.parts)
        _Part(
          lessonId: lesson.id,
          isLocked: lesson.isLocked,
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

  List<_Slot> _slotsFor(Set<int> disciplineIds, {List<_Part> siblings = const [], int? lessonId, int? keep})
  {
    final presence = _entry.presence;

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

  void _reconcile()
  {
    for (final part in _parts)
    {
      if (part.isLocked)
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
        final first = _parts.first;

        first.disciplineIds = {..._entry.requestedDisciplineIds};
        _parts.removeRange(1, _parts.length);
      }

      if (count == 2 && _parts.length == 1)
      {
        final first = _parts.first;
        final ordered = _requestedDisciplines;

        final cut = (ordered.length / 2).ceil();

        first.disciplineIds = ordered.take(cut).toSet();

        final rest = ordered.skip(cut).toSet();

        final second = ordered.isEmpty
            ? const <int>{}
            : rest.isEmpty
                ? {ordered.last}
                : rest;
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

  Future<void> _confirm() async
  {
    if (_isSaving)
    {
      return;
    }

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

  bool get _canSplit => _booking.duration >= 2 * kMinimumBandMinutes;

  Widget _buildDivision()
  {
    final disciplines = _requestedDisciplines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: AppDialogPill(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSegmentedTabs(
                  labels: const ['Una', 'Due'],
                  selectedIndex: _parts.length > 1 ? 1 : 0,
                  onSelected: _canSplit && !_isLocked ? (index) => _setPartCount(index + 1) : (_) {},
                  height: 38,
                  fontSize: 13,
                  padding: EdgeInsets.zero,
                  hugContent: true,
                ),
                if (!_canSplit) ...[
                  const SizedBox(height: 10),
                  Text(
                    'È stata prenotata meno di un\'ora: non è possibile dividere la materia in due '
                        'lezioni poiché ognuna deve durare almeno mezz\'ora.',
                    style: _noteStyle,
                  ),
                ],
              ],
            ),
          ),
        ),
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

  String _assignedWord(int minutes)
  {
    final hours = minutes ~/ 60;

    if (hours == 0)
    {
      return 'Assegnati';
    }

    return hours == 1 ? 'Assegnata' : 'Assegnate';
  }

  Widget _buildTotals()
  {
    final assigned = _parts.fold(0, (total, part) => total + part.minutes);
    final left = _booking.duration - assigned;

    return AppDialogPill(
      expand: true,
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
          if (part.isLocked)
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

  String? get _obstacle
  {
    if (_isLocked)
    {
      return kSettledRefusal;
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

  String? get _blockedReason
  {
    if (_requestedDisciplines.isNotEmpty && _parts.any((part) => part.disciplineIds.isEmpty))
    {
      return 'Ogni lezione deve avere almeno una disciplina.';
    }

    return null;
  }

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
