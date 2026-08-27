import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../people/models/person_item.dart';
import '../models/booking_summary_item.dart';
import '../models/subject_request.dart';
import 'booking_fields_section.dart';
import 'person_avatar.dart';
import 'subject_pick_row.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

String ministrySubjectName(List<MinistrySubjectItem> subjects, int? id, {String fallback = 'Materia da scegliere'})
{
  for (final subject in subjects)
  {
    if (subject.id == id)
    {
      return subject.name;
    }
  }

  return fallback;
}

List<String> disciplineNames(List<MinistrySubjectItem> subjects, SubjectRequestDraft request)
{
  final names = <String>[];

  for (final subject in subjects)
  {
    if (subject.id != request.ministrySubjectId)
    {
      continue;
    }

    for (final discipline in subject.associationSubjects)
    {
      if (request.associationSubjectIds.contains(discipline.id))
      {
        names.add(discipline.name);
      }
    }
  }

  return names;
}

List<String> teacherNames(List<PersonItem> teachers, List<String> taxCodes)
{
  final names = <String>[];

  for (final taxCode in taxCodes)
  {
    for (final teacher in teachers)
    {
      if (teacher.fiscalCode == taxCode)
      {
        names.add('${teacher.firstName} ${teacher.lastName}');
      }
    }
  }

  return names;
}

class SubjectRequestList extends StatelessWidget
{
  final List<SubjectRequestDraft> requests;

  // The full catalogue, for naming bookings written before the pupil changed programme.
  final List<MinistrySubjectItem> ministrySubjects;

  // The subjects choosable now; null means same as ministrySubjects.
  final List<MinistrySubjectItem>? offeredSubjects;

  final List<PersonItem> teachers;

  final String emptyLabel;

  final VoidCallback? onAdd;

  final void Function(int index) onRemove;

  final void Function(int index)? onEdit;

  const SubjectRequestList({
    super.key,
    required this.requests,
    required this.ministrySubjects,
    required this.teachers,
    required this.onRemove,
    this.offeredSubjects,
    this.emptyLabel = 'Nessuna materia richiesta.',
    this.onAdd,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              emptyLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.trialMutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        for (var index = 0; index < requests.length; index++)
          SubjectRequestTile(
            key: ObjectKey(requests[index]),
            draft: requests[index],
            ministrySubjects: ministrySubjects,
            offeredSubjects: offeredSubjects,
            teachers: teachers,
            onDelete: () => onRemove(index),
            onEdit: onEdit == null ? null : () => onEdit!(index),
          ),
        if (onAdd != null) ...[
          const SizedBox(height: 4),
          AppAddRowButton(label: 'AGGIUNGI MATERIA', dense: true, onTap: onAdd!),
        ],
      ],
    );
  }
}

class SubjectRequestTile extends StatefulWidget
{
  final SubjectRequestDraft draft;
  final List<MinistrySubjectItem> ministrySubjects;
  final List<MinistrySubjectItem>? offeredSubjects;
  final List<PersonItem> teachers;

  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const SubjectRequestTile({
    super.key,
    required this.draft,
    required this.ministrySubjects,
    required this.teachers,
    required this.onDelete,
    this.offeredSubjects,
    this.onEdit,
  });

  @override
  State<SubjectRequestTile> createState() => _SubjectRequestTileState();
}

class _SubjectRequestTileState extends State<SubjectRequestTile>
{
  bool _hover = false;

  String get _title
  {
    if (widget.draft.kind != BookingRequestKind.ministrySubject)
    {
      return widget.draft.displayName;
    }

    return ministrySubjectName(widget.ministrySubjects, widget.draft.ministrySubjectId);
  }

  String get _summary
  {
    final disciplines = disciplineNames(widget.ministrySubjects, widget.draft);

    final pieces = <String>[
      if (widget.draft.duration != null) formatMinutes(widget.draft.duration!),
      if (disciplines.isNotEmpty) disciplines.join(', '),
    ];

    return pieces.join(' · ');
  }

  void _showDetails()
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'SubjectRequestDetails',
      builder: (dialogContext) => _SubjectRequestDetailsDialog(
        title: _title,
        draft: widget.draft,
        ministrySubjects: widget.ministrySubjects,
        teachers: widget.teachers,
        onEdit: widget.onEdit == null
            ? null
            : ()
              {
                Navigator.of(dialogContext).pop();
                widget.onEdit!();
              },
        onDelete: ()
        {
          Navigator.of(dialogContext).pop();
          widget.onDelete();
        },
      ),
    );
  }

  Widget _buildHeader()
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showDetails,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OverflowTooltipText(
                    text: _title,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.trialOcean,
                    ),
                  ),
                  if (_summary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    OverflowTooltipText(
                      text: _summary,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (widget.onEdit != null)
              FadeHoverIconButton(
                icon: Icons.edit_outlined,
                color: AppTheme.trialTealDeep,
                hoverColor: AppTheme.trialGoldSurface,
                onTap: widget.onEdit!,
              ),
            FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDanger,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(16),
        // Border always present (transparent when idle) so hover does not shift layout.
        border: Border.all(
          color: _hover
              ? AppTheme.trialGold
              : AppTheme.trialGold.withValues(alpha: 0),
          width: 2,
        ),
      ),
      child: _buildHeader(),
    );
  }
}

class _SubjectRequestDetailsDialog extends StatelessWidget
{
  static const double _maxWidth = 560;

  static const double _loneButtonWidth = 240;

  static const String _empty = '—';

  final String title;

  final SubjectRequestDraft draft;
  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const _SubjectRequestDetailsDialog({
    required this.title,
    required this.draft,
    required this.ministrySubjects,
    required this.teachers,
    required this.onDelete,
    this.onEdit,
  });

  List<(String, String)> get _voices
  {
    String said(String value) => value.trim().isEmpty ? _empty : value.trim();

    final disciplines = disciplineNames(ministrySubjects, draft);

    return [
      ('Discipline', disciplines.length > 1 ? disciplines.join(', ') : _empty),
      ('Durata', draft.duration == null ? _empty : formatMinutes(draft.duration!)),
      ('Tipo di lezione', said(bookingTagLabels(draft.tags).join(', '))),
      ('Argomento', said(draft.topic)),
      ('Docenti preferiti', said(teacherNames(teachers, draft.preferredTeacherTaxCodes).join(', '))),
      ('Docenti da evitare', said(teacherNames(teachers, draft.excludedTeacherTaxCodes).join(', '))),
      ('Note per il docente', said(draft.notes)),
    ];
  }

  Widget _buildVoice(String label, String value, {required bool first})
  {
    final isEmpty = value == _empty;

    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFieldLabel(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: isEmpty ? AppTheme.trialMutedText : AppTheme.trialInk,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget deleteButton = AppGradientButton(
      label: 'ELIMINA',
      icon: Icons.delete_outline_rounded,
      gradient: AppTheme.dangerGradient,
      accent: AppTheme.trialDanger,
      height: _dialogButtonHeight,
      fontSize: _dialogButtonFontSize,
      onPressed: onDelete,
    );

    final voices = _voices;

    return AppDialogStack(
      eyebrow: 'Materia richiesta',
      title: title,
      maxWidth: _maxWidth,
      footer: onEdit == null
          ? Center(child: SizedBox(width: _loneButtonWidth, child: deleteButton))
          : AppDialogFooter(
              secondary: deleteButton,
              primary: AppGradientButton(
                label: 'MODIFICA',
                icon: Icons.edit_outlined,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                onPressed: onEdit!,
              ),
            ),
      children: [
        AppDialogPill(
          expand: true,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < voices.length; i++)
                  _buildVoice(voices[i].$1, voices[i].$2, first: i == 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const double _teacherListMaxHeight = 340;

class TeacherPicker extends StatefulWidget
{
  final String label;
  final IconData icon;

  final String hint;

  // A teacher added to `chosen` is removed from `other`: the two lists are
  // mutually exclusive.
  final List<String> chosen;
  final List<String> other;

  final List<PersonItem> offered;

  final VoidCallback onChanged;

  const TeacherPicker({
    super.key,
    required this.label,
    required this.icon,
    required this.chosen,
    required this.other,
    required this.offered,
    required this.onChanged,
    this.hint = 'Cerca docente...',
  });

  @override
  State<TeacherPicker> createState() => _TeacherPickerState();
}

class _TeacherPickerState extends State<TeacherPicker>
{
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _query = '';

  @override
  void dispose()
  {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _full => widget.chosen.length >= SubjectRequestDraft.maxPreferredTeachers;

  List<PersonItem> get _available
  {
    final query = _query.trim().toLowerCase();

    return widget.offered.where((teacher)
    {
      if (widget.other.contains(teacher.fiscalCode))
      {
        return false;
      }

      if (query.isEmpty)
      {
        return true;
      }

      return '${teacher.firstName} ${teacher.lastName}'.toLowerCase().contains(query);
    }).toList();
  }

  void _add(PersonItem teacher)
  {
    if (_full)
    {
      return;
    }

    setState(()
    {
      widget.other.remove(teacher.fiscalCode);
      widget.chosen.add(teacher.fiscalCode);
    });

    widget.onChanged();
  }

  void _remove(String taxCode)
  {
    widget.chosen.remove(taxCode);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(widget.icon, size: 15, color: AppTheme.trialMutedText),
              const SizedBox(width: 8),
              Expanded(
                child: AppFieldLabel(widget.label),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.chosen.length} di ${SubjectRequestDraft.maxPreferredTeachers}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.trialTealDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (widget.offered.isEmpty)
          Text(
            'Nessun docente presente nell\'anagrafica.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
              fontStyle: FontStyle.italic,
            ),
          )
        else ...[
          AppSearchField(
            controller: _controller,
            hintText: _full
                ? 'Tre è il massimo: rimuovine uno per cambiarli'
                : widget.hint,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          if (_available.isEmpty)
            Text(
              _full
                  ? 'Ne hai già scelti tre.'
                  : 'Nessun docente trovato.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.trialMutedText,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _teacherListMaxHeight),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final teacher in _available)
                        SubjectPickRow(
                          key: ValueKey(teacher.fiscalCode),
                          name: '${teacher.firstName} ${teacher.lastName}',
                          leading: PersonAvatar(person: teacher, size: PersonAvatar.pickerSize),
                          selected: widget.chosen.contains(teacher.fiscalCode),
                          hasChoice: false,
                          onSelected: (selected) => selected
                              ? _add(teacher)
                              : setState(() => _remove(teacher.fiscalCode)),
                          onEditDisciplines: () {},
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
