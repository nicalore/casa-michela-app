import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/rome_clock.dart';
import '../../../../features/association/notices/notice_card.dart' show NoticePinnedIcon;
import '../../../../features/association/notices/notice_format.dart';
import '../../../../features/association/notices/notice_item.dart';
import '../../../../features/association/notices/notice_strings.dart';
import '../../../../features/notifications/device_notifications.dart';
import '../../../../features/notifications/notification_board.dart';
import '../../../../features/notifications/notification_item.dart';
import '../../../../features/notifications/notification_look.dart';
import '../../../../features/notifications/notification_strings.dart';
import '../../../shared/mobile_line_breaks.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../../association/widgets/mobile_notice_sheet.dart';
import '../../notifications/mobile_notifications_offer.dart';

const double _cardGap = 12;
const double _iconSize = 34;
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

  const MobileNoticesList({super.key, this.notices = const MobileHomeNotices()});

  @override
  Widget build(BuildContext context)
  {
    const Widget tasks = _NotificationsCard();

    final Widget latest = _NoticesCard(notices: notices);

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

// Grows with its list: every notification is read here.
class _NotificationsCard extends StatelessWidget
{
  const _NotificationsCard();

  Widget _status(String text)
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: MobilePalette.mutedText,
        ),
      ),
    );
  }

  // While they are off, an empty list says nothing: the row above says enough.
  Widget _body(NotificationBoard board, {required bool off})
  {
    if (board.loading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: AppTheme.trialTealDeep),
          ),
        ),
      );
    }

    final List<NotificationItem>? items = board.items;

    if (items == null)
    {
      return _status(kNotificationsUnavailable);
    }

    if (items.isEmpty)
    {
      return off ? const SizedBox(height: 8) : _status(kNotificationsEmpty);
    }

    final DateTime now = romeNow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed)
          _NotificationLine(item: item, when: notificationWhen(item.createdAt, now: now), first: index == 0),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final NotificationBoard board = NotificationBoard.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([board, DeviceNotifications.state]),
      builder: (context, _)
      {
        final NotificationSwitch device = DeviceNotifications.state.value;
        final bool off = device == NotificationSwitch.off || device == NotificationSwitch.blocked;

        return MobileGlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _Head(
                  eyebrow: kNotificationsEyebrow,
                  title: kNotificationsTitle,
                  trailing: board.unread > 0 ? MobilePill(notificationsNewLabel(board.unread)) : null,
                ),
              ),
              const SizedBox(height: 8),
              if (off) const _OffRow(),
              _body(board, off: off),
            ],
          ),
        );
      },
    );
  }
}

class _OffRow extends StatelessWidget
{
  const _OffRow();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.trialGoldSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_rounded, size: 22, color: AppTheme.modifiedAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  withoutOrphans(kNotificationsOffTitle),
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.trialInk),
                ),
                const SizedBox(height: 2),
                Text(
                  withoutOrphans(kNotificationsOffMobile),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppTheme.modifiedAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => turnMobileNotificationsOn(context),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [AppTheme.trialGold, Color(0xFFF3C766)]),
                boxShadow: const [BoxShadow(color: Color(0x52E3A83C), offset: Offset(0, 6), blurRadius: 14)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kNotificationsTurnOn.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppTheme.trialDeepWater,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.notifications_active_rounded, size: 16, color: AppTheme.trialDeepWater),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationLine extends StatelessWidget
{
  final NotificationItem item;
  final String when;
  final bool first;

  const _NotificationLine({required this.item, required this.when, required this.first});

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => NotificationBoard.instance.open(item),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 0, 12),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.1))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotificationIcon(
              kind: item.kind,
              unread: !item.read,
              size: _iconSize,
              surface: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    withoutOrphans(item.title),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: item.read ? FontWeight.w700 : FontWeight.w800,
                      letterSpacing: -0.1,
                      color: AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    withoutOrphans(item.body),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: MobilePalette.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              when,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MobilePalette.mutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
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
        textAlign: TextAlign.center,
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
