import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_entity_chip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/ministry_subject_chip.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/ministry_subject_item.dart';
import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';

// The read-only panel opens over the details dialog, not over the page, so it
// needs more depth than the usual dialog shadow to lift off the white behind it.
const List<BoxShadow> _floatingPanelShadow = [
  BoxShadow(color: Color(0x2A000000), offset: Offset(0, 12), blurRadius: 36),
];

// Both dialogs of this file stand at the same height and type size as the ones
// in the settings and in the role switch.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

class SchoolCard extends StatefulWidget
{
  final SchoolItem school;
  final List<StudyProgramItem> availableStudyPrograms;
  final List<MinistrySubjectItem> availableMinistrySubjects;
  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const SchoolCard({
    super.key,
    required this.school,
    required this.availableStudyPrograms,
    required this.availableMinistrySubjects,
    required this.onEditRequested,
    required this.onDelete,
  });

  @override
  State<SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends State<SchoolCard>
{
  bool _isHovering = false;

  void _showDetailsDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SchoolDetails',
      builder: (dialogContext) => _SchoolDetailsDialogContent(
        school: widget.school,
        availableStudyPrograms: widget.availableStudyPrograms,
        availableMinistrySubjects: widget.availableMinistrySubjects,
        onEditRequested: ()
        {
          Navigator.of(dialogContext).pop();
          // The reopen callback reuses the card state, not the dialog context
          // that is about to become invalid.
          widget.onEditRequested(_showDetailsDialog);
        },
        onDelete: widget.onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: _showDetailsDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 360,
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            // Gold under the pointer, the same mark a module card takes on the
            // dashboard and a document row in the settings.
            border: Border.all(
              color: _isHovering ? AppTheme.trialGold : Colors.transparent,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OverflowTooltipText(
                text: widget.school.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialOcean,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              OverflowTooltipText(
                text: '${widget.school.city} (${widget.school.province})',
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolDetailsDialogContent extends StatelessWidget
{
  final SchoolItem school;
  final List<StudyProgramItem> availableStudyPrograms;
  final List<MinistrySubjectItem> availableMinistrySubjects;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _SchoolDetailsDialogContent({
    required this.school,
    required this.availableStudyPrograms,
    required this.availableMinistrySubjects,
    required this.onEditRequested,
    required this.onDelete,
  });

  // Two full buttons rather than two words in a corner: this one throws a school
  // away, and the answer that does it should not be quieter than the one that
  // walks away from it.
  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmSchoolDeletion',
      builder: (confirmContext) => AppDialogShell(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        width: 460,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'ELIMINA',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              Navigator.pop(context);
              onDelete();
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'La scuola '),
                TextSpan(
                  text: school.name,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' verrà eliminata definitivamente.'),
              ],
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ),
    );
  }

  // The program id carried by a SchoolStudyProgramOption is resolved against
  // the full StudyProgramItem list loaded elsewhere, so the read only dialog
  // can show ministry subjects and years that the option does not carry.
  void _openReadOnlyProgramDialog(BuildContext context, int programId)
  {
    final fullProgram = availableStudyPrograms.firstWhere(
      (program) => program.id == programId,
      orElse: () => throw Exception('Percorso non trovato nei dati caricati'),
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ReadOnlyProgramDetails',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            // Placed by the dialog itself, which is the only place it can be
            // done: see the note on AppDialogShell.alignment.
            child: _ReadOnlyStudyProgramDialogContent(
              program: fullProgram,
              availableMinistrySubjects: availableMinistrySubjects,
            ),
          ),
        );
      },
    );
  }

  // Small, tracked and muted over the value it names: the same pairing the
  // settings cards use, and the same the top bar uses over a role.
  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 20),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.trialMutedText,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  TextStyle get _valueStyle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      );

  @override
  Widget build(BuildContext context)
  {
    final hasCode = school.mechanographicCode != null && school.mechanographicCode!.isNotEmpty;

    return AppDialogShell(
      eyebrow: 'Scuola',
      title: school.name,
      width: 600,
      maxHeight: MediaQuery.of(context).size.height * 0.85,
      // Selection stops at the body: the buttons underneath are not text you
      // would ever want to drag a cursor through.
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'ELIMINA',
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => _showDeleteConfirmation(context),
        ),
        primary: AppGradientButton(
          label: 'MODIFICA',
          icon: Icons.edit_outlined,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: onEditRequested,
        ),
      ),
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Città'),
                        Text(school.city, style: _valueStyle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Provincia'),
                        Text(school.province, style: _valueStyle),
                      ],
                    ),
                  ),
                ],
              ),
              _buildFieldLabel('Codice meccanografico'),
              Text(
                hasCode ? school.mechanographicCode! : 'Non presente',
                style: hasCode
                    ? _valueStyle
                    : _valueStyle.copyWith(
                        color: AppTheme.trialMutedText,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
              ),
              _buildFieldLabel('Percorsi di studio attivi'),
              if (school.studyPrograms.isEmpty)
                Text(
                  'Nessun percorso associato a questa scuola.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.trialMutedText,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: school.studyPrograms.map((program)
                    {
                      return AppEntityChip(
                        label: program.name,
                        onTap: () => _openReadOnlyProgramDialog(context, program.id),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyStudyProgramDialogContent extends StatelessWidget
{
  final StudyProgramItem program;
  final List<MinistrySubjectItem> availableMinistrySubjects;

  const _ReadOnlyStudyProgramDialogContent({
    required this.program,
    required this.availableMinistrySubjects,
  });

  // Small, tracked and muted over the value it names: the same pairing the
  // settings cards use, and the same the top bar uses over a role.
  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 20),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.trialMutedText,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  TextStyle get _valueStyle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      );

  @override
  Widget build(BuildContext context)
  {
    final hasDescription = program.description.isNotEmpty;

    return AppDialogShell(
      eyebrow: 'Percorso di studio',
      title: program.name,
      maxHeight: MediaQuery.of(context).size.height * 0.85,
      // To the right of centre, so the school details it was opened from stay
      // readable behind it rather than being covered up.
      alignment: const Alignment(0.5, 0),
      shadow: _floatingPanelShadow,
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Livello'),
                        Text(schoolLevelLabel(program.level), style: _valueStyle),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Anni di corso'),
                        Text('${program.minYear} - ${program.maxYear}', style: _valueStyle),
                      ],
                    ),
                  ),
                ],
              ),
              _buildFieldLabel('Descrizione'),
              Text(
                hasDescription ? program.description : 'Nessuna descrizione fornita.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: hasDescription ? AppTheme.trialInk : AppTheme.trialMutedText,
                  fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
                ),
              ),
              _buildFieldLabel('Materie ministeriali incluse'),
              if (program.ministrySubjects.isEmpty)
                Text(
                  'Nessuna materia associata.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.trialMutedText,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: program.ministrySubjects.map((option)
                    {
                      return MinistrySubjectChip(
                        option: option,
                        availableMinistrySubjects: availableMinistrySubjects,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}