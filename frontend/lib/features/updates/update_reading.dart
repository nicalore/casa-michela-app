import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/descender_room.dart';
import '../../shared/widgets/dialog_components.dart';
import '../association/notices/notice_embeds.dart';
import '../association/notices/notice_message_view.dart';
import 'update_item.dart';
import 'update_strings.dart';
import 'widgets/update_badges.dart';

const double _dialogWidth = 800;
// Cards of one version sit closer than the dialog's pieces, which are its versions.
const double _cardGap = 14;
const double _badgeIndent = 12;

NoticeImages updateImages(int updateId) =>
    NoticeImages(fetcher: (key) => ApiService().fetchUpdateImage(updateId, key));

// Fetched and decoded before the message opens, so it opens whole; a failed one waits in it.
Future<Map<int, NoticeImages>> preloadUpdateImages(BuildContext context, List<UpdateReadingItem> updates) async
{
  final Map<int, NoticeImages> images = {for (final update in updates) update.id: updateImages(update.id)};

  try
  {
    await Future.wait([
      for (final update in updates)
        images[update.id]!.preload(context, [for (final image in update.images) image.key]),
    ]);
  }
  catch (_)
  {
    // A missing image is fetched again in the message, under a placeholder.
  }

  return images;
}

Widget updatePillTitle(String text)
{
  return DescenderRoom(
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, color: AppTheme.trialOcean),
    ),
  );
}

// Each version once, from the newest; its updates in the order given, newest first.
List<List<UpdateReadingItem>> updatesByVersion(List<UpdateReadingItem> updates)
{
  final Map<String, List<UpdateReadingItem>> groups = {};

  for (final update in updates)
  {
    groups.putIfAbsent(update.version, () => []).add(update);
  }

  return groups.values.toList();
}

String updatesMessageTitle(int count) => count == 1 ? kUpdateSingleTitle : kUpdatesGroupTitle;

class UpdateCardBody extends StatelessWidget
{
  final UpdateReadingItem update;
  final NoticeImages images;

  const UpdateCardBody({super.key, required this.update, required this.images});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          update.title,
          style: GoogleFonts.plusJakartaSans(fontSize: 23, fontWeight: FontWeight.w800, height: 1.25, color: AppTheme.trialInk),
        ),
        const SizedBox(height: 14),
        NoticeMessageView(message: update.message, images: images, tight: true),
      ],
    );
  }
}

Future<void> showUpdatesMessage(
  BuildContext context,
  List<UpdateReadingItem> updates, {
  required Map<int, NoticeImages> images,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'UpdatesMessage',
    builder: (_) => AppDialogStack(
      header: updatePillTitle(updatesMessageTitle(updates.length)),
      maxWidth: _dialogWidth,
      children: [
        for (final group in updatesByVersion(updates))
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: _badgeIndent),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: UpdateVersionBadge(group.first.version, height: 30, fontSize: 14),
                ),
              ),
              for (final update in group) ...[
                const SizedBox(height: _cardGap),
                AppDialogPill(
                  expand: true,
                  child: UpdateCardBody(update: update, images: images[update.id]!),
                ),
              ],
            ],
          ),
      ],
    ),
  );
}
