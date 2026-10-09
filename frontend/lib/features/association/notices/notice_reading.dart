import 'package:flutter/material.dart';

import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/snackbar.dart';
import 'notice_details_dialog.dart';
import 'notice_embeds.dart';
import 'notice_item.dart';

// Read only, administrators included: whom it went to is left out.
Future<void> openNoticeReading(BuildContext context, int id) async
{
  final NoticeItem notice;

  try
  {
    notice = await ApiService().readNotice(id);
  }
  catch (error)
  {
    if (context.mounted)
    {
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
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

  await showNoticeReading(context, notice, images: images);
}
