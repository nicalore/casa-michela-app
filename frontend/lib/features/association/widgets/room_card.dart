import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_catalogue_card.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../models/room_item.dart';
import '../models/subject_taxonomy.dart';

const Color _capacityTextColor = AppTheme.trialTealDeep;

// Null when uncounted: unmeasured is not a room with zero seats.
String? roomCapacityLabel(int? capacity)
{
  if (capacity == null)
  {
    return null;
  }

  return capacity == 1 ? '1 posto' : '$capacity posti';
}

class RoomCard extends StatelessWidget
{
  final RoomItem room;
  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const RoomCard({
    super.key,
    required this.room,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDetailsDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RoomDetails',
      builder: (dialogContext) => _RoomDetailsDialogContent(
        room: room,
        onEditRequested: ()
        {
          Navigator.of(dialogContext).pop();
          // Carries the card's context, not the closing dialog's.
          onEditRequested(() => _showDetailsDialog(context));
        },
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String? capacity = roomCapacityLabel(room.capacity);
    final String? description = descriptionOrNull(room.description);

    return AppCatalogueCard(
      title: room.name,
      details: [
        if (capacity != null) CatalogueDetail(capacity, color: _capacityTextColor),
        if (description != null) CatalogueDetail(description),
      ],
      onTap: () => _showDetailsDialog(context),
    );
  }
}

class _RoomDetailsDialogContent extends StatelessWidget
{
  static const double _dialogButtonHeight = 52;

  static const double _confirmWidth = 480;

  static const double _detailsWidth = 600;
  static const double _dialogButtonFontSize = 14;

  final RoomItem room;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _RoomDetailsDialogContent({
    required this.room,
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
                  const TextSpan(text: 'La stanza '),
                  TextSpan(
                    text: room.name,
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

  Widget _buildValue(
    String? value,
    String missing, {
    required double fontSize,
    required FontWeight fontWeight,
    double? height,
  })
  {
    return Text(
      value ?? missing,
      style: GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: value != null ? AppTheme.trialInk : AppTheme.trialMutedText,
        fontStyle: value != null ? FontStyle.normal : FontStyle.italic,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String? capacity = roomCapacityLabel(room.capacity);
    final String? description = descriptionOrNull(room.description);

    return AppDialogStack(
      eyebrow: 'Stanza',
      title: room.name,
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
                _buildFieldLabel('Capienza', first: true),
                _buildValue(
                  capacity,
                  'Non indicata.',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                _buildFieldLabel('Descrizione'),
                _buildValue(
                  description,
                  'Nessuna descrizione fornita.',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
