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

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// The name of a ministry subject, or what to say where none has been chosen.
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

// The disciplines of a request, by name.
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

// The names behind a list of tax codes, in the order they were given.
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

// A list of subjects asked for, each one a row that opens onto its own window.
//
// The rows are a list and stay a list: what a subject holds is seven things,
// and seven things unfolding inside a row pushed every other row off the
// bottom of the window. Pressing one opens them in the middle of the screen
// instead, where there is room to read them.
class SubjectRequestList extends StatelessWidget
{
  final List<SubjectRequestDraft> requests;

  // Every subject there is, for naming what is already asked for: a booking
  // written before the pupil changed programme still has to say what it is.
  final List<MinistrySubjectItem> ministrySubjects;

  // And the ones that may be chosen now — what the pupil's own programme
  // teaches. Left out, they are the same.
  final List<MinistrySubjectItem>? offeredSubjects;

  final List<PersonItem> teachers;

  // Said in place of the list where there is nothing in it yet.
  final String emptyLabel;

  // Left out where nothing may be added — a way of being there with no hours
  // on it has nothing to spend.
  final VoidCallback? onAdd;

  final void Function(int index) onRemove;

  // Where the pencil goes: the window that asks a subject a question at a
  // time. Left out, the rows only open on what they say.
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

// One subject asked for: a line that opens onto a card of everything it holds.
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

  // How it is called, whichever of the three kinds it is: a ministry subject is
  // looked up in the catalogue, while a discipline asked on its own and a
  // service carry their own name with them.
  String get _title
  {
    if (widget.draft.kind != BookingRequestKind.ministrySubject)
    {
      return widget.draft.displayName;
    }

    return ministrySubjectName(widget.ministrySubjects, widget.draft.ministrySubjectId);
  }

  // What it costs and what it is made of, in that order: the duration is what
  // one line of a list is read for.
  String get _summary
  {
    final disciplines = disciplineNames(widget.ministrySubjects, widget.draft);

    final pieces = <String>[
      if (widget.draft.duration != null) formatMinutes(widget.draft.duration!),
      if (disciplines.isNotEmpty) disciplines.join(', '),
    ];

    return pieces.join(' · ');
  }

  // The card the row opens onto, in the middle of the screen. The two buttons
  // under it do what the two icons on the row do: whoever came in by pressing
  // the name should not have to go back out to the row to act on what they have
  // just read.
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
        // The outline is always there, transparent: what lights up must not
        // move by two pixels what is inside it.
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

// Everything a requested subject holds, opened at the centre of the screen.
//
// The entries sit in a row like the facts of a school year, and for the same
// reason: seven short values in a column make a tall card saying very little,
// whereas in a row they read at a glance. Above them the pill with the subject's
// name, which is what holds the seven answers together.
class _SubjectRequestDetailsDialog extends StatelessWidget
{
  // The size of the read-only dialogs — the same as an availability's page.
  // Seven values side by side want more than a thousand pixels not to be
  // squeezed, and three of them are sentences that wrapped four times each in a
  // narrow column.
  static const double _maxWidth = 560;

  // How wide the single remaining button is where there is nothing to edit —
  // barely half of what two take, so it does not turn into a band.
  static const double _loneButtonWidth = 240;

  // What stands in for an answer that was not given. Every entry is there
  // regardless: that a subject's topic went unsaid is something worth reading,
  // and a card changing columns depending on what is filled in does not read the
  // same way twice.
  static const String _empty = '—';

  // What the thing being looked at is called: it sits in the pill above the
  // card, because every entry that follows speaks of it.
  final String title;

  final SubjectRequestDraft draft;
  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  // Off where the rows cannot be edited: the card is then read-only, and the
  // only button left at the bottom is the one that removes.
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

  // All seven, always, with a dash where nothing was answered, and in the order
  // they are asked in.
  List<(String, String)> get _voices
  {
    String said(String value) => value.trim().isEmpty ? _empty : value.trim();

    // The disciplines only where there is more than one: a single one already
    // sits in the row this dialog opened from, under the subject's name, and
    // here the dash is left as for any other entry with nothing to say.
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

  // Name above, value below: the pair every detail dialog of the app says one
  // thing with. The value wraps as much as it needs — a topic and a note are
  // sentences, not words.
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
              // The dash is not an answer and does not read as one: it is
              // there to say the question was left blank.
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
          // Selection stops at the body: the buttons underneath are not text
          // you would ever want to drag a cursor through.
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

// How tall the teacher list gets before it starts scrolling on its own.
const double _teacherListMaxHeight = 340;

// Who the pupil would rather have, or rather not. Searched for by name and
// gathered as chips: an association with forty teachers cannot put forty chips
// on a form, and the one being looked for is known by name rather than found
// by reading the list.
class TeacherPicker extends StatefulWidget
{
  final String label;
  final IconData icon;

  // What the field says while it is empty. The same either way: it is a name
  // being looked for, whichever of the two lists it is going into.
  final String hint;

  // The list being written, and the one on the other side of the same
  // question: a teacher named here leaves the other rather than standing on
  // both.
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

  // Who can still be picked, and who has already been picked here. Whoever is
  // on the other list does not show up: preferred and not preferred are mutually
  // exclusive answers, and offering someone here would be offering to
  // contradict oneself.
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
      // The two lists are two sides of one answer, so a teacher moves between
      // them rather than standing on both.
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
              // The label gives way rather than running off the end: inside the
              // window that opens off a day this row is a column of a pair, and
              // "DOCENTI DA EVITARE" is wider than half of it.
              Expanded(
                child: AppFieldLabel(widget.label),
              ),
              const SizedBox(width: 8),
              // Like the time taken next to the duration: same line, same
              // size, same colour. They say the same thing — how much of what
              // there is has been used — and have to read the same way.
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
          // A list that stays put instead of a dropdown that opens and closes.
          // As a dropdown, picking one left it open — and one had to press
          // elsewhere to get rid of it — while closing it forced a return to the
          // field for the second name. A list that stays has neither problem:
          // one ticks and carries on.
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
                          // The face and nothing else, with no second line:
                          // what they teach is not what one looks at to
                          // recognise them, and it was the line that grew the
                          // list here while saying nothing.
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
          // No chips below carrying the picked names: the tick in the list
          // already says so, and repeating it was the same answer written
          // twice.
        ],
      ],
    );
  }
}
