import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/ministry_subject_item.dart';
import '../../../../features/association/models/subject_taxonomy.dart';
import '../../../../features/lessons/models/band_offer.dart';
import '../../../../features/lessons/models/subject_request.dart';
import '../../../../features/lessons/utils/booking_wizard_strings.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/utils/teacher_fit.dart';
import '../../../../features/lessons/widgets/booking_fields_section.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../layout/mobile_breakpoints.dart';
import '../../../shared/widgets/mobile_danger_button.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../../../shared/widgets/mobile_wizard_parts.dart';
import '../mobile_bookings_tour.dart';
import 'mobile_booking_parts.dart';

const Duration _turn = Duration(milliseconds: 340);
const Curve _turnCurve = Curves.easeInOutCubic;

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

const EdgeInsets _tourInflate = EdgeInsets.all(5);
const double _tourRadius = 20;

// What a tour explains on each page, in its order.
const Map<SubjectRequestStep, List<SubjectFlowMark>> _tourMarks = {
  SubjectRequestStep.disciplines: [SubjectFlowMark.disciplines],
  SubjectRequestStep.what: [SubjectFlowMark.kinds, SubjectFlowMark.topic, SubjectFlowMark.next],
  SubjectRequestStep.duration: [SubjectFlowMark.durations, SubjectFlowMark.count],
  SubjectRequestStep.teachers: [SubjectFlowMark.teachers, SubjectFlowMark.search],
  SubjectRequestStep.notes: [SubjectFlowMark.notes, SubjectFlowMark.add, SubjectFlowMark.save],
};

Widget _lit(SubjectFlowMark mark, Widget child)
{
  return MobileTourTarget(id: subjectFlowTourTarget(mark), inflate: _tourInflate, radius: _tourRadius, child: child);
}

// Mirrors the desktop's subject wizard.
class MobileSubjectFlow
{
  final SubjectRequestDraft draft;
  final SubjectRequestDraft? replacing;

  final String mode;
  final PersonItem pupil;
  final bool isSelf;
  final bool isEditing;

  final List<MinistrySubjectItem> ministrySubjects;

  // Already without the teachers the pupil would rather not have.
  final List<PersonItem> offered;

  final int? studyProgramId;

  // More than one adds a step to choose the band.
  final List<BandOffer> bands;
  final Map<int, int> minutesByDisciplineTakenByOthers;

  final PageController pages = PageController();

  late final TextEditingController topic = TextEditingController(text: draft.topic);
  late final TextEditingController notes = TextEditingController(text: draft.notes);
  final TextEditingController search = TextEditingController();

  // The settled step; the controller tracks a swipe in progress.
  int step = 0;

  // Whose tour explains the flow, null for none.
  final String? tourFor;

  MobileSubjectFlow({
    required SubjectRequestDraft from,
    this.replacing,
    required this.mode,
    required this.pupil,
    required this.isSelf,
    required this.isEditing,
    required this.ministrySubjects,
    required this.offered,
    required this.studyProgramId,
    required this.bands,
    required this.minutesByDisciplineTakenByOthers,
    this.tourFor,
  }) : draft = from.copy()
  {
    final Set<String> codes = {for (final teacher in offered) teacher.fiscalCode};

    // The picker shows only these, so the rest could never be removed.
    draft.preferredTeacherTaxCodes.retainWhere(codes.contains);

    if (bands.length == 1)
    {
      draft.band = bands.single.band;
    }
  }

  void dispose()
  {
    pages.dispose();
    topic.dispose();
    notes.dispose();
    search.dispose();
  }

  String get eyebrow => '${draft.displayName} · ${modeLabel(mode).toLowerCase()}';

  String get title => isEditing ? kEditSubjectTitle : kAddSubjectTitle;

  List<AssociationSubjectOption> get disciplineChoices
  {
    if (!draft.asksForDisciplines)
    {
      return const [];
    }

    for (final subject in ministrySubjects)
    {
      if (subject.id == draft.ministrySubjectId)
      {
        return subject.associationSubjects.length > 1 ? subject.associationSubjects : const [];
      }
    }

    return const [];
  }

  BandOffer? get _offer => bands.where((offer) => offer.band == draft.band).firstOrNull;

  int? get minutesAvailable => _offer?.minutes;

  int get minutesTakenByOthers => _offer?.takenByOthers ?? 0;

  bool get _choosesBand => bands.length > 1;

  List<SubjectRequestStep> get steps => [
        if (_choosesBand) SubjectRequestStep.band,
        if (disciplineChoices.isNotEmpty) SubjectRequestStep.disciplines,
        if (draft.asksForTopicAndTag) SubjectRequestStep.what,
        SubjectRequestStep.duration,
        SubjectRequestStep.teachers,
        SubjectRequestStep.notes,
      ];

  int get minutesTaken => minutesTakenByOthers + (draft.duration ?? 0);

  bool get exceeds
  {
    final int? available = minutesAvailable;

    return available != null && minutesTaken > available;
  }

  (int, int)? get _overCeiling
  {
    final int? duration = draft.duration;

    if (duration == null)
    {
      return null;
    }

    for (final discipline in draft.disciplineIds)
    {
      final int minutes = (minutesByDisciplineTakenByOthers[discipline] ?? 0) + duration;

      if (minutes > maxDailyMinutesPerDiscipline)
      {
        return (discipline, minutes);
      }
    }

    return null;
  }

  String _disciplineName(int id)
  {
    if (draft.associationSubjectId == id && draft.associationSubjectName != null)
    {
      return draft.associationSubjectName!;
    }

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

    return 'La disciplina';
  }

  String? blockedReason(SubjectRequestStep step)
  {
    switch (step)
    {
      case SubjectRequestStep.band:
        return draft.band == null ? kPickBandToGoOn : null;

      case SubjectRequestStep.disciplines:
        return draft.associationSubjectIds.isEmpty ? kPickDisciplineToGoOn : null;

      case SubjectRequestStep.what:
        return draft.tags.isEmpty ? kPickKindToGoOn : null;

      case SubjectRequestStep.duration:
        if (draft.duration == null)
        {
          return kPickDurationToGoOn;
        }

        if (exceeds)
        {
          return durationOverStay(
            minutesTaken,
            minutesAvailable ?? 0,
            isSelf: isSelf,
            name: pupil.firstName,
            band: _choosesBand ? draft.band : null,
          );
        }

        if (_overCeiling case final (int, int) over)
        {
          return disciplineOverCeiling(_disciplineName(over.$1), over.$2, maxDailyMinutesPerDiscipline);
        }

        return null;

      case SubjectRequestStep.teachers:
      case SubjectRequestStep.notes:
        return null;
    }
  }

  String? get problem
  {
    for (final step in steps)
    {
      final String? reason = blockedReason(step);

      if (reason != null)
      {
        return reason;
      }
    }

    return null;
  }

  SubjectRequestDraft finish()
  {
    draft.topic = topic.text.trim();
    draft.notes = notes.text.trim();

    return draft;
  }

  List<PersonItem> get _teachers
  {
    final String query = search.text.trim().toLowerCase();

    return teachersFitFirst(offered, disciplineIds: draft.disciplineIds, studyProgramId: studyProgramId)
        .where((teacher) => query.isEmpty || '${teacher.firstName} ${teacher.lastName}'.toLowerCase().contains(query))
        .toList();
  }

  bool get _full => draft.preferredTeacherTaxCodes.length >= SubjectRequestDraft.maxPreferredTeachers;

  List<Widget> page(int index, {required bool tablet, required VoidCallback onChanged})
  {
    final SubjectRequestStep shown = steps[index];

    return [
      MobileWizardGuide(
        question: shown.questionFor(isSelf: isSelf),
        hint: shown.hintFor(studentName: pupil.firstName, isSelf: isSelf),
      ),
      const SizedBox(height: 18),
      ...switch (shown)
      {
        SubjectRequestStep.band => _bandChoices(onChanged),
        SubjectRequestStep.disciplines => _disciplines(onChanged),
        SubjectRequestStep.what => _what(onChanged),
        SubjectRequestStep.duration => _duration(onChanged),
        SubjectRequestStep.teachers => _teacherList(tablet: tablet, onChanged: onChanged),
        SubjectRequestStep.notes => _notes(),
      },
    ];
  }

  List<Widget> _bandChoices(VoidCallback onChanged)
  {
    return [
      for (final offer in bands)
        MobileSelectRow(
          key: ValueKey(offer.band),
          title: bandLabel(offer.band),
          subtitle: '${offer.hours} · ${minutesLeftLabel(offer.left)}',
          selected: draft.band == offer.band,
          onTap: ()
          {
            draft.band = offer.band;
            onChanged();
          },
        ),
    ];
  }

  List<Widget> _disciplines(VoidCallback onChanged)
  {
    return [
      _lit(
        SubjectFlowMark.disciplines,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final discipline in disciplineChoices)
              MobileSelectRow(
                key: ValueKey(discipline.id),
                title: discipline.name,
                subtitle: descriptionOrNull(discipline.description),
                selected: draft.associationSubjectIds.contains(discipline.id),
                onTap: ()
                {
                  if (!draft.associationSubjectIds.remove(discipline.id))
                  {
                    draft.associationSubjectIds.add(discipline.id);
                  }

                  onChanged();
                },
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _what(VoidCallback onChanged)
  {
    return [
      const MobileFieldHead(kLessonKindLabel),
      _lit(
        SubjectFlowMark.kinds,
        Wrap(
          spacing: kMobileChipGap,
          runSpacing: kMobileChipGap,
          children: [
            for (final option in bookingTagOptions)
              MobileSelectChip(
                label: option.label,
                selected: draft.tags.contains(option.value),
                onTap: ()
                {
                  if (!draft.tags.remove(option.value))
                  {
                    draft.tags.add(option.value);
                  }

                  onChanged();
                },
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _lit(
        SubjectFlowMark.topic,
        MobileTextField(
          controller: topic,
          label: kTopicLabel,
          hintText: kTopicHint,
          maxLength: FieldLimits.topic,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    ];
  }

  List<Widget> _duration(VoidCallback onChanged)
  {
    final int? available = minutesAvailable;

    return [
      MobileFieldHead(
        kDurationLabel,
        count: available == null ? null : '${formatMinutes(minutesTaken)} di ${formatMinutes(available)}',
        over: exceeds,
        countTourTarget: subjectFlowTourTarget(SubjectFlowMark.count),
      ),
      _lit(
        SubjectFlowMark.durations,
        Wrap(
          spacing: kMobileChipGap,
          runSpacing: kMobileChipGap,
          children: [
            for (final minutes in bookingDurationOptions)
              MobileSelectChip(
                label: formatMinutes(minutes),
                selected: draft.duration == minutes,
                onTap: ()
                {
                  draft.duration = minutes;
                  onChanged();
                },
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _teacherList({required bool tablet, required VoidCallback onChanged})
  {
    final List<String> chosen = draft.preferredTeacherTaxCodes;

    if (offered.isEmpty)
    {
      return [
        MobileFieldHead(preferredTeachersLabel(pupil.gender)),
        const MobileQuietLine(kNoTeachers),
      ];
    }

    final List<PersonItem> shown = _teachers;

    return [
      MobileFieldHead(
        preferredTeachersLabel(pupil.gender),
        count: '${chosen.length} di ${SubjectRequestDraft.maxPreferredTeachers}',
      ),
      _lit(
        SubjectFlowMark.search,
        MobileSearchField(
          controller: search,
          hintText: _full ? kTeachersFull : kSearchTeacher,
          onChanged: (_) => onChanged(),
          onGlass: true,
        ),
      ),
      const SizedBox(height: 12),
      if (shown.isEmpty) MobileQuietLine(_full ? kTeachersFullNoMatch : kNoTeacherMatch),
      // Cut to the page: the list may run longer than the screen.
      MobileTourTarget(
        id: shown.isEmpty ? null : subjectFlowTourTarget(SubjectFlowMark.teachers),
        inflate: _tourInflate,
        radius: _tourRadius,
        clipped: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final teacher in shown)
              MobileSelectRow(
                key: ValueKey(teacher.fiscalCode),
                title: '${teacher.firstName} ${teacher.lastName}',
                leading: MobileTeacherFace(teacher: teacher, size: tablet ? 64 : 56),
                selected: chosen.contains(teacher.fiscalCode),
                onTap: ()
                {
                  if (chosen.contains(teacher.fiscalCode))
                  {
                    chosen.remove(teacher.fiscalCode);
                  }
                  else if (!_full)
                  {
                    chosen.add(teacher.fiscalCode);
                  }

                  onChanged();
                },
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _notes()
  {
    return [
      _lit(
        SubjectFlowMark.notes,
        MobileTextField(
          controller: notes,
          label: kTeacherNotesLabel,
          hintText: kTeacherNotesHint,
          maxLength: FieldLimits.notes,
          minLines: 3,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
        ),
      ),
    ];
  }
}

// Null [onBackFromStart] hides the back button on the first step.
MobileSheet mobileSubjectFlowSheet({
  required BuildContext context,
  required MobileSubjectFlow flow,
  required bool tablet,
  required bool busy,
  required VoidCallback onChanged,
  required VoidCallback? onBackFromStart,
  VoidCallback? onRemove,
  required VoidCallback onDone,
})
{
  final List<SubjectRequestStep> steps = flow.steps;
  final int step = flow.step.clamp(0, steps.length - 1);
  final bool last = step == steps.length - 1;
  final VoidCallback? back = step > 0
      ? () => flow.pages.animateToPage(step - 1, duration: _turn, curve: _turnCurve)
      : onBackFromStart;

  void next()
  {
    if (busy)
    {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final String? reason = last ? flow.problem : flow.blockedReason(steps[step]);

    if (reason != null)
    {
      MobileNotice.show(context, reason, error: true);

      return;
    }

    if (last)
    {
      onDone();

      return;
    }

    flow.pages.animateToPage(step + 1, duration: _turn, curve: _turnCurve);
  }

  final VoidCallback? remove = onRemove;

  return MobileSheet(
    eyebrow: flow.eyebrow,
    title: flow.title,
    aboveKeyboard: true,
    subhead: MobileWizardDots(count: steps.length, position: flow.pages, fallback: step),
    content: MobileStepPager(
      key: ObjectKey(flow),
      controller: flow.pages,
      keys: [for (final shown in steps) 'subject/${shown.name}'],
      pageBuilder: (index) => flow.page(index, tablet: tablet, onChanged: onChanged),
      onPageChanged: (index)
      {
        flow.step = index;
        onChanged();
      },
      blockedReason: (index) => flow.blockedReason(steps[index]),
    ),
    footer: Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MobileWizardBackSlot(onBack: back, busy: busy),
              Expanded(
                child: MobileTourTarget(
                  id: kSubjectFlowTourFooter,
                  inflate: const EdgeInsets.all(4),
                  radius: 22,
                  child: MobileGoldButton(
                    label: last ? (flow.isEditing ? 'Salva' : 'Aggiungi') : 'Avanti',
                    icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    busy: busy,
                    onPressed: next,
                  ),
                ),
              ),
            ],
          ),
          if (remove != null) ...[
            const SizedBox(height: 12),
            MobileDangerButton(
              label: kRemoveSubjectLink,
              icon: Icons.delete_outline_rounded,
              onPressed: remove,
            ),
          ],
        ],
      ),
    ),
  );
}

// True once saved; turned to from another sheet, the caller closes that sheet.
Future<bool> showMobileSubjectSheet({
  required BuildContext context,
  required MobileSubjectFlow flow,
  required Future<bool> Function(SubjectRequestDraft draft) onSave,
}) async
{
  final bool? saved = await showMobileSheet<bool>(
    context: context,
    draggable: false,
    builder: (context) => MobileSubjectPage(
      flow: flow,
      onDone: (draft) async
      {
        final bool saved = await onSave(draft);

        if (saved && context.mounted)
        {
          finishMobileSheet(context, true);
        }

        return saved;
      },
    ),
  );

  return saved ?? false;
}

// Owns [flow] and disposes of it.
class MobileSubjectPage extends StatefulWidget
{
  final MobileSubjectFlow flow;

  // False keeps the page as it was, to try again.
  final Future<bool> Function(SubjectRequestDraft draft) onDone;

  final Future<void> Function(BuildContext page)? onRemove;

  const MobileSubjectPage({super.key, required this.flow, required this.onDone, this.onRemove});

  @override
  State<MobileSubjectPage> createState() => _MobileSubjectPageState();
}

class _MobileSubjectPageState extends State<MobileSubjectPage>
{
  bool _busy = false;

  final SubjectFlowTourPulse _tourPulse = SubjectFlowTourPulse();

  MobileSubjectFlow get _flow => widget.flow;

  @override
  void initState()
  {
    super.initState();

    if (_flow.tourFor != null)
    {
      _flow.pages.addListener(_onPages);
      mobileTourChanges.addListener(_tourLater);
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    mobileTourChanges.removeListener(_tourLater);
    _flow.pages.removeListener(_onPages);
    widget.flow.dispose();

    // Not while the tree is locked: a tour ends, and redraws, on hearing it.
    final SubjectFlowTourPulse pulse = _tourPulse;

    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      pulse.leave();
      pulse.dispose();
    });

    super.dispose();
  }

  String _keyOf(int index) => 'subject/${_flow.steps[index].name}';

  double get _page
  {
    final PageController pages = _flow.pages;

    return pages.hasClients && pages.position.haveDimensions ? pages.page ?? _flow.step.toDouble() : _flow.step.toDouble();
  }

  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  void _onPages()
  {
    final double page = _page;
    final bool settled = (page - page.round()).abs() < _settled && page.round() < _flow.steps.length;

    _tourPulse.rest(settled ? _keyOf(page.round()) : null);

    if (settled)
    {
      _tourLater();
    }
  }

  // Once the sheet stands still on a page, its parts never explained; the intro on the first page.
  Future<void> _tourCheck() async
  {
    final String? taxCode = _flow.tourFor;
    final double page = _page;

    if (!mounted || taxCode == null || _busy || isMobileTourShown)
    {
      return;
    }

    if (isMobileSheetMoving(context))
    {
      _tourLater();

      return;
    }

    final int index = page.round();

    if ((page - index).abs() >= _settled || index != _flow.step || index >= _flow.steps.length)
    {
      return;
    }

    final String key = _keyOf(index);

    _tourPulse.rest(key);

    await startSubjectFlowTour(
      taxCode: taxCode,
      marks: _tourMarks[_flow.steps[index]] ?? const [],
      page: key,
      first: index == 0,
      editing: _flow.isEditing,
      online: _flow.mode == kOnlineMode,
      pupil: BookingTourPupil.of(self: _flow.isSelf, gender: _flow.pupil.gender),
      pulse: _tourPulse,
    );
  }

  Future<void> _done() async
  {
    setState(() => _busy = true);

    final bool done = await widget.onDone(widget.flow.finish());

    if (mounted && !done)
    {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final Future<void> Function(BuildContext page)? remove = widget.onRemove;

    return mobileSubjectFlowSheet(
      context: context,
      flow: widget.flow,
      tablet: MobileBreakpoints.of(context).isTablet,
      busy: _busy,
      onChanged: () => setState(() {}),
      onBackFromStart: null,
      onRemove: remove == null ? null : () => remove(context),
      onDone: _done,
    );
  }
}
