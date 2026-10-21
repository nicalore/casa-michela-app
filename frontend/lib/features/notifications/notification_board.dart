import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/api_service.dart';
import 'notification_item.dart';
import 'push_types.dart';

// Mirrors _GONE_ONCE_READ in backend/app/api/notifications.py.
const Set<NotificationKind> _goneOnceRead = {
  NotificationKind.newDevice,
  NotificationKind.ratingReminder,
  NotificationKind.teacherNoteAdded,
};

class NotificationBoard extends ChangeNotifier
{
  static final NotificationBoard instance = NotificationBoard._();

  NotificationBoard._();

  bool _loading = true;
  List<NotificationItem>? _items;
  DateTime? _listedAt;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  // The newest fetch, which a dropped one waits for.
  Future<void>? _latest;

  Timer? _expiry;

  // Where a notification leads; the desktop sets it, the mobile app has nowhere to go yet.
  void Function(NotificationItem item)? follow;

  final ValueNotifier<NotificationItem?> _arrival = ValueNotifier<NotificationItem?>(null);

  // The latest one the system did not show, for the app to show it.
  ValueListenable<NotificationItem?> get arrival => _arrival;

  bool get loading => _loading;

  // Null when they could not be read.
  List<NotificationItem>? get items => _items;

  // When the current list was fetched: system notifications shown before it are in it.
  DateTime? get listedAt => _listedAt;

  int get unread => _items?.where((item) => !item.read).length ?? 0;

  Future<void> load()
  {
    final Future<void> fetch = _fetch(++_request);
    _latest = fetch;

    return fetch;
  }

  Future<void> _fetch(int request) async
  {
    final DateTime asked = DateTime.now();
    List<NotificationItem>? items;

    try
    {
      items = await ApiService().getNotifications();
    }
    catch (_)
    {
      items = null;
    }

    // A newer read is under way, as when a tap launches the app and the home reads too.
    if (request != _request)
    {
      await _latest;

      return;
    }

    // A failed refresh keeps what was read before.
    if (items != null)
    {
      _items = items;
      _listedAt = asked;
      _expireLater();
    }

    _loading = false;
    notifyListeners();
  }

  // Gone at its moment even with no dismissal: Safari is sent none.
  void _expireLater()
  {
    _expiry?.cancel();

    final List<DateTime> moments = [...?_items?.map((item) => item.expiresAt).nonNulls]..sort();

    if (moments.isNotEmpty)
    {
      _expiry = Timer(moments.first.difference(DateTime.now()), _dropExpired);
    }
  }

  void _dropExpired()
  {
    final DateTime now = DateTime.now();
    final List<NotificationItem>? items = _items;

    if (items == null)
    {
      return;
    }

    _items = [for (final item in items) if (!item.hasExpired(now)) item];
    _expireLater();
    notifyListeners();
  }

  // Widget tests that announce one without a push.
  @visibleForTesting
  void debugArrive(NotificationItem item) => _arrival.value = item;

  // Widget tests that build a home without loading it.
  @visibleForTesting
  void debugShow(List<NotificationItem>? items)
  {
    _request++;
    _latest = null;
    _items = items;
    _listedAt = items == null ? null : DateTime.now();
    _expireLater();
    _loading = false;
    notifyListeners();
  }

  // Signed out, or someone else signed in.
  void clear()
  {
    _request++;
    _latest = null;
    _expiry?.cancel();
    _items = null;
    _listedAt = null;
    _arrival.value = null;
    _loading = true;
    notifyListeners();
  }

  // Whatever a notification leads to, opening it reads it.
  Future<void> open(NotificationItem item) async
  {
    follow?.call(item);

    if (item.read)
    {
      return;
    }

    _markRead(item.id);

    try
    {
      await ApiService().markNotificationRead(item.id);
    }
    catch (_) {}
  }

  // A report resolved: the news of it goes, as the server took it away.
  void dropReport(int id)
  {
    _drop(NotificationKind.reportReceived, (item) => item.reportId == id);
  }

  // Reports fetched before [asked] and no longer open were resolved by someone else.
  void keepOpenReports(Set<int> open, {required DateTime asked})
  {
    _drop(
      NotificationKind.reportReceived,
      (item) => !open.contains(item.reportId) && item.createdAt.isBefore(asked),
    );
  }

  // A teacher rated anew: the reminder to rate them goes, as the server took it away.
  void dropRatingReminder(String teacherTaxCode)
  {
    _drop(NotificationKind.ratingReminder, (item) => item.teacherTaxCode == teacherTaxCode);
  }

  // A teacher's note deleted: its news goes, as the server took it away.
  void dropTeacherNote(int id)
  {
    _drop(NotificationKind.teacherNoteAdded, (item) => item.teacherNoteId == id);
  }

  void _drop(NotificationKind kind, bool Function(NotificationItem item) gone)
  {
    final List<NotificationItem>? items = _items;

    if (items == null)
    {
      return;
    }

    final List<NotificationItem> kept = [
      for (final item in items)
        if (item.kind != kind || !gone(item)) item,
    ];

    if (kept.length != items.length)
    {
      _items = kept;
      notifyListeners();
    }
  }

  void _markRead(int id)
  {
    final List<NotificationItem>? items = _items;

    if (items == null)
    {
      return;
    }

    _items = [
      for (final item in items)
        // Some have said all they had to once read: the server takes them away too.
        if (item.id != id) item else if (!_goneOnceRead.contains(item.kind)) item.asRead(),
    ];
    notifyListeners();
  }

  NotificationItem? _find(int id) => _items?.where((item) => item.id == id).firstOrNull;

  // An app opened by a tap may not have read its list yet.
  Future<void> hear(PushNews news) async
  {
    switch (news.type)
    {
      case PushNewsType.arrived:
        await load();

        final NotificationItem? item = _find(news.id);

        if (news.quiet && item != null && !item.read)
        {
          _arrival.value = item;
        }
      case PushNewsType.dismissed:
        await load();
      case PushNewsType.opened:
        NotificationItem? item = _find(news.id);

        // Shown by the system while the app was away, so not in the list held since.
        if (item == null)
        {
          await load();
          item = _find(news.id);
        }

        if (item != null)
        {
          await open(item);
        }
      case PushNewsType.renewed:
        break;
    }
  }
}
