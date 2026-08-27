import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_catalogue_card.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_entity_chip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/ministry_subject_chip.dart';
import '../models/ministry_subject_item.dart';
import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';

// Deeper than the usual dialog shadow: this panel opens over another dialog.
const List<BoxShadow> _floatingPanelShadow = [
  BoxShadow(color: Color(0x2A000000), offset: Offset(0, 12), blurRadius: 36),
];

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _confirmWidth = 480;

class SchoolCard extends StatelessWidget
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

  void _showDetailsDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SchoolDetails',
      builder: (dialogContext) => _SchoolDetailsDialogContent(
        school: school,
        availableStudyPrograms: availableStudyPrograms,
        availableMinistrySubjects: availableMinistrySubjects,
        onEditRequested: ()
        {
          Navigator.of(dialogContext).pop();
          // Reopen with the card's context, not the closing dialog's.
          onEditRequested(() => _showDetailsDialog(context));
        },
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCatalogueCard(
      title: school.name,
      details: [
        CatalogueDetail('${school.city} (${school.province})'),
      ],
      onTap: () => _showDetailsDialog(context),
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

  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmSchoolDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        showClose: false,
        maxWidth: _confirmWidth,
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
        children: [
          AppDialogPill(
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
        ],
      ),
    );
  }

  // The option only carries the program id; the full StudyProgramItem is
  // resolved from the loaded list to show subjects and years.
  void _openReadOnlyProgramDialog(BuildContext context, int programId)
  {
    final fullProgram = availableStudyPrograms.firstWhere(
      (program) => program.id == programId,
      orElse: () => throw Exception('Percorso non trovato nei dati caricati'),
    );

    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ReadOnlyProgramDetails',
      builder: (_) => _ReadOnlyStudyProgramDialogContent(
        program: fullProgram,
        availableMinistrySubjects: availableMinistrySubjects,
      ),
    );
  }

  Widget _buildFieldLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 6, top: first ? 0 : 20),
      child: AppFieldLabel(text),
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

    return AppDialogStack(
      eyebrow: 'Scuola',
      title: school.name,
      maxWidth: 600,
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
      children: [
        AppDialogPill(
          expand: true,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                          _buildFieldLabel('Città', first: true),
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
                          _buildFieldLabel('Provincia', first: true),
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
              ],
            ),
          ),
        ),
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Percorsi di studio attivi', first: true),
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
      ],
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

  Widget _buildFieldLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 6, top: first ? 0 : 20),
      child: AppFieldLabel(text),
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

    return AppDialogStack(
      eyebrow: 'Percorso di studio',
      title: program.name,
      maxWidth: 560,
      // Right of centre so the school details stay readable behind it.
      alignment: const Alignment(0.5, 0),
      children: [
        AppDialogPill(
          shadow: _floatingPanelShadow,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Livello', first: true),
                            Text(schoolLevelLabel(program.level), style: _valueStyle),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Anni di corso', first: true),
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
              ],
            ),
          ),
        ),
        AppDialogPill(
          shadow: _floatingPanelShadow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Materie ministeriali incluse', first: true),
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
      ],
    );
  }
}