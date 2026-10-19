import 'package:flutter/foundation.dart';

import '../../services/api_service.dart';
import '../auth/models/me_response.dart';
import '../notifications/notification_board.dart';
import 'report_item.dart';

class ReportsBoard extends ChangeNotifier
{
  static final ReportsBoard instance = ReportsBoard._();

  ReportsBoard._()
  {
    ApiService().identity.addListener(_onIdentity);
  }

  List<ReportItem>? _reports;
  String? _owner;

  // The menus' badge.
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  bool get loaded => _reports != null;

  List<ReportItem> get reports => _reports ?? const [];

  // Another account signed in: the last one's reports are not theirs.
  void _onIdentity()
  {
    final String? owner = ApiService().lastKnownIdentity?.taxCode;

    if (owner != _owner)
    {
      _owner = owner;
      _set(null);
    }
  }

  void _set(List<ReportItem>? reports)
  {
    _reports = reports;
    unread.value = reports?.where((report) => !report.read).length ?? 0;
    notifyListeners();
  }

  Future<void> load() async
  {
    final DateTime asked = DateTime.now();
    final List<ReportItem> reports = await ApiService().getReports();

    _set(reports);
    NotificationBoard.instance.keepOpenReports({for (final report in reports) report.id}, asked: asked);
  }

  // For the menus: a failure keeps what was known.
  Future<void> refresh(MeResponse? user) async
  {
    if (user == null || !user.readsReports)
    {
      return;
    }

    try
    {
      await load();
    }
    catch (_)
    {
      // The page reports its own errors when opened.
    }
  }

  void opened(ReportItem report)
  {
    final List<ReportItem>? reports = _reports;

    if (reports == null)
    {
      return;
    }

    _set([for (final known in reports) known.id == report.id ? report.asRead() : known]);
  }

  void resolved(int id)
  {
    NotificationBoard.instance.dropReport(id);

    final List<ReportItem>? reports = _reports;

    if (reports == null)
    {
      return;
    }

    _set([for (final known in reports) if (known.id != id) known]);
  }
}
