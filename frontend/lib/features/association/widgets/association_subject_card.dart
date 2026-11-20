import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_catalogue_card.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../models/association_subject_item.dart';
import '../models/subject_taxonomy.dart';

class AssociationSubjectCard extends StatelessWidget
{
  final AssociationSubjectItem subject;

  // Both null for a reader: the details then open with nothing to press.
  final void Function(VoidCallback onSaved)? onEditRequested;
  final VoidCallback? onDelete;

  const AssociationSubjectCard({
    super.key,
    required this.subject,
    this.onEditRequested,
    this.onDelete,
  });

  void _showDetailsDialog(BuildContext context)
  {
    final edit = onEditRequested;

    showBlurredDialog(
      context: context,
      barrierLabel: 'AssociationSubjectDetails',
      builder: (dialogContext) => _AssociationSubjectDetailsDialogContent(
        subject: subject,
        areaLabel: subjectAreaLabel(subject.area),
        // Wizard stacks over the details: closing and reopening them replayed their entrance.
        onEditRequested: edit == null ? null : () => edit(() => Navigator.of(dialogContext).pop()),
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
        if (description != null) CatalogueDetail(description),
      ],
      onTap: () => _showDetailsDialog(context),
    );
  }
}

class _AssociationSubjectDetailsDialogContent extends StatelessWidget
{
  static const double _dialogButtonHeight = 52;

  static const double _confirmWidth = 480;

  static const double _detailsWidth = 600;
  static const double _dialogButtonFontSize = 14;

  final AssociationSubjectItem subject;
  final String areaLabel;
  final VoidCallback? onEditRequested;
  final VoidCallback? onDelete;

  const _AssociationSubjectDetailsDialogContent({
    required this.subject,
    required this.areaLabel,
    this.onEditRequested,
    this.onDelete,
  });

  // Readers have no other discipline kind to distinguish from.
  String get _eyebrow => onEditRequested == null ? tr('Disciplina', 'Discipline') : tr('Disciplina interna', 'Internal discipline');

  void _showDeleteConfirmation(BuildContext context, VoidCallback delete)
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
              delete();
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: tr('La disciplina ', 'The discipline ')),
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

  Widget? _buildFooter(BuildContext context)
  {
    final edit = onEditRequested;
    final delete = onDelete;

    if (edit == null || delete == null)
    {
      return null;
    }

    return AppDialogFooter(
      secondary: AppGradientButton(
        label: tr('ELIMINA', 'DELETE'),
        icon: Icons.delete_outline_rounded,
        gradient: AppTheme.dangerGradient,
        accent: AppTheme.trialDangerText,
        height: _dialogButtonHeight,
        fontSize: _dialogButtonFontSize,
        onPressed: () => _showDeleteConfirmation(context, delete),
      ),
      primary: AppGradientButton(
        label: tr('MODIFICA', 'EDIT'),
        icon: Icons.edit_outlined,
        height: _dialogButtonHeight,
        fontSize: _dialogButtonFontSize,
        onPressed: edit,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final hasDescription = subject.description != null && subject.description!.isNotEmpty;

    return AppDialogStack(
      eyebrow: _eyebrow,
      title: subject.name,
      maxWidth: _detailsWidth,
      footer: _buildFooter(context),
      children: [
        AppDialogPill(
          expand: true,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel(tr('Area', 'Area'), first: true),
                Text(areaLabel, style: _valueStyle),
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
      ],
    );
  }
}
