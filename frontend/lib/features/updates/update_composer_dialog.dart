import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/field_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_dialog_footer.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/app_field_label.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/app_selectable_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/dialog_components.dart';
import '../../shared/widgets/snackbar.dart';
import '../association/notices/notice_editor.dart';
import '../association/notices/notice_embeds.dart';
import '../association/notices/notice_format.dart';
import '../association/notices/notice_item.dart';
import '../association/notices/notice_markdown.dart';
import 'update_item.dart';
import 'update_strings.dart';

const double _dialogWidth = 900;
const double _confirmWidth = 560;
const double _editorHeight = 260;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _labelTop = 16;
const double _labelBottom = 6;

typedef UpdateSaver = Future<bool> Function(UpdateDraft draft, void Function(String) onError);

// As a notice is written, without attachments; the update is null for a new one.
Future<void> showUpdateComposer(
  BuildContext context, {
  UpdateItem? update,
  required NoticeImages images,
  required UpdateSaver onSave,
  VoidCallback? onEditSaved,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'UpdateComposer',
    builder: (_) => _UpdateComposer(update: update, images: images, onSave: onSave, onEditSaved: onEditSaved),
  );
}

class _UpdateComposer extends StatefulWidget
{
  final UpdateItem? update;
  final NoticeImages images;
  final UpdateSaver onSave;
  final VoidCallback? onEditSaved;

  const _UpdateComposer({required this.update, required this.images, required this.onSave, required this.onEditSaved});

  @override
  State<_UpdateComposer> createState() => _UpdateComposerState();
}

class _UpdateComposerState extends State<_UpdateComposer>
{
  final ApiService _apiService = ApiService();

  late final Set<UpdateRole> _recipients = {...?widget.update?.recipients};
  late final TextEditingController _title = TextEditingController(text: widget.update?.title);
  late final QuillController _message = QuillController(
    document: noticeDocument(widget.update?.message ?? ''),
    selection: const TextSelection.collapsed(offset: 0),
  );
  NoticeImages get _images => widget.images;

  int? _people;
  int _countRequest = 0;
  // While the count is fetched and the confirmation is open: no spinner, no second tap.
  bool _asking = false;
  bool _saving = false;

  bool get _editing => widget.update != null;

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
  int get _imagesBytes
  {
    final Set<String> shown = documentImageKeys(_message.document);
    final Map<String, int> saved = {for (final image in widget.update?.images ?? <NoticeImageItem>[]) image.key: image.size};
    int total = 0;

    for (final key in shown)
    {
      total += _images.added[key]?.size ?? saved[key] ?? 0;
    }

    return total;
  }

  bool _fits(int bytes)
  {
    if (_imagesBytes + bytes <= kNoticeFilesMaxBytes)
    {
      return true;
    }

    CustomSnackBar.show(context: context, message: kUpdateImagesTooLarge, isError: true);

    return false;
  }

  List<UpdateRole> get _ordered => UpdateRole.values.where(_recipients.contains).toList();

  Future<void> _refreshCount() async
  {
    final int request = ++_countRequest;

    if (_recipients.isEmpty)
    {
      setState(() => _people = null);

      return;
    }

    try
    {
      final int people = await _apiService.countUpdateRecipients(_ordered);

      if (mounted && request == _countRequest)
      {
        setState(() => _people = people);
      }
    }
    catch (_)
    {
      // The hint only helps; the confirmation asks again before publishing.
    }
  }

  void _toggle(UpdateRole role, bool chosen)
  {
    setState(() => chosen ? _recipients.add(role) : _recipients.remove(role));
    _refreshCount();
  }

  String? _problem(String title, String markdown)
  {
    if (_recipients.isEmpty)
    {
      return kNoUpdateRecipients;
    }

    if (title.isEmpty)
    {
      return kNoUpdateTitle;
    }

    if (markdown.isEmpty)
    {
      return kNoUpdateMessage;
    }

    if (markdown.length > FieldLimits.noticeMessage)
    {
      return kUpdateMessageTooLong;
    }

    if (_imagesBytes > kNoticeFilesMaxBytes)
    {
      return kUpdateImagesTooLarge;
    }

    return null;
  }

  // Only a new update asks first: an edit reaches just those who have not read it.
  Future<bool> _confirmed() async
  {
    if (_editing)
    {
      return true;
    }

    _asking = true;

    try
    {
      final int people = await _apiService.countUpdateRecipients(_ordered);

      return mounted && await _confirm(people);
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }

      return false;
    }
    finally
    {
      _asking = false;
    }
  }

  Future<void> _save() async
  {
    final String title = _title.text.trim();
    final String markdown = noticeMarkdown(_message.document);
    final String? problem = _problem(title, markdown);

    if (problem != null)
    {
      CustomSnackBar.show(context: context, message: problem, isError: true);

      return;
    }

    if (_asking || _saving || !await _confirmed() || !mounted)
    {
      return;
    }

    setState(() => _saving = true);

    final Set<String> shown = documentImageKeys(_message.document);
    final UpdateDraft draft = UpdateDraft(
      title: title,
      message: markdown,
      recipients: _ordered,
      images: {
        for (final entry in _images.added.entries)
          if (shown.contains(entry.key)) entry.key: entry.value,
      },
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
      setState(() => _saving = false);

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
      barrierLabel: 'ConfirmUpdatePublishing',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: kPublishEyebrow,
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
            onPressed: () => Navigator.of(confirmContext).pop(false),
          ),
          primary: AppGradientButton(
            label: kPublishUpdate,
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
                  TextSpan(text: publishConfirmationOpening(people)),
                  TextSpan(text: updatePeopleLabel(people), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  TextSpan(text: publishConfirmationClosing([for (final role in _ordered) role.plural])),
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

  Widget? _countHint()
  {
    final int? people = _people;

    if (people == null || _recipients.isEmpty)
    {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.group_rounded, size: 16, color: AppTheme.trialMutedText),
        const SizedBox(width: 6),
        Text(
          updatePeopleLabel(people),
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kUpdateEyebrow,
      title: _editing ? kEditUpdateTitle : kNewUpdateTitle,
      maxWidth: _dialogWidth,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: _editing ? kSaveUpdate : kPublishUpdate,
          icon: _editing ? Icons.check_rounded : Icons.send_rounded,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          busy: _saving,
          onPressed: _save,
        ),
      ),
      children: [
        AppScrollingDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(kUpdateRecipientsLabel, trailing: _countHint(), first: true),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in UpdateRole.values)
                    AppSelectableChip(
                      label: role.plural,
                      selected: _recipients.contains(role),
                      onSelected: (chosen) => _toggle(role, chosen),
                    ),
                ],
              ),
              AppTextField(
                controller: _title,
                label: kUpdateTitleLabel,
                hintText: '',
                maxLength: FieldLimits.noticeTitle,
                textCapitalization: TextCapitalization.sentences,
              ),
              _label(kUpdateMessageLabel),
              NoticeEditor(
                controller: _message,
                images: _images,
                height: _editorHeight,
                canAdd: _fits,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
