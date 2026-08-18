import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/ministry_subject_item.dart';

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const Duration _selectFade = Duration(milliseconds: 180);

// The height a row always has, picked or not: the name, the line below it and
// the room separating them from the edge.
const double rowHeight = 68;

// The one for rows carrying a face: the circle plus the room around it.
const double rowHeightWithAvatar = 76;

// One subject in the catalogue, ticked or not.
//
// The shape a discipline has in the anagrafica, where a teacher's competences
// are picked: the tick, the name, and under it what qualifies it. Here the
// second line is the parts of the subject that were chosen, and the control on
// the right is both the answer to "which parts" and the way to change it.
//
// A subject made of one discipline has nothing to qualify: ticking it is the
// whole answer, and the row carries neither a second line nor a control.
class SubjectPickRow extends StatefulWidget
{
  final String name;

  // What sits under the name, on a single line. On a subject it is the chosen
  // parts and how long it lasts; on a discipline or a service it is the
  // description, that is what they are — and, once picked, the duration in front
  // too. Empty where there is nothing to say, and then the name is centred.
  final String subtitle;

  final bool selected;

  // False where the subject is made of a single discipline: there is nothing
  // to open.
  final bool hasChoice;

  // Something to put before the tick: a teacher's photo, where the row names
  // one. Subjects and services have no face.
  final Widget? leading;

  final ValueChanged<bool> onSelected;
  final VoidCallback onEditDisciplines;

  const SubjectPickRow({
    super.key,
    required this.name,
    this.subtitle = '',
    required this.selected,
    required this.hasChoice,
    this.leading,
    required this.onSelected,
    required this.onEditDisciplines,
  });

  @override
  State<SubjectPickRow> createState() => _SubjectPickRowState();
}

class _SubjectPickRowState extends State<SubjectPickRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.selected),
        child: AnimatedContainer(
          duration: _selectFade,
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          // As tall as if the second line were always there: ticking an entry
          // must not grow the row under the fingers and shift everything after
          // it. While the second line is absent, the name is centred.
          height: widget.leading == null ? rowHeight : rowHeightWithAvatar,
          decoration: BoxDecoration(
            // Transparent *of this colour*, not Colors.transparent: that is
            // black at zero opacity, and halfway through the fade the row went
            // through a grey nobody asked for.
            color: widget.selected ? kPickedSurface : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
            // The outline is always there, transparent: what lights up must not
            // move by two pixels what is inside it.
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AppCheckMark(selected: widget.selected),
              const SizedBox(width: 14),
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OverflowTooltipText(
                      text: widget.name,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      OverflowTooltipText(
                        text: widget.subtitle,
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
              // On a row already ticked it changes the parts; on one not ticked
              // it is the quiet way in for whoever already knows they want only
              // some of them — it opens the same window, and confirming there
              // is what brings the subject in.
              if (widget.hasChoice)
                Tooltip(
                  // Neutral: what pressing it opens is not always a choice of
                  // disciplines — a service has none.
                  message: 'Modifica',
                  waitDuration: const Duration(milliseconds: 400),
                  child: _TuneButton(onTap: widget.onEditDisciplines),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// The same glyph the competences use for "which parts of this": a control that
// opens rather than one that does.
class _TuneButton extends StatefulWidget
{
  final VoidCallback onTap;

  const _TuneButton({required this.onTap});

  @override
  State<_TuneButton> createState() => _TuneButtonState();
}

class _TuneButtonState extends State<_TuneButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _selectFade,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.trialGoldSurface : AppTheme.trialGoldSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.tune_rounded, size: 20, color: AppTheme.trialTealDeep),
        ),
      ),
    );
  }
}

// Which parts of one subject, asked in a window of its own.
//
// It opens by itself the moment a subject with more than one part is ticked:
// the question belongs to that subject, and asking it on a card further along
// meant walking the same list of subjects a second time.
class SubjectDisciplinesDialog extends StatefulWidget
{
  final MinistrySubjectItem subject;
  final Set<int> chosen;

  // What comes back. Empty is not one of the answers: a subject with no parts
  // chosen is a subject that was not asked for, and the tick on the row is how
  // that is said.
  final ValueChanged<Set<int>> onConfirmed;

  const SubjectDisciplinesDialog({
    super.key,
    required this.subject,
    required this.chosen,
    required this.onConfirmed,
  });

  @override
  State<SubjectDisciplinesDialog> createState() => _SubjectDisciplinesDialogState();
}

class _SubjectDisciplinesDialogState extends State<SubjectDisciplinesDialog>
{
  late final Set<int> _chosen = {...widget.chosen};

  void _confirm()
  {
    if (_chosen.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Scegli almeno una disciplina.',
        isError: true,
      );

      return;
    }

    widget.onConfirmed(_chosen);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Discipline',
      title: widget.subject.name,
      maxWidth: 520,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'CONFERMA',
          icon: Icons.check_rounded,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _confirm,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Di ${widget.subject.name}, che cosa vuole fare?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final discipline in widget.subject.associationSubjects)
                    AppSelectableChip(
                      label: discipline.name,
                      selected: _chosen.contains(discipline.id),
                      onSelected: (selected) => setState(()
                      {
                        if (selected)
                        {
                          _chosen.add(discipline.id);

                          return;
                        }

                        _chosen.remove(discipline.id);
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
