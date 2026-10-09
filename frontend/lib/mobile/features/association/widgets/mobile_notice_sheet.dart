import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/association/notices/notice_embeds.dart';
import '../../../../features/association/notices/notice_format.dart';
import '../../../../features/association/notices/notice_item.dart';
import '../../../../features/association/notices/notice_message_view.dart';
import '../../../../features/association/notices/notice_strings.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../../services/api_service.dart';
import '../../../shared/device_files.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../profile/widgets/mobile_detail_card.dart';

// The title wraps onto two lines more often than not: it needs air above the first card.
const double _titleRoom = 18;
const double _cardGap = 12;
const double _fileGap = 8;
const double _badgeSize = 32;

// Read before the sheet rises, images included, so it opens whole.
Future<void> showMobileNotice(BuildContext context, int id) async
{
  final NoticeItem notice;

  try
  {
    notice = await ApiService().readNotice(id);
  }
  catch (e)
  {
    if (context.mounted)
    {
      MobileNotice.show(context, readableApiError(e), error: true);
    }

    return;
  }

  if (!context.mounted)
  {
    return;
  }

  final NoticeImages images = NoticeImages(noticeId: notice.id);

  try
  {
    await images.preload(context, [for (final image in notice.images) image.key]);
  }
  catch (_)
  {
    // A missing image is fetched again in the message, under a placeholder.
  }

  if (!context.mounted)
  {
    return;
  }

  await showMobileSheet<void>(context: context, builder: (_) => _NoticeSheet(notice: notice, images: images));
}

class _NoticeSheet extends StatefulWidget
{
  final NoticeItem notice;
  final NoticeImages images;

  const _NoticeSheet({required this.notice, required this.images});

  @override
  State<_NoticeSheet> createState() => _NoticeSheetState();
}

class _NoticeSheetState extends State<_NoticeSheet>
{
  // Attachments being fetched and saved; a second tap on one is dropped.
  final Set<int> _saving = {};

  NoticeItem get _notice => widget.notice;

  Future<void> _save(NoticeAttachmentItem attachment) async
  {
    if (!_saving.add(attachment.id))
    {
      return;
    }

    setState(() {});

    try
    {
      final ApiFile file = await ApiService().fetchNoticeAttachment(_notice.id, attachment);
      final bool saved = await saveToDevice(file.bytes, fileName: file.fileName, mimeType: attachment.contentType);

      if (saved && mounted)
      {
        MobileNotice.show(context, kAttachmentSaved);
      }
    }
    on PlatformException catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il salvataggio di un allegato');

      if (mounted)
      {
        MobileNotice.show(context, kAttachmentSaveFailed, error: true);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _saving.remove(attachment.id));
      }
    }
  }

  Widget _buildFacts()
  {
    final DateTime? editedAt = _notice.editedAt;

    return MobileSheetCard(
      child: MobileDetailRows(
        rows: [
          DetailRowData(kSentLabel, noticeSentLong(_notice.createdAt)),
          if (editedAt != null) DetailRowData(kEditedLabel, noticeSentLong(editedAt)),
          DetailRowData(kAuthorLabel, _notice.authorName),
        ],
      ),
    );
  }

  Widget _buildAttachments()
  {
    final List<NoticeAttachmentItem> attachments = _notice.attachments;

    return MobileSheetCard(
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              noticeAttachmentCountLabel(attachments.length),
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.trialTealDeep),
            ),
            for (final attachment in attachments) ...[
              const SizedBox(height: _fileGap + 2),
              _FileRow(
                attachment: attachment,
                saving: _saving.contains(attachment.id),
                onTap: () => _save(attachment),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileSheet(
      eyebrow: kNoticeEyebrow,
      title: _notice.title,
      body: [
        const SizedBox(height: _titleRoom),
        _buildFacts(),
        const SizedBox(height: _cardGap),
        MobileSheetCard(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: NoticeMessageView(message: _notice.message, images: widget.images),
          ),
        ),
        if (_notice.attachments.isNotEmpty) ...[
          const SizedBox(height: _cardGap),
          _buildAttachments(),
        ],
      ],
    );
  }
}

class _FileRow extends StatelessWidget
{
  final NoticeAttachmentItem attachment;
  final bool saving;
  final VoidCallback onTap;

  const _FileRow({required this.attachment, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    final NoticeFileKind kind = NoticeFileKind.of(attachment.fileName);

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: AppTheme.trialPaper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.trialLine, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: _badgeSize,
                height: _badgeSize,
                decoration: BoxDecoration(color: kind.color, borderRadius: BorderRadius.circular(9)),
                child: Icon(kind.icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.trialInk),
                    ),
                    Text(
                      fileSizeLabel(attachment.size),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: MobilePalette.mutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 24,
                child: saving
                    ? const Padding(
                        padding: EdgeInsets.all(3),
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.trialTealDeep),
                      )
                    : const Icon(Icons.download_rounded, size: 22, color: AppTheme.trialTealDeep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
