import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import 'notice_editor.dart';
import 'notice_embeds.dart';
import 'notice_files.dart';
import 'notice_format.dart';
import 'notice_item.dart';
import 'notice_markdown.dart';
import 'notice_strings.dart';

const double _dialogWidth = 900;
const double _confirmWidth = 560;
const double _editorHeight = 220;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _labelTop = 16;
const double _labelBottom = 6;
const double _meterWidth = 150;

typedef NoticeSaver = Future<bool> Function(NoticeDraft draft, void Function(String) onError);

// The notice is null for a new one; onEditSaved also closes the details below.
Future<void> showNoticeComposer(
  BuildContext context, {
  NoticeItem? notice,
  NoticeImages? images,
  required NoticeSaver onSave,
  VoidCallback? onEditSaved,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'NoticeComposer',
    builder: (_) => _NoticeComposer(
      notice: notice,
      images: images ?? NoticeImages(noticeId: notice?.id),
      onSave: onSave,
      onEditSaved: onEditSaved,
    ),
  );
}

class _NoticeComposer extends StatefulWidget
{
  final NoticeItem? notice;
  final NoticeImages images;
  final NoticeSaver onSave;
  final VoidCallback? onEditSaved;

  const _NoticeComposer({required this.notice, required this.images, required this.onSave, required this.onEditSaved});

  @override
  State<_NoticeComposer> createState() => _NoticeComposerState();
}

class _NoticeComposerState extends State<_NoticeComposer>
{
  final ApiService _apiService = ApiService();

  late final Set<NoticeRole> _recipients = {...?widget.notice?.recipients};
  late final TextEditingController _title = TextEditingController(text: widget.notice?.title);
  late final QuillController _message = QuillController(
    document: noticeDocument(widget.notice?.message ?? ''),
    selection: const TextSelection.collapsed(offset: 0),
  );
  NoticeImages get _images => widget.images;
  late final List<NoticeAttachmentItem> _kept = [...?widget.notice?.attachments];
  final List<NoticeUpload> _added = [];

  NoticeRecipientCount? _count;
  int _countRequest = 0;
  // While the count is fetched and the confirmation is open: no spinner, no second tap.
  bool _asking = false;
  bool _sending = false;

  bool get _editing => widget.notice != null;

  @override
  void initState()
  {
    super.initState();
    _refreshCount();
  }

  @override
  void dispose()
  {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  // Images count only while the message still shows them.
  int get _filesBytes
  {
    final Set<String> shown = documentImageKeys(_message.document);
    final Map<String, int> sent = {for (final image in widget.notice?.images ?? <NoticeImageItem>[]) image.key: image.size};
    int total = 0;

    for (final key in shown)
    {
      total += _images.added[key]?.size ?? sent[key] ?? 0;
    }

    for (final file in _kept)
    {
      total += file.size;
    }

    for (final file in _added)
    {
      total += file.size;
    }

    return total;
  }

  bool _fits(int bytes)
  {
    if (_filesBytes + bytes <= kNoticeFilesMaxBytes)
    {
      return true;
    }

    CustomSnackBar.show(context: context, message: kTooLarge, isError: true);

    return false;
  }

  Future<void> _refreshCount() async
  {
    final int request = ++_countRequest;

    if (_recipients.isEmpty)
    {
      setState(() => _count = null);

      return;
    }

    try
    {
      final NoticeRecipientCount count = await _apiService.countNoticeRecipients(_ordered);

      if (mounted && request == _countRequest)
      {
        setState(() => _count = count);
      }
    }
    catch (_)
    {
      // The hint only helps; the confirmation asks again before sending.
    }
  }

  List<NoticeRole> get _ordered => NoticeRole.values.where(_recipients.contains).toList();

  void _toggle(NoticeRole role, bool chosen)
  {
    setState(() => chosen ? _recipients.add(role) : _recipients.remove(role));
    _refreshCount();
  }

  void _addFiles(List<NoticeUpload> files)
  {
    final int bytes = files.fold(0, (sum, file) => sum + file.size);

    if (_fits(bytes))
    {
      setState(() => _added.addAll(files));
    }
  }

  String? _problem(String title, String markdown)
  {
    if (_recipients.isEmpty)
    {
      return kNoRecipients;
    }

    if (title.isEmpty)
    {
      return kNoTitle;
    }

    if (markdown.isEmpty)
    {
      return kNoMessage;
    }

    if (markdown.length > FieldLimits.noticeMessage)
    {
      return kMessageTooLong;
    }

    if (_filesBytes > kNoticeFilesMaxBytes)
    {
      return kTooLarge;
    }

    return null;
  }

  Future<void> _send() async
  {
    final String title = _title.text.trim();
    final String markdown = noticeMarkdown(_message.document);
    final String? problem = _problem(title, markdown);

    if (problem != null)
    {
      CustomSnackBar.show(context: context, message: problem, isError: true);

      return;
    }

    if (_asking || _sending)
    {
      return;
    }

    _asking = true;

    final NoticeRecipientCount count;

    try
    {
      count = await _apiService.countNoticeRecipients(_ordered);
    }
    catch (error)
    {
      _asking = false;

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }

      return;
    }

    if (!mounted)
    {
      return;
    }

    final bool confirmed = await _confirm(count.people);

    _asking = false;

    if (!mounted || !confirmed)
    {
      return;
    }

    setState(() => _sending = true);

    final Set<String> shown = documentImageKeys(_message.document);
    final NoticeDraft draft = NoticeDraft(
      title: title,
      message: markdown,
      recipients: _ordered,
      attachments: _added,
      images: {
        for (final entry in _images.added.entries)
          if (shown.contains(entry.key)) entry.key: entry.value,
      },
      keptAttachmentIds: [for (final file in _kept) file.id],
    );

    final bool saved = await widget.onSave(draft, (message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    });

    if (!mounted)
    {
      return;
    }

    if (!saved)
    {
      setState(() => _sending = false);

      return;
    }

    Navigator.of(context).pop();
    widget.onEditSaved?.call();
  }

  Future<bool> _confirm(int people)
  {
    final TextStyle text = GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: AppTheme.trialInk);

    return showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ConfirmNoticeSending',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: kSendEyebrow,
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
            onPressed: () => Navigator.of(confirmContext).pop(false),
          ),
          primary: AppGradientButton(
            label: kSend,
            icon: Icons.send_rounded,
            height: _buttonHeight,
            fontSize: _buttonFontSize,
            onPressed: () => Navigator.of(confirmContext).pop(true),
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: sendConfirmationOpening(people)),
                  TextSpan(text: noticePeopleLabel(people), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  TextSpan(text: sendConfirmationClosing([for (final role in _ordered) role.plural])),
                ],
              ),
              style: text,
            ),
          ),
        ],
      ),
    ).then((confirmed) => confirmed ?? false);
  }

  Widget _label(String text, {Widget? trailing, bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : _labelTop, bottom: _labelBottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: AppFieldLabel(text)),
          ?trailing,
        ],
      ),
    );
  }

  TextStyle get _hintStyle => GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

  Widget? _countHint()
  {
    final NoticeRecipientCount? count = _count;

    if (count == null || _recipients.isEmpty)
    {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mail_rounded, size: 16, color: AppTheme.trialMutedText),
        const SizedBox(width: 6),
        Text(recipientHint(count.people, count.emails), style: _hintStyle),
      ],
    );
  }

  Widget _usage()
  {
    final int bytes = _filesBytes;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(attachmentsUsage(fileSizeLabel(bytes), kNoticeFilesLimitLabel), style: _hintStyle),
        const SizedBox(width: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            width: _meterWidth,
            height: 6,
            child: LinearProgressIndicator(
              value: (bytes / kNoticeFilesMaxBytes).clamp(0, 1).toDouble(),
              backgroundColor: AppTheme.closedSurface,
              color: AppTheme.trialTurquoise,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kNoticeEyebrow,
      title: _editing ? kEditNoticeTitle : kNewNoticeTitle,
      maxWidth: _dialogWidth,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kSend,
          icon: Icons.send_rounded,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          busy: _sending,
          onPressed: _send,
        ),
      ),
      children: [
        AppScrollingDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(kRecipientsLabel, trailing: _countHint(), first: true),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in NoticeRole.values)
                    AppSelectableChip(
                      label: role.plural,
                      selected: _recipients.contains(role),
                      onSelected: (chosen) => _toggle(role, chosen),
                    ),
                ],
              ),
              AppTextField(
                controller: _title,
                label: kTitleLabel,
                hintText: '',
                maxLength: FieldLimits.noticeTitle,
                textCapitalization: TextCapitalization.sentences,
              ),
              _label(kMessageLabel),
              NoticeEditor(
                controller: _message,
                images: _images,
                height: _editorHeight,
                canAdd: _fits,
              ),
              ListenableBuilder(
                listenable: _message,
                builder: (context, _) => _label(kAttachmentsLabel, trailing: _usage()),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final file in _kept)
                    NoticeFileChip(
                      fileName: file.fileName,
                      size: file.size,
                      onRemove: () => setState(() => _kept.remove(file)),
                    ),
                  for (final file in _added)
                    NoticeFileChip(
                      fileName: file.fileName,
                      size: file.size,
                      onRemove: () => setState(() => _added.remove(file)),
                    ),
                  NoticeDropZone(onFiles: _addFiles),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
