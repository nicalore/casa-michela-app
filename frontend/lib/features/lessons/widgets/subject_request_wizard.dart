import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
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

enum _Step
{
  disciplines(
    'Cosa deve studiare di questa materia?',
    'Almeno uno.',
  ),

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

  final double width;

  const _Step(this.question, this.hint, {this.width = _cardWidth});
}

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _cardWidth = 520;

const double _widestCard = 880;
const double _stackWidth =
    _widestCard + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

class SubjectRequestWizard extends StatefulWidget
{
  final String mode;

  final SubjectRequestDraft draft;

  final List<MinistrySubjectItem> ministrySubjects;

  final List<PersonItem> teachers;

  final bool isEditing;

  final int? minutesAvailable;
  final int minutesTakenByOthers;

  final Map<int, int> minutesByDisciplineTakenByOthers;

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

  String? _blockedReason(_Step step)
  {
    if (step == _Step.disciplines && _draft.associationSubjectIds.isEmpty)
    {
      return 'Seleziona almeno una disciplina per andare avanti.';
    }

    if (step == _Step.what && _draft.tags.isEmpty)
    {
      return 'Seleziona almeno un tipo di lezione per andare avanti.';
    }

    if (step == _Step.duration && _draft.duration == null)
    {
      return 'Seleziona la durata per andare avanti.';
    }

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

  Widget _buildLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

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

  Widget _buildDisciplinesStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          maxLength: FieldLimits.topic,
        ),
      ],
    );
  }

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
          maxLength: FieldLimits.notes,
          maxLines: 4,
          minLines: 3,
        ),
      ],
    );
  }

  Widget _buildStep()
  {
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
