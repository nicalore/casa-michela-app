import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

const Color _levelTextColor = AppTheme.trialTealDeep;

class MinistrySubjectCard extends StatelessWidget
{
  final MinistrySubjectItem subject;
  final void Function(VoidCallback onCancel) onEditRequested;
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
                  const TextSpan(text: 'La materia '),
                  TextSpan(
                    text: subject.name,
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
    final compact = AppBreakpoints.of(context).isCompact;

    // Fixed-width column: "Scuola Secondaria di II Grado" needs 254px and must
    // not wrap.
    final Widget levelBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Livello', first: true),
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
        _buildFieldLabel(areaLabels.length == 1 ? 'Area' : 'Aree', first: true),
        for (int i = 0; i < areaLabels.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: Text(areaLabels[i], style: _valueStyle),
          ),
      ],
    );

    return AppDialogStack(
      eyebrow: 'Materia ministeriale',
      title: subject.name,
      maxWidth: 660,
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
                _buildFieldLabel('Descrizione'),
                Text(
                  hasDescription ? subject.description! : 'Nessuna descrizione fornita.',
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
              _buildFieldLabel('Discipline interne associate', first: true),
              if (subject.associationSubjects.isEmpty)
                Text(
                  'Nessuna disciplina associata.',
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
