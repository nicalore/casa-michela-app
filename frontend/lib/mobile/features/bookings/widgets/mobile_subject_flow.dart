import 'package:flutter/material.dart';

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
import '../../../shared/widgets/mobile_wizard_parts.dart';
import 'mobile_booking_parts.dart';

const Duration _turn = Duration(milliseconds: 340);
const Curve _turnCurve = Curves.easeInOutCubic;

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
    ];
  }

  List<Widget> _what(VoidCallback onChanged)
  {
    return [
      const MobileFieldHead(kLessonKindLabel),
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
      const SizedBox(height: 20),
      MobileTextField(
        controller: topic,
        label: kTopicLabel,
        hintText: kTopicHint,
        maxLength: FieldLimits.topic,
        textCapitalization: TextCapitalization.sentences,
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
      ),
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
      MobileSearchField(
        controller: search,
        hintText: _full ? kTeachersFull : kSearchTeacher,
        onChanged: (_) => onChanged(),
        onGlass: true,
      ),
      const SizedBox(height: 12),
      if (shown.isEmpty) MobileQuietLine(_full ? kTeachersFullNoMatch : kNoTeacherMatch),
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
    ];
  }

  List<Widget> _notes()
  {
    return [
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
                child: MobileGoldButton(
                  label: last ? (flow.isEditing ? 'Salva' : 'Aggiungi') : 'Avanti',
                  icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  busy: busy,
                  onPressed: next,
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

  @override
  void dispose()
  {
    widget.flow.dispose();
    super.dispose();
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
