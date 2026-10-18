import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/association/notices/notice_embeds.dart';
import '../../../features/association/notices/notice_message_view.dart';
import '../../../features/updates/unread_updates.dart';
import '../../../features/updates/update_item.dart';
import '../../../features/updates/update_reading.dart';
import '../../../features/updates/widgets/update_badges.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../notifications/mobile_notifications_offer.dart';

const Duration _waitStep = Duration(milliseconds: 200);

const double _titleRoom = 18;
// Cards of one version sit closer than the versions.
const double _cardGap = 10;
const double _versionGap = 22;
const double _badgeIndent = 4;

// Over the home, after the notifications question and before its tour.
Future<void> showMobileUnreadUpdatesOnce(BuildContext context)
{
  return UnreadUpdates.once((updates) async
  {
    while (context.mounted && (isMobileNotificationsOfferPending || isMobileTourShown || isMobileSheetOpen))
    {
      await Future<void>.delayed(_waitStep);
    }

    if (!context.mounted)
    {
      return false;
    }

    final Map<int, NoticeImages> images = await preloadUpdateImages(context, updates);

    if (!context.mounted)
    {
      return false;
    }

    await showMobileSheet<void>(
      context: context,
      builder: (_) => _UpdatesSheet(updates: updates, images: images),
    );

    return true;
  });
}

// As on the computer: each version's badge over its cards, one card per update.
class _UpdatesSheet extends StatelessWidget
{
  final List<UpdateReadingItem> updates;
  final Map<int, NoticeImages> images;

  const _UpdatesSheet({required this.updates, required this.images});

  @override
  Widget build(BuildContext context)
  {
    final List<List<UpdateReadingItem>> groups = updatesByVersion(updates);

    return MobileSheet(
      eyebrow: '',
      title: updatesMessageTitle(updates.length),
      body: [
        for (var g = 0; g < groups.length; g++) ...[
          SizedBox(height: g == 0 ? _titleRoom : _versionGap),
          Padding(
            padding: const EdgeInsets.only(left: _badgeIndent),
            child: Align(
              alignment: Alignment.centerLeft,
              child: UpdateVersionBadge(groups[g].first.version, height: 26, fontSize: 13),
            ),
          ),
          for (final update in groups[g]) ...[
            const SizedBox(height: _cardGap),
            MobileSheetCard(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      update.title,
                      style: GoogleFonts.plusJakartaSans(fontSize: 21, fontWeight: FontWeight.w800, height: 1.25, color: AppTheme.trialInk),
                    ),
                    const SizedBox(height: 10),
                    NoticeMessageView(message: update.message, images: images[update.id]!, tight: true),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// For a home with no tour of its own: asks once the page has settled.
class MobileUnreadUpdatesTrigger extends StatefulWidget
{
  final Widget child;

  const MobileUnreadUpdatesTrigger({super.key, required this.child});

  @override
  State<MobileUnreadUpdatesTrigger> createState() => _MobileUnreadUpdatesTriggerState();
}

class _MobileUnreadUpdatesTriggerState extends State<MobileUnreadUpdatesTrigger>
{
  bool _asked = false;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_asked && mobileTourSettled(context))
    {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          showMobileUnreadUpdatesOnce(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
