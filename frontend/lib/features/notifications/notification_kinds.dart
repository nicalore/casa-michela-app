import 'package:flutter/foundation.dart';

import '../../services/api_service.dart';
import 'notification_item.dart';
import 'notification_strings.dart';

// Per-account kind switches; read on every visit, as another device may change them.
class NotificationKinds extends ChangeNotifier
{
  static final NotificationKinds instance = NotificationKinds._();

  NotificationKinds._();

  List<NotificationKindChoice>? _choices;

  // Bumped on every read so a stale answer is dropped.
  int _request = 0;

  // Null until read; only the kinds this app can name.
  List<NotificationKindChoice>? get choices => _choices;

  int get enabledCount => _choices?.where((choice) => choice.enabled).length ?? 0;

  static List<NotificationKindChoice> _known(List<NotificationKindChoice> choices)
  {
    return [for (final choice in choices) if (kNotificationKindLabels.containsKey(choice.kind)) choice];
  }

  Future<void> load() async
  {
    final int request = ++_request;

    try
    {
      final List<NotificationKindChoice> read = await ApiService().getNotificationKinds();

      if (request == _request)
      {
        _choices = _known(read);
        notifyListeners();
      }
    }
    catch (_)
    {
      // What was read before stays.
    }
  }

  // Shown at once; put back if the server refuses. Throws what it said.
  Future<void> save(List<NotificationKindChoice> wanted) async
  {
    final List<NotificationKindChoice>? before = _choices;
    final int request = ++_request;

    _choices = wanted;
    notifyListeners();

    try
    {
      final List<NotificationKindChoice> saved = await ApiService().setNotificationKinds(wanted);

      if (request == _request)
      {
        _choices = _known(saved);
        notifyListeners();
      }
    }
    catch (_)
    {
      if (request == _request)
      {
        _choices = before;
        notifyListeners();
      }

      rethrow;
    }
  }

  // Signed out, or someone else signed in.
  void clear()
  {
    _request++;
    _choices = null;
    notifyListeners();
  }

  // Widget tests that build the settings without a server.
  @visibleForTesting
  void debugShow(List<NotificationKindChoice>? choices)
  {
    _request++;
    _choices = choices;
    notifyListeners();
  }
}
