import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/association/notices/notice_embeds.dart';
import '../../../features/association/notices/notice_message_view.dart';
import '../../../features/updates/unread_updates.dart';
import '../../../features/updates/update_item.dart';
import '../../../features/updates/update_reading.dart';
import '../../../features/updates/update_strings.dart';
import '../../../features/updates/widgets/update_badges.dart';
import '../../shared/mobile_line_breaks.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../notifications/mobile_notifications_offer.dart';

const Duration _waitStep = Duration(milliseconds: 200);

// The title wraps onto two lines more often than not: it needs air above the first card.
const double _titleRoom = 18;
const double _cardGap = 12;

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

class _UpdatesSheet extends StatelessWidget
{
  final List<UpdateReadingItem> updates;
  final Map<int, NoticeImages> images;

  const _UpdatesSheet({required this.updates, required this.images});

  Widget _card(List<Widget> children)
  {
    return MobileSheetCard(
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // As a notice opens: what it is above, its own title below.
    if (updates.length == 1)
    {
      final UpdateReadingItem update = updates.single;

      return MobileSheet(
        eyebrow: withoutOrphans(updateHeading(update.version)),
        title: update.title,
        body: [
          const SizedBox(height: _titleRoom),
          _card([NoticeMessageView(message: update.message, images: images[update.id]!)]),
        ],
      );
    }

    return MobileSheet(
      eyebrow: '',
      title: kUpdatesGroupTitle,
      body: [
        for (var i = 0; i < updates.length; i++) ...[
          SizedBox(height: i == 0 ? _titleRoom : _cardGap),
          _card([
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: UpdateVersionBadge(updates[i].version, height: 26, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              updates[i].title,
              style: GoogleFonts.plusJakartaSans(fontSize: 21, fontWeight: FontWeight.w800, height: 1.25, color: AppTheme.trialInk),
            ),
            const SizedBox(height: 10),
            NoticeMessageView(message: updates[i].message, images: images[updates[i].id]!, tight: true),
          ]),
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
