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
import '../models/course_item.dart';
import '../models/subject_taxonomy.dart';

Color get _costTextColor => AppTheme.trialTealDeepText;

class CourseCard extends StatelessWidget
{
  final CourseItem course;
  final void Function(VoidCallback onSaved) onEditRequested;
  final VoidCallback onDelete;

  const CourseCard({
    super.key,
    required this.course,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDetailsDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'CourseDetails',
      builder: (dialogContext) => _CourseDetailsDialogContent(
        course: course,
        // Wizard stacks over the details: closing and reopening them replayed their entrance.
        onEditRequested: () => onEditRequested(() => Navigator.of(dialogContext).pop()),
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String? cost = descriptionOrNull(course.cost);
    final String? description = descriptionOrNull(course.description);

    return AppCatalogueCard(
      title: course.name,
      details: [
        if (cost != null) CatalogueDetail(cost, color: _costTextColor),
        if (description != null) CatalogueDetail(description),
      ],
      onTap: () => _showDetailsDialog(context),
    );
  }
}

class _CourseDetailsDialogContent extends StatelessWidget
{
  static const double _dialogButtonHeight = 52;

  static const double _confirmWidth = 480;

  static const double _detailsWidth = 600;
  static const double _dialogButtonFontSize = 14;

  final CourseItem course;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _CourseDetailsDialogContent({
    required this.course,
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
                  TextSpan(text: tr('Il corso ', 'The course ')),
                  TextSpan(
                    text: course.name,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: tr(' verrà eliminato definitivamente.', ' will be deleted permanently.')),
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

  @override
  Widget build(BuildContext context)
  {
    final hasCost = course.cost != null && course.cost!.isNotEmpty;
    final hasDescription = course.description != null && course.description!.isNotEmpty;

    return AppDialogStack(
      eyebrow: tr('Corso', 'Course'),
      title: course.name,
      maxWidth: _detailsWidth,
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
                _buildFieldLabel(tr('Costo', 'Cost'), first: true),
                Text(
                  hasCost ? course.cost! : tr('Non indicato.', 'Not given.'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: hasCost ? AppTheme.trialInk : AppTheme.trialMutedText,
                    fontStyle: hasCost ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                _buildFieldLabel(tr('Descrizione', 'Description')),
                Text(
                  hasDescription ? course.description! : tr('Nessuna descrizione fornita.', 'No description given.'),
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
