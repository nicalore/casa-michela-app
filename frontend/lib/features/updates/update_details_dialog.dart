import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_dialog_footer.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/app_field_label.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/dialog_components.dart';
import '../association/notices/notice_embeds.dart';
import '../association/notices/notice_format.dart';
import '../association/notices/notice_message_view.dart';
import 'update_item.dart';
import 'update_strings.dart';
import 'widgets/update_badges.dart';

const double _dialogWidth = 800;
const double _confirmWidth = 480;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _labelColumn = 110;

// onEdit gets the callback that closes these details once the edit is saved.
Future<void> showUpdateDetails(
  BuildContext context,
  UpdateItem update, {
  required NoticeImages images,
  required void Function(VoidCallback onSaved) onEdit,
  required VoidCallback onDelete,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'UpdateDetails',
    builder: (dialogContext) => _UpdateDetails(
      update: update,
      images: images,
      onEdit: () => onEdit(() => Navigator.of(dialogContext).pop()),
      onDelete: onDelete,
    ),
  );
}

class _UpdateDetails extends StatelessWidget
{
  final UpdateItem update;
  final NoticeImages images;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UpdateDetails({required this.update, required this.images, required this.onEdit, required this.onDelete});

  void _confirmDeletion(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmUpdateDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: kDeleteUpdateEyebrow,
        title: kUpdateConfirmTitle,
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: kUpdateCancel,
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _buttonHeight,
            fontSize: _buttonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: kUpdateDelete,
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _buttonHeight,
            fontSize: _buttonFontSize,
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
                  const TextSpan(text: kDeleteUpdateOpening),
                  TextSpan(text: update.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  const TextSpan(text: kDeleteUpdateClosing),
                ],
              ),
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: AppTheme.trialInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget value, {bool first = false})
  {
    return Container(
      padding: EdgeInsets.only(top: first ? 0 : 10, bottom: 10),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: AppTheme.trialLine)),
      ),
      child: Row(
        children: [
          SizedBox(width: _labelColumn, child: AppFieldLabel(label)),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _value(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.trialInk),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime? editedAt = update.editedAt;

    return AppDialogStack(
      eyebrow: updateHeading(update.version),
      title: update.title,
      maxWidth: _dialogWidth,
      fillLast: true,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: kUpdateDelete,
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: () => _confirmDeletion(context),
        ),
        primary: AppGradientButton(
          label: kUpdateEdit,
          icon: Icons.edit_outlined,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: onEdit,
        ),
      ),
      children: [
        AppScrollingDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(kUpdateSentLabel, _value(noticeSentLong(update.createdAt)), first: true),
              if (editedAt != null) _row(kUpdateEditedLabel, _value(noticeSentLong(editedAt))),
              _row(kUpdateAuthorLabel, _value(update.authorName)),
              _row(kUpdateRecipientsLabel, Align(alignment: Alignment.centerLeft, child: UpdateRoleBadges(roles: update.recipients))),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
              ),
              NoticeMessageView(message: update.message, images: images),
            ],
          ),
        ),
      ],
    );
  }
}
