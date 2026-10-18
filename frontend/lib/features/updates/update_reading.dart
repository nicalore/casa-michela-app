import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/dialog_components.dart';
import '../association/notices/notice_embeds.dart';
import '../association/notices/notice_message_view.dart';
import 'update_item.dart';
import 'update_strings.dart';
import 'widgets/update_badges.dart';

const double _dialogWidth = 800;

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

// The title alone in the pill, set as the dialogs set theirs.
Widget updatePillTitle(String text)
{
  return Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, color: AppTheme.trialOcean),
  );
}

// One update, a version, its title, then what changed; for a message with several.
class UpdateSection extends StatelessWidget
{
  final UpdateReadingItem update;
  final NoticeImages images;

  const UpdateSection({super.key, required this.update, required this.images});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: UpdateVersionBadge(update.version, height: 28, fontSize: 13.5),
        ),
        const SizedBox(height: 12),
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

// One update as a notice opens; several, each in a card of its own under one pill.
Future<void> showUpdatesMessage(
  BuildContext context,
  List<UpdateReadingItem> updates, {
  required Map<int, NoticeImages> images,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'UpdatesMessage',
    builder: (_)
    {
      if (updates.length == 1)
      {
        final UpdateReadingItem update = updates.single;

        return AppDialogStack(
          eyebrow: updateHeading(update.version),
          title: update.title,
          maxWidth: _dialogWidth,
          fillLast: true,
          children: [
            AppScrollingDialogPill(child: NoticeMessageView(message: update.message, images: images[update.id]!)),
          ],
        );
      }

      return AppDialogStack(
        header: updatePillTitle(kUpdatesGroupTitle),
        maxWidth: _dialogWidth,
        children: [
          for (final update in updates)
            AppDialogPill(expand: true, child: UpdateSection(update: update, images: images[update.id]!)),
        ],
      );
    },
  );
}
