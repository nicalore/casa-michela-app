import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/subject_taxonomy.dart';
import 'subject_pick_row.dart';
import '../../people/edit/widgets/person_edit_guide.dart';
import '../../people/models/person_item.dart';
import '../models/subject_request.dart';
import '../utils/opening_window.dart';
import 'booking_fields_section.dart';
import 'subject_request_tile.dart';

// The possible steps. Which of them are taken depends on what was asked for:
// the questions that make no sense for that kind are not put.
enum _Step
{
  // Which parts of the subject. Only where there is more than one to choose
  // from: a single one is already decided, and a lone discipline or a service
  // has none.
  disciplines(
    'Cosa deve studiare di questa materia?',
    'Almeno uno.',
  ),

  // What kind of hour, and about what. On a service nothing of this is left,
  // and the step is not taken.
  what(
    'Cosa deve fare durante la lezione?',
    'Almeno una tipologia. Queste informazioni aiuteranno il docente a rendere la lezione più '
        'adatta alle esigenze dello studente.',
  ),
  duration(
    'Quanto deve durare la lezione?',
    'Non è possibile organizzare più di due ore di lezione al giorno per la stessa materia. Se hai bisogno di altre ore, puoi richiedere una lezione online.',
  ),
  teachers(
    'Con quale docente?',
    'Se vuoi, puoi indicare fino a tre docenti preferiti o non graditi dallo studente. '
    'Le preferenze indicate verranno tenute in considerazione, ma potrebbero non essere soddisfatte in base alle esigenze dell\'Associazione.',
    width: 880,
  ),
  notes(
    'Altro?',
    'Se lo desideri, puoi inserire qui sotto altre informazioni che ritieni utili. Le indicazioni saranno lette dal docente che seguirà lo studente.',
  );

  final String question;
  final String hint;

  // How wide this step's card is comfortable. The teachers one holds two side
  // by side and needs twice the room.
  final double width;

  const _Step(this.question, this.hint, {this.width = _cardWidth});
}

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// One column of fields, and the frame around it: the card plus an arrow and a
// gap on either side, and a little more so the frame is over its own threshold
// rather than exactly on it — under that it drops the arrows below the card.
const double _cardWidth = 520;

// The dialog is as wide as its widest step: resizing at every arrow would make
// the edges jump back and forth.
const double _widestCard = 880;
const double _stackWidth =
    _widestCard + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

// One subject asked for, a question at a time: laid out together these answers
// are a form nobody reads to the end, and folded into their row they make a list
// a page tall the moment one is opened.
//
// How many cards are needed depends on the kind: a service has neither parts nor
// a topic and opens straight on the duration.
class SubjectRequestWizard extends StatefulWidget
{
  // The way of being there this subject is asked for in, said in the eyebrow:
  // an hour asked online is a different hour from the same one asked here.
  final String mode;

  // Copied on the way in, so walking away leaves the day exactly as it was.
  final SubjectRequestDraft draft;

  // What the pupil's own study programme teaches.
  final List<MinistrySubjectItem> ministrySubjects;

  // Everyone: a pupil asking for a teacher the register does not list under that
  // discipline is telling the association something it may not know, and a form
  // that hides the name cannot be told it.
  final List<PersonItem> teachers;

  final bool isEditing;

  // How much time the pupil gives in this mode and how much is already taken:
  // what says how much is left, and what stops more being taken. Null where
  // nobody knows, rather than treating every duration as over a zero budget.
  final int? minutesAvailable;
  final int minutesTakenByOthers;

  // Minutes already put on each discipline by the other subjects. Two hours a
  // day on one is the whole of it, and a subject can pass that ceiling without
  // passing the pupil's own time.
  final Map<int, int> minutesByDisciplineTakenByOthers;

  // True where it landed. The window closes on true and stays on false, with
  // whatever was said still in it.
  final Future<bool> Function(SubjectRequestDraft draft) onSave;

  const SubjectRequestWizard({
    super.key,
    required this.mode,
    required this.draft,
    required this.ministrySubjects,
    required this.teachers,
    required this.onSave,
    this.isEditing = false,
    this.minutesAvailable,
    this.minutesTakenByOthers = 0,
    this.minutesByDisciplineTakenByOthers = const {},
  });

  @override
  State<SubjectRequestWizard> createState() => _SubjectRequestWizardState();
}

class _SubjectRequestWizardState extends State<SubjectRequestWizard>
{
  late final SubjectRequestDraft _draft = widget.draft.copy();

  late final TextEditingController _topicController =
      TextEditingController(text: _draft.topic);
  late final TextEditingController _notesController =
      TextEditingController(text: _draft.notes);

  int _step = 0;
  bool _movingForward = true;
  bool _isSaving = false;

  // The first two steps exist only where they have something to ask: a single
  // discipline has no parts to choose from, and a service starts from the
  // duration rather than opening on an empty card.
  List<_Step> get _stepList => [
        if (_disciplineChoices.isNotEmpty) _Step.disciplines,
        if (_draft.asksForTopicAndTag) _Step.what,
        _Step.duration,
        _Step.teachers,
        _Step.notes,
      ];

  int get _steps => _stepList.length;

  @override
  void dispose()
  {
    _topicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _goTo(int step)
  {
    if (step > _step && _blockedReason(_stepList[_step]) != null)
    {
      return;
    }

    setState(()
    {
      _movingForward = step > _step;
      _step = step.clamp(0, _steps - 1);
    });
  }

  // Why this step does not let one move on. Three carry a mandatory answer —
  // which parts, what kind, how long; naming no teacher is an ordinary request.
  // The reason is returned and not shouted: the arrow darkens and says it on
  // hover.
  String? _blockedReason(_Step step)
  {
    // The disciplines are asked for only where there are some to choose from:
    // under a ministry subject holding more than one.
    if (step == _Step.disciplines && _draft.associationSubjectIds.isEmpty)
    {
      return 'Seleziona almeno una disciplina per andare avanti.';
    }

    // What the hour is for is what the teacher prepares against: an hour that
    // does not say is an hour they arrive at cold. The step is only put where
    // it means something — a service is not a lesson about anything.
    if (step == _Step.what && _draft.tags.isEmpty)
    {
      return 'Seleziona almeno un tipo di lezione per andare avanti.';
    }

    if (step == _Step.duration && _draft.duration == null)
    {
      return 'Seleziona la durata per andare avanti.';
    }

    // The pupil's time is what it is: a subject going over it cannot be added,
    // and is shortened here rather than refused on save.
    if (step == _Step.duration && _exceeds)
    {
      return 'La durata totale delle lezioni è ${formatMinutes(_minutesTaken)}, ma lo studente è '
          'presente per ${formatMinutes(widget.minutesAvailable ?? 0)}.';
    }

    if (step == _Step.duration)
    {
      final over = _disciplineOverCeiling;

      if (over != null)
      {
        return '${_disciplineName(over.$1)}: ${formatMinutes(over.$2)} in un '
            'giorno. Su una stessa disciplina non si può andare oltre '
            '${formatMinutes(maxDailyMinutesPerDiscipline)} nella stessa '
            'modalità.';
      }
    }

    return null;
  }

  // The first discipline this request would push past the daily ceiling. Read
  // against the whole day: two hours is two hours whether asked in one go or in
  // four quarters spread over as many subjects.
  (int, int)? get _disciplineOverCeiling
  {
    final duration = _draft.duration;

    if (duration == null)
    {
      return null;
    }

    for (final discipline in _draft.disciplineIds)
    {
      final minutes =
          (widget.minutesByDisciplineTakenByOthers[discipline] ?? 0) + duration;

      if (minutes > maxDailyMinutesPerDiscipline)
      {
        return (discipline, minutes);
      }
    }

    return null;
  }

  // A discipline by name, out of what this window was handed. The lone-
  // discipline kind carries its own; under a ministry subject the catalogue has
  // it.
  String _disciplineName(int id)
  {
    if (_draft.associationSubjectId == id && _draft.associationSubjectName != null)
    {
      return _draft.associationSubjectName!;
    }

    for (final subject in widget.ministrySubjects)
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

  // Saving from any step must not skip the mandatory answers of the steps
  // before it. Here the reason is spoken aloud: the save button is not the
  // arrow, and has no tooltip to rest on.
  bool _canSave()
  {
    for (final step in _stepList)
    {
      final reason = _blockedReason(step);

      if (reason != null)
      {
        CustomSnackBar.show(context: context, message: reason, isError: true);

        return false;
      }
    }

    return true;
  }

  Future<void> _save() async
  {
    if (_isSaving || !_canSave())
    {
      return;
    }

    _draft.topic = _topicController.text.trim();
    _draft.notes = _notesController.text.trim();

    setState(() => _isSaving = true);

    final saved = await widget.onSave(_draft);

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (saved)
    {
      Navigator.of(context).pop();
    }
  }

  // Dark and in sentence case, like the section titles of the dialog this one
  // opens from and like the name AppTextField gives its fields.
  Widget _buildLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  // The disciplines under the chosen ministry subject, where there is more than
  // one to choose from.
  List<AssociationSubjectOption> get _disciplineChoices
  {
    if (!_draft.asksForDisciplines)
    {
      return const [];
    }

    for (final subject in widget.ministrySubjects)
    {
      if (subject.id == _draft.ministrySubjectId)
      {
        return subject.associationSubjects.length > 1
            ? subject.associationSubjects
            : const [];
      }
    }

    return const [];
  }

  // One row per discipline. Chips said the name and nothing else, where a row
  // also carries what the discipline is — the thing being decided on.
  Widget _buildDisciplinesStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A subject's catalogue can be long: it scrolls inside the card instead
        // of stretching it and dragging the whole dialog along.
        CardScrollArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final discipline in _disciplineChoices)
                SubjectPickRow(
                  key: ValueKey(discipline.id),
                  name: discipline.name,
                  subtitle: descriptionOrNull(discipline.description) ?? '',
                  selected: _draft.associationSubjectIds.contains(discipline.id),
                  hasChoice: false,
                  onSelected: (selected) => setState(()
                  {
                    if (selected)
                    {
                      _draft.associationSubjectIds.add(discipline.id);

                      return;
                    }

                    _draft.associationSubjectIds.remove(discipline.id);
                  }),
                  onEditDisciplines: () {},
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabel('Tipo di lezione', first: true),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in bookingTagOptions)
              AppSelectableChip(
                label: option.label,
                selected: _draft.tags.contains(option.value),
                // More than one where the hour is two things at once, and never
                // none: what the hour is for is what the teacher prepares
                // against. Pressing one again removes it.
                onSelected: (selected) => setState(()
                {
                  if (selected)
                  {
                    _draft.tags.add(option.value);

                    return;
                  }

                  _draft.tags.remove(option.value);
                }),
              ),
          ],
        ),
        _buildLabel('Argomento (opzionale)'),
        AppTextField(
          controller: _topicController,
          label: 'Argomento',
          showLabel: false,
          hintText: 'Es. Disequazioni di secondo grado',
        ),
      ],
    );
  }

  // How much time is taken in total, this request included.
  int get _minutesTaken => widget.minutesTakenByOthers + (_draft.duration ?? 0);

  bool get _exceeds
  {
    final available = widget.minutesAvailable;

    return available != null && _minutesTaken > available;
  }

  Widget _buildDurationStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Next to the title, how much has already been taken: the duration is
        // picked while looking at it, instead of finding out at the end that the
        // sums do not add up.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppFieldLabel('Durata'),
              if (widget.minutesAvailable != null)
              Text(
                '${formatMinutes(_minutesTaken)} di '
                '${formatMinutes(widget.minutesAvailable!)}',
                style: GoogleFonts.plusJakartaSans(
                  // Red when over budget: it is the only thing preventing one
                  // from moving on, and has to look like it.
                  color: _exceeds ? AppTheme.trialDanger : AppTheme.trialTealDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final minutes in bookingDurationOptions)
              AppSelectableChip(
                label: formatMinutes(minutes),
                selected: _draft.duration == minutes,
                onSelected: (_) => setState(() => _draft.duration = minutes),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeachersStep()
  {
    final preferred = TeacherPicker(
      label: 'Docenti preferiti',
      icon: Icons.thumb_up_outlined,
      chosen: _draft.preferredTeacherTaxCodes,
      other: _draft.excludedTeacherTaxCodes,
      offered: widget.teachers,
      onChanged: () => setState(() {}),
    );

    final avoided = TeacherPicker(
      label: 'Docenti da evitare',
      icon: Icons.thumb_down_outlined,
      chosen: _draft.excludedTeacherTaxCodes,
      other: _draft.preferredTeacherTaxCodes,
      offered: widget.teachers,
      onChanged: () => setState(() {}),
    );

    // Two separate cards, like the two modes on a day's page: inside one box
    // they read as a single list with a rule through the middle. How many can be
    // named is told by the counter at the head of each.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: AppDialogPill(expand: true, child: preferred)),
        const SizedBox(width: 20),
        Expanded(child: AppDialogPill(expand: true, child: avoided)),
      ],
    );
  }

  Widget _buildNotesStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabel('Note per il docente', first: true),
        AppTextField(
          controller: _notesController,
          label: 'Note',
          showLabel: false,
          hintText: 'Inserisci...',
          maxLines: 4,
          minLines: 3,
        ),
      ],
    );
  }

  Widget _buildStep()
  {
    // Every step is one card, except the teachers one: those are two distinct
    // answers and live in two separate cards, side by side.
    return switch (_stepList[_step])
    {
      _Step.disciplines => AppDialogPill(expand: true, child: _buildDisciplinesStep()),
      _Step.what => AppDialogPill(expand: true, child: _buildSubjectStep()),
      _Step.duration => AppDialogPill(expand: true, child: _buildDurationStep()),
      _Step.teachers => _buildTeachersStep(),
      _Step.notes => AppDialogPill(expand: true, child: _buildNotesStep()),
    };
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Passo ${_step + 1} di $_steps · ${modeLabel(widget.mode).toLowerCase()}',
      title: widget.isEditing ? 'Modifica materia' : 'Aggiungi materia',
      maxWidth: _stackWidth,
      // The two buttons answer the window; the arrows beside the card walk
      // between the passes. A footer that sometimes saves and sometimes moves is
      // one nobody can press without reading.
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: widget.isEditing ? 'SALVA' : 'AGGIUNGI',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      children: [
        // The question being answered, with how to answer it below: the same
        // pill that sits at the top of the dialog this one opens from.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _widestCard),
            child: AppDialogPill(
              expand: true,
              child: PersonEditGuide(
                question: _stepList[_step].question,
                hint: _stepList[_step].hint,
              ),
            ),
          ),
        ),
        AppCarouselFrame(
          index: _step,
          movingForward: _movingForward,
          maxContentWidth: _stepList[_step].width,
          canGoBack: _step > 0,
          canGoForward: _step < _steps - 1,
          forwardBlockedReason: _blockedReason(_stepList[_step]),
          onBack: () => _goTo(_step - 1),
          onForward: () => _goTo(_step + 1),
          child: _buildStep(),
        ),
      ],
    );
  }
}
