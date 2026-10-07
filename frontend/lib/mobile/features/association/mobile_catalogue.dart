import 'package:flutter/material.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/association/models/association_subject_item.dart';
import '../../../features/association/models/subject_taxonomy.dart';
import '../../../services/api_service.dart';

typedef MobileSubjectGroup = ({String title, List<AssociationSubjectItem> items});

// Held by the page so a swipe away and back keeps the tab's state.
class MobileCatalogue extends ChangeNotifier
{
  final TextEditingController search = TextEditingController();

  bool loading = true;
  bool failed = false;

  List<AssociationSubjectItem> _subjects = const [];

  Future<void>? _loaded;
  bool _disposed = false;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  bool get isEmpty => _subjects.isEmpty;

  Future<void> ensureLoaded() => _loaded ??= load();

  Future<void> load({bool quiet = false}) async
  {
    final int request = ++_request;

    try
    {
      final List<AssociationSubjectItem> subjects =
          await ApiService().getAssociationSubjects(refresh: quiet);

      if (_disposed || request != _request)
      {
        return;
      }

      _subjects = subjects;
      loading = false;
      failed = false;
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle discipline');

      if (_disposed || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      loading = false;
      failed = !quiet || _subjects.isEmpty;
    }

    notifyListeners();
  }

  void searched() => notifyListeners();

  List<MobileSubjectGroup> get groups
  {
    final String query = search.text.toLowerCase();

    final List<AssociationSubjectItem> shown = _subjects
        .where((subject) => subject.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return groupByArea(shown, (subject) => subject.area);
  }

  @override
  void dispose()
  {
    _disposed = true;
    search.dispose();

    super.dispose();
  }
}
