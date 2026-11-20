import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_catalogue_card.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_entity_chip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../models/ministry_subject_item.dart';
import '../models/subject_taxonomy.dart';

Color get _levelTextColor => AppTheme.trialTealDeepText;

class MinistrySubjectCard extends StatelessWidget
{
  final MinistrySubjectItem subject;
  final void Function(VoidCallback onSaved) onEditRequested;
  final VoidCallback onDelete;

  const MinistrySubjectCard({
    super.key,
    required this.subject,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDetailsDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'MinistrySubjectDetails',
      builder: (dialogContext) => _MinistrySubjectDetailsDialogContent(
        subject: subject,
        levelLabel: schoolLevelLabel(subject.level),
        areaLabels: subject.areas.map(subjectAreaLabel).toList(),
        // Wizard stacks over the details: closing and reopening them replayed their entrance.
        onEditRequested: () => onEditRequested(() => Navigator.of(dialogContext).pop()),
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String? description = descriptionOrNull(subject.description);

    return AppCatalogueCard(
      title: subject.name,
      details: [
        CatalogueDetail(schoolLevelLabel(subject.level), color: _levelTextColor),
        if (description != null) CatalogueDetail(description),
      ],
      onTap: () => _showDetailsDialog(context),
    );
  }
}

class _MinistrySubjectDetailsDialogContent extends StatelessWidget
{
  static const double _dialogButtonHeight = 52;

  static const double _confirmWidth = 480;
  static const double _dialogButtonFontSize = 14;

  // Fits the longest of the three levels with a little to spare.
  static const double _levelColumnWidth = 300;

  final MinistrySubjectItem subject;
  final String levelLabel;
  final List<String> areaLabels;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _MinistrySubjectDetailsDialogContent({
    required this.subject,
    required this.levelLabel,
    required this.areaLabels,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: tr('Eliminazione', 'Deletion'),
        title: tr('Confermi?', 'Confirm?'),
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: tr('ANNULLA', 'CANCEL'),
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialVioletText,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: tr('ELIMINA', 'DELETE'),
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDangerText,
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
                  TextSpan(text: tr('La materia ', 'The subject ')),
                  TextSpan(
                    text: subject.name,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: tr(' verrà eliminata definitivamente.', ' will be deleted permanently.')),
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
    final hasDescription = subject.description != null && subject.description!.isNotEmpty;
    final compact = AppBreakpoints.of(context).isNarrow;

    // Fixed-width column: "Scuola Secondaria di II Grado" needs 254px and must
    // not wrap.
    final Widget levelBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(tr('Livello', 'Level'), first: true),
        Text(
          levelLabel,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: _valueStyle,
        ),
      ],
    );

    final Widget areasBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(areaLabels.length == 1 ? tr('Area', 'Area') : tr('Aree', 'Areas'), first: true),
        for (int i = 0; i < areaLabels.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: Text(areaLabels[i], style: _valueStyle),
          ),
      ],
    );

    return AppDialogStack(
      eyebrow: tr('Materia ministeriale', 'Curriculum subject'),
      title: subject.name,
      maxWidth: 660,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: tr('ELIMINA', 'DELETE'),
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => _showDeleteConfirmation(context),
        ),
        primary: AppGradientButton(
          label: tr('MODIFICA', 'EDIT'),
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
                if (compact) ...[
                  levelBlock,
                  areasBlock,
                ]
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: _levelColumnWidth, child: levelBlock),
                      const SizedBox(width: 40),
                      Expanded(child: areasBlock),
                    ],
                  ),
                _buildFieldLabel(tr('Descrizione', 'Description')),
                Text(
                  hasDescription ? subject.description! : tr('Nessuna descrizione fornita.', 'No description given.'),
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
              _buildFieldLabel(tr('Discipline interne associate', 'Linked internal disciplines'), first: true),
              if (subject.associationSubjects.isEmpty)
                Center(
                  child: Text(
                    tr('Nessuna disciplina associata.', 'No linked disciplines.'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.trialMutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: subject.associationSubjects
                        .map((discipline) => AppEntityChip(label: discipline.name))
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
