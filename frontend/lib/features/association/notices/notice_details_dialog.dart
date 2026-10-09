import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/file_download.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import 'notice_card.dart';
import 'notice_embeds.dart';
import 'notice_files.dart';
import 'notice_format.dart';
import 'notice_item.dart';
import 'notice_message_view.dart';
import 'notice_strings.dart';

const double _dialogWidth = 800;
const double _confirmWidth = 480;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _labelColumn = 110;

// onEdit gets the callback that closes these details once the edit is saved.
Future<void> showNoticeDetails(
  BuildContext context,
  NoticeItem notice, {
  required NoticeImages images,
  required bool own,
  required void Function(VoidCallback onSaved) onEdit,
  required VoidCallback onDelete,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'NoticeDetails',
    builder: (dialogContext) => _NoticeDetails(
      notice: notice,
      images: images,
      own: own,
      recipients: true,
      onEdit: () => onEdit(() => Navigator.of(dialogContext).pop()),
      onDelete: onDelete,
    ),
  );
}

// Read only, as the homes and the readers' list open it: no buttons, no recipients.
Future<void> showNoticeReading(
  BuildContext context,
  NoticeItem notice, {
  required NoticeImages images,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'NoticeReading',
    builder: (_) => _NoticeDetails(
      notice: notice,
      images: images,
      own: false,
      recipients: false,
      onEdit: () {},
      onDelete: () {},
    ),
  );
}

class _NoticeDetails extends StatefulWidget
{
  final NoticeItem notice;
  final NoticeImages images;
  final bool own;
  final bool recipients;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoticeDetails({
    required this.notice,
    required this.images,
    required this.own,
    required this.recipients,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_NoticeDetails> createState() => _NoticeDetailsState();
}

class _NoticeDetailsState extends State<_NoticeDetails>
{
  NoticeItem get _notice => widget.notice;

  Future<void> _download(NoticeAttachmentItem attachment) async
  {
    try
    {
      final file = await ApiService().fetchNoticeAttachment(_notice.id, attachment);

      await downloadFile(file.bytes, fileName: file.fileName, mimeType: attachment.contentType);
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  void _confirmDeletion()
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmNoticeDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: kDeleteEyebrow,
        title: kConfirmTitle,
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: kCancel,
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _buttonHeight,
            fontSize: _buttonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: kDelete,
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _buttonHeight,
            fontSize: _buttonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              Navigator.pop(context);
              widget.onDelete();
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: kDeleteOpening),
                  TextSpan(text: _notice.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  const TextSpan(text: kDeleteClosing),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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

  // Under the rows the line sits as close as between them: their own bottom padding is the room.
  Widget _divider({double above = 16}) => Padding(
        padding: EdgeInsets.only(top: above, bottom: 16),
        child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
      );

  @override
  Widget build(BuildContext context)
  {
    final DateTime? editedAt = _notice.editedAt;

    return AppDialogStack(
      eyebrow: kNoticeEyebrow,
      title: _notice.title,
      maxWidth: _dialogWidth,
      fillLast: true,
      footer: widget.own
          ? AppDialogFooter(
              secondary: AppGradientButton(
                label: kDelete,
                icon: Icons.delete_outline_rounded,
                gradient: AppTheme.dangerGradient,
                accent: AppTheme.trialDanger,
                height: _buttonHeight,
                fontSize: _buttonFontSize,
                onPressed: _confirmDeletion,
              ),
              primary: AppGradientButton(
                label: kEdit,
                icon: Icons.edit_outlined,
                height: _buttonHeight,
                fontSize: _buttonFontSize,
                onPressed: widget.onEdit,
              ),
            )
          : null,
      children: [
        AppScrollingDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(kSentLabel, _value(noticeSentLong(_notice.createdAt)), first: true),
              if (editedAt != null) _row(kEditedLabel, _value(noticeSentLong(editedAt))),
              _row(kAuthorLabel, _value(_notice.authorName)),
              if (widget.recipients)
                _row(
                  kRecipientsLabel,
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      NoticeRoleBadges(roles: _notice.recipients),
                      Text(
                        noticePeopleLabel(_notice.recipientCount),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
                      ),
                    ],
                  ),
                ),
              _divider(above: 0),
              NoticeMessageView(message: _notice.message, images: widget.images),
              if (_notice.attachments.isNotEmpty) ...[
                _divider(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: AppFieldLabel(kAttachmentsLabel),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final attachment in _notice.attachments)
                      NoticeFileChip(
                        fileName: attachment.fileName,
                        size: attachment.size,
                        onDownload: () => _download(attachment),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
