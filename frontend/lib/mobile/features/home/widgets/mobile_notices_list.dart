import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/rome_clock.dart';
import '../../../../features/association/notices/notice_card.dart' show NoticePinnedIcon;
import '../../../../features/association/notices/notice_format.dart';
import '../../../../features/association/notices/notice_item.dart';
import '../../../../features/association/notices/notice_strings.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../../association/widgets/mobile_notice_sheet.dart';

const double _cardGap = 12;
const double _columnGap = 24;
const double _emptyHeight = 110;
const double _pinSize = 17;

// Mirrors HOME_LIMIT in backend/app/services/notices.py.
const int _shown = 5;

// What the home has read of the notices sent to its role.
class MobileHomeNotices
{
  final bool loading;

  // Null when they could not be read.
  final List<NoticeHeadlineItem>? items;

  const MobileHomeNotices({this.loading = true, this.items});
}

// The two feeds of the web home: activities still to come, the latest notices.
class MobileNoticesList extends StatelessWidget
{
  final MobileHomeNotices notices;

  // Tablets: the two cards side by side, as tall as each other.
  final bool beside;

  const MobileNoticesList({super.key, this.notices = const MobileHomeNotices(), this.beside = false});

  @override
  Widget build(BuildContext context)
  {
    const Widget tasks = _ComingCard(
      eyebrow: 'Cose da fare',
      title: 'Attività e notifiche',
      icon: Icons.checklist_rounded,
    );

    final Widget latest = _NoticesCard(notices: notices);

    if (beside)
    {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: tasks),
            const SizedBox(width: _columnGap),
            Expanded(child: latest),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [tasks, const SizedBox(height: _cardGap), latest],
    );
  }
}

class _Head extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final Widget? trailing;

  const _Head({required this.eyebrow, required this.title, this.trailing});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppTheme.trialInk.withValues(alpha: 0.62),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialInk,
          ),
        ),
      ],
    );
  }
}

class _ComingCard extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final IconData icon;

  const _ComingCard({required this.eyebrow, required this.title, required this.icon});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(
            eyebrow: eyebrow,
            title: title,
            trailing: const MobilePill('In arrivo', tone: MobilePillTone.teal),
          ),
          SizedBox(
            height: _emptyHeight,
            child: Center(
              child: Icon(icon, size: 44, color: AppTheme.trialInk.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticesCard extends StatelessWidget
{
  final MobileHomeNotices notices;

  const _NoticesCard({required this.notices});

  static final DateTime _sampleDay = DateTime(2000, 9, 30);

  // Never drawn: holds the room of five lines, so the card keeps its height whatever arrives.
  static final List<NoticeHeadlineItem> _five = [
    for (var i = 0; i < _shown; i++)
      NoticeHeadlineItem(id: -1 - i, title: 'Titolo', authorName: 'Nome Cognome', createdAt: _sampleDay, pinned: true),
  ];

  Widget _lines(BuildContext context, List<NoticeHeadlineItem> items, {required DateTime today, bool live = true})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          _NoticeLine(
            notice: items[i],
            day: noticeLongDay(items[i].createdAt, today: today),
            first: i == 0,
            onTap: live ? () => showMobileNotice(context, items[i].id) : null,
          ),
      ],
    );
  }

  Widget _status(String text)
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: MobilePalette.mutedText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime now = romeNow();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<NoticeHeadlineItem>? items = notices.items;

    final Widget body = switch ((notices.loading, items))
    {
      (true, _) => const Center(
          child: SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: AppTheme.trialTealDeep),
          ),
        ),
      (false, null) => _status(kHomeNoticesUnavailable),
      (false, final List<NoticeHeadlineItem> read) when read.isEmpty => _status(kHomeNoNotices),
      (false, final List<NoticeHeadlineItem> read) => _lines(context, read, today: today),
    };

    return MobileGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: _Head(eyebrow: kHomeNoticesEyebrow, title: kHomeNoticesTitle),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Visibility.maintain(visible: false, child: _lines(context, _five, today: today, live: false)),
              Positioned.fill(child: Align(alignment: Alignment.topCenter, child: body)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoticeLine extends StatelessWidget
{
  final NoticeHeadlineItem notice;
  final String day;
  final bool first;
  final VoidCallback? onTap;

  const _NoticeLine({required this.notice, required this.day, required this.first, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.1))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$day · ${notice.authorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: MobilePalette.mutedText),
                  ),
                ],
              ),
            ),
            if (notice.pinned) ...[
              const SizedBox(width: 8),
              const NoticePinnedIcon(size: _pinSize),
            ],
            Icon(Icons.chevron_right_rounded, size: 24, color: AppTheme.trialInk.withValues(alpha: 0.36)),
          ],
        ),
      ),
    );
  }
}
