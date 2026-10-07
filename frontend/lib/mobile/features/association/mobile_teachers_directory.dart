import 'package:flutter/material.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/association/teacher_opinions.dart';
import '../../../features/people/models/person_item.dart';
import '../../../features/people/models/teacher_subject_item.dart';
import '../../../services/api_service.dart';

// Held by the page so a swipe away and back keeps the tab's state.
class MobileTeachersDirectory extends ChangeNotifier
{
  final bool parent;

  // False for a pupil a parent answers for: no opinions at all.
  final bool canReport;

  final TextEditingController search = TextEditingController();

  bool loading = true;
  bool failed = false;

  List<PersonItem> _teachers = const [];
  List<OpinionPupil> _pupils = const [];

  TeacherSort _sort = TeacherSort.nameAsc;
  Set<int> _subjectIds = const {};
  bool _onlyDisliked = false;

  Future<void>? _loaded;
  bool _disposed = false;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  MobileTeachersDirectory({required this.parent, required this.canReport});

  List<OpinionPupil> get pupils => _pupils;
  TeacherSort get sort => _sort;
  Set<int> get subjectIds => _subjectIds;
  bool get onlyDisliked => _onlyDisliked;

  bool get speaksForSelf => !parent;

  Future<void> ensureLoaded() => _loaded ??= load();

  Future<void> load({bool quiet = false}) async
  {
    final int request = ++_request;

    try
    {
      final List<PersonItem> teachers = await ApiService().getTeachers(refresh: quiet);
      final List<OpinionPupil> pupils =
          canReport ? await readOpinionPupils(parent: parent) : const <OpinionPupil>[];

      if (_disposed || request != _request)
      {
        return;
      }

      _teachers = teachers;
      _pupils = pupils;
      loading = false;
      failed = false;
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento dei docenti');

      if (_disposed || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      loading = false;
      failed = !quiet || _teachers.isEmpty;
    }

    notifyListeners();
  }

  String get intro
  {
    if (!canReport || _pupils.isEmpty)
    {
      return teachersIntro(verb: 'Toccando');
    }

    return teachersIntro(verb: 'Toccando', whoGotOn: whoGotOn(_pupils, parent: parent));
  }

  bool isDisliked(PersonItem teacher) => _pupils.any((pupil) => pupil.dislikes(teacher));

  List<TeacherSubjectItem> get subjectOptions
  {
    return taughtSubjectsOf(_teachers).values.toList()
      ..sort((a, b) => a.subjectName.compareTo(b.subjectName));
  }

  List<PersonItem> get shown
  {
    final String query = search.text.toLowerCase();

    return _teachers.where((teacher)
    {
      final String name = '${teacher.firstName} ${teacher.lastName}'.toLowerCase();

      return name.contains(query) &&
          (!_onlyDisliked || isDisliked(teacher)) &&
          (_subjectIds.isEmpty || teachesOneOf(teacher, _subjectIds));
    }).toList()
      ..sort(_sort.compare);
  }

  void searched() => notifyListeners();

  void sortBy(TeacherSort sort)
  {
    _sort = sort;
    notifyListeners();
  }

  void filterBySubjects(Set<int> ids)
  {
    _subjectIds = ids;
    notifyListeners();
  }

  void toggleOnlyDisliked()
  {
    _onlyDisliked = !_onlyDisliked;
    notifyListeners();
  }

  Future<void> setOpinion(OpinionPupil pupil, PersonItem teacher, bool disliked) async
  {
    final OpinionPupil fresh = await saveTeacherOpinion(pupil, teacher, disliked);

    if (_disposed)
    {
      return;
    }

    _pupils = [for (final each in _pupils) each.taxCode == fresh.taxCode ? fresh : each];
    notifyListeners();
  }

  @override
  void dispose()
  {
    _disposed = true;
    search.dispose();

    super.dispose();
  }
}
