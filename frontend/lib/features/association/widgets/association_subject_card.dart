import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const AssociationSubjectCard({
    super.key,
    required this.subject,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDetailsDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'AssociationSubjectDetails',
      builder: (dialogContext) => _AssociationSubjectDetailsDialogContent(
        subject: subject,
        areaLabel: subjectAreaLabel(subject.area),
        onEditRequested: ()
        {
          Navigator.of(dialogContext).pop();
          // The callback that reopens the details carries the card's context
          // along, not that of the dialog about to close.
          onEditRequested(() => _showDetailsDialog(context));
        },
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // The name and what it is. The area used to be here and is gone: there are
    // three areas, so one card in three repeats the same word, and whoever is
    // looking for a discipline needs to know what is done inside it — the area is
    // already told by the filter they searched with.
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
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;

  // Narrow: a question of one sentence, and the two answers under it.
  static const double _confirmWidth = 480;

  static const double _detailsWidth = 600;
  static const double _dialogButtonFontSize = 14;

  final AssociationSubjectItem subject;
  final String areaLabel;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _AssociationSubjectDetailsDialogContent({
    required this.subject,
    required this.areaLabel,
    required this.onEditRequested,
    required this.onDelete,
  });

  // Two full buttons rather than two words in a corner: this one throws
  // something away, and the answer that does it should not be quieter than the
  // one that walks away from it.
  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        // ANNULLA is already the way out of this one.
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
                  const TextSpan(text: 'La disciplina '),
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

  // Small, tracked and muted over the value it names: the same pairing the
  // settings cards use, and the same the top bar uses over a role.
  // The first label of a piece sits at its top edge; the ones after it open a
  // gap from what they follow.
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

    return AppDialogStack(
      eyebrow: 'Disciplina interna',
      title: subject.name,
      maxWidth: _detailsWidth,
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
                _buildFieldLabel('Area', first: true),
                Text(areaLabel, style: _valueStyle),
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
      ],
    );
  }
}
