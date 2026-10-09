import 'package:flutter/material.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/association/notices/notice_item.dart';
import '../../../services/api_service.dart';
import '../../../shared/utils/day_marks.dart';

DateTime noticeDayOf(NoticeSummaryItem notice) =>
    DateTime(notice.createdAt.year, notice.createdAt.month, notice.createdAt.day);

// Held by the page so a swipe away and back keeps the tab's search and order.
class MobileNoticesBoard extends ChangeNotifier
{
  // The role worn: only what was sent to it is read.
  final String role;

  final TextEditingController search = TextEditingController();

  bool loading = true;
  bool failed = false;

  List<NoticeSummaryItem> _notices = const [];
  bool _oldestFirst = false;

  Future<void>? _loaded;
  bool _disposed = false;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  MobileNoticesBoard({required this.role});

  bool get oldestFirst => _oldestFirst;

  bool get isEmpty => _notices.isEmpty;

  Future<void> ensureLoaded() => _loaded ??= load();

  Future<void> load({bool quiet = false}) async
  {
    final int request = ++_request;

    try
    {
      final List<NoticeSummaryItem> notices = await ApiService().getReceivedNotices(role);

      if (_disposed || request != _request)
      {
        return;
      }

      _notices = notices;
      loading = false;
      failed = false;
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle comunicazioni');

      if (_disposed || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      loading = false;
      failed = !quiet || _notices.isEmpty;
    }

    notifyListeners();
  }

  // Pinned first, then by sending in the order chosen.
  List<NoticeSummaryItem> get shown
  {
    final String query = search.text.trim().toLowerCase();

    return noticeListingOrder(
      _notices.where((notice) =>
          query.isEmpty ||
          notice.title.toLowerCase().contains(query) ||
          notice.preview.toLowerCase().contains(query) ||
          notice.authorName.toLowerCase().contains(query)),
      oldestFirst: _oldestFirst,
    );
  }

  void searched() => notifyListeners();

  void orderOldestFirst(bool oldestFirst)
  {
    _oldestFirst = oldestFirst;
    notifyListeners();
  }

  // The month picker reaches back to the first notice sent.
  DateTime firstDay(DateTime today)
  {
    DateTime first = today;

    for (final notice in _notices)
    {
      final DateTime day = noticeDayOf(notice);

      if (day.isBefore(first))
      {
        first = day;
      }
    }

    return first;
  }

  // Dotted: the days of the notices listed.
  Future<DayMarks> marks(DateTime from, DateTime to) async
  {
    return DayMarks(
      busy: {
        for (final notice in shown)
          if (!noticeDayOf(notice).isBefore(from) && !noticeDayOf(notice).isAfter(to)) noticeDayOf(notice),
      },
    );
  }

  @override
  void dispose()
  {
    _disposed = true;
    search.dispose();
    super.dispose();
  }
}
