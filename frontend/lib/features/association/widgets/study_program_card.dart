import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_catalogue_card.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/ministry_subject_chip.dart';
import '../models/ministry_subject_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';

class StudyProgramCard extends StatelessWidget
{
  final StudyProgramItem program;
  final List<MinistrySubjectItem> availableMinistrySubjects;
  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const StudyProgramCard({
    super.key,
    required this.program,
    required this.availableMinistrySubjects,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDetailsDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'StudyProgramDetails',
      builder: (dialogContext) => _StudyProgramDetailsDialogContent(
        program: program,
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
      eyebrow: program.sector,
      title: program.name,
      onTap: () => _showDetailsDialog(context),
    );
  }
}

class _StudyProgramDetailsDialogContent extends StatelessWidget
{
  static const double _dialogButtonHeight = 52;

  static const double _confirmWidth = 480;
  static const double _dialogButtonFontSize = 14;

  final StudyProgramItem program;
  final List<MinistrySubjectItem> availableMinistrySubjects;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _StudyProgramDetailsDialogContent({
    required this.program,
    required this.availableMinistrySubjects,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmDeletion',
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
                  const TextSpan(text: 'Il percorso '),
                  TextSpan(
                    text: program.name,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' verrà eliminato definitivamente.'),
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
      eyebrow: program.sector ?? 'Percorso di studio',
      title: program.name,
      maxWidth: 650,
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
          expand: true,
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
                    spacing: 10,
                    runSpacing: 10,
                    children: program.ministrySubjects
                        .map((option) => MinistrySubjectChip(
                              option: option,
                              availableMinistrySubjects: availableMinistrySubjects,
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
