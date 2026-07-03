import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';
import '../../../shared/widgets/snackbar.dart';
import '../association/models/association_subject_item.dart';
import '../association/models/school_item.dart';
import '../association/models/study_program_item.dart';
import 'models/person_item.dart';
import 'models/school_enrollment_item.dart';
import 'person_wizard_components.dart';

class PersonEditDialog extends StatefulWidget 
{
  final PersonItem person;
  
  const PersonEditDialog
  ({
    super.key,
    required this.person,
  });

  @override
  State<PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends State<PersonEditDialog> 
{
  int  _currentStep           = 0;
  int  _involvementType       = -1;
  bool _genitoreIsAssociato   = false;
  bool _wasAssociato          = false;
  int  _currentFormCardIndex  = 0;
  int  _currentStep4CardIndex = 0;
  bool _movingForward         = true;
  bool _cardMovingForward     = true;
  bool _card4MovingForward    = true;
  bool _isSubmitting          = false;
  bool _isLoadingData         = true;

  final Set<String> _selectedRoles = {};

  final List<Map<String, dynamic>> _availableRoles = 
  [
    {
      'id':    'DOCENTE', 
      'label': 'Docente', 
      'desc':  'Svolge attività di supporto didattico e ripetizioni.', 
      'icon':  Icons.school_outlined
    },
    {
      'id':    'STUDENTE', 
      'label': 'Studente', 
      'desc':  'Riceve supporto didattico e ripetizioni.', 
      'icon':  Icons.menu_book_outlined
    },
    {
      'id':    'AMMINISTRATORE', 
      'label': 'Amministratore', 
      'desc':  'Gestisce le attività amministrative, organizzative e operative dell\'Associazione.', 
      'icon':  Icons.computer_outlined
    },
    {
      'id':    'PSICOLOGO', 
      'label': 'Psicologo', 
      'desc':  'Svolge colloqui psicologici e supporta gli studenti.', 
      'icon':  Icons.psychology_outlined
    },
    {
      'id':    'CORSISTA', 
      'label': 'Corsista', 
      'desc':  'Partecipa ai corsi organizzati dall\'Associazione, come yoga o pilates.', 
      'icon':  Icons.self_improvement_rounded
    },
    {
      'id':    'GENITORE', 
      'label': 'Genitore / Tutore', 
      'desc':  'È il responsabile legale di uno o più iscritti all\'Associazione.', 
      'icon':  Icons.family_restroom_outlined
    },
  ];

  Map<String, String> _formErrors = {};
  Uint8List?          _fotoProfilo;

  final TextEditingController _nomeCtrl            = TextEditingController();
  final TextEditingController _cognomeCtrl         = TextEditingController();
  String?                     _sesso;
  final TextEditingController _cfCtrl              = TextEditingController();
  final TextEditingController _dataNascitaCtrl     = TextEditingController();
  final TextEditingController _cittaNascitaCtrl    = TextEditingController();
  final TextEditingController _provNascitaCtrl     = TextEditingController();
  final TextEditingController _tipoViaCtrl         = TextEditingController();
  final TextEditingController _indirizzoNomeCtrl   = TextEditingController();
  final TextEditingController _civicoCtrl          = TextEditingController();
  final TextEditingController _cittaResidenzaCtrl  = TextEditingController();
  final TextEditingController _provResidenzaCtrl   = TextEditingController();
  final TextEditingController _capCtrl             = TextEditingController();
  final TextEditingController _emailCtrl           = TextEditingController();
  final TextEditingController _telefonoCtrl        = TextEditingController();

  final List<WizardEnrollmentRowData> _enrollmentRows = [];
  final List<int?>                    _enrollmentIds  = [];
  final List<WizardSchoolRowData>     _schoolRows     = [];

  final TextEditingController _scadenzaCertificatoCtrl      = TextEditingController();
  final TextEditingController _tipoCorsoCtrl                = TextEditingController();
  final TextEditingController _ibanCtrl                     = TextEditingController();
  String?                     _tipoCollaborazione;
  String?                     _ruoloAmministratore;
  final TextEditingController _altroRuoloAmministratoreCtrl = TextEditingController();
  final TextEditingController _studiScolasticiCtrl          = TextEditingController();
  final TextEditingController _studiUniversitariCtrl        = TextEditingController();

  String?                _uscitaAnticipata;
  List<SchoolItem>       _allSchools  = [];
  List<StudyProgramItem> _allPrograms = [];

  final TextEditingController _searchParentsCtrl  = TextEditingController();
  String                      _searchParentsText  = '';
  String                      _sortParentsBy      = 'surname_asc';
  final Set<String>           _selectedParents    = {};
  List<PersonItem>            _allAdults          = [];

  final TextEditingController _searchMinorsCtrl = TextEditingController();
  String                      _searchMinorsText = '';
  String                      _sortMinorsBy     = 'surname_asc';
  String?                     _filterMinorsRole;
  final Set<String>           _selectedMinors   = {};
  List<PersonItem>            _allMinors        = [];

  List<AssociationSubjectItem> _allSubjects                 = [];
  final TextEditingController  _searchSubjectsCtrl          = TextEditingController();
  String                       _searchSubjectsText          = '';
  String                       _sortSubjectsBy              = 'name_asc';
  String?                      _filterSubjectsArea;
  final Map<int, bool>         _subjectToggles              = {};
  final Map<int, Set<int>>     _selectedProgramsForSubject  = {};

  @override
  void initState() 
  {
    super.initState();
    _loadExistingData();
    _loadAllData();
  }

  @override
  void dispose() 
  {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _cfCtrl.dispose();
    _dataNascitaCtrl.dispose();
    _cittaNascitaCtrl.dispose();
    _provNascitaCtrl.dispose();
    _tipoViaCtrl.dispose();
    _indirizzoNomeCtrl.dispose();
    _civicoCtrl.dispose();
    _cittaResidenzaCtrl.dispose();
    _provResidenzaCtrl.dispose();
    _capCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _scadenzaCertificatoCtrl.dispose();
    _tipoCorsoCtrl.dispose();
    _ibanCtrl.dispose();
    _altroRuoloAmministratoreCtrl.dispose();
    _studiScolasticiCtrl.dispose();
    _studiUniversitariCtrl.dispose();
    _searchSubjectsCtrl.dispose();
    _searchMinorsCtrl.dispose();
    _searchParentsCtrl.dispose();
    for (final row in _enrollmentRows) 
    {
      row.yearCtrl.dispose();
      row.dateCtrl.dispose();
    }
    for (final row in _schoolRows)
    {
      row.yearCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAllData() async 
  {
    try 
    {
      final results = await Future.wait(
      [
        ApiService().getStudyPrograms(),
        ApiService().getSchools(), 
        ApiService().getAssociationSubjects(),
        ApiService().getPeople(),
      ]);
      
      if (mounted) 
      {
        setState(() 
        {
          _allPrograms = results[0] as List<StudyProgramItem>;
          _allSchools  = results[1] as List<SchoolItem>;
          _allSubjects = results[2] as List<AssociationSubjectItem>;
          
          final allPeople = results[3] as List<PersonItem>;
          _allMinors = allPeople.where((p) => ((p.age != null && p.age! < 18) || (widget.person.children?.any((c) => c.fiscalCode == p.fiscalCode) ?? false)) && p.fiscalCode != widget.person.fiscalCode).toList();
          _allAdults = allPeople.where((p) => (p.age == null || p.age! >= 18) && p.roles.any((r) => r.toUpperCase() == 'GENITORE') && p.fiscalCode != widget.person.fiscalCode).toList();
          
          //LoadSchoolEnrollments
          if (_schoolRows.isEmpty && widget.person.roles.any((r) => r.toUpperCase() == 'STUDENTE'))
          {
            final enrollments = widget.person.schoolEnrollments ?? [];
            if (enrollments.isNotEmpty) 
            {
              final sorted = List<SchoolEnrollmentItem>.from(enrollments)..sort((a, b) => b.startYear.compareTo(a.startYear));
              for (var e in sorted) 
              {
                final school  = _allSchools.where((s) => s.mechanographicCode == e.schoolMechanographicCode).firstOrNull;
                final program = _allPrograms.where((p) => p.id == e.studyProgramId).firstOrNull;
                
                String? gradeString;
                if (program != null)
                {
                  const map = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI', 7: 'VII', 8: 'VIII'};
                  gradeString = map[e.grade];
                }

                _schoolRows.add(WizardSchoolRowData
                (
                  yearCtrl:        TextEditingController(text: e.startYear.toString()),
                  selectedSchool:  school,
                  selectedProgram: program,
                  selectedGrade:   gradeString,
                ));
              }
            }
            else
            {
              SchoolItem?       matchedSchool;
              StudyProgramItem? matchedProgram;
              try { matchedSchool = _allSchools.firstWhere((s) => s.name == widget.person.schoolName); } catch (_) {}
              try { matchedProgram = _allPrograms.firstWhere((p) => p.name == widget.person.studyProgram); } catch (_) {}

              _schoolRows.add(WizardSchoolRowData
              (
                yearCtrl:        TextEditingController(text: widget.person.enrollmentYear ?? _getCurrentSchoolYearStart().toString()),
                selectedSchool:  matchedSchool,
                selectedProgram: matchedProgram,
                selectedGrade:   widget.person.schoolClass,
              ));
            }
          }

          _isLoadingData = false;
        });
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _loadExistingData() 
  {
    _nomeCtrl.text           = widget.person.firstName;
    _cognomeCtrl.text        = widget.person.lastName;
    _sesso                   = widget.person.gender;
    _cfCtrl.text             = widget.person.fiscalCode;
    
    if (widget.person.birthDate != null)
    {
      _dataNascitaCtrl.text  = DateFormat('dd/MM/yyyy').format(widget.person.birthDate!);
    }
    
    _cittaNascitaCtrl.text   = widget.person.birthCity ?? '';
    _provNascitaCtrl.text    = widget.person.birthProvince ?? '';
    
    _tipoViaCtrl.text        = widget.person.residenceType ?? '';
    _indirizzoNomeCtrl.text  = widget.person.address ?? '';
    _civicoCtrl.text         = widget.person.addressNumber ?? '';
    _cittaResidenzaCtrl.text = widget.person.city ?? '';
    _provResidenzaCtrl.text  = widget.person.province ?? '';
    _capCtrl.text            = widget.person.zipCode ?? '';
    
    _emailCtrl.text          = widget.person.email ?? '';
    _telefonoCtrl.text       = widget.person.phoneNumber ?? '';

    final roles = widget.person.roles.map((r) => r.toUpperCase()).toSet();
    _selectedRoles.clear();
    _selectedRoles.addAll(roles);

    if (roles.contains('ASSOCIATO') || roles.any((r) => r != 'GENITORE')) 
    {
      _wasAssociato = true;
    } 
    else 
    {
      _wasAssociato = false;
    }

    if (roles.length == 1 && roles.contains('ASSOCIATO')) 
    {
      _involvementType = 1;
    } 
    else 
    {
      _involvementType = 0;
    }
    
    if (roles.contains('GENITORE') && roles.contains('ASSOCIATO')) 
    {
      _genitoreIsAssociato = true;
    } 
    else 
    {
      _genitoreIsAssociato = false;
    }

    try 
    {
      final dynamic p = widget.person;
      dynamic mems;
      try { mems = p.memberships; } catch(_) {}
      if (mems == null) { try { mems = p.member_data?['memberships']; } catch(_) {} }
      
      if (mems != null && mems is Iterable && mems.isNotEmpty) 
      {
        for (var mem in mems) 
        {
          int? mId;
          try { mId = (mem is Map) ? mem['id'] : mem.id; } catch(_) {}
          
          final String yearStr = (mem is Map) ? mem['year']?.toString() ?? '' : mem.year?.toString() ?? '';
          
          dynamic startDate = (mem is Map) ? mem['start_date'] : mem.startDate;
          String dateStr = '';
          if (startDate != null) 
          {
            if (startDate is DateTime) 
            {
              dateStr = '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}';
            } 
            else if (startDate is String) 
            {
              final DateTime? d = DateTime.tryParse(startDate);
              if (d != null) 
              {
                dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
              } 
              else 
              {
                final parts = startDate.split('-');
                if (parts.length == 3) 
                {
                  dateStr = '${parts[2]}/${parts[1]}';
                }
              }
            }
          }
          
          _enrollmentRows.add(WizardEnrollmentRowData
          (
            yearCtrl: TextEditingController(text: yearStr),
            dateCtrl: TextEditingController(text: dateStr),
          ));
          _enrollmentIds.add(mId);
        }
      }
    } 
    catch (_) {}

    if (_enrollmentRows.isEmpty) 
    {
      final now = DateTime.now();
      _enrollmentRows.add(WizardEnrollmentRowData
      (
        yearCtrl: TextEditingController(text: now.year.toString()),
        dateCtrl: TextEditingController(text: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}'),
      ));
      _enrollmentIds.add(null);
    }

    _scadenzaCertificatoCtrl.text = widget.person.medicalCertificateExpiration != null 
        ? DateFormat('dd/MM/yyyy').format(widget.person.medicalCertificateExpiration!) 
        : '';
    _tipoCorsoCtrl.text = widget.person.courseType ?? '';
    _ibanCtrl.text      = widget.person.iban ?? '';
    
    if (widget.person.collaborationType == 'Volontario' || widget.person.collaborationType == 'VOLUNTEER') _tipoCollaborazione = 'Volontario';
    if (widget.person.collaborationType == 'Retribuito' || widget.person.collaborationType == 'PAID') _tipoCollaborazione = 'Retribuito';
    if (widget.person.collaborationType == 'PCTO' || widget.person.collaborationType == 'FSC (Ex PCT0)') _tipoCollaborazione = 'FSC (Ex PCT0)';

    if (widget.person.adminRole != null) 
    {
      final role = widget.person.adminRole!;
      if (role == 'PRESIDENT' || role == 'Presidente') _ruoloAmministratore = 'Presidente';
      else if (role == 'VICE_PRESIDENT' || role == 'Vice Presidente') _ruoloAmministratore = 'Vicepresidente';
      else if (role == 'TREASURER' || role == 'Tesoriere') _ruoloAmministratore = 'Tesoriere';
      else 
      {
        _ruoloAmministratore = 'Altro';
        _altroRuoloAmministratoreCtrl.text = widget.person.adminOtherRole ?? role;
      }
    }

    _studiScolasticiCtrl.text   = widget.person.schoolEducation ?? '';
    _studiUniversitariCtrl.text = widget.person.universityEducation ?? '';

    if (widget.person.earlyExit != null) 
    {
      _uscitaAnticipata = widget.person.earlyExit! ? 'Sì' : 'No';
    }

    if (widget.person.parents != null) 
    {
      for (var parent in widget.person.parents!) 
      {
        _selectedParents.add(parent.fiscalCode);
      }
    }

    if (widget.person.children != null) 
    {
      for (var child in widget.person.children!) 
      {
        _selectedMinors.add(child.fiscalCode);
      }
    }

    if (widget.person.teacherSubjects != null) 
    {
      for (var ts in widget.person.teacherSubjects!) 
      {
        _subjectToggles[ts.subjectId] = true;
        _selectedProgramsForSubject[ts.subjectId] = ts.studyProgramIds.toSet();
      }
    }
  }

  String? _toIsoDate(String? itaDate) 
  {
    if (itaDate == null || itaDate.isEmpty) return null;
    final parts = itaDate.split('/');
    if (parts.length != 3) return null;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  bool _isValidDate(String dateStr)
  {
    try 
    {
      final parts = dateStr.split('/');
      if (parts.length != 3) return false;
      
      final day   = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year  = int.parse(parts[2]);
      final date  = DateTime(year, month, day);
      
      return date.year == year && date.month == month && date.day == day;
    } 
    catch (_)
    {
      return false;
    }
  }

  bool _isValidDayMonthYear(String dm, String yearStr) 
  {
    try 
    {
      final parts = dm.split('/');
      if (parts.length != 2) return false;
      
      final day   = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year  = int.parse(yearStr);
      final date  = DateTime(year, month, day);
      
      return date.year == year && date.month == month && date.day == day;
    } 
    catch (_)
    {
      return false;
    }
  }

  bool get _isMinor
  {
    if (_dataNascitaCtrl.text.isEmpty) return false;
    if (!_isValidDate(_dataNascitaCtrl.text)) return false;
    
    final parts = _dataNascitaCtrl.text.split('/');
    final date  = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    final now   = DateTime.now();
    int   age   = now.year - date.year;
    
    if (now.month < date.month || (now.month == date.month && now.day < date.day))
    {
      age--;
    }
    
    return age < 18;
  }

  int _getCurrentSchoolYearStart() 
  {
    final now = DateTime.now();
    return now.month < 9 ? now.year - 1 : now.year;
  }

  int _romanToNumeric(String roman) 
  {
    const map = 
    {
      'I':    1, 
      'II':   2, 
      'III':  3, 
      'IV':   4, 
      'V':    5,
      'VI':   6,
      'VII':  7,
      'VIII': 8,
    };
    return map[roman] ?? 1;
  }

  List<StudyProgramItem> _getProgramsForSubject(AssociationSubjectItem subject) 
  {
    final List<StudyProgramItem> linkedPrograms = [];
    
    for (final prog in _allPrograms) 
    {
      bool hasMatch = false;
      try 
      {
        final dynamic minSubjects = (prog as dynamic).ministrySubjects;
        if (minSubjects != null && minSubjects is Iterable) 
        {
          for (var m in minSubjects) 
          {
            final dynamic assocSubjects = (m as dynamic).associationSubjects;
            if (assocSubjects != null && assocSubjects is Iterable) 
            {
              for (var assoc in assocSubjects) 
              {
                final int? assocId = (assoc is Map) ? assoc['id'] as int? : (assoc as dynamic).id as int?;
                if (assocId == subject.id)
                {
                  hasMatch = true;
                  break;
                }
              }
            }
            if (hasMatch) break; 
          }
        }
      }
      catch (_) {}
      
      if (hasMatch) linkedPrograms.add(prog);
    }
    
    return linkedPrograms;
  }

  List<AssociationSubjectItem> get _filteredFilteredSubjects 
  {
    var result = _allSubjects.where((subject)
    {
      if (_getProgramsForSubject(subject).isEmpty) return false;
      
      final query         = _searchSubjectsText.toLowerCase();
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea   = _filterSubjectsArea == null || subject.area == _filterSubjectsArea;
      
      return matchesSearch && matchesArea;
    }).toList();

    result.sort((a, b)
    {
      if (_sortSubjectsBy == 'name_asc') return a.name.compareTo(b.name);
      if (_sortSubjectsBy == 'name_desc') return b.name.compareTo(a.name);
      if (_sortSubjectsBy == 'date_asc') return a.createdAt.compareTo(b.createdAt);
      if (_sortSubjectsBy == 'date_desc') return b.createdAt.compareTo(a.createdAt);
      return 0;
    });

    return result;
  }

  List<PersonItem> get _filteredAdults
  {
    var result = _allAdults.where((adult)
    {
      final query    = _searchParentsText.toLowerCase();
      final fullName = '${adult.firstName} ${adult.lastName}'.toLowerCase();
      return fullName.contains(query);
    }).toList();

    result.sort((a, b)
    {
      if (_sortParentsBy == 'name_asc') return a.firstName.compareTo(b.firstName);
      if (_sortParentsBy == 'name_desc') return b.firstName.compareTo(a.firstName);
      if (_sortParentsBy == 'surname_asc') return a.lastName.compareTo(b.lastName);
      if (_sortParentsBy == 'surname_desc') return b.lastName.compareTo(a.lastName);
      if (_sortParentsBy == 'date_desc') return b.createdAt.compareTo(a.createdAt);
      if (_sortParentsBy == 'date_asc') return a.createdAt.compareTo(b.createdAt);
      return 0;
    });

    return result;
  }

  List<PersonItem> get _filteredMinors
  {
    var result = _allMinors.where((minor)
    {
      final query         = _searchMinorsText.toLowerCase();
      final fullName      = '${minor.firstName} ${minor.lastName}'.toLowerCase();
      final matchesSearch = fullName.contains(query);
      final matchesRole   = _filterMinorsRole == null || minor.roles.any((r) => r.trim().toUpperCase() == _filterMinorsRole!.trim().toUpperCase());
      
      return matchesSearch && matchesRole;
    }).toList();

    result.sort((a, b)
    {
      if (_sortMinorsBy == 'name_asc') return a.firstName.compareTo(b.firstName);
      if (_sortMinorsBy == 'name_desc') return b.firstName.compareTo(a.firstName);
      if (_sortMinorsBy == 'surname_asc') return a.lastName.compareTo(b.lastName);
      if (_sortMinorsBy == 'surname_desc') return b.lastName.compareTo(a.lastName);
      if (_sortMinorsBy == 'date_desc') return b.createdAt.compareTo(a.createdAt);
      if (_sortMinorsBy == 'date_asc') return a.createdAt.compareTo(b.createdAt);
      return 0;
    });

    return result;
  }

  List<Widget> get _activeStep4Cards 
  {
    final List<Widget> cards       = [];
    final List<String> activeRoles = _selectedRoles.toList();
    
    final bool isOnlyGenitoreNotAssociato = activeRoles.length == 1 && activeRoles.contains('GENITORE') && !_genitoreIsAssociato;

    if (!isOnlyGenitoreNotAssociato)
    {
      cards.add(_buildFormCardIscrizione());
    }

    final bool isStaff = activeRoles.contains('AMMINISTRATORE') || 
                         activeRoles.contains('DOCENTE') || 
                         activeRoles.contains('PSICOLOGO');
                         
    if (isStaff) cards.add(_buildFormCardStaff());
    if (activeRoles.contains('AMMINISTRATORE')) cards.add(_buildFormCardAmministratore());
    if (activeRoles.contains('DOCENTE')) cards.add(_buildFormCardDocente());
    if (activeRoles.contains('CORSISTA')) cards.add(_buildFormCardCorsista());
    if (activeRoles.contains('STUDENTE')) cards.add(_buildFormCardStudente());
    
    return cards;
  }

  bool _validateRoles() 
  {
    final activeRoles = _selectedRoles.where((role) => role != 'ASSOCIATO').toList();
    if (activeRoles.isEmpty) 
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno un ruolo.', isError: true);
      return false;
    }

    final bool wasGenitore = widget.person.roles.any((r) => r.toUpperCase() == 'GENITORE');
    final bool isGenitore  = _selectedRoles.contains('GENITORE');

    if (wasGenitore && !isGenitore && widget.person.children != null) 
    {
      //CheckOrphanStatus
      for (final child in widget.person.children!) 
      {
        final minorIterable = _allMinors.where((m) => m.fiscalCode == child.fiscalCode);
        if (minorIterable.isNotEmpty)
        {
          final PersonItem minorData = minorIterable.first;
          if (minorData.parents != null) 
          {
            final otherParents = minorData.parents!.where((p) => p.fiscalCode != widget.person.fiscalCode).toList();
            if (otherParents.isEmpty) 
            {
              CustomSnackBar.show
              (
                context: context, 
                message: 'Impossibile rimuovere il ruolo Genitore: ${minorData.firstName} ${minorData.lastName} rimarrebbe senza genitori.', 
                isError: true,
              );
              return false;
            }
          }
        }
      }
    }

    return true;
  }

  bool _validateDatiGenerali() 
  {
    setState(() 
    {
      _formErrors.clear();
      _tipoViaCtrl.text        = _tipoViaCtrl.text.trim();
      _indirizzoNomeCtrl.text  = _indirizzoNomeCtrl.text.trim();
      _civicoCtrl.text         = _civicoCtrl.text.trim();
      _cittaResidenzaCtrl.text = _cittaResidenzaCtrl.text.trim();
      _provResidenzaCtrl.text  = _provResidenzaCtrl.text.trim().toUpperCase();
      _capCtrl.text            = _capCtrl.text.trim();
      _emailCtrl.text          = _emailCtrl.text.trim();
      _telefonoCtrl.text       = _telefonoCtrl.text.replaceAll(' ', ''); 
    });

    bool                isValid          = true;
    int?                firstInvalidCard;
    Map<String, String> newErrors        = {};

    void addError(String field, String message, int cardIndex) 
    {
      newErrors[field] = message;
      isValid          = false;
      if (firstInvalidCard == null || cardIndex < firstInvalidCard!) 
      {
        firstInvalidCard = cardIndex;
      }
    }

    if (_tipoViaCtrl.text.isEmpty) addError('tipoVia', 'Campo obbligatorio', 3);
    if (_indirizzoNomeCtrl.text.isEmpty) addError('indirizzoNome', 'Campo obbligatorio', 3);
    if (_civicoCtrl.text.isEmpty) addError('civico', 'Campo obbligatorio', 3);
    if (_cittaResidenzaCtrl.text.isEmpty) addError('cittaResidenza', 'Campo obbligatorio', 3);
    
    if (_provResidenzaCtrl.text.isEmpty) 
    {
      addError('provResidenza', 'Campo obbligatorio', 3);
    } 
    else if (!RegExp(r'^[A-Z]{2}$').hasMatch(_provResidenzaCtrl.text)) 
    {
      addError('provResidenza', 'Inserire 2 lettere (es. VI)', 3);
    }
    
    if (_capCtrl.text.isEmpty) 
    {
      addError('cap', 'Campo obbligatorio', 3);
    } 
    else if (!RegExp(r'^\d{5}$').hasMatch(_capCtrl.text)) 
    {
      addError('cap', 'Deve contenere esattamente 5 numeri', 3);
    }

    if (_emailCtrl.text.isEmpty) 
    {
      addError('email', 'Campo obbligatorio', 4);
    } 
    else if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(_emailCtrl.text)) 
    {
      addError('email', 'Formato email non valido', 4);
    }

    if (_telefonoCtrl.text.isEmpty) 
    {
      addError('telefono', 'Campo obbligatorio', 4);
    } 
    else if (!RegExp(r'^\+?[0-9]+$').hasMatch(_telefonoCtrl.text)) 
    {
      addError('telefono', 'Formato telefono non valido', 4);
    }

    setState(() 
    {
      _formErrors = newErrors;
      if (!isValid && firstInvalidCard != null) 
      {
        _cardMovingForward    = firstInvalidCard! >= _currentFormCardIndex;
        _currentFormCardIndex = firstInvalidCard!;
      }
    });

    if (!isValid) 
    {
      CustomSnackBar.show(context: context, message: 'Ci sono errori nei dati inseriti. Correggi i campi.', isError: true);
    }

    return isValid;
  }

  bool _validateDatiSpecifici()
  {
    setState(()
    {
      _formErrors.clear();
      _scadenzaCertificatoCtrl.text      = _scadenzaCertificatoCtrl.text.trim();
      _tipoCorsoCtrl.text                = _tipoCorsoCtrl.text.trim();
      _ibanCtrl.text                     = _ibanCtrl.text.replaceAll(' ', '').toUpperCase();
      _altroRuoloAmministratoreCtrl.text = _altroRuoloAmministratoreCtrl.text.trim();
      _studiScolasticiCtrl.text          = _studiScolasticiCtrl.text.trim();
      _studiUniversitariCtrl.text        = _studiUniversitariCtrl.text.trim();
    });

    bool                isValid             = true;
    bool                showFutureYearError = false;
    int?                firstInvalidCard;
    Map<String, String> newErrors           = {};

    void addError(String field, String message, int targetCardLogicIndex)
    {
      newErrors[field] = message;
      isValid          = false;
      if (firstInvalidCard == null || targetCardLogicIndex < firstInvalidCard!)
      {
        firstInvalidCard = targetCardLogicIndex;
      }
    }

    final List<String> activeRoles = _selectedRoles.toList();
    final bool isOnlyGenitoreNotAssociato = activeRoles.length == 1 && activeRoles.contains('GENITORE') && !_genitoreIsAssociato;
    final bool isStaff = activeRoles.contains('AMMINISTRATORE') || 
                         activeRoles.contains('DOCENTE') || 
                         activeRoles.contains('PSICOLOGO');
    
    int currentMappedIndex = 0;

    if (!isOnlyGenitoreNotAssociato)
    {
      if (_enrollmentRows.isEmpty)
      {
        addError('enrollmentGeneral', 'Aggiungi almeno un\'iscrizione', currentMappedIndex);
      }
      for (int i = 0; i < _enrollmentRows.length; i++) 
      {
        final row = _enrollmentRows[i];
        bool yearValid = false;
        
        if (row.yearCtrl.text.trim().isEmpty) 
        {
          addError('enrollmentYear_$i', 'Campo obbligatorio', currentMappedIndex);
        } 
        else if (!RegExp(r'^\d{4}$').hasMatch(row.yearCtrl.text.trim())) 
        {
          addError('enrollmentYear_$i', 'Anno non valido', currentMappedIndex);
        }
        else
        {
          int parsedYear = int.parse(row.yearCtrl.text.trim());
          if (parsedYear > DateTime.now().year)
          {
            addError('enrollmentYear_$i', 'Anno non futuro', currentMappedIndex);
          }
          else
          {
            yearValid = true;
          }
        }
        
        if (row.dateCtrl.text.trim().isEmpty) 
        {
          addError('enrollmentDate_$i', 'Campo obbligatorio', currentMappedIndex);
        } 
        else if (yearValid && !_isValidDayMonthYear(row.dateCtrl.text.trim(), row.yearCtrl.text.trim())) 
        {
          addError('enrollmentDate_$i', 'Data non valida', currentMappedIndex);
        }
        else if (!yearValid && !RegExp(r'^\d{2}/\d{2}$').hasMatch(row.dateCtrl.text.trim()))
        {
          addError('enrollmentDate_$i', 'Formato gg/mm', currentMappedIndex);
        }
      }
      currentMappedIndex++;
    }

    if (isStaff)
    {
      if (_ibanCtrl.text.isNotEmpty && !RegExp(r'^IT\d{2}[A-Z]\d{10}[A-Z0-9]{12}$').hasMatch(_ibanCtrl.text))
      {
        addError('iban', 'Formato IBAN italiano non valido', currentMappedIndex);
      }
      if (_tipoCollaborazione == null)
      {
        addError('tipoCollaborazione', 'Campo obbligatorio', currentMappedIndex);
      }
      currentMappedIndex++;
    }

    if (activeRoles.contains('AMMINISTRATORE'))
    {
      if (_ruoloAmministratore == null)
      {
        addError('ruoloAmministratore', 'Campo obbligatorio', currentMappedIndex);
      }
      else if (_ruoloAmministratore == 'Altro' && _altroRuoloAmministratoreCtrl.text.isEmpty)
      {
        addError('altroRuoloAmministratore', 'Specificare il ruolo', currentMappedIndex);
      }
      currentMappedIndex++;
    }

    if (activeRoles.contains('DOCENTE'))
    {
      currentMappedIndex++; 
    }

    if (activeRoles.contains('CORSISTA'))
    {
      if (_scadenzaCertificatoCtrl.text.isEmpty)
      {
        addError('scadenzaCertificato', 'Campo obbligatorio', currentMappedIndex);
      }
      else if (!_isValidDate(_scadenzaCertificatoCtrl.text))
      {
        addError('scadenzaCertificato', 'Formato data non valido', currentMappedIndex);
      }
      
      if (_tipoCorsoCtrl.text.isEmpty)
      {
        addError('tipoCorso', 'Campo obbligatorio', currentMappedIndex);
      }
      currentMappedIndex++;
    }
    
    if (activeRoles.contains('STUDENTE'))
    {
      if (_isMinor && _uscitaAnticipata == null) 
      {
        addError('uscitaAnticipata', 'Campo obbligatorio', currentMappedIndex);
      }
      if (_schoolRows.isEmpty) 
      {
        addError('schoolGeneral', 'Aggiungi almeno un anno scolastico', currentMappedIndex);
      }

      final Set<int> distinctYears = {};
      for (int i = 0; i < _schoolRows.length; i++) 
      {
        final r = _schoolRows[i];

        if (r.yearCtrl.text.trim().isEmpty) 
        {
          addError('schoolYear_$i', 'Obbligatorio', currentMappedIndex);
        } 
        else if (!RegExp(r'^\d{4}$').hasMatch(r.yearCtrl.text.trim())) 
        {
          addError('schoolYear_$i', 'Anno non valido', currentMappedIndex);
        } 
        else 
        {
          int parsedYear = int.parse(r.yearCtrl.text.trim());
          if (parsedYear > _getCurrentSchoolYearStart()) 
          {
            addError('schoolYear_$i', 'Anno futuro non permesso', currentMappedIndex);
            showFutureYearError = true;
          } 
          else if (distinctYears.contains(parsedYear)) 
          {
            addError('schoolYear_$i', 'Duplicato', currentMappedIndex);
          } 
          else 
          {
            distinctYears.add(parsedYear);
          }
        }

        if (r.selectedSchool == null) addError('schoolName_$i', 'Obbligatorio', currentMappedIndex);
        if (r.selectedProgram == null) addError('schoolProgram_$i', 'Obbligatorio', currentMappedIndex);
        if (r.selectedGrade == null) addError('schoolGrade_$i', 'Obbligatorio', currentMappedIndex);
      }
      currentMappedIndex++;
    }

    setState(()
    {
      _formErrors = newErrors;
      if (!isValid && firstInvalidCard != null)
      {
        _card4MovingForward    = firstInvalidCard! >= _currentStep4CardIndex;
        _currentStep4CardIndex = firstInvalidCard!;
      }
    });

    if (!isValid)
    {
      if (showFutureYearError)
      {
        CustomSnackBar.show(context: context, message: 'Non è possibile inserire anni scolastici futuri.', isError: true);
      }
      else
      {
        CustomSnackBar.show(context: context, message: 'Ci sono errori nelle informazioni associative. Correggi i campi.', isError: true);
      }
    }

    return isValid;
  }

  void _onSave() async 
  {
    setState(() => _isSubmitting = true);
    
    try 
    {
      final Set<String> finalRolesSet = _selectedRoles.where((r) => r != 'ASSOCIATO').toSet();
        
      if (_involvementType == 1) 
      {
          finalRolesSet.clear();
          finalRolesSet.add('ASSOCIATO');
      } 
      else 
      {
          if (finalRolesSet.any((r) => r != 'GENITORE')) 
          {
              finalRolesSet.add('ASSOCIATO');
          } 
          else if (_genitoreIsAssociato) 
          {
              finalRolesSet.add('ASSOCIATO');
          }
      }

      final List<String> finalRoles = finalRolesSet.toList();
      final bool isOnlyGenitoreNotAssociato = finalRoles.length == 1 && finalRoles.contains('GENITORE') && !_genitoreIsAssociato;

      List<Map<String, dynamic>> membershipsData = [];
      if (!isOnlyGenitoreNotAssociato) 
      {
        for (int i = 0; i < _enrollmentRows.length; i++) 
        {
          final row = _enrollmentRows[i];
          final parts   = row.dateCtrl.text.trim().split('/');
          final isoDate = '${row.yearCtrl.text.trim()}-${parts[1]}-${parts[0]}';
          
          final Map<String, dynamic> memMap = 
          {
            "year":                int.parse(row.yearCtrl.text.trim()),
            "start_date":          isoDate,
            "end_date":            "${row.yearCtrl.text.trim()}-12-31",
            "renewal_period_days": 30,
            "revocation":          "NO"
          };
          
          if (_enrollmentIds.length > i && _enrollmentIds[i] != null) 
          {
            memMap["id"] = _enrollmentIds[i];
          }
          
          membershipsData.add(memMap);
        }
      }

      Map<String, dynamic>? memberData;
      if (!isOnlyGenitoreNotAssociato && membershipsData.isNotEmpty) 
      {
        memberData = 
        {
          "collaborating_active": _involvementType == 0,
          "memberships":          membershipsData
        };
      }

      Map<String, dynamic>? staffData;
      Map<String, dynamic>? adminData;
      Map<String, dynamic>? teacherData;
      Map<String, dynamic>? courseParticipantData;
      Map<String, dynamic>? studentData;

      final isStaff = finalRoles.contains('AMMINISTRATORE') || 
                      finalRoles.contains('DOCENTE') || 
                      finalRoles.contains('PSICOLOGO');
                      
      if (isStaff) 
      {
        String collType = 'VOLUNTEER';
        if (_tipoCollaborazione == 'Retribuito') collType = 'PAID';
        if (_tipoCollaborazione == 'FSC (Ex PCT0)') collType = 'PCTO';

        staffData = 
        {
          "collaboration_type": collType,
          "iban":               _ibanCtrl.text.isNotEmpty ? _ibanCtrl.text.trim().toUpperCase() : null,
        };
      }

      if (finalRoles.contains('AMMINISTRATORE')) 
      {
        String adminRole = 'OTHER';
        if (_ruoloAmministratore == 'Presidente') adminRole = 'PRESIDENT';
        if (_ruoloAmministratore == 'Vicepresidente') adminRole = 'VICE_PRESIDENT';
        if (_ruoloAmministratore == 'Tesoriere') adminRole = 'TREASURER';

        adminData = 
        {
          "role":       adminRole,
          "other_role": adminRole == 'OTHER' ? _altroRuoloAmministratoreCtrl.text.trim() : null,
        };
      }

      if (finalRoles.contains('DOCENTE')) 
      {
        teacherData = 
        {
          "school_education":     _studiScolasticiCtrl.text.isNotEmpty ? _studiScolasticiCtrl.text.trim() : null,
          "university_education": _studiUniversitariCtrl.text.isNotEmpty ? _studiUniversitariCtrl.text.trim() : null,
          "competences":          _subjectToggles.entries
              .where((e) => e.value) 
              .map((e) => 
              {
                "subject_id":        e.key,
                "study_program_ids": _selectedProgramsForSubject[e.key]?.toList() ?? [],
              })
              .toList(),
        };
      }

      if (finalRoles.contains('CORSISTA')) 
      {
        courseParticipantData = 
        {
          "medical_certificate_expiration": _scadenzaCertificatoCtrl.text.isNotEmpty ? _scadenzaCertificatoCtrl.text.trim().split('/').reversed.join('-') : null,
          "course_type":                    _tipoCorsoCtrl.text.trim(),
        };
      }

      if (finalRoles.contains('STUDENTE')) 
      {
        studentData = 
        {
          "authorized_early_exit":      _isMinor ? (_uscitaAnticipata == 'Sì') : true,
          "school_mechanographic_code": _schoolRows.isNotEmpty ? _schoolRows.first.selectedSchool!.mechanographicCode : '',
          "study_program_id":           _schoolRows.isNotEmpty ? _schoolRows.first.selectedProgram!.id : 0,
          "school_class":               _schoolRows.isNotEmpty ? _schoolRows.first.selectedGrade! : '',
        };
      }

      final payload = 
      {
        "general_data": 
        {
          "first_name":              _nomeCtrl.text.trim(),
          "last_name":               _cognomeCtrl.text.trim(),
          "tax_code":                _cfCtrl.text.trim().toUpperCase(),
          "gender":                  _sesso,
          "birth_date":              _toIsoDate(_dataNascitaCtrl.text.trim()),
          "birth_city":              _cittaNascitaCtrl.text.trim(),
          "birth_province":          _provNascitaCtrl.text.trim().toUpperCase(),
          "residence_type":          _tipoViaCtrl.text.trim(),
          "residence_address":       _indirizzoNomeCtrl.text.trim(),
          "residence_street_number": _civicoCtrl.text.trim(),
          "residence_city":          _cittaResidenzaCtrl.text.trim(),
          "residence_province":      _provResidenzaCtrl.text.trim().toUpperCase(),
          "postal_code":             _capCtrl.text.trim(),
          "email":                   _emailCtrl.text.trim(),
          "phone":                   _telefonoCtrl.text.replaceAll(' ', ''),
        },
        "roles":                   finalRoles,
        "member_data":             memberData,
        "staff_data":              staffData,
        "admin_data":              adminData,
        "teacher_data":            teacherData,
        "course_participant_data": courseParticipantData,
        "student_data":            studentData,
        "relationships": 
        {
          "minors_tax_codes":  _selectedMinors.toList(),
          "parents_tax_codes": _selectedParents.toList(),
        }
      };

      final newFiscalCode = await ApiService().updatePerson
      (
        widget.person.fiscalCode,
        payload,
        imageBytes: _fotoProfilo,
      );

      //UpdateAllSchoolEnrollments
      if (finalRoles.contains('STUDENTE') && _schoolRows.isNotEmpty)
      {
        List<Map<String, dynamic>> payloadEnrollments = [];
        for (var r in _schoolRows)
        {
          payloadEnrollments.add(
          {
            "start_year":                 int.parse(r.yearCtrl.text.trim()),
            "school_mechanographic_code": r.selectedSchool!.mechanographicCode,
            "study_program_id":           r.selectedProgram!.id,
            "grade":                      _romanToNumeric(r.selectedGrade!),
          });
        }
        await ApiService().updatePersonSchoolEnrollments(newFiscalCode, payloadEnrollments);
      }

      if (mounted) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: 'Anagrafica aggiornata con successo!', 
          isError: false,
        );
        Navigator.of(context).pop(newFiscalCode);
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: e.toString().replaceAll('Exception: ', ''), 
          isError: true,
        );
      }
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openProgramsDialog(AssociationSubjectItem subject) 
  {
    final programs = _getProgramsForSubject(subject);
    
    showGeneralDialog
    (
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'ProgramsSelection', 
      barrierColor:       Colors.black.withValues(alpha: .15), 
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter
        (
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child:  FadeTransition
          (
            opacity: animation,
            child:   ScaleTransition
            (
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: WizardProgramsSelectionDialog
              (
                subject:         subject,
                programs:        programs,
                initialSelected: _selectedProgramsForSubject[subject.id] ?? {},
                onSave:          (selected) 
                {
                  setState(() 
                  {
                    if (selected.isEmpty) 
                    {
                      _subjectToggles[subject.id] = false;
                      _selectedProgramsForSubject.remove(subject.id);
                    } 
                    else 
                    {
                      _subjectToggles[subject.id] = true;
                      _selectedProgramsForSubject[subject.id] = selected;
                    }
                  });
                },
                onCancel: ()
                {
                  setState(() 
                  {
                    if (!(_subjectToggles[subject.id] ?? false))
                    {
                      _subjectToggles[subject.id] = false;
                      _selectedProgramsForSubject.remove(subject.id);
                    }
                  });
                }
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCancelConfirmation() 
  {
    showDialog
    (
      context: context,
      builder: (BuildContext confirmContext) 
      {
        return AlertDialog
        (
          backgroundColor: Colors.white,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:           Text
          (
            'Annulla Modifiche', 
            style: GoogleFonts.plusJakartaSans
            (
              fontWeight: FontWeight.w700, 
              color:      const Color(0xFF003C82),
            ),
          ),
          content: Text
          (
            'Sei sicuro di voler uscire? Le modifiche non salvate andranno perse.', 
            style: GoogleFonts.plusJakartaSans(fontSize: 16),
          ),
          actions: 
          [
            TextButton
            (
              style: ButtonStyle
              (
                overlayColor:    WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.resolveWith((states) => const Color(0xFF8A8A8A)),
              ),
              onPressed: () => Navigator.pop(confirmContext), 
              child:     Text
              (
                'RIPRENDI', 
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton
            (
              style: ButtonStyle
              (
                overlayColor:    WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFE53935)),
              ),
              onPressed: () 
              {
                Navigator.pop(confirmContext);
                Navigator.of(context).pop();
              }, 
              child: Text
              (
                'ESCI SENZA SALVARE', 
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onNext() 
  {
      if (_currentStep == 0) 
      {
          if (_involvementType == -1) 
          {
              CustomSnackBar.show(context: context, message: 'Seleziona una categoria per continuare.', isError: true);
              return;
          }
          
          if (_involvementType == 1) 
          {
              _selectedRoles.clear(); 
              setState(() 
              {
                  _movingForward        = true;
                  _currentStep          = 3;
                  _cardMovingForward    = true;
                  _currentFormCardIndex = 0;
              });
          } 
          else 
          {
              setState(() 
              {
                  _movingForward = true;
                  _currentStep   = 1;
              });
          }
          return;
      }

      if (_currentStep == 1) 
      {
          if (!_validateRoles()) return;
          
          bool requiresAdult = _selectedRoles.contains('GENITORE') || 
                               _selectedRoles.contains('PSICOLOGO') || 
                               _selectedRoles.contains('AMMINISTRATORE');
          if (requiresAdult && _isMinor) 
          {
              CustomSnackBar.show(context: context, message: 'I ruoli Genitore, Psicologo e Amministratore richiedono la maggiore età.', isError: true);
              return;
          }

          final activeRoles = _selectedRoles.where((r) => r != 'ASSOCIATO').toList();

          if (activeRoles.length == 1 && activeRoles.contains('GENITORE') && !_wasAssociato) 
          {
              setState(() 
              {
                  _movingForward = true;
                  _currentStep   = 2;
              });
          } 
          else 
          {
              _genitoreIsAssociato = true;
              setState(() 
              {
                  _movingForward        = true;
                  _currentStep          = 3;
                  _cardMovingForward    = true;
                  _currentFormCardIndex = 0;
              });
          }
          return;
      }

      if (_currentStep == 2) 
      {
          setState(() 
          {
              _movingForward        = true;
              _currentStep          = 3;
              _cardMovingForward    = true;
              _currentFormCardIndex = 0;
          });
          return;
      }
      
      if (_currentStep == 3) 
      {
          if (!_validateDatiGenerali()) return;

          if (_activeStep4Cards.isEmpty) 
          {
              if (_isMinor) 
              {
                  setState(() { _movingForward = true; _currentStep = 5; });
              } 
              else if (_selectedRoles.contains('GENITORE')) 
              {
                  setState(() { _movingForward = true; _currentStep = 6; });
              } 
              else if (_selectedRoles.contains('DOCENTE')) 
              {
                  setState(() { _movingForward = true; _currentStep = 7; });
              } 
              else 
              {
                  _onSave();
              }
          } 
          else 
          {
              setState(() 
              {
                  _movingForward         = true;
                  _currentStep           = 4;
                  _card4MovingForward    = true;
                  _currentStep4CardIndex = 0;
              });
          }
          return;
      }
      
      if (_currentStep == 4) 
      {
          if (!_validateDatiSpecifici()) return;
          
          if (_isMinor) 
          {
              setState(() { _movingForward = true; _currentStep = 5; });
          } 
          else if (_selectedRoles.contains('GENITORE')) 
          {
              setState(() { _movingForward = true; _currentStep = 6; });
          } 
          else if (_selectedRoles.contains('DOCENTE')) 
          {
              setState(() { _movingForward = true; _currentStep = 7; });
          } 
          else 
          {
              _onSave();
          }
          return;
      }
      
      if (_currentStep == 5) 
      {
          if (_selectedParents.isEmpty || _selectedParents.length > 2) 
          {
              CustomSnackBar.show(context: context, message: 'Seleziona 1 o 2 genitori/tutori per il minore.', isError: true);
              return;
          }
          
          if (_selectedRoles.contains('DOCENTE')) 
          {
              setState(() { _movingForward = true; _currentStep = 7; });
          } 
          else 
          {
              _onSave();
          }
          return;
      }
      
      if (_currentStep == 6) 
      {
          if (widget.person.children != null) 
          {
            for (final child in widget.person.children!) 
            {
              if (!_selectedMinors.contains(child.fiscalCode)) 
              {
                final minorIterable = _allMinors.where((m) => m.fiscalCode == child.fiscalCode);
                if (minorIterable.isNotEmpty) 
                {
                  final minorData = minorIterable.first;
                  if (minorData.parents != null) 
                  {
                    final otherParents = minorData.parents!.where((p) => p.fiscalCode != widget.person.fiscalCode).toList();
                    if (otherParents.isEmpty) 
                    {
                      CustomSnackBar.show
                      (
                        context: context, 
                        message: 'Impossibile rimuovere il figlio: ${minorData.firstName} ${minorData.lastName} rimarrebbe senza genitori.', 
                        isError: true,
                      );
                      return;
                    }
                  }
                }
              }
            }
          }

          for (final minorId in _selectedMinors) 
          {
            final minorIterable = _allMinors.where((m) => m.fiscalCode == minorId);
            if (minorIterable.isNotEmpty) 
            {
              final minorData    = minorIterable.first;
              final otherParents = minorData.parents?.where((p) => p.fiscalCode != widget.person.fiscalCode).toList() ?? [];

              if (otherParents.length >= 2) 
              {
                CustomSnackBar.show
                (
                  context: context, 
                  message: 'Impossibile aggiungere ${minorData.firstName} ${minorData.lastName}: ha già due genitori associati.', 
                  isError: true,
                );
                return;
              }
            }
          }

          if (_selectedRoles.contains('DOCENTE')) 
          {
              setState(() { _movingForward = true; _currentStep = 7; });
          } 
          else 
          {
              _onSave();
          }
          return;
      }
      
      if (_currentStep == 7) 
      {
          bool hasAtLeastOneSubject = _subjectToggles.values.any((isSelected) => isSelected == true);
          if (!hasAtLeastOneSubject) 
          {
              CustomSnackBar.show(context: context, message: 'Seleziona almeno una disciplina insegnata per procedere.', isError: true);
              return;
          }
          _onSave();
          return;
      }
  }

  void _onBack() 
  {
      setState(() => _movingForward = false);

      if (_currentStep == 7) 
      {
          if (_selectedRoles.contains('GENITORE')) 
          {
              setState(() => _currentStep = 6);
          } 
          else if (_isMinor) 
          {
              setState(() => _currentStep = 5);
          } 
          else 
          {
              setState(() => _currentStep = _activeStep4Cards.isEmpty ? 3 : 4);
          }
      } 
      else if (_currentStep == 6) 
      {
          if (_isMinor) 
          {
              setState(() => _currentStep = 5);
          } 
          else 
          {
              setState(() => _currentStep = _activeStep4Cards.isEmpty ? 3 : 4);
          }
      } 
      else if (_currentStep == 5) 
      {
          setState(() => _currentStep = _activeStep4Cards.isEmpty ? 3 : 4);
      } 
      else if (_currentStep == 4) 
      {
          setState(() => _currentStep = 3);
      } 
      else if (_currentStep == 3) 
      {
          final activeRoles = _selectedRoles.where((r) => r != 'ASSOCIATO').toList();

          if (_involvementType == 1) 
          {
              setState(() => _currentStep = 0);
          } 
          else if (activeRoles.length == 1 && activeRoles.contains('GENITORE') && !_wasAssociato) 
          {
              setState(() => _currentStep = 2);
          } 
          else 
          {
              setState(() => _currentStep = 1);
          }
      } 
      else if (_currentStep == 2) 
      {
          setState(() => _currentStep = 1);
      } 
      else if (_currentStep == 1) 
      {
          setState(() => _currentStep = 0);
      }
  }

  void _openReportDialog() 
  {
    showGeneralDialog
    (
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'ReportError', 
      barrierColor:       Colors.black.withValues(alpha: .3), 
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child) 
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter
        (
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child:  FadeTransition
          (
            opacity: animation,
            child:   ScaleTransition
            (
              scale: CurvedAnimation
              (
                parent:       animation, 
                curve:        Curves.easeOutBack, 
                reverseCurve: Curves.easeIn,
              ),
              child: _ReportErrorDialog(person: widget.person),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepWidget(int step) 
  {
    if (step == 0) return _buildStep0Type();
    if (step == 1) return _buildStep1Roles();
    if (step == 2) return _buildStep2Association();
    if (step == 3) return _buildStep3DatiGenerali();
    if (step == 4) return _buildStep4DatiSpecifici();
    if (step == 5) return _buildStep5Parents();
    if (step == 6) return _buildStep6Minors();
    if (step == 7) return _buildStep7Discipline();
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) 
  {
    final bool isLastStep;
    if (_currentStep == 7) 
    {
      isLastStep = true;
    } 
    else if (_currentStep == 6 && !_selectedRoles.contains('DOCENTE')) 
    {
      isLastStep = true;
    } 
    else if (_currentStep == 5 && !_selectedRoles.contains('DOCENTE') && !_selectedRoles.contains('GENITORE')) 
    {
      isLastStep = true;
    } 
    else if (_currentStep == 4 && !_isMinor && !_selectedRoles.contains('GENITORE') && !_selectedRoles.contains('DOCENTE')) 
    {
      isLastStep = true;
    } 
    else if (_currentStep == 3 && _activeStep4Cards.isEmpty && !_isMinor && !_selectedRoles.contains('GENITORE') && !_selectedRoles.contains('DOCENTE')) 
    {
      isLastStep = true;
    } 
    else 
    {
      isLastStep = false;
    }

    return Dialog
    (
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container
      (
        width:       MediaQuery.of(context).size.width * 0.85,
        height:      MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration
        (
          color:        const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(40),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x26000000),
              offset:     Offset(0, 12),
              blurRadius: 36,
            )
          ],
        ),
        child: ClipRRect
        (
          borderRadius: BorderRadius.circular(40),
          child: Stack
          (
            children: 
            [
              Positioned
              (
                right: -400, 
                top:   -400,
                child: IgnorePointer
                (
                  child: Container
                  (
                    width:  800, 
                    height: 800,
                    decoration: const BoxDecoration
                    (
                      shape:    BoxShape.circle,
                      gradient: RadialGradient
                      (
                        colors: [Color(0x22003C82), Color(0x00003C82)], 
                        stops:  [0.0, 1.0]
                      ),
                    ),
                  ),
                ),
              ),
              Positioned
              (
                left:   -400, 
                bottom: -400,
                child: IgnorePointer
                (
                  child: Container
                  (
                    width:  800, 
                    height: 800,
                    decoration: const BoxDecoration
                    (
                      shape:    BoxShape.circle,
                      gradient: RadialGradient
                      (
                        colors: [Color(0x22003C82), Color(0x00003C82)], 
                        stops:  [0.0, 1.0]
                      ),
                    ),
                  ),
                ),
              ),
              Column
              (
                children: 
                [
                  Padding
                  (
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
                    child: Row
                    (
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: 
                      [
                        Text
                        (
                          'Modifica Anagrafica',
                          style: GoogleFonts.plusJakartaSans
                          (
                            fontSize:   26, 
                            fontWeight: FontWeight.w700, 
                            color:      const Color(0xFF003C82),
                          ),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
                  Expanded
                  (
                    child: Padding
                    (
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AnimatedSwitcher
                      (
                        duration:       const Duration(milliseconds: 300),
                        switchInCurve:  Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder:  (currentChild, previousChildren) => Stack(alignment: Alignment.center, children: [...previousChildren, if (currentChild != null) currentChild]),
                        transitionBuilder: (child, animation) 
                        {
                          final isEntering   = (child.key as ValueKey<String>).value == 'step${_currentStep}_e';
                          Offset beginOffset = _movingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                          
                          return FadeTransition
                          (
                            opacity: animation, 
                            child:   SlideTransition
                            (
                              position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), 
                              child:    child
                            ),
                          );
                        },
                        child: KeyedSubtree
                        (
                          key:   ValueKey('step${_currentStep}_e'),
                          child: _buildStepWidget(_currentStep),
                        ),
                      ),
                    ),
                  ),
                  Padding
                  (
                    padding: const EdgeInsets.only(top: 16, bottom: 32),
                    //StacksVerticallyWhenTheDialogIsTooNarrowForBothFixedWidthButtonsSideBySide
                    child: _ResponsiveWizardBottomBar
                    (
                      secondaryButton: _currentStep == 0
                          ? WizardAnimatedActionButton
                            (
                              text:       'ANNULLA', 
                              icon:       Icons.close_rounded, 
                              baseColor:  const Color(0xFFE53935), 
                              hoverColor: const Color(0xFFEF5350), 
                              onPressed:  _showCancelConfirmation,
                            )
                          : WizardOutlinedActionButton
                            (
                              text:      'INDIETRO', 
                              icon:      Icons.arrow_back_rounded, 
                              onPressed: _onBack
                            ),
                      primaryButton: WizardAnimatedActionButton
                      (
                        text:       _isSubmitting ? 'SALVATAGGIO...' : (isLastStep ? 'SALVA MODIFICHE' : 'AVANTI'), 
                        icon:       isLastStep ? Icons.check_circle_outline : Icons.arrow_forward_rounded, 
                        baseColor:  const Color(0xFF003C82), 
                        hoverColor: const Color(0xFF004D99), 
                        onPressed:  _isSubmitting ? () {} : _onNext,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0Type() 
  {
    return SizedBox
    (
      key:   const ValueKey('step0_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.center,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text
                (
                  'Qual è il rapporto di questa persona con l\'Associazione?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 8),
                Text
                (
                  'Scegli la categoria che descrive meglio la sua posizione.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded
          (
            child: Center
            (
              child: SingleChildScrollView
              (
                child: Wrap
                (
                  spacing:    32,
                  runSpacing: 32,
                  alignment:  WrapAlignment.center,
                  children: 
                  [
                    WizardSelectionCard
                    (
                      title:      'Coinvolto nelle attività', 
                      subtitle:   'Partecipa alla vita dell\'Associazione, svolge uno o più ruoli oppure è un genitore.', 
                      icon:       Icons.workspaces_outline, 
                      isSelected: _involvementType == 0, 
                      onTap:      () => setState(() => _involvementType = 0),
                    ),
                    WizardSelectionCard
                    (
                      title:      'Solo Socio', 
                      subtitle:   'Paga regolarmente la quota di iscrizione per sostenere l\'Associazione, ma non ricopre alcun ruolo.', 
                      icon:       Icons.card_membership_rounded, 
                      isSelected: _involvementType == 1, 
                      onTap:      () => setState(() => _involvementType = 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Roles() 
  {
    return SizedBox
    (
      key:   const ValueKey('step1_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.center,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text
                (
                  'Modifica Ruoli',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 8),
                Text
                (
                  'Aggiorna i ruoli ricoperti dalla persona all\'interno dell\'Associazione.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded
          (
            child: Center
            (
              child: SingleChildScrollView
              (
                child: ConstrainedBox
                (
                  constraints: const BoxConstraints(maxWidth: 1150),
                  child: Wrap
                  (
                    spacing:    24,
                    runSpacing: 24,
                    alignment:  WrapAlignment.center,
                    children: _availableRoles.map((role) 
                    {
                      final isSelected = _selectedRoles.contains(role['id']);
                      return SizedBox
                      (
                        width: 350,
                        child: WizardSelectionCard
                        (
                          title:      role['label'], 
                          subtitle:   role['desc'], 
                          icon:       role['icon'], 
                          isSelected: isSelected, 
                          onTap:      () => setState(() => isSelected ? _selectedRoles.remove(role['id']) : _selectedRoles.add(role['id'])),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Association() 
  {
    return SizedBox
    (
      key:   const ValueKey('step2_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.center,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text
                (
                  'Iscrizione all\'Associazione',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 8),
                Text
                (
                  'Il genitore può iscrivere il proprio figlio senza diventare socio. Scegli se desidera aderire anche personalmente.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded
          (
            child: Center
            (
              child: SingleChildScrollView
              (
                child: Wrap
                (
                  spacing:    32,
                  runSpacing: 32,
                  alignment:  WrapAlignment.center,
                  children: 
                  [
                    WizardSelectionCard
                    (
                      title:      'Sì', 
                      subtitle:   'Il genitore aderisce all\'Associazione e versa la quota annuale.', 
                      icon:       Icons.person_outlined, 
                      isSelected: _genitoreIsAssociato == true, 
                      onTap:      () => setState(() => _genitoreIsAssociato = true),
                    ),
                    WizardSelectionCard
                    (
                      title:      'No', 
                      subtitle:   'Il genitore viene registrato solo come tutore del minore.', 
                      icon:       Icons.person_off_outlined, 
                      isSelected: _genitoreIsAssociato == false, 
                      onTap:      () => setState(() => _genitoreIsAssociato = false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3DatiGenerali() 
  {
    Widget currentCard = const SizedBox.shrink();

    switch (_currentFormCardIndex) 
    {
      case 0:
        currentCard = WizardFormSectionCard
        (
          title:       'Protezione Dati',
          leadingIcon: const WizardStaticAvatar(icon: Icons.security_rounded),
          children: 
          [
            Text
            (
              'Per motivi di sicurezza e per garantire la coerenza dei dati, le informazioni personali principali (nome, cognome, sesso, codice fiscale, data di nascita, città di nascita, provincia di nascita) non possono essere modificate manualmente.\n\nSe hai riscontrato un errore, puoi richiederne la correzione utilizzando il pulsante qui sotto.',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 32),
            WizardOutlinedActionButton(text: 'SEGNALA ERRORE ANAGRAFICA', icon: Icons.report_problem_outlined, onPressed: _openReportDialog),
          ],
        );
        break;
      case 1:
        currentCard = WizardFormSectionCard
        (
          title:       'Identità',
          leadingIcon: const WizardStaticAvatar(icon: Icons.badge_outlined),
          children: 
          [
            WizardFormInputRow
            (
              label:       'Foto profilo',
              inputWidget: WizardProfilePhotoUploader(imageBytes: _fotoProfilo, initialImageUrl: widget.person.profileImageUrl, onImagePicked: (bytes) => setState(() => _fotoProfilo = bytes)),
            ),
            const SizedBox(height: 24),
            WizardFormInputRow(label: 'Nome', inputWidget: WizardAnimatedTextField(controller: _nomeCtrl, hint: 'Es. Mario', enabled: false, errorText: _formErrors['nome'], onChanged: (_) => setState(() => _formErrors.remove('nome')))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Cognome', inputWidget: WizardAnimatedTextField(controller: _cognomeCtrl, hint: 'Es. Rossi', enabled: false, errorText: _formErrors['cognome'], onChanged: (_) => setState(() => _formErrors.remove('cognome')))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Sesso', inputWidget: WizardAnimatedOverlayDropdown(value: _sesso, items: const ['M', 'F'], hint: 'Seleziona', enabled: false, errorText: _formErrors['sesso'], onChanged: (val) => setState(() { _sesso = val; _formErrors.remove('sesso'); }))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Codice fiscale', inputWidget: WizardAnimatedTextField(controller: _cfCtrl, hint: 'Es. RSSMRA80A01L157H', enabled: false, errorText: _formErrors['cf'], onChanged: (_) => setState(() => _formErrors.remove('cf')))),
          ],
        );
        break;
      case 2:
        currentCard = WizardFormSectionCard
        (
          title:       'Dati anagrafici',
          leadingIcon: const WizardStaticAvatar(icon: Icons.cake_rounded),
          children: 
          [
            WizardFormInputRow(label: 'Data di nascita', inputWidget: WizardAnimatedTextField(controller: _dataNascitaCtrl, hint: 'gg/mm/aaaa', enabled: false, errorText: _formErrors['dataNascita'], onChanged: (_) => setState(() => _formErrors.remove('dataNascita')))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Città di nascita', inputWidget: WizardAnimatedTextField(controller: _cittaNascitaCtrl, hint: 'Es. Thiene', enabled: false, errorText: _formErrors['cittaNascita'], onChanged: (_) => setState(() => _formErrors.remove('cittaNascita')))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Provincia', inputWidget: WizardAnimatedTextField(controller: _provNascitaCtrl, hint: 'Es. VI', enabled: false, errorText: _formErrors['provNascita'], onChanged: (_) => setState(() => _formErrors.remove('provNascita')))),
          ],
        );
        break;
      case 3:
        currentCard = WizardFormSectionCard
        (
          title:       'Residenza',
          leadingIcon: const WizardStaticAvatar(icon: Icons.home_rounded),
          children: 
          [
            WizardFormInputRow
            (
              label:       'Indirizzo',
              //StessoCriterioResponsivoDiPersonWizardPage_ImpilaSottoSoglia
              inputWidget: _WizardAddressFieldsRow
              (
                tipoViaCtrl:      _tipoViaCtrl,
                tipoViaError:     _formErrors['tipoVia'],
                onTipoViaChanged: (_) => setState(() => _formErrors.remove('tipoVia')),
                nomeCtrl:         _indirizzoNomeCtrl,
                nomeError:        _formErrors['indirizzoNome'],
                onNomeChanged:    (_) => setState(() => _formErrors.remove('indirizzoNome')),
                civicoCtrl:       _civicoCtrl,
                civicoError:      _formErrors['civico'],
                onCivicoChanged:  (_) => setState(() => _formErrors.remove('civico')),
              ),
            ),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Città', inputWidget: WizardAnimatedTextField(controller: _cittaResidenzaCtrl, hint: 'Es. Thiene', errorText: _formErrors['cittaResidenza'], onChanged: (_) => setState(() => _formErrors.remove('cittaResidenza')))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Provincia', inputWidget: WizardAnimatedTextField(controller: _provResidenzaCtrl, hint: 'Es. VI', errorText: _formErrors['provResidenza'], onChanged: (_) => setState(() => _formErrors.remove('provResidenza')))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'CAP', inputWidget: WizardAnimatedTextField(controller: _capCtrl, hint: 'Es. 36016', keyboardType: TextInputType.number, errorText: _formErrors['cap'], onChanged: (_) => setState(() => _formErrors.remove('cap')))),
          ],
        );
        break;
      case 4:
        currentCard = WizardFormSectionCard
        (
          title:       'Contatti',
          leadingIcon: const WizardStaticAvatar(icon: Icons.alternate_email_rounded),
          children: 
          [
            WizardFormInputRow(label: 'Email', inputWidget: WizardAnimatedTextField(controller: _emailCtrl, hint: 'Es. mario.rossi@email.com', keyboardType: TextInputType.emailAddress, errorText: _formErrors['email'], onChanged: (_) => setState(() => _formErrors.remove('email')))),
            const SizedBox(height: 16),
            WizardFormInputRow(label: 'Telefono', inputWidget: WizardAnimatedTextField(controller: _telefonoCtrl, hint: 'Es. 3331234567', keyboardType: TextInputType.phone, errorText: _formErrors['telefono'], onChanged: (_) => setState(() => _formErrors.remove('telefono')))),
          ],
        );
        break;
    }

    return SizedBox
    (
      key:   const ValueKey('step3_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.center,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text('Informazioni personali', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                const SizedBox(height: 8),
                Text('Modifica i dati anagrafici e di contatto.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded
          (
            child: LayoutBuilder
            (
              builder: (context, constraints)
              {
                final bool isCompact = constraints.maxWidth < 900;

                final Widget desktopAnimatedCard = AnimatedSwitcher
                (
                  duration:       const Duration(milliseconds: 300),
                  switchInCurve:  Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder:  (currentChild, previousChildren) => Stack(alignment: Alignment.center, children: [...previousChildren, if (currentChild != null) currentChild]),
                  transitionBuilder: (child, animation) 
                  {
                    final isEntering   = (child.key as ValueKey<int>).value == _currentFormCardIndex;
                    Offset beginOffset = _cardMovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                    return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                  },
                  child: KeyedSubtree(key: ValueKey(_currentFormCardIndex), child: currentCard),
                );

                final Widget compactAnimatedCard = AnimatedSwitcher
                (
                  duration:       const Duration(milliseconds: 300),
                  switchInCurve:  Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder:  (currentChild, previousChildren) => Stack(alignment: Alignment.topCenter, children: [...previousChildren, if (currentChild != null) currentChild]),
                  transitionBuilder: (child, animation) 
                  {
                    final isEntering   = (child.key as ValueKey<int>).value == _currentFormCardIndex;
                    Offset beginOffset = _cardMovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                    return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                  },
                  child: KeyedSubtree
                  (
                    key:   ValueKey(_currentFormCardIndex),
                    //NoFixedHeightAnymore_TakesWhateverHeightTheOuterExpandedGivesIt
                    child: SizedBox
                    (
                      width:  constraints.maxWidth,
                      child:  SingleChildScrollView(child: currentCard),
                    ),
                  ),
                );

                return isCompact
                    ? Column
                      (
                        children: 
                        [
                          //ExpandedGivesTheCardExactlyTheResidualHeight_NoFragileFixedConstantAnymore
                          Expanded
                          (
                            child: SizedBox(width: constraints.maxWidth, child: compactAnimatedCard),
                          ),
                          const SizedBox(height: 24),
                          Row
                          (
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: 
                            [
                              WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentFormCardIndex == 0, onTap: () => setState(() { _cardMovingForward = false; _currentFormCardIndex--; })),
                              const SizedBox(width: 24),
                              WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentFormCardIndex == 4, onTap: () => setState(() { _cardMovingForward = true; _currentFormCardIndex++; })),
                            ],
                          ),
                        ],
                      )
                    : Row
                      (
                        mainAxisAlignment:  MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: 
                        [
                          WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentFormCardIndex == 0, onTap: () => setState(() { _cardMovingForward = false; _currentFormCardIndex--; })),
                          const SizedBox(width: 32),
                          Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: desktopAnimatedCard)),
                          const SizedBox(width: 32),
                          WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentFormCardIndex == 4, onTap: () => setState(() { _cardMovingForward = true; _currentFormCardIndex++; })),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4DatiSpecifici()
  {
    final cards = _activeStep4Cards;
    
    if (_isLoadingData) 
    {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)));
    }

    final Widget currentCardStep4 = cards.isNotEmpty ? cards[_currentStep4CardIndex] : const SizedBox.shrink();

    return SizedBox
    (
      key: const ValueKey('step4_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.center,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text('Informazioni associative', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                const SizedBox(height: 8),
                Text('Compila i dati richiesti dai ruoli selezionati.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded
          (
            child: LayoutBuilder
            (
              builder: (context, constraints)
              {
                final bool isCompact = constraints.maxWidth < 900;

                final Widget desktopAnimatedCards = AnimatedSwitcher
                (
                  duration:           const Duration(milliseconds: 300),
                  switchInCurve:      Curves.easeOutCubic,
                  switchOutCurve:     Curves.easeInCubic,
                  layoutBuilder:      (currentChild, previousChildren) => Stack(alignment: Alignment.center, children: [...previousChildren, if (currentChild != null) currentChild]),
                  transitionBuilder:  (child, animation) 
                  {
                    final isEntering   = (child.key as ValueKey<int>).value == _currentStep4CardIndex;
                    Offset beginOffset = _card4MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                    return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                  },
                  child: KeyedSubtree(key: ValueKey(_currentStep4CardIndex), child: currentCardStep4),
                );

                final Widget compactAnimatedCards = AnimatedSwitcher
                (
                  duration:           const Duration(milliseconds: 300),
                  switchInCurve:      Curves.easeOutCubic,
                  switchOutCurve:     Curves.easeInCubic,
                  layoutBuilder:      (currentChild, previousChildren) => Stack(alignment: Alignment.topCenter, children: [...previousChildren, if (currentChild != null) currentChild]),
                  transitionBuilder:  (child, animation) 
                  {
                    final isEntering   = (child.key as ValueKey<int>).value == _currentStep4CardIndex;
                    Offset beginOffset = _card4MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                    return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                  },
                  child: KeyedSubtree
                  (
                    key:   ValueKey(_currentStep4CardIndex),
                    //NoFixedHeightAnymore_TakesWhateverHeightTheOuterExpandedGivesIt
                    child: SizedBox
                    (
                      width:  constraints.maxWidth,
                      child:  SingleChildScrollView(child: currentCardStep4),
                    ),
                  ),
                );

                return isCompact
                    ? Column
                      (
                        children: 
                        [
                          //ExpandedGivesTheCardExactlyTheResidualHeight_NoFragileFixedConstantAnymore
                          Expanded
                          (
                            child: SizedBox(width: constraints.maxWidth, child: compactAnimatedCards),
                          ),
                          const SizedBox(height: 24),
                          Row
                          (
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: 
                            [
                              WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentStep4CardIndex == 0, onTap: () => setState(() { _card4MovingForward = false; _currentStep4CardIndex--; })),
                              const SizedBox(width: 24),
                              WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentStep4CardIndex >= cards.length - 1, onTap: () => setState(() { _card4MovingForward = true; _currentStep4CardIndex++; })),
                            ],
                          ),
                        ],
                      )
                    : Row
                      (
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: 
                        [
                          WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentStep4CardIndex == 0, onTap: () => setState(() { _card4MovingForward = false; _currentStep4CardIndex--; })),
                          const SizedBox(width: 32),
                          Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: desktopAnimatedCards)),
                          const SizedBox(width: 32),
                          WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentStep4CardIndex >= cards.length - 1, onTap: () => setState(() { _card4MovingForward = true; _currentStep4CardIndex++; })),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCardIscrizione()
  {
    return WizardFormSectionCard
    (
      title:       'Iscrizioni Associative',
      leadingIcon: const WizardStaticAvatar(icon: Icons.assignment_ind_outlined),
      children: 
      [
        //StessoCriterioResponsivoDiPersonWizardPage_ImpilaSottoSoglia
        ...List.generate(_enrollmentRows.length, (index) 
        {
          final row = _enrollmentRows[index];
          return Padding
          (
            padding: const EdgeInsets.only(bottom: 16),
            child: _WizardEnrollmentFieldRow
            (
              yearCtrl:      row.yearCtrl,
              dateCtrl:      row.dateCtrl,
              yearError:     _formErrors['enrollmentYear_$index'],
              dateError:     _formErrors['enrollmentDate_$index'],
              onYearChanged: (_) => setState(() => _formErrors.remove('enrollmentYear_$index')),
              onDateChanged: (_) => setState(() => _formErrors.remove('enrollmentDate_$index')),
              onRemove:      index > 0
                  ? () 
                    {
                      setState(() 
                      {
                        _enrollmentRows[index].yearCtrl.dispose();
                        _enrollmentRows[index].dateCtrl.dispose();
                        _enrollmentRows.removeAt(index);
                        if (_enrollmentIds.length > index) 
                        {
                          _enrollmentIds.removeAt(index);
                        }
                        _formErrors.remove('enrollmentYear_$index');
                        _formErrors.remove('enrollmentDate_$index');
                      });
                    }
                  : null,
            ),
          );
        }),
        Align
        (
          alignment: Alignment.centerRight,
          child: WizardTextLinkButton
          (
            text:  'Aggiungi iscrizione',
            icon:  Icons.add_rounded,
            onTap: () 
            {
              int lastYear = DateTime.now().year;
              if (_enrollmentRows.isNotEmpty) 
              {
                lastYear = int.tryParse(_enrollmentRows.last.yearCtrl.text) ?? lastYear;
              }
              setState(() 
              {
                _enrollmentRows.add(WizardEnrollmentRowData
                (
                  yearCtrl: TextEditingController(text: (lastYear - 1).toString()),
                  dateCtrl: TextEditingController(),
                ));
                _enrollmentIds.add(null);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardStaff()
  {
    return WizardFormSectionCard
    (
      title:       'Dati Amministrativi',
      leadingIcon: const WizardStaticAvatar(icon: Icons.account_balance_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'IBAN',
          inputWidget: WizardAnimatedTextField
          (
            controller: _ibanCtrl, 
            hint:       'Es. IT00A...', 
            errorText:  _formErrors['iban'],
            onChanged:  (_) => setState(() => _formErrors.remove('iban')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Collaborazione',
          inputWidget: WizardAnimatedOverlayDropdown
          (
            value:     _tipoCollaborazione,
            items:     const ['Volontario', 'Retribuito', 'FSC (Ex PCT0)'],
            hint:      'Seleziona',
            errorText: _formErrors['tipoCollaborazione'],
            onChanged: (val) => setState(() 
            {
              _tipoCollaborazione = val;
              _formErrors.remove('tipoCollaborazione');
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardAmministratore()
  {
    return WizardFormSectionCard
    (
      title:       'Dettagli Amministratore',
      leadingIcon: const WizardStaticAvatar(icon: Icons.computer_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Ruolo',
          inputWidget: WizardAnimatedOverlayDropdown
          (
            value:     _ruoloAmministratore,
            items:     const ['Presidente', 'Vicepresidente', 'Tesoriere', 'Altro'],
            hint:      'Seleziona',
            errorText: _formErrors['ruoloAmministratore'],
            onChanged: (val) => setState(() 
            {
              _ruoloAmministratore = val;
              _formErrors.remove('ruoloAmministratore');
            }),
          ),
        ),
        if (_ruoloAmministratore == 'Altro') ...[
          const SizedBox(height: 16),
          WizardFormInputRow
          (
            label:       'Specifica ruolo',
            inputWidget: WizardAnimatedTextField
            (
              controller: _altroRuoloAmministratoreCtrl, 
              hint:       'Inserisci il ruolo', 
              errorText:  _formErrors['altroRuoloAmministratore'],
              onChanged:  (_) => setState(() => _formErrors.remove('altroRuoloAmministratore')),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildFormCardDocente()
  {
    return WizardFormSectionCard
    (
      title:       'Dettagli Docente',
      leadingIcon: const WizardStaticAvatar(icon: Icons.school_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Studi scolastici',
          inputWidget: WizardAnimatedTextField
          (
            controller: _studiScolasticiCtrl, 
            hint:       'Es. Liceo', 
            errorText:  _formErrors['studiScolastici'],
            onChanged:  (_) => setState(() => _formErrors.remove('studiScolastici')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Studi universitari',
          inputWidget: WizardAnimatedTextField
          (
            controller: _studiUniversitariCtrl, 
            hint:       'Es. Laurea', 
            errorText:  _formErrors['studiUniversitari'],
            onChanged:  (_) => setState(() => _formErrors.remove('studiUniversitari')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardCorsista()
  {
    return WizardFormSectionCard
    (
      title:       'Dettagli Corsista',
      leadingIcon: const WizardStaticAvatar(icon: Icons.self_improvement_rounded),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Scadenza certificato',
          inputWidget: WizardAnimatedTextField
          (
            controller:      _scadenzaCertificatoCtrl, 
            hint:            'gg/mm/aaaa', 
            keyboardType:    TextInputType.number,
            inputFormatters: [WizardDateInputFormatter()],
            errorText:       _formErrors['scadenzaCertificato'],
            onChanged:       (_) => setState(() => _formErrors.remove('scadenzaCertificato')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Tipo corso',
          inputWidget: WizardAnimatedTextField
          (
            controller: _tipoCorsoCtrl, 
            hint:       'Es. Pilates', 
            errorText:  _formErrors['tipoCorso'],
            onChanged:  (_) => setState(() => _formErrors.remove('tipoCorso')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardStudente()
  {
    return WizardFormSectionCard
    (
      title:       'Dettagli Studente',
      leadingIcon: const WizardStaticAvatar(icon: Icons.menu_book_outlined),
      children: 
      [
        if (_isMinor) ...[
          WizardFormInputRow
          (
            label:       'Uscita anticipata',
            inputWidget: WizardAnimatedOverlayDropdown
            (
              value:     _uscitaAnticipata,
              items:     const ['Sì', 'No'],
              hint:      'Seleziona',
              errorText: _formErrors['uscitaAnticipata'],
              onChanged: (val) => setState(() 
              {
                _uscitaAnticipata = val;
                _formErrors.remove('uscitaAnticipata');
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...List.generate(_schoolRows.length, (index)
        {
          final r = _schoolRows[index];
          final List<String> schoolNames = _allSchools.map((s) => '${s.name} (${s.city})').toList();
          
          List<String> programNames = [];
          List<String> gradeOptions = [];

          if (r.selectedSchool != null)
          {
            try 
            {
              dynamic progs;
              try { progs = (r.selectedSchool as dynamic).studyPrograms; } catch (_) {}
              if (progs == null) { try { progs = (r.selectedSchool as dynamic).study_programs; } catch (_) {} }
              
              if (progs != null && progs is Iterable) 
              {
                for (var p in progs) 
                {
                  String? pName = (p is Map) ? p['name'] as String? : (p as dynamic).name as String?;
                  if (pName != null && pName.isNotEmpty) 
                  {
                    if (_allPrograms.any((allP) => allP.name == pName) && !programNames.contains(pName)) 
                    {
                      programNames.add(pName);
                    }

                    if (r.selectedProgram != null && pName == r.selectedProgram!.name)
                    {
                      final globalProgram = _allPrograms.firstWhere((gp) => gp.id == r.selectedProgram!.id);
                      
                      const romanGrades = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI', 7: 'VII', 8: 'VIII'};
                      for (int j = globalProgram.minYear; j <= globalProgram.maxYear; j++) 
                      {
                        if (romanGrades.containsKey(j) && !gradeOptions.contains(romanGrades[j]!))
                        {
                          gradeOptions.add(romanGrades[j]!);
                        }
                      }
                    }
                  }
                }
              }
            } 
            catch (_) {}
          }

          if (r.selectedProgram != null && gradeOptions.isEmpty)
          {
            gradeOptions = ['I', 'II', 'III', 'IV', 'V'];
          }

          //StessoCriterioResponsivoDiPersonWizardPage_ImpilaSottoSoglia
          return _WizardSchoolFieldRow
          (
            yearCtrl:         r.yearCtrl,
            yearError:        _formErrors['schoolYear_$index'],
            onYearChanged:    (_) => setState(() => _formErrors.remove('schoolYear_$index')),
            schoolValue:      r.selectedSchool != null ? '${r.selectedSchool!.name} (${r.selectedSchool!.city})' : null,
            schoolOptions:    schoolNames,
            schoolError:      _formErrors['schoolName_$index'],
            onSchoolSelected: (val) 
            {
              setState(() 
              {
                r.selectedSchool  = _allSchools.firstWhere((s) => '${s.name} (${s.city})' == val);
                r.selectedProgram = null;
                r.selectedGrade   = null;
                _formErrors.remove('schoolName_$index');
              });
            },
            programValue:      r.selectedProgram?.name,
            programOptions:    programNames,
            programEnabled:    r.selectedSchool != null && programNames.isNotEmpty,
            programError:      _formErrors['schoolProgram_$index'],
            onProgramSelected: (val) 
            {
              setState(() 
              {
                r.selectedProgram = _allPrograms.firstWhere((p) => p.name == val);
                r.selectedGrade   = null;
                _formErrors.remove('schoolProgram_$index');
              });
            },
            gradeValue:      r.selectedGrade,
            gradeOptions:    gradeOptions,
            gradeEnabled:    r.selectedProgram != null && gradeOptions.isNotEmpty,
            gradeError:      _formErrors['schoolGrade_$index'],
            onGradeSelected: (val) => setState(() 
            {
              r.selectedGrade = val;
              _formErrors.remove('schoolGrade_$index');
            }),
            onRemove: index > 0
                ? () => setState(() 
                  {
                    r.yearCtrl.dispose();
                    _schoolRows.removeAt(index);
                    _formErrors.remove('schoolYear_$index');
                    _formErrors.remove('schoolName_$index');
                    _formErrors.remove('schoolProgram_$index');
                    _formErrors.remove('schoolGrade_$index');
                  })
                : null,
          );
        }),
        Align
        (
          alignment: Alignment.centerRight,
          child: WizardTextLinkButton
          (
            text:  'Aggiungi anno scolastico',
            icon:  Icons.add_rounded,
            onTap: () 
            {
              int lastYear = DateTime.now().year;
              if (_schoolRows.isNotEmpty) 
              {
                int maxYear = 0;
                for (var r in _schoolRows)
                {
                  int y = int.tryParse(r.yearCtrl.text) ?? 0;
                  if (y > maxYear) maxYear = y;
                }
                lastYear = maxYear > 0 ? maxYear : lastYear;
              }
              setState(() 
              {
                _schoolRows.add(WizardSchoolRowData(yearCtrl: TextEditingController(text: (lastYear - 1).toString())));
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Parents()
  {
    final validAdults = _filteredAdults;

    return SizedBox
    (
      key:   const ValueKey('step5_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.start,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text
                (
                  'Associazione Genitori',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 8),
                Text
                (
                  'Seleziona i genitori o i tutori legali del minore (almeno uno, massimo due).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF64748B),
                    height:     1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center
          (
            child: ConstrainedBox
            (
              constraints: const BoxConstraints(maxWidth: 1320),
              //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold_NotAlwaysSplit
              //ErroreCorretto_LaVersionePrecedenteSpezzavaSempreLaRigaAncheSuSchermiLarghi
              child: _ResponsiveSearchFilterRow
              (
                breakpoint: 500,
                searchBar: WizardAnimatedSearchBar
                (
                  controller: _searchParentsCtrl, 
                  onChanged:  (value) => setState(() => _searchParentsText = value), 
                  hintText:   'Cerca genitore...',
                ),
                filterWidgets: 
                [
                  WizardFilterMenu<String>
                  (
                    hint:          'Ordina per', 
                    icon:          Icons.sort_rounded, 
                    value:         _sortParentsBy, 
                    menuWidth:     180, 
                    showClearIcon: false, 
                    onChanged:     (val) => setState(() => _sortParentsBy = val), 
                    onClear:       () {}, 
                    options: 
                    [
                      WizardFilterOption(value: 'surname_asc', label: 'Cognome (A-Z)'), 
                      WizardFilterOption(value: 'surname_desc', label: 'Cognome (Z-A)'), 
                      WizardFilterOption(value: 'name_asc', label: 'Nome (A-Z)'), 
                      WizardFilterOption(value: 'name_desc', label: 'Nome (Z-A)'), 
                      WizardFilterOption(value: 'date_desc', label: 'Più recente'), 
                      WizardFilterOption(value: 'date_asc', label: 'Meno recente'),
                    ]
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded
          (
            child: _isLoadingData 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
              : SizedBox
                (
                  width: double.infinity,
                  child: SingleChildScrollView
                  (
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Center
                    (
                      child: ConstrainedBox
                      (
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: Wrap
                        (
                          spacing:    16,
                          runSpacing: 16,
                          alignment:  WrapAlignment.start,
                          children:   validAdults.map((adult) 
                          {
                            final adultId    = adult.fiscalCode;
                            final isSelected = _selectedParents.contains(adultId);
                            
                            return WizardSelectablePersonCard
                            (
                              person:     adult,
                              isSelected: isSelected,
                              onTap:      () => setState(() 
                              {
                                if (isSelected) 
                                {
                                  _selectedParents.remove(adultId);
                                } 
                                else 
                                {
                                  if (_selectedParents.length >= 2)
                                  {
                                    CustomSnackBar.show(context: context, message: 'Massimo 2 genitori selezionabili.', isError: true);
                                    return;
                                  }
                                  _selectedParents.add(adultId);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep6Minors()
  {
    final validMinors = _filteredMinors;

    return SizedBox
    (
      key:   const ValueKey('step6_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.start,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text
                (
                  'Associazione Minori',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 8),
                Text
                (
                  'Seleziona i minori di cui questa persona è genitore o tutore legale.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF64748B),
                    height:     1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center
          (
            child: ConstrainedBox
            (
              constraints: const BoxConstraints(maxWidth: 1320),
              //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold_NotAlwaysSplit
              //ErroreCorretto_LaVersionePrecedenteSpezzavaSempreLaRigaAncheSuSchermiLarghi
              child: _ResponsiveSearchFilterRow
              (
                breakpoint: 700,
                searchBar: WizardAnimatedSearchBar
                (
                  controller: _searchMinorsCtrl, 
                  onChanged:  (value) => setState(() => _searchMinorsText = value), 
                  hintText:   'Cerca minore...',
                ),
                filterWidgets: 
                [
                  WizardFilterMenu<String>
                  (
                    hint:          'Ordina per', 
                    icon:          Icons.sort_rounded, 
                    value:         _sortMinorsBy, 
                    menuWidth:     180, 
                    showClearIcon: false, 
                    onChanged:     (val) => setState(() => _sortMinorsBy = val), 
                    onClear:       () {}, 
                    options: 
                    [
                      WizardFilterOption(value: 'surname_asc', label: 'Cognome (A-Z)'), 
                      WizardFilterOption(value: 'surname_desc', label: 'Cognome (Z-A)'), 
                      WizardFilterOption(value: 'name_asc', label: 'Nome (A-Z)'), 
                      WizardFilterOption(value: 'name_desc', label: 'Nome (Z-A)'), 
                      WizardFilterOption(value: 'date_desc', label: 'Più recente'), 
                      WizardFilterOption(value: 'date_asc', label: 'Meno recente'),
                    ]
                  ),
                  WizardFilterMenu<String>
                  (
                    hint:          'Tutti i ruoli', 
                    icon:          Icons.badge_outlined, 
                    value:         _filterMinorsRole, 
                    menuWidth:     200, 
                    showClearIcon: true, 
                    onChanged:     (val) => setState(() => _filterMinorsRole = val), 
                    onClear:       () => setState(() => _filterMinorsRole = null), 
                    options: 
                    [
                      WizardFilterOption(value: 'STUDENTE', label: 'Studente'), 
                      WizardFilterOption(value: 'CORSISTA', label: 'Corsista'), 
                      WizardFilterOption(value: 'DOCENTE', label: 'Docente'),
                      WizardFilterOption(value: 'ASSOCIATO', label: 'Solo Associato'),
                    ]
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded
          (
            child: _isLoadingData 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
              : SizedBox
                (
                  width: double.infinity,
                  child: SingleChildScrollView
                  (
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Center
                    (
                      child: ConstrainedBox
                      (
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: Wrap
                        (
                          spacing:    16,
                          runSpacing: 16,
                          alignment:  WrapAlignment.start,
                          children:   validMinors.map((minor) 
                          {
                            final minorId    = minor.fiscalCode;
                            final isSelected = _selectedMinors.contains(minorId);
                            
                            return WizardSelectablePersonCard
                            (
                              person:     minor,
                              isSelected: isSelected,
                              onTap:      () => setState(() 
                              {
                                if (isSelected) 
                                {
                                  _selectedMinors.remove(minorId);
                                } 
                                else 
                                {
                                  _selectedMinors.add(minorId);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep7Discipline() 
  {
    final validSubjects = _filteredFilteredSubjects;

    return SizedBox
    (
      key:   const ValueKey('step7_e'),
      width: double.infinity,
      child: Column
      (
        mainAxisAlignment: MainAxisAlignment.start,
        children: 
        [
          Padding
          (
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column
            (
              children: 
              [
                Text
                (
                  'Discipline Insegnate',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 8),
                Text
                (
                  'Seleziona le discipline e i percorsi di studio in cui il docente insegnerà.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF64748B),
                    height:     1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center
          (
            child: ConstrainedBox
            (
              constraints: const BoxConstraints(maxWidth: 1140),
              //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold_NotAlwaysSplit
              //ErroreCorretto_LaVersionePrecedenteSpezzavaSempreLaRigaAncheSuSchermiLarghi
              child: _ResponsiveSearchFilterRow
              (
                breakpoint: 650,
                searchBar: WizardAnimatedSearchBar
                (
                  controller: _searchSubjectsCtrl, 
                  onChanged:  (value) => setState(() => _searchSubjectsText = value), 
                  hintText:   'Cerca disciplina...',
                ),
                filterWidgets: 
                [
                  WizardFilterMenu<String>
                  (
                    hint:          'Ordina per', 
                    icon:          Icons.sort_rounded, 
                    value:         _sortSubjectsBy, 
                    menuWidth:     180, 
                    showClearIcon: false, 
                    onChanged:     (val) => setState(() => _sortSubjectsBy = val), 
                    onClear:       () {}, 
                    options: 
                    [
                      WizardFilterOption(value: 'name_asc', label: 'Nome (A-Z)'), 
                      WizardFilterOption(value: 'name_desc', label: 'Nome (Z-A)'),
                      WizardFilterOption(value: 'date_desc', label: 'Più recente'), 
                      WizardFilterOption(value: 'date_asc', label: 'Meno recente'), 
                    ]
                  ),
                  WizardFilterMenu<String>
                  (
                    hint:          'Tutte le aree', 
                    icon:          Icons.category_outlined, 
                    value:         _filterSubjectsArea, 
                    menuWidth:     200, 
                    showClearIcon: true, 
                    onChanged:     (val) => setState(() => _filterSubjectsArea = val), 
                    onClear:       () => setState(() => _filterSubjectsArea = null), 
                    options: 
                    [
                      WizardFilterOption(value: 'HUMANITIES', label: 'Area Umanistica'), 
                      WizardFilterOption(value: 'LINGUISTICS', label: 'Area Linguistica'), 
                      WizardFilterOption(value: 'SCIENCES', label: 'Area Scientifica')
                    ]
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded
          (
            child: _isLoadingData 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
              : SizedBox
                (
                  width: double.infinity,
                  child: SingleChildScrollView
                  (
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Center
                    (
                      child: ConstrainedBox
                      (
                        constraints: const BoxConstraints(maxWidth: 1140),
                        child: Wrap
                        (
                          spacing:    16,
                          runSpacing: 16,
                          alignment:  WrapAlignment.start,
                          children:   validSubjects.map((subject) 
                          {
                            final isSelected    = _subjectToggles[subject.id] ?? false;
                            final selectedCount = (_selectedProgramsForSubject[subject.id] ?? {}).length;
                            
                            return WizardSubjectGridCard
                            (
                              subject:       subject,
                              isSelected:    isSelected,
                              selectedCount: selectedCount,
                              onTap:         () => _openProgramsDialog(subject),
                              onRemove:      () 
                              {
                                setState(() 
                                {
                                  _subjectToggles[subject.id] = false;
                                  _selectedProgramsForSubject.remove(subject.id);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _ReportErrorDialog extends StatefulWidget 
{
  final PersonItem person;

  const _ReportErrorDialog
  ({
    required this.person,
  });

  @override
  State<_ReportErrorDialog> createState() => _ReportErrorDialogState();
}

class _ReportErrorDialogState extends State<_ReportErrorDialog> 
{
  final Set<String>                        _selectedFields = {};
  final Map<String, TextEditingController> _controllers    = {};
  bool                                     _isSaving       = false;

  @override
  void dispose() 
  {
    for (final ctrl in _controllers.values) 
    {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _sendReport() async 
  {
    if (_selectedFields.isEmpty) 
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno un campo da modificare.', isError: true);
      return;
    }
    
    bool hasEmptyFields = false;
    for (final field in _selectedFields) 
    {
      if (_controllers[field]?.text.trim().isEmpty ?? true) 
      {
        hasEmptyFields = true;
        break;
      }
    }

    if (hasEmptyFields) 
    {
      CustomSnackBar.show(context: context, message: 'Compila i dettagli per tutti i campi selezionati.', isError: true);
      return;
    }

    setState(() 
    {
      _isSaving = true;
    });

    try 
    {
      final Map<String, String> corrections = {};
      for (final field in _selectedFields) 
      {
        corrections[field] = _controllers[field]!.text.trim();
      }

      await ApiService().sendAnagraphicErrorReport(widget.person.fiscalCode, corrections);

      if (mounted) 
      {
        CustomSnackBar.show(context: context, message: 'Segnalazione inviata con successo!', isError: false);
        Navigator.of(context).pop();
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() 
        {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildFieldLabel(String text) 
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 12, top: 16), 
      child:   Text
      (
        text, 
        style: GoogleFonts.plusJakartaSans
        (
          color:      const Color(0xFF003C82), 
          fontWeight: FontWeight.w700, 
          fontSize:   16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return Dialog
    (
      backgroundColor: Colors.transparent, 
      elevation:       0,
      child: Container
      (
        //LarghezzaResponsive_RiempieLoSpazioDisponibileMaMaiOltre540
        //SenzaQuestoIlBreakpointSullaRigaDeiBottoniQuiSottoNonScatterebbeMai
        width:       double.infinity,
        constraints: BoxConstraints(maxWidth: 540, maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration
        (
          color:        Colors.white, 
          borderRadius: BorderRadius.circular(30), 
          boxShadow: const 
          [
            BoxShadow
            (
              color:      Color(0x1A000000), 
              offset:     Offset(0, 8), 
              blurRadius: 24,
            )
          ],
        ),
        child: Column
        (
          mainAxisSize: MainAxisSize.min,
          children: 
          [
            Padding
            (
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row
              (
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: 
                [
                  Text
                  (
                    'Segnala Errore', 
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize:   22, 
                      fontWeight: FontWeight.w700, 
                      color:      const Color(0xFF003C82),
                    ),
                  ),
                  WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Flexible
            (
              child: SingleChildScrollView
              (
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
                child: SizedBox
                (
                  width: double.infinity,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      _buildFieldLabel('Campi da modificare'),
                      Wrap
                      (
                        spacing:    12, 
                        runSpacing: 12,
                        children: 
                        [
                          'Nome', 
                          'Cognome', 
                          'Sesso', 
                          'Codice fiscale', 
                          'Data di nascita', 
                          'Città di nascita', 
                          'Provincia'
                        ].map((field) 
                        {
                          return _ErrorFieldChip
                          (
                            label:      field, 
                            isSelected: _selectedFields.contains(field), 
                            onSelected: (v) 
                            {
                              setState(() 
                              {
                                if (v) 
                                {
                                  _selectedFields.add(field);
                                  _controllers[field] = TextEditingController();
                                } 
                                else 
                                {
                                  _selectedFields.remove(field);
                                  _controllers[field]?.dispose();
                                  _controllers.remove(field);
                                }
                              });
                            }
                          );
                        }).toList(),
                      ),
                      if (_selectedFields.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildFieldLabel('Dettagli per campo'),
                        ..._selectedFields.map((field) 
                        {
                          return Padding
                          (
                            padding: const EdgeInsets.only(bottom: 16),
                            child: WizardAnimatedTextField
                            (
                              controller: _controllers[field]!, 
                              hint:       'Inserisci il dato corretto per $field...', 
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding
            (
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 24),
              //StacksVerticallyWhenTheDialogIsTooNarrowForBothButtonsSideBySide
              //ModalitaAffiancataRestaComEra(Expanded50/50)_SoloLoStackingUsaLarghezzaFissa
              child: _ResponsiveReportDialogButtonsRow
              (
                secondaryButton: WizardAnimatedActionButton
                (
                  text:       'ANNULLA', 
                  icon:       Icons.cancel_outlined, 
                  baseColor:  const Color(0xFFE53935), 
                  hoverColor: const Color(0xFFEF5350), 
                  onPressed:  () => Navigator.of(context).pop()
                ),
                primaryButton: WizardAnimatedActionButton
                (
                  text:       _isSaving ? 'INVIO IN CORSO...' : 'INVIA SEGNALAZIONE', 
                  icon:       Icons.send_rounded, 
                  baseColor:  const Color(0xFF003C82), 
                  hoverColor: const Color(0xFF004D99),
                  onPressed:  _isSaving ? () {} : _sendReport,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//DecideSoloSeAffiancareOImpilare_LaModalitaAffiancataRestaComEra(50/50)_SoloLoStackingUsaLarghezzaFissa
//StessoCriterioGiaUsatoInAssociationSubjectsTab
class _ResponsiveReportDialogButtonsRow extends StatelessWidget
{
  final Widget secondaryButton;
  final Widget primaryButton;
  final double breakpoint;

  const _ResponsiveReportDialogButtonsRow
  ({
    required this.secondaryButton,
    required this.primaryButton,
    this.breakpoint = 460,
  });

  static const double _kStackedButtonWidth = 240;

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column
          (
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              SizedBox(width: _kStackedButtonWidth, child: primaryButton),
              const SizedBox(height: 16),
              SizedBox(width: _kStackedButtonWidth, child: secondaryButton),
            ],
          );
        }

        return Row
        (
          children: 
          [
            Expanded(child: secondaryButton),
            const SizedBox(width: 16),
            Expanded(child: primaryButton),
          ],
        );
      },
    );
  }
}

class _ErrorFieldChip extends StatefulWidget 
{ 
  final String             label; 
  final bool               isSelected; 
  final ValueChanged<bool> onSelected; 
  
  const _ErrorFieldChip
  ({
    required this.label, 
    required this.isSelected, 
    required this.onSelected, 
  }); 
  
  @override 
  State<_ErrorFieldChip> createState() => _ErrorFieldChipState(); 
}

class _ErrorFieldChipState extends State<_ErrorFieldChip> 
{ 
  bool _isHovered = false; 
  
  @override 
  Widget build(BuildContext context) 
  { 
    return MouseRegion
    (
      cursor:  SystemMouseCursors.click, 
      onEnter: (_) => setState(() => _isHovered = true), 
      onExit:  (_) => setState(() => _isHovered = false), 
      child: GestureDetector
      (
        onTap: () => widget.onSelected(!widget.isSelected), 
        child: AnimatedContainer
        (
          duration:   const Duration(milliseconds: 150), 
          padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
          decoration: BoxDecoration
          (
            color:        widget.isSelected ? const Color(0xFF003C82) : (_isHovered ? const Color(0xFFF5F8FC) : Colors.white), 
            borderRadius: BorderRadius.circular(100), 
            border:       Border.all
            (
              color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), 
              width: 1.0,
            ),
          ), 
          child: AnimatedDefaultTextStyle
          (
            duration: const Duration(milliseconds: 150), 
            style: GoogleFonts.plusJakartaSans
            (
              fontSize:   14, 
              fontWeight: FontWeight.w600, 
              color:      widget.isSelected ? Colors.white : const Color(0xFF003C82),
            ), 
            child: Text(widget.label),
          ),
        ),
      ),
    ); 
  } 
}

//DecideRowVsColumnBasedOnActualAvailableWidth_NeverLetsTheButtonsStretchToFillTheSpace
//StessoCriterioDiPersonWizardPage_ConLarghezzaFissa230CoerenteConQuestoDialog
class _ResponsiveWizardBottomBar extends StatelessWidget
{
  final Widget secondaryButton;
  final Widget primaryButton;

  const _ResponsiveWizardBottomBar
  ({
    required this.secondaryButton,
    required this.primaryButton,
  });

  static const double _kButtonWidth = 230;
  static const double _kSpacing = 24;
  static const double _kBreakpoint = _kButtonWidth * 2 + _kSpacing + 40;

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        if (isCompact)
        {
          return Column
          (
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              SizedBox(width: _kButtonWidth, child: primaryButton),
              const SizedBox(height: 16),
              SizedBox(width: _kButtonWidth, child: secondaryButton),
            ],
          );
        }

        return Row
        (
          mainAxisAlignment: MainAxisAlignment.center,
          children: 
          [
            SizedBox(width: _kButtonWidth, child: secondaryButton),
            const SizedBox(width: _kSpacing),
            SizedBox(width: _kButtonWidth, child: primaryButton),
          ],
        );
      },
    );
  }
}

//DecideSeAffiancareOImpilareViaPiazza+Nome+Civico_StessoCriterioDiPersonWizardPage
class _WizardAddressFieldsRow extends StatelessWidget
{
  final TextEditingController tipoViaCtrl;
  final String?               tipoViaError;
  final ValueChanged<String>  onTipoViaChanged;

  final TextEditingController nomeCtrl;
  final String?               nomeError;
  final ValueChanged<String>  onNomeChanged;

  final TextEditingController civicoCtrl;
  final String?               civicoError;
  final ValueChanged<String>  onCivicoChanged;

  const _WizardAddressFieldsRow
  ({
    required this.tipoViaCtrl,
    required this.tipoViaError,
    required this.onTipoViaChanged,
    required this.nomeCtrl,
    required this.nomeError,
    required this.onNomeChanged,
    required this.civicoCtrl,
    required this.civicoError,
    required this.onCivicoChanged,
  });

  static const double _kBreakpoint = 420;

  Widget _buildLabel(String text)
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 6),
      child:   Text
      (
        text, 
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   13, 
          fontWeight: FontWeight.w600, 
          color:      const Color(0xFF7A7A7A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        final Widget tipoViaField = WizardAnimatedTextField
        (
          controller: tipoViaCtrl, 
          hint:       'Via/Strada/...',
          errorText:  tipoViaError,
          onChanged:  onTipoViaChanged,
        );

        final Widget nomeField = WizardAnimatedTextField
        (
          controller: nomeCtrl, 
          hint:       'Nome',
          errorText:  nomeError,
          onChanged:  onNomeChanged,
        );

        final Widget civicoField = WizardAnimatedTextField
        (
          controller: civicoCtrl, 
          hint:       'N°',
          errorText:  civicoError,
          onChanged:  onCivicoChanged,
        );

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              _buildLabel('Via / Piazza'),
              tipoViaField,
              const SizedBox(height: 16),
              _buildLabel('Nome via'),
              nomeField,
              const SizedBox(height: 16),
              _buildLabel('Numero civico'),
              civicoField,
            ],
          );
        }

        return Row
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            Expanded(flex: 3, child: tipoViaField),
            const SizedBox(width: 8),
            Expanded(flex: 5, child: nomeField),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: civicoField),
          ],
        );
      },
    );
  }
}

//DecideSeAffiancareOImpilareAnnoEDataInizio_StessoCriterioDiPersonWizardPage
class _WizardEnrollmentFieldRow extends StatelessWidget
{
  final TextEditingController yearCtrl;
  final TextEditingController dateCtrl;
  final String?               yearError;
  final String?               dateError;
  final ValueChanged<String>  onYearChanged;
  final ValueChanged<String>  onDateChanged;
  final VoidCallback?         onRemove;

  const _WizardEnrollmentFieldRow
  ({
    required this.yearCtrl,
    required this.dateCtrl,
    required this.yearError,
    required this.dateError,
    required this.onYearChanged,
    required this.onDateChanged,
    required this.onRemove,
  });

  static const double _kBreakpoint = 360;

  Widget _buildLabel(String text)
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 8),
      child:   Text
      (
        text, 
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   14, 
          fontWeight: FontWeight.w600, 
          color:      const Color(0xFF7A7A7A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        final Widget yearField = Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            _buildLabel('Anno'),
            WizardAnimatedTextField
            (
              controller:   yearCtrl, 
              hint:         'Es. 2024', 
              keyboardType: TextInputType.number,
              errorText:    yearError,
              onChanged:    onYearChanged,
            ),
          ],
        );

        final Widget dateField = Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            _buildLabel('Data inizio'),
            WizardAnimatedTextField
            (
              controller:      dateCtrl, 
              hint:            'gg/mm', 
              keyboardType:    TextInputType.number,
              inputFormatters: [WizardDayMonthInputFormatter()],
              errorText:       dateError,
              onChanged:       onDateChanged,
            ),
          ],
        );

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              yearField,
              const SizedBox(height: 16),
              onRemove == null
                  ? dateField
                  : Row
                    (
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: 
                      [
                        Expanded(child: dateField),
                        const SizedBox(width: 8),
                        WizardRemoveRowButton(onTap: onRemove!),
                      ],
                    ),
            ],
          );
        }

        return Row
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            Expanded(flex: 2, child: yearField),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: dateField),
            onRemove != null
                ? Padding
                  (
                    padding: const EdgeInsets.only(top: 32, left: 8),
                    child:   WizardRemoveRowButton(onTap: onRemove!),
                  )
                : const SizedBox(width: 48),
          ],
        );
      },
    );
  }
}

//DecideSeAffiancareOImpilareIQuattroCampi_StessoCriterioDiPersonWizardPage
class _WizardSchoolFieldRow extends StatelessWidget
{
  final TextEditingController yearCtrl;
  final String?                yearError;
  final ValueChanged<String>   onYearChanged;

  final String?                 schoolValue;
  final List<String>            schoolOptions;
  final String?                 schoolError;
  final ValueChanged<String>    onSchoolSelected;

  final String?                 programValue;
  final List<String>            programOptions;
  final bool                    programEnabled;
  final String?                 programError;
  final ValueChanged<String>    onProgramSelected;

  final String?                 gradeValue;
  final List<String>            gradeOptions;
  final bool                    gradeEnabled;
  final String?                 gradeError;
  final ValueChanged<String>    onGradeSelected;

  final VoidCallback?           onRemove;

  const _WizardSchoolFieldRow
  ({
    required this.yearCtrl,
    required this.yearError,
    required this.onYearChanged,
    required this.schoolValue,
    required this.schoolOptions,
    required this.schoolError,
    required this.onSchoolSelected,
    required this.programValue,
    required this.programOptions,
    required this.programEnabled,
    required this.programError,
    required this.onProgramSelected,
    required this.gradeValue,
    required this.gradeOptions,
    required this.gradeEnabled,
    required this.gradeError,
    required this.onGradeSelected,
    required this.onRemove,
  });

  static const double _kBreakpoint = 700;

  Widget _buildLabel(String text)
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 8),
      child:   Text
      (
        text, 
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   12, 
          fontWeight: FontWeight.w700, 
          color:      const Color(0xFF64748B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container
    (
      margin:     const EdgeInsets.only(bottom: 16),
      padding:    const EdgeInsets.all(20),
      decoration: BoxDecoration
      (
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFFE2E8F0)),
        color:        const Color(0xFFF8FAFC),
      ),
      child: LayoutBuilder
      (
        builder: (context, constraints)
        {
          final bool isCompact = constraints.maxWidth < _kBreakpoint;

          final Widget yearField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              _buildLabel('Anno inizio'),
              WizardAnimatedTextField
              (
                controller:   yearCtrl,
                hint:         'Es. 2024',
                errorText:    yearError,
                keyboardType: TextInputType.number,
                onChanged:    onYearChanged,
              ),
            ],
          );

          final Widget schoolField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              _buildLabel('Scuola'),
              WizardAnimatedOverlayDropdown
              (
                value:      schoolValue,
                items:      schoolOptions,
                hint:       'Scuola',
                errorText:  schoolError,
                onChanged:  onSchoolSelected,
              ),
            ],
          );

          final Widget programField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              _buildLabel('Percorso'),
              WizardAnimatedOverlayDropdown
              (
                value:      programValue,
                items:      programOptions,
                hint:       'Percorso',
                enabled:    programEnabled,
                errorText:  programError,
                onChanged:  onProgramSelected,
              ),
            ],
          );

          final Widget gradeField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              _buildLabel('Classe'),
              WizardAnimatedOverlayDropdown
              (
                value:      gradeValue,
                items:      gradeOptions,
                hint:       'Classe',
                enabled:    gradeEnabled,
                errorText:  gradeError,
                onChanged:  onGradeSelected,
              ),
            ],
          );

          if (isCompact)
          {
            return Column
            (
              crossAxisAlignment: CrossAxisAlignment.start,
              children: 
              [
                yearField,
                const SizedBox(height: 16),
                schoolField,
                const SizedBox(height: 16),
                programField,
                const SizedBox(height: 16),
                onRemove == null
                    ? gradeField
                    : Row
                      (
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: 
                        [
                          Expanded(child: gradeField),
                          const SizedBox(width: 8),
                          WizardRemoveRowButton(onTap: onRemove!),
                        ],
                      ),
              ],
            );
          }

          return Row
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              Expanded(flex: 2, child: yearField),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: schoolField),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: programField),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: gradeField),
              onRemove != null
                  ? Padding
                    (
                      padding: const EdgeInsets.only(top: 28, left: 16),
                      child:   WizardRemoveRowButton(onTap: onRemove!),
                    )
                  : const SizedBox(width: 48),
            ],
          );
        },
      ),
    );
  }
}


//DecideSeAffiancareRicercaEFiltriOImpilarli_SoloSottoSoglia_NonSempreCome_LaVersionePrecedenteSbagliava
class _ResponsiveSearchFilterRow extends StatelessWidget
{
  final Widget searchBar;
  final List<Widget> filterWidgets;
  final double breakpoint;
  final double spacing;

  const _ResponsiveSearchFilterRow
  ({
    required this.searchBar,
    required this.filterWidgets,
    this.breakpoint = 700,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              searchBar,
              SizedBox(height: spacing),
              Wrap
              (
                spacing:    spacing,
                runSpacing: spacing,
                children:   filterWidgets,
              ),
            ],
          );
        }

        final List<Widget> rowChildren = [Expanded(child: searchBar)];
        for (final w in filterWidgets)
        {
          rowChildren.add(SizedBox(width: spacing));
          rowChildren.add(w);
        }

        return Row(children: rowChildren);
      },
    );
  }
}