import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../models/person_item.dart';
import '../models/teacher_subject_item.dart';
import 'competence_picker.dart';

class TeacherCompetencesDraft
{
  final List<Map<String, dynamic>> competences;
  final List<String> services;

  const TeacherCompetencesDraft({required this.competences, required this.services});

  bool get isEmpty => competences.isEmpty && services.isEmpty;
}

class TeacherCompetencesEditor extends StatefulWidget
{
  final PersonItem person;

  // True offers only competences not held yet; the draft then carries the additions alone.
  final bool onlyNew;

  final ValueChanged<TeacherCompetencesDraft> onChanged;

  final Widget Function(BuildContext context, Widget filters, Widget list) builder;

  final bool scrollable;

  const TeacherCompetencesEditor({
    super.key,
    required this.person,
    this.onlyNew = false,
    required this.onChanged,
    required this.builder,
    this.scrollable = true,
  });

  @override
  State<TeacherCompetencesEditor> createState() => _TeacherCompetencesEditorState();
}

class _TeacherCompetencesEditorState extends State<TeacherCompetencesEditor>
{
  final Map<int, bool> _isSubjectSelected = {};
  final Map<int, Set<int>> _programsBySubject = {};

  final Set<String> _selectedServices = {};

  final Map<int, List<StudyProgramItem>> _programsBySubjectId = {};

  bool _isLoading = true;

  List<AssociationSubjectItem> _allSubjects = [];
  List<StudyProgramItem> _allPrograms = [];
  List<ServiceItem> _allServices = [];

  @override
  void initState()
  {
    super.initState();
    _loadAllData();
  }

  List<StudyProgramItem> _findProgramsFor(AssociationSubjectItem subject)
  {
    return _allPrograms.where((program) => program.teaches(subject.id)).toList();
  }

  Future<void> _loadAllData() async
  {
    try
    {
      final results = await Future.wait([
        ApiService().getAssociationSubjects(),
        ApiService().getStudyPrograms(),
        ApiService().getServices(),
      ]);

      if (!mounted)
      {
        return;
      }

      final List<TeacherSubjectItem> held = widget.person.teacherSubjects ?? const [];
      final List<String> heldServices = widget.person.teacherServices ?? const [];

      final Set<int> heldIds = {for (final competence in held) competence.subjectId};

      final subjects = results[0] as List<AssociationSubjectItem>;
      final services = results[2] as List<ServiceItem>;

      setState(()
      {
        _allSubjects = widget.onlyNew
            ? subjects.where((subject) => !heldIds.contains(subject.id)).toList()
            : subjects;
        _allPrograms = results[1] as List<StudyProgramItem>;
        _allServices = widget.onlyNew
            ? services.where((service) => !heldServices.contains(service.name)).toList()
            : services;

        for (final subject in _allSubjects)
        {
          _programsBySubjectId[subject.id] = _findProgramsFor(subject);
        }

        if (!widget.onlyNew)
        {
          for (final competence in held)
          {
            _isSubjectSelected[competence.subjectId] = true;
            _programsBySubject[competence.subjectId] = competence.studyProgramIds.toSet();
          }

          _selectedServices.addAll(heldServices);
        }

        _isLoading = false;
      });

      _publish();
    }
    catch (_)
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
      }
    }
  }

  void _publish()
  {
    widget.onChanged(TeacherCompetencesDraft(
      competences: _isSubjectSelected.entries
          .where((entry) => entry.value)
          .map((entry) => <String, dynamic>{
                'subject_id': entry.key,
                'study_program_ids': _programsBySubject[entry.key]?.toList() ?? [],
              })
          .toList(),
      services: _selectedServices.toList(),
    ));
  }

  @override
  Widget build(BuildContext context)
  {
    return CompetenceCatalogue(
      subjects: _allSubjects,
      programsBySubjectId: _programsBySubjectId,
      isSelected: _isSubjectSelected,
      programsBySubject: _programsBySubject,
      services: _allServices,
      selectedServices: _selectedServices,
      isLoading: _isLoading,
      scrollable: widget.scrollable,
      onChanged: ()
      {
        setState(() {});
        _publish();
      },
      builder: widget.builder,
    );
  }
}
