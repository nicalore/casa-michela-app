import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_state.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../shared/widgets/dialog_components.dart';
import '../notifications/widgets/desktop_notifications_offer.dart';
import 'update_item.dart';
import 'update_reading.dart';

const Duration _waitStep = Duration(milliseconds: 200);

// True once the message was on screen and closed; false leaves it for the next page.
typedef UpdatesShower = Future<bool> Function(List<UpdateReadingItem> updates);

// Once per person signed in and per app run: the unread updates, read once closed.
abstract final class UnreadUpdates
{
  static String? _checkedFor;
  static Future<void>? _running;
  static bool _listening = false;

  // A second caller waits for the first, so what follows the message comes after it.
  static Future<void> once(UpdatesShower show)
  {
    final Future<void>? running = _running;

    if (running != null)
    {
      return running;
    }

    final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

    if (taxCode == null || taxCode == _checkedFor)
    {
      return Future.value();
    }

    _listen();
    _checkedFor = taxCode;

    final Future<void> run = _run(show);
    _running = run;

    return run.whenComplete(()
    {
      if (identical(_running, run))
      {
        _running = null;
      }
    });
  }

  // A message left open by a sign-out no longer holds the next one back.
  static void forget()
  {
    _checkedFor = null;
    _running = null;
  }

  // Signed out, the next sign-in asks again, whoever it is.
  static void _listen()
  {
    if (_listening)
    {
      return;
    }

    _listening = true;

    final ApiService api = ApiService();

    api.authState.addListener(()
    {
      if (api.authState.value != AuthState.authenticated)
      {
        forget();
      }
    });
  }

  static Future<void> _run(UpdatesShower show) async
  {
    final List<UpdateReadingItem> updates;

    try
    {
      updates = await ApiService().getUnreadUpdates();
    }
    catch (_)
    {
      // Asked again on the next page: an update is never lost to a failed read.
      _checkedFor = null;

      return;
    }

    if (updates.isEmpty)
    {
      return;
    }

    if (!await show(updates))
    {
      _checkedFor = null;

      return;
    }

    try
    {
      await ApiService().markUpdatesSeen([for (final update in updates) update.id]);
    }
    catch (_)
    {
      // Unmarked, they come back next time: better twice than never.
    }
  }
}

// Over any page once it has settled, after the notifications question and any tour.
Future<void> showUnreadUpdatesOnce(BuildContext context)
{
  return UnreadUpdates.once((updates) async
  {
    if (!context.mounted)
    {
      return false;
    }

    await settleDesktopPage(context);

    while (context.mounted && (isNotificationsOfferPending || isDesktopTourShown))
    {
      await Future<void>.delayed(_waitStep);
    }

    await blurredDialogsGone();

    if (!context.mounted)
    {
      return false;
    }

    final images = await preloadUpdateImages(context, updates);

    if (!context.mounted)
    {
      return false;
    }

    await showUpdatesMessage(context, updates, images: images);
    await blurredDialogsGone();

    return true;
  });
}
