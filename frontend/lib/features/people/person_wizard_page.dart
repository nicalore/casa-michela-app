import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/snackbar.dart';
import '../../../services/api_service.dart';

import '../association/models/association_subject_item.dart';
import '../association/models/study_program_item.dart';
import '../association/models/school_item.dart';
import './models/person_item.dart';

import './person_wizard_components.dart';
import './minor_creation_dialog.dart';
import './parent_creation_dialog.dart';

class PersonWizardPage extends StatefulWidget 
{
  const PersonWizardPage({super.key});

  @override
  State<PersonWizardPage> createState() => _PersonWizardPageState();
}

class _PersonWizardPageState extends State<PersonWizardPage> 
{
  int  _currentStep         = 0;
  int  _involvementType     = -1;
  bool _movingForward       = true;
  bool _card1MovingForward  = true;
  bool _card4MovingForward  = true;
  bool _genitoreIsAssociato = false;
  
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

  int                 _currentFormCardIndex = 0; 
  Map<String, String> _formErrors           = {};
  Uint8List?          _fotoProfilo;
  
  final TextEditingController _nomeCtrl             = TextEditingController();
  final TextEditingController _cognomeCtrl          = TextEditingController();
  String?                     _sesso;
  final TextEditingController _cfCtrl               = TextEditingController();
  final TextEditingController _dataNascitaCtrl      = TextEditingController();
  final TextEditingController _cittaNascitaCtrl     = TextEditingController();
  final TextEditingController _provNascitaCtrl      = TextEditingController();
  final TextEditingController _tipoViaCtrl          = TextEditingController();
  final TextEditingController _indirizzoNomeCtrl    = TextEditingController();
  final TextEditingController _civicoCtrl           = TextEditingController();
  final TextEditingController _cittaResidenzaCtrl   = TextEditingController();
  final TextEditingController _provResidenzaCtrl    = TextEditingController();
  final TextEditingController _capCtrl              = TextEditingController();
  final TextEditingController _emailCtrl            = TextEditingController();
  final TextEditingController _telefonoCtrl         = TextEditingController();

  int _currentStep4CardIndex = 0;
  
  final List<WizardEnrollmentRowData> _enrollmentRows = [];
  final List<WizardSchoolRowData>     _schoolRows     = [];

  final TextEditingController _scadenzaCertificatoCtrl      = TextEditingController();
  final TextEditingController _tipoCorsoCtrl                = TextEditingController();
  final TextEditingController _ibanCtrl                     = TextEditingController();
  String?                     _tipoCollaborazione;
  String?                     _ruoloAmministratore;
  final TextEditingController _altroRuoloAmministratoreCtrl = TextEditingController();
  final TextEditingController _studiScolasticiCtrl          = TextEditingController();
  final TextEditingController _studiUniversitariCtrl        = TextEditingController();

  String?          _uscitaAnticipata;
  List<SchoolItem> _allSchools = [];

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
  final Set<String>           _lockedMinors     = {};
  List<PersonItem>            _allMinors        = [];

  bool                         _isLoadingData = true;
  List<AssociationSubjectItem> _allSubjects   = [];
  List<StudyProgramItem>       _allPrograms   = [];

  final TextEditingController  _searchSubjectsCtrl         = TextEditingController();
  String                       _searchSubjectsText         = '';
  String                       _sortSubjectsBy             = 'name_asc';
  String?                      _filterSubjectsArea;
  final Map<int, bool>         _subjectToggles             = {};
  final Map<int, Set<int>>     _selectedProgramsForSubject = {};
  bool                         _isSubmitting               = false;

  final List<Map<String, dynamic>> _pendingPersonsToCreate = [];
  static const double _kCompactCardBoxHeight = 560.0;

  @override
  void initState() 
  {
    super.initState();
    final now = DateTime.now();
    _enrollmentRows.add(WizardEnrollmentRowData
    (
      yearCtrl: TextEditingController(text: now.year.toString()),
      dateCtrl: TextEditingController(text: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}'),
    ));
    _schoolRows.add(WizardSchoolRowData
    (
      yearCtrl: TextEditingController(text: _getCurrentSchoolYearStart().toString()),
    ));
    
    _loadAllData();
  }

  Future<void> _loadAllData() async 
  {
    try 
    {
      final results = await Future.wait(
      [
        ApiService().getAssociationSubjects(),
        ApiService().getStudyPrograms(),
        ApiService().getSchools(), 
        ApiService().getPeople(),
      ]);
      
      if (mounted) 
      {
        setState(() 
        {
          _allSubjects = results[0] as List<AssociationSubjectItem>;
          _allPrograms = results[1] as List<StudyProgramItem>;
          _allSchools  = results[2] as List<SchoolItem>;
          
          final allPeople = results[3] as List<PersonItem>;
          
          _allMinors = allPeople.where((p) => p.age != null && p.age! < 18).toList();
          _allAdults = allPeople.where((p) => (p.age == null || p.age! >= 18) && p.roles.any((r) => r.toUpperCase() == 'GENITORE')).toList();
          
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

  bool _isCodiceFiscaleValid(String cf) 
  {
    if (!RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(cf)) return false;
    
    const oddValues = 
    {
      '0': 1, '1': 0, '2': 5, '3': 7, '4': 9, '5': 13, '6': 15, '7': 17, '8': 19, '9': 21,
      'A': 1, 'B': 0, 'C': 5, 'D': 7, 'E': 9, 'F': 13, 'G': 15, 'H': 17, 'I': 19, 'J': 21,
      'K': 2, 'L': 4, 'M': 18, 'N': 20, 'O': 11, 'P': 3, 'Q': 6, 'R': 8, 'S': 12, 'T': 14,
      'U': 16, 'V': 10, 'W': 22, 'X': 25, 'Y': 24, 'Z': 23
    };
    
    const evenValues = 
    {
      '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
      'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5, 'G': 6, 'H': 7, 'I': 8, 'J': 9,
      'K': 10, 'L': 11, 'M': 12, 'N': 13, 'O': 14, 'P': 15, 'Q': 16, 'R': 17, 'S': 18, 'T': 19,
      'U': 20, 'V': 21, 'W': 22, 'X': 23, 'Y': 24, 'Z': 25
    };
    
    int sum = 0;
    
    for (int i = 0; i < 15; i++) 
    {
      final char = cf[i];
      if ((i + 1) % 2 != 0) 
      {
        sum += oddValues[char]!;
      } 
      else 
      {
        sum += evenValues[char]!;
      }
    }
    
    final checkDigit = String.fromCharCode((sum % 26) + 65);
    return cf[15] == checkDigit;
  }

  bool _doesCfMatchData(String cf, String dateStr, String gender) 
  {
    if (cf.length != 16) return false;
    
    final parts = dateStr.split('/');
    if (parts.length != 3) return false;
    
    final year = parts[2].substring(2, 4);
    if (cf.substring(6, 8) != year) return false;
    
    const monthCodes = {'01': 'A', '02': 'B', '03': 'C', '04': 'D', '05': 'E', '06': 'H', '07': 'L', '08': 'M', '09': 'P', '10': 'R', '11': 'S', '12': 'T'};
    if (cf.substring(8, 9) != monthCodes[parts[1]]) return false;
    
    int day = int.parse(parts[0]);
    if (gender == 'F') day += 40;
    
    final dayStr = day.toString().padLeft(2, '0');
    if (cf.substring(9, 11) != dayStr) return false;
    
    return true;
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

  bool _validateRoles() 
  {
    if (_selectedRoles.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno un ruolo per procedere.', isError: true);
      return false;
    }
    return true;
  }

  bool _validateDatiGenerali()
  {
    setState(()
    {
      _formErrors.clear();
      _nomeCtrl.text           = _nomeCtrl.text.trim();
      _cognomeCtrl.text        = _cognomeCtrl.text.trim();
      _cfCtrl.text             = _cfCtrl.text.trim().toUpperCase();
      _dataNascitaCtrl.text    = _dataNascitaCtrl.text.trim();
      _cittaNascitaCtrl.text   = _cittaNascitaCtrl.text.trim();
      _provNascitaCtrl.text    = _provNascitaCtrl.text.trim().toUpperCase();
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

    if (_nomeCtrl.text.isEmpty) addError('nome', 'Campo obbligatorio', 0);
    if (_cognomeCtrl.text.isEmpty) addError('cognome', 'Campo obbligatorio', 0);
    if (_sesso == null) addError('sesso', 'Campo obbligatorio', 0);
    
    if (_cfCtrl.text.isEmpty)
    {
      addError('cf', 'Campo obbligatorio', 0);
    }
    else if (!_isCodiceFiscaleValid(_cfCtrl.text))
    {
      addError('cf', 'Formato codice fiscale non valido', 0);
    }
    else if (_sesso != null && _dataNascitaCtrl.text.isNotEmpty && _isValidDate(_dataNascitaCtrl.text))
    {
      if (!_doesCfMatchData(_cfCtrl.text, _dataNascitaCtrl.text, _sesso!))
      {
        addError('cf', 'Il codice fiscale non corrisponde ai dati', 0);
      }
    }

    if (_dataNascitaCtrl.text.isEmpty)
    {
      addError('dataNascita', 'Campo obbligatorio', 1);
    }
    else
    {
      if (!_isValidDate(_dataNascitaCtrl.text))
      {
        addError('dataNascita', 'Formato data non valido', 1);
      }
      else
      {
        final parts   = _dataNascitaCtrl.text.split('/');
        final date    = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final now     = DateTime.now();
        final minDate = DateTime(1900, 1, 1);
        
        if (date.isBefore(minDate) || date.isAfter(now))
        {
          addError('dataNascita', 'Data di nascita non consentita', 1);
        }
        else
        {
          bool requiresAdult = _involvementType == -1 && _selectedRoles.contains('GENITORE') || 
                               _selectedRoles.contains('AMMINISTRATORE') || 
                               _selectedRoles.contains('PSICOLOGO') || 
                               _selectedRoles.contains('GENITORE');
                               
          if (requiresAdult)
          {
            int age = now.year - date.year;
            if (now.month < date.month || (now.month == date.month && now.day < date.day))
            {
              age--;
            }
            if (age < 18)
            {
              addError('dataNascita', 'Il ruolo scelto richiede 18 anni compiuti', 1);
            }
          }
        }
      }
    }
    
    if (_cittaNascitaCtrl.text.isEmpty) addError('cittaNascita', 'Campo obbligatorio', 1);
    
    if (_provNascitaCtrl.text.isEmpty)
    {
      addError('provNascita', 'Campo obbligatorio', 1);
    }
    else if (!RegExp(r'^[A-Z]{2}$').hasMatch(_provNascitaCtrl.text))
    {
      addError('provNascita', 'Inserire 2 lettere (es. VI)', 1);
    }

    if (_tipoViaCtrl.text.isEmpty) addError('tipoVia', 'Campo obbligatorio', 2);
    if (_indirizzoNomeCtrl.text.isEmpty) addError('indirizzoNome', 'Campo obbligatorio', 2);
    if (_civicoCtrl.text.isEmpty) addError('civico', 'Campo obbligatorio', 2);
    if (_cittaResidenzaCtrl.text.isEmpty) addError('cittaResidenza', 'Campo obbligatorio', 2);
    
    if (_provResidenzaCtrl.text.isEmpty)
    {
      addError('provResidenza', 'Campo obbligatorio', 2);
    }
    else if (!RegExp(r'^[A-Z]{2}$').hasMatch(_provResidenzaCtrl.text))
    {
      addError('provResidenza', 'Inserire 2 lettere (es. VI)', 2);
    }
    
    if (_capCtrl.text.isEmpty)
    {
      addError('cap', 'Campo obbligatorio', 2);
    }
    else if (!RegExp(r'^\d{5}$').hasMatch(_capCtrl.text))
    {
      addError('cap', 'Deve contenere esattamente 5 numeri', 2);
    }

    if (_emailCtrl.text.isEmpty)
    {
      addError('email', 'Campo obbligatorio', 3);
    }
    else if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(_emailCtrl.text))
    {
      addError('email', 'Formato indirizzo email non valido', 3);
    }

    if (_telefonoCtrl.text.isEmpty)
    {
      addError('telefono', 'Campo obbligatorio', 3);
    }
    else if (!RegExp(r'^\d+$').hasMatch(_telefonoCtrl.text))
    {
      addError('telefono', 'Ammessi esclusivamente numeri', 3);
    }

    setState(()
    {
      _formErrors = newErrors;
      if (!isValid && firstInvalidCard != null)
      {
        _card1MovingForward   = firstInvalidCard! >= _currentFormCardIndex;
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
    _scadenzaCertificatoCtrl.text      = _scadenzaCertificatoCtrl.text.trim();
    _tipoCorsoCtrl.text                = _tipoCorsoCtrl.text.trim();
    _ibanCtrl.text                     = _ibanCtrl.text.replaceAll(' ', '').toUpperCase();
    _altroRuoloAmministratoreCtrl.text = _altroRuoloAmministratoreCtrl.text.trim();
    _studiScolasticiCtrl.text          = _studiScolasticiCtrl.text.trim();
    _studiUniversitariCtrl.text        = _studiUniversitariCtrl.text.trim();

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

    final activeRoles                = _selectedRoles.toList();
    final bool isOnlyGenitoreNotAssociato = activeRoles.length == 1 && activeRoles.contains('GENITORE') && !_genitoreIsAssociato;
    final bool isStaff               = activeRoles.contains('AMMINISTRATORE') || activeRoles.contains('DOCENTE') || activeRoles.contains('PSICOLOGO');
    final bool isAmministratore      = activeRoles.contains('AMMINISTRATORE');
    final bool isCorsista            = activeRoles.contains('CORSISTA');
    final bool isStudente            = activeRoles.contains('STUDENTE');

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

    if (isAmministratore)
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

    if (isCorsista)
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
    
    if (isStudente)
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
        CustomSnackBar.show(context: context, message: 'Non è possibile inserire iscrizioni per anni scolastici futuri.', isError: true);
      }
      else
      {
        CustomSnackBar.show(context: context, message: 'Ci sono errori nelle informazioni associative. Correggi i campi.', isError: true);
      }
    }

    return isValid;
  }

  Future<void> _submitForm() async 
  {
    setState(() => _isSubmitting = true);

    try 
    {
      final List<String> finalRoles = _selectedRoles.toList();
      
      if (_involvementType == 1) 
      {
        finalRoles.add('ASSOCIATO');
      } 
      else 
      {
        if (finalRoles.any((r) => r != 'GENITORE')) 
        {
          finalRoles.add('ASSOCIATO');
        } 
        else if (_genitoreIsAssociato) 
        {
          finalRoles.add('ASSOCIATO');
        }
      }

      final bool isOnlyGenitoreNotAssociato = finalRoles.length == 1 && finalRoles.contains('GENITORE') && !_genitoreIsAssociato;

      List<Map<String, dynamic>> membershipsData = [];
      if (!isOnlyGenitoreNotAssociato) 
      {
        for (final row in _enrollmentRows) 
        {
          final parts   = row.dateCtrl.text.trim().split('/');
          final isoDate = '${row.yearCtrl.text.trim()}-${parts[1]}-${parts[0]}';
          
          membershipsData.add(
          {
            "year":                int.parse(row.yearCtrl.text.trim()),
            "start_date":          isoDate,
            "end_date":            "${row.yearCtrl.text.trim()}-12-31",
            "renewal_period_days": 30,
            "revocation":          "NO"
          });
        }
      }

      Map<String, dynamic>? memberData;
      if (!isOnlyGenitoreNotAssociato && membershipsData.isNotEmpty) 
      {
        memberData = 
        {
          "memberships": membershipsData
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
          "authorized_early_exit": _isMinor ? (_uscitaAnticipata == 'Sì') : true,
          "school_enrollments": _schoolRows.map((r) => 
          {
            "start_year":                 int.parse(r.yearCtrl.text.trim()),
            "school_mechanographic_code": r.selectedSchool!.mechanographicCode,
            "study_program_id":           r.selectedProgram!.id,
            "school_class":               r.selectedGrade!,
          }).toList(),
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
          "birth_date":              _dataNascitaCtrl.text.isNotEmpty ? _dataNascitaCtrl.text.trim().split('/').reversed.join('-') : null,
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

      for (final pending in _pendingPersonsToCreate)
      {
        await ApiService().createPersonFromWizard
        (
          pending['payload'], 
          imageBytes: pending['imageBytes'],
        );
      }

      await ApiService().createPersonFromWizard
      (
        payload, 
        imageBytes: _fotoProfilo,
      );

      if (mounted) 
      {
        CustomSnackBar.show(context: context, message: 'Persona creata con successo!', isError: false);
        context.go('/people');
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

  Future<void> _createNewMinor() async
  {
    final newMinorData = await showGeneralDialog<Map<String, dynamic>>
    (
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'MinorCreation', 
      barrierColor:       Colors.black.withValues(alpha: .5), 
      transitionDuration: const Duration(milliseconds: 300),
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
              child: MinorCreationDialog
              (
                allSchools:  _allSchools,
                allPrograms: _allPrograms,
                allSubjects: _allSubjects,
              ),
            ),
          ),
        );
      },
    );

    if (newMinorData != null)
    {
      final newMinor = newMinorData['person'] as PersonItem;
      _pendingPersonsToCreate.add(newMinorData);
      setState(() 
      {
        _allMinors.add(newMinor);
        _selectedMinors.add(newMinor.fiscalCode);
        _lockedMinors.add(newMinor.fiscalCode);
      });
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: 'Minore creato e selezionato con successo!', isError: false);
      }
    }
  }

  Future<void> _createNewParent() async
  {
    final newParentData = await showGeneralDialog<Map<String, dynamic>>
    (
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'ParentCreation', 
      barrierColor:       Colors.black.withValues(alpha: .5), 
      transitionDuration: const Duration(milliseconds: 300),
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
              child: const ParentCreationDialog(),
            ),
          ),
        );
      },
    );

    if (newParentData != null)
    {
      final newParent = newParentData['person'] as PersonItem;
      _pendingPersonsToCreate.add(newParentData);
      setState(() 
      {
        _allAdults.add(newParent);
        if (_selectedParents.length < 2)
        {
          _selectedParents.add(newParent.fiscalCode);
        }
      });
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: 'Genitore creato e selezionato con successo!', isError: false);
      }
    }
  }

  List<Widget> get _activeStep4Cards 
  {
    final List<Widget> cards                      = [];
    final List<String> activeRoles                = _selectedRoles.toList();
    final bool         isOnlyGenitoreNotAssociato = activeRoles.length == 1 && activeRoles.contains('GENITORE') && !_genitoreIsAssociato;
    
    if (!isOnlyGenitoreNotAssociato)
    {
      cards.add(_buildFormCardIscrizione());
    }
    
    final bool isStaff = activeRoles.contains('AMMINISTRATORE') || 
                         activeRoles.contains('DOCENTE') || 
                         activeRoles.contains('PSICOLOGO');
                         
    if (isStaff)
    {
      cards.add(_buildFormCardStaff());
    }
    
    if (activeRoles.contains('AMMINISTRATORE'))
    {
      cards.add(_buildFormCardAmministratore());
    }
    
    if (activeRoles.contains('DOCENTE'))
    {
      cards.add(_buildFormCardDocente());
    }
    
    if (activeRoles.contains('CORSISTA'))
    {
      cards.add(_buildFormCardCorsista());
    }
    
    if (activeRoles.contains('STUDENTE'))
    {
      cards.add(_buildFormCardStudente());
    }
    
    return cards;
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
          _card1MovingForward   = true;
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
      
      if (_selectedRoles.length == 1 && _selectedRoles.contains('GENITORE'))
      {
        setState(() 
        {
          _movingForward = true;
          _currentStep   = 2;
        });
      }
      else
      {
        setState(() 
        {
          _movingForward        = true;
          _currentStep          = 3;
          _card1MovingForward   = true;
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
        _card1MovingForward   = true;
        _currentFormCardIndex = 0;
      });
      return;
    }

    if (_currentStep == 3)
    {
      final bool isSkip = _nomeCtrl.text.trim().toLowerCase() == 'skip';
      
      if (!isSkip && !_validateDatiGenerali()) return;

      if (_activeStep4Cards.isEmpty)
      {
        if (_isMinor)
        {
          setState(() 
          {
            _movingForward = true;
            _currentStep   = 5;
          });
        }
        else if (_selectedRoles.contains('GENITORE'))
        {
          setState(() 
          {
            _movingForward = true;
            _currentStep   = 6;
          });
        }
        else if (_selectedRoles.contains('DOCENTE'))
        {
          setState(() 
          {
            _movingForward = true;
            _currentStep   = 7;
          });
        }
        else
        {
          _submitForm();
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
      final bool isSkip = _nomeCtrl.text.trim().toLowerCase() == 'skip';
      
      if (!isSkip && !_validateDatiSpecifici()) return;
      
      if (_isMinor)
      {
        setState(() 
        {
          _movingForward = true;
          _currentStep   = 5;
        });
      }
      else if (_selectedRoles.contains('GENITORE'))
      {
        setState(() 
        {
          _movingForward = true;
          _currentStep   = 6;
        });
      }
      else if (_selectedRoles.contains('DOCENTE'))
      {
        setState(() 
        {
          _movingForward = true;
          _currentStep   = 7;
        });
      }
      else
      {
        _submitForm();
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
        setState(() 
        {
          _movingForward = true;
          _currentStep   = 7;
        });
      }
      else
      {
        _submitForm();
      }
      return;
    }

    if (_currentStep == 6)
    {
      for (final minorId in _selectedMinors) 
      {
        final minorIterable = _allMinors.where((m) => m.fiscalCode == minorId);
        if (minorIterable.isNotEmpty) 
        {
          final minorData       = minorIterable.first;
          final existingParents = minorData.parents ?? [];

          if (existingParents.length >= 2) 
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
        setState(() 
        {
          _movingForward = true;
          _currentStep   = 7;
        });
      }
      else
      {
        _submitForm();
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
      
      _submitForm();
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
      if (_involvementType == 1) 
      {
        setState(() => _currentStep = 0);
      } 
      else if (_selectedRoles.length == 1 && _selectedRoles.contains('GENITORE'))
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
          title: Text
          (
            'Annulla Inserimento', 
            style: GoogleFonts.plusJakartaSans
            (
              fontWeight: FontWeight.w700, 
              color:      const Color(0xFF003C82),
            ),
          ),
          content: Text
          (
            'Sei sicuro di voler annullare la procedura? Tutti i dati inseriti fino ad ora andranno persi.', 
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
              child: Text
              (
                'RIPRENDI INSERIMENTO', 
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
                context.go('/people');
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

  Widget _getStepWidget(int step) 
  {
    switch (step) 
    {
      case 0:  return _buildStep0Type();
      case 1:  return _buildStep1Roles();
      case 2:  return _buildStep2Association();
      case 3:  return _buildStep3DatiGenerali();
      case 4:  return _buildStep4DatiSpecifici();
      case 5:  return _buildStep5Parents();
      case 6:  return _buildStep6Minors();
      case 7:  return _buildStep7Discipline();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final viewportWidth = MediaQuery.of(context).size.width;

    return Scaffold
    (
      backgroundColor: Colors.transparent,
      body: AppPageContainer
      (
        minWidth:  AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder:   (context, width, height) 
        {
          return Container
          (
            width:  width,
            height: height,
            color:  const Color(0xFFF4F7F9),
            child: Stack
            (
              children: 
              [
                Positioned
                (
                  right: -800,
                  top:   -800,
                  child: IgnorePointer
                  (
                    child: Container
                    (
                      width:  1600,
                      height: 1600,
                      decoration: const BoxDecoration
                      (
                        shape:    BoxShape.circle,
                        gradient: RadialGradient
                        (
                          colors: 
                          [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned
                (
                  left:   -800,
                  bottom: -800,
                  child: IgnorePointer
                  (
                    child: Container
                    (
                      width:  1600,
                      height: 1600,
                      decoration: const BoxDecoration
                      (
                        shape:    BoxShape.circle,
                        gradient: RadialGradient
                        (
                          colors: 
                          [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                if (viewportWidth > 1024)
                  Positioned.fill
                  (
                    child: IgnorePointer
                    (
                      child: Center
                      (
                        child: Opacity
                        (
                          opacity: 0.04,
                          child: Image.asset
                          (
                            'assets/images/house_watermark.png',
                            width: 800,
                            fit:   BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea
                (
                  child: Padding
                  (
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column
                    (
                      children: 
                      [
                        _buildHeader(),
                        const SizedBox(height: 32),
                        Expanded
                        (
                          child: AnimatedSwitcher
                          (
                            duration:           const Duration(milliseconds: 450),
                            switchInCurve:      Curves.easeOutCubic,
                            switchOutCurve:     Curves.easeInCubic,
                            layoutBuilder:      (Widget? currentChild, List<Widget> previousChildren) 
                            {
                              return Stack
                              (
                                alignment: Alignment.center,
                                children:  <Widget>
                                [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            transitionBuilder:  (Widget child, Animation<double> animation) 
                            {
                              final keyString  = (child.key as ValueKey<String>).value;
                              final isEntering = keyString == 'step$_currentStep';

                              Offset beginOffset;
                              
                              if (_movingForward) 
                              {
                                beginOffset = isEntering ? const Offset(0.05, 0.0) : const Offset(-0.05, 0.0);
                              } 
                              else 
                              {
                                beginOffset = isEntering ? const Offset(-0.05, 0.0) : const Offset(0.05, 0.0);
                              }

                              return FadeTransition
                              (
                                opacity: animation,
                                child: SlideTransition
                                (
                                  position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
                                  child:    child,
                                ),
                              );
                            },
                            child: _getStepWidget(_currentStep),
                          ),
                        ),
                        _buildBottomBar(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() 
  {
    return Row
    (
      children: 
      [
        WizardHeaderBackButton(onTap: _showCancelConfirmation),
        const SizedBox(width: 12),
        Container
        (
          height:  54, 
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration
          (
            color:        Colors.white, 
            borderRadius: BorderRadius.circular(40), 
            boxShadow: const 
            [
              BoxShadow
              (
                color:      Color(0x0A000000), 
                offset:     Offset(0, 4), 
                blurRadius: 16,
              )
            ],
          ),
          child: Center
          (
            child: Text
            (
              'Nuova persona', 
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   30, 
                fontWeight: FontWeight.w500, 
                color:      const Color(0xFF003C82),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep0Type() 
  {
    return SizedBox
    (
      key:   const ValueKey('step0'),
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
                  'Scegli la categoria che descrive meglio la sua posizione',
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
      key:   const ValueKey('step1'),
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
                  'Quali ruoli ricopre all\'interno dell\'Associazione?',
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
                  'Puoi selezionare più di un\'opzione.',
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
      key:   const ValueKey('step2'),
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
    Widget currentCard;
    
    switch (_currentFormCardIndex) 
    {
      case 0:
        currentCard = _buildFormCardIdentita();
        break;
      case 1:
        currentCard = _buildFormCardAnagrafica();
        break;
      case 2:
        currentCard = _buildFormCardResidenza();
        break;
      case 3:
        currentCard = _buildFormCardContatti();
        break;
      default:
        currentCard = const SizedBox.shrink();
    }

    final double viewportWidth = MediaQuery.of(context).size.width;
    final bool   isCompact     = viewportWidth < 1100;

    final Widget desktopAnimatedCard = AnimatedSwitcher
    (
      duration:           const Duration(milliseconds: 300),
      switchInCurve:      Curves.easeOutCubic,
      switchOutCurve:     Curves.easeInCubic,
      layoutBuilder:      (Widget? currentChild, List<Widget> previousChildren) 
      {
        return Stack
        (
          alignment: Alignment.center,
          children:  <Widget>
          [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder:  (Widget child, Animation<double> animation) 
      {
        final isEntering   = (child.key as ValueKey<int>).value == _currentFormCardIndex;
        Offset beginOffset = _card1MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));

        return FadeTransition
        (
          opacity: animation,
          child: SlideTransition
          (
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
            child:    child,
          ),
        );
      },
      child: KeyedSubtree
      (
        key:   ValueKey(_currentFormCardIndex),
        child: currentCard,
      ),
    );

    final Widget compactAnimatedCard = AnimatedSwitcher
    (
      duration:           const Duration(milliseconds: 300),
      switchInCurve:      Curves.easeOutCubic,
      switchOutCurve:     Curves.easeInCubic,
      layoutBuilder:      (Widget? currentChild, List<Widget> previousChildren) 
      {
        return Stack
        (
          alignment: Alignment.topCenter,
          children:  <Widget>
          [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder:  (Widget child, Animation<double> animation) 
      {
        final isEntering   = (child.key as ValueKey<int>).value == _currentFormCardIndex;
        Offset beginOffset = _card1MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));

        return FadeTransition
        (
          opacity: animation,
          child: SlideTransition
          (
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
            child:    child,
          ),
        );
      },
      child: KeyedSubtree
      (
        key:   ValueKey(_currentFormCardIndex),
        child: SizedBox
        (
          height: _kCompactCardBoxHeight,
          width:  viewportWidth - 64,
          child:  SingleChildScrollView(child: currentCard),
        ),
      ),
    );

    return Column
    (
      key: const ValueKey('step3'),
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
                'Informazioni personali',
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
                'Compila i dati anagrafici e di contatto della persona. Dopo la creazione, sarà possibile modificare solo la residenza e i contatti.',
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
          child: isCompact
              ? Center
                (
                  child: Column
                  (
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: 
                    [
                      SizedBox
                      (
                        height: _kCompactCardBoxHeight,
                        width:  viewportWidth - 64,
                        child:  compactAnimatedCard,
                      ),
                      const SizedBox(height: 24),
                      Row
                      (
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: 
                        [
                          WizardCarouselArrowButton
                          (
                            icon:       Icons.chevron_left_rounded,
                            isDisabled: _currentFormCardIndex == 0,
                            onTap:      () => setState(() { _card1MovingForward = false; _currentFormCardIndex--; }),
                          ),
                          const SizedBox(width: 24),
                          WizardCarouselArrowButton
                          (
                            icon:       Icons.chevron_right_rounded,
                            isDisabled: _currentFormCardIndex == 3,
                            onTap:      () => setState(() { _card1MovingForward = true; _currentFormCardIndex++; }),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Row
                (
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: 
                  [
                    WizardCarouselArrowButton
                    (
                      icon:       Icons.chevron_left_rounded,
                      isDisabled: _currentFormCardIndex == 0,
                      onTap:      () => setState(() { _card1MovingForward = false; _currentFormCardIndex--; }),
                    ),
                    const SizedBox(width: 32),
                    ConstrainedBox
                    (
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child:       desktopAnimatedCard,
                    ),
                    const SizedBox(width: 32),
                    WizardCarouselArrowButton
                    (
                      icon:       Icons.chevron_right_rounded,
                      isDisabled: _currentFormCardIndex == 3,
                      onTap:      () => setState(() { _card1MovingForward = true; _currentFormCardIndex++; }),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStep4DatiSpecifici()
  {
    final cards = _activeStep4Cards;

    final double viewportWidth = MediaQuery.of(context).size.width;
    final bool   isCompact     = viewportWidth < 1200;

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

        return FadeTransition
        (
          opacity: animation,
          child: SlideTransition
          (
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
            child:    child,
          ),
        );
      },
      child: KeyedSubtree
      (
        key:   ValueKey(_currentStep4CardIndex),
        child: cards.isNotEmpty ? cards[_currentStep4CardIndex] : const SizedBox.shrink(),
      ),
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

        return FadeTransition
        (
          opacity: animation,
          child: SlideTransition
          (
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
            child:    child,
          ),
        );
      },
      child: KeyedSubtree
      (
        key:   ValueKey(_currentStep4CardIndex),
        child: SizedBox
        (
          height: _kCompactCardBoxHeight,
          width:  viewportWidth - 64,
          child:  SingleChildScrollView(child: cards.isNotEmpty ? cards[_currentStep4CardIndex] : const SizedBox.shrink()),
        ),
      ),
    );
    
    return Column
    (
      key: const ValueKey('step4'),
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
                'Informazioni associative',
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
                'Compila i dati richiesti dai ruoli selezionati.',
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
          child: isCompact
              ? Center
                (
                  child: Column
                  (
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: 
                    [
                      SizedBox
                      (
                        height: _kCompactCardBoxHeight,
                        width:  viewportWidth - 64,
                        child:  compactAnimatedCards,
                      ),
                      const SizedBox(height: 24),
                      Row
                      (
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: 
                        [
                          WizardCarouselArrowButton
                          (
                            icon:       Icons.chevron_left_rounded,
                            isDisabled: _currentStep4CardIndex == 0,
                            onTap:      () => setState(() { _card4MovingForward = false; _currentStep4CardIndex--; }),
                          ),
                          const SizedBox(width: 24),
                          WizardCarouselArrowButton
                          (
                            icon:       Icons.chevron_right_rounded,
                            isDisabled: _currentStep4CardIndex >= cards.length - 1,
                            onTap:      () => setState(() { _card4MovingForward = true; _currentStep4CardIndex++; }),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Row
                (
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: 
                  [
                    WizardCarouselArrowButton
                    (
                      icon:       Icons.chevron_left_rounded,
                      isDisabled: _currentStep4CardIndex == 0,
                      onTap:      () => setState(() { _card4MovingForward = false; _currentStep4CardIndex--; }),
                    ),
                    const SizedBox(width: 32),
                    Flexible
                    (
                      child: ConstrainedBox
                      (
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child:       desktopAnimatedCards,
                      ),
                    ),
                    const SizedBox(width: 32),
                    WizardCarouselArrowButton
                    (
                      icon:       Icons.chevron_right_rounded,
                      isDisabled: _currentStep4CardIndex >= cards.length - 1,
                      onTap:      () => setState(() { _card4MovingForward = true; _currentStep4CardIndex++; }),
                    ),
                  ],
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
      key:   const ValueKey('step5'),
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
                  'Seleziona i genitori o tutori legali del minore (min 1, max 2).\nSe il genitore non è presente a sistema, puoi registrarlo ora.',
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
          Row
          (
            mainAxisAlignment: MainAxisAlignment.center,
            children: 
            [
              SizedBox
              (
                width: 260,
                child: WizardAnimatedSearchBar
                (
                  controller: _searchParentsCtrl, 
                  onChanged:  (value) => setState(() => _searchParentsText = value), 
                  hintText:   'Cerca per nome...',
                ),
              ),
              const SizedBox(width: 12),
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
              const SizedBox(width: 12),
              WizardMiniActionPillButton
              (
                text:  'Nuovo genitore', 
                icon:  Icons.person_add_alt_1_rounded, 
                onTap: _createNewParent,
              ),
            ],
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
                    child: Wrap
                    (
                      spacing:    16,
                      runSpacing: 16,
                      alignment:  WrapAlignment.center,
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
        ],
      ),
    );
  }

  Widget _buildStep6Minors()
  {
    final validMinors = _filteredMinors;

    return SizedBox
    (
      key:   const ValueKey('step6'),
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
                  'Seleziona i minori di cui questa persona è genitore o tutore legale.\nSe il minore non è presente a sistema, puoi registrarlo ora.',
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
          Row
          (
            mainAxisAlignment: MainAxisAlignment.center,
            children: 
            [
              SizedBox
              (
                width: 260,
                child: WizardAnimatedSearchBar
                (
                  controller: _searchMinorsCtrl, 
                  onChanged:  (value) => setState(() => _searchMinorsText = value), 
                  hintText:   'Cerca per nome...',
                ),
              ),
              const SizedBox(width: 12),
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
              const SizedBox(width: 12),
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
              const SizedBox(width: 12),
              WizardMiniActionPillButton
              (
                text:  'Nuovo minore', 
                icon:  Icons.person_add_alt_1_rounded, 
                onTap: _createNewMinor,
              ),
            ],
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
                    child: Wrap
                    (
                      spacing:    16,
                      runSpacing: 16,
                      alignment:  WrapAlignment.center,
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
                            if (_lockedMinors.contains(minorId))
                            {
                              CustomSnackBar.show(context: context, message: 'Impossibile deselezionare un minore creato qui.', isError: true);
                              return;
                            }

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
        ],
      ),
    );
  }

  Widget _buildStep7Discipline() 
  {
    final validSubjects = _filteredFilteredSubjects;

    return SizedBox
    (
      key:   const ValueKey('step7'),
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
                  'Seleziona le discipline e i percorsi di studio in cui il docente è competente.\nIl docente potrà aggiornare queste informazioni dal proprio account in qualsiasi momento.',
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
          Row
          (
            mainAxisAlignment: MainAxisAlignment.center,
            children: 
            [
              SizedBox
              (
                width: 300,
                child: WizardAnimatedSearchBar
                (
                  controller: _searchSubjectsCtrl, 
                  onChanged:  (value) => setState(() => _searchSubjectsText = value), 
                  hintText:   'Cerca disciplina...',
                ),
              ),
              const SizedBox(width: 16),
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
              const SizedBox(width: 16),
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
                    child: Wrap
                    (
                      spacing:    16,
                      runSpacing: 16,
                      alignment:  WrapAlignment.center,
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
        ...List.generate(_enrollmentRows.length, (index) 
        {
          final row = _enrollmentRows[index];
          return Padding
          (
            padding: const EdgeInsets.only(bottom: 16),
            child: Row
            (
              crossAxisAlignment: CrossAxisAlignment.start,
              children: 
              [
                Expanded
                (
                  flex:  2,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      if (index == 0) ...[
                        Text
                        (
                          'Anno',
                          style: GoogleFonts.plusJakartaSans
                          (
                            fontSize:   14, 
                            fontWeight: FontWeight.w600, 
                            color:      const Color(0xFF7A7A7A),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      WizardAnimatedTextField
                      (
                        controller:   row.yearCtrl, 
                        hint:         'Es. 2024', 
                        keyboardType: TextInputType.number,
                        errorText:    _formErrors['enrollmentYear_$index'],
                        onChanged:    (_) => setState(() => _formErrors.remove('enrollmentYear_$index')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded
                (
                  flex:  3,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      if (index == 0) ...[
                        Text
                        (
                          'Data inizio',
                          style: GoogleFonts.plusJakartaSans
                          (
                            fontSize:   14, 
                            fontWeight: FontWeight.w600, 
                            color:      const Color(0xFF7A7A7A),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      WizardAnimatedTextField
                      (
                        controller:      row.dateCtrl, 
                        hint:            'gg/mm', 
                        keyboardType:    TextInputType.number,
                        inputFormatters: [WizardDayMonthInputFormatter()],
                        errorText:       _formErrors['enrollmentDate_$index'],
                        onChanged:       (_) => setState(() => _formErrors.remove('enrollmentDate_$index')),
                      ),
                    ],
                  ),
                ),
                if (index > 0)
                  Padding
                  (
                    padding: const EdgeInsets.only(top: 6, left: 8),
                    child: WizardRemoveRowButton
                    (
                      onTap: () 
                      {
                        setState(() 
                        {
                          _enrollmentRows[index].yearCtrl.dispose();
                          _enrollmentRows[index].dateCtrl.dispose();
                          _enrollmentRows.removeAt(index);
                          _formErrors.remove('enrollmentYear_$index');
                          _formErrors.remove('enrollmentDate_$index');
                        });
                      },
                    ),
                  )
                else
                  const SizedBox(width: 48), 
              ],
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
            hint:       'Es. Liceo Classico', 
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
            hint:       'Es. Laurea in Informatica', 
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
              final List<SchoolStudyProgramOption> progs = r.selectedSchool!.studyPrograms;
              for (var p in progs) 
              {
                if (p.name.isNotEmpty) 
                {
                  if (_allPrograms.any((allP) => allP.name == p.name) && !programNames.contains(p.name)) 
                  {
                    programNames.add(p.name);
                  }
                  
                  if (r.selectedProgram != null && p.name == r.selectedProgram!.name)
                  {
                    final globalProgram = _allPrograms.firstWhere((gp) => gp.id == r.selectedProgram!.id);
                    
                    const romanGrades = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI', 7: 'VII', 8: 'VIII'};
                    for (int i = globalProgram.minYear; i <= globalProgram.maxYear; i++) 
                    {
                      if (romanGrades.containsKey(i) && !gradeOptions.contains(romanGrades[i]!))
                      {
                        gradeOptions.add(romanGrades[i]!);
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
            child: Row
            (
              crossAxisAlignment: CrossAxisAlignment.start,
              children: 
              [
                Expanded
                (
                  flex: 2,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      Padding
                      (
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text
                        (
                          'Anno inizio',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                      ),
                      WizardAnimatedTextField
                      (
                        controller:   r.yearCtrl,
                        hint:         'Es. 2024',
                        errorText:    _formErrors['schoolYear_$index'],
                        keyboardType: TextInputType.number,
                        onChanged:    (_) => setState(() => _formErrors.remove('schoolYear_$index')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded
                (
                  flex: 4,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      Padding
                      (
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text
                        (
                          'Scuola',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                      ),
                      WizardAnimatedOverlayDropdown
                      (
                        value:      r.selectedSchool != null ? '${r.selectedSchool!.name} (${r.selectedSchool!.city})' : null,
                        items:      schoolNames,
                        hint:       'Scuola',
                        errorText:  _formErrors['schoolName_$index'],
                        onChanged:  (val) 
                        {
                          setState(() 
                          {
                            r.selectedSchool  = _allSchools.firstWhere((s) => '${s.name} (${s.city})' == val);
                            r.selectedProgram = null;
                            r.selectedGrade   = null;
                            _formErrors.remove('schoolName_$index');
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded
                (
                  flex: 4,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      Padding
                      (
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text
                        (
                          'Percorso',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                      ),
                      WizardAnimatedOverlayDropdown
                      (
                        value:      r.selectedProgram?.name,
                        items:      programNames,
                        hint:       'Percorso',
                        enabled:    r.selectedSchool != null && programNames.isNotEmpty,
                        errorText:  _formErrors['schoolProgram_$index'],
                        onChanged:  (val) 
                        {
                          setState(() 
                          {
                            r.selectedProgram = _allPrograms.firstWhere((p) => p.name == val);
                            r.selectedGrade   = null;
                            _formErrors.remove('schoolProgram_$index');
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded
                (
                  flex: 2,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      Padding
                      (
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text
                        (
                          'Classe',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                      ),
                      WizardAnimatedOverlayDropdown
                      (
                        value:      r.selectedGrade,
                        items:      gradeOptions,
                        hint:       'Classe',
                        enabled:    r.selectedProgram != null && gradeOptions.isNotEmpty,
                        errorText:  _formErrors['schoolGrade_$index'],
                        onChanged:  (val) => setState(() 
                        {
                          r.selectedGrade = val;
                          _formErrors.remove('schoolGrade_$index');
                        }),
                      ),
                    ],
                  ),
                ),
                if (index > 0)
                  Padding
                  (
                    padding: const EdgeInsets.only(top: 28, left: 16),
                    child: WizardRemoveRowButton
                    (
                      onTap: () => setState(() 
                      {
                        r.yearCtrl.dispose();
                        _schoolRows.removeAt(index);
                        _formErrors.remove('schoolYear_$index');
                        _formErrors.remove('schoolName_$index');
                        _formErrors.remove('schoolProgram_$index');
                        _formErrors.remove('schoolGrade_$index');
                      }),
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          );
        }),
        Align
        (
          alignment: Alignment.centerRight,
          child: WizardTextLinkButton
          (
            text:  'Aggiungi anno',
            icon:  Icons.add_rounded,
            onTap: () 
            {
              int lastYear = _getCurrentSchoolYearStart();
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

  Widget _buildFormCardIdentita() 
  {
    return WizardFormSectionCard
    (
      title:       'Identità',
      leadingIcon: const WizardStaticAvatar(icon: Icons.badge_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Foto profilo',
          inputWidget: WizardProfilePhotoUploader
          (
            imageBytes:    _fotoProfilo,
            onImagePicked: (bytes) => setState(() => _fotoProfilo = bytes),
          ),
        ),
        const SizedBox(height: 24),
        WizardFormInputRow
        (
          label:       'Nome',
          inputWidget: WizardAnimatedTextField
          (
            controller: _nomeCtrl, 
            hint:       'Es. Mario',
            errorText:  _formErrors['nome'],
            onChanged:  (_) => setState(() => _formErrors.remove('nome')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Cognome',
          inputWidget: WizardAnimatedTextField
          (
            controller: _cognomeCtrl, 
            hint:       'Es. Rossi',
            errorText:  _formErrors['cognome'],
            onChanged:  (_) => setState(() => _formErrors.remove('cognome')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Sesso',
          inputWidget: WizardAnimatedOverlayDropdown
          (
            value:     _sesso,
            items:     const ['M', 'F'],
            hint:      'Seleziona',
            errorText: _formErrors['sesso'],
            onChanged: (val) => setState(() 
            {
              _sesso = val;
              _formErrors.remove('sesso');
            }),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Codice fiscale',
          inputWidget: WizardAnimatedTextField
          (
            controller: _cfCtrl, 
            hint:       'Es. RSSMRA80A01L157H', 
            errorText:  _formErrors['cf'],
            onChanged:  (_) => setState(() => _formErrors.remove('cf')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardAnagrafica() 
  {
    return WizardFormSectionCard
    (
      title:       'Dati anagrafici',
      leadingIcon: const WizardStaticAvatar(icon: Icons.cake_rounded),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Data di nascita',
          inputWidget: WizardAnimatedTextField
          (
            controller:      _dataNascitaCtrl,
            hint:            'gg/mm/aaaa',
            keyboardType:    TextInputType.number,
            inputFormatters: [WizardDateInputFormatter()],
            errorText:       _formErrors['dataNascita'],
            onChanged:       (_) => setState(() => _formErrors.remove('dataNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Città di nascita',
          inputWidget: WizardAnimatedTextField
          (
            controller: _cittaNascitaCtrl, 
            hint:       'Es. Thiene',
            errorText:  _formErrors['cittaNascita'],
            onChanged:  (_) => setState(() => _formErrors.remove('cittaNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Provincia',
          inputWidget: WizardAnimatedTextField
          (
            controller: _provNascitaCtrl, 
            hint:       'Es. VI',
            errorText:  _formErrors['provNascita'],
            onChanged:  (_) => setState(() => _formErrors.remove('provNascita')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardResidenza() 
  {
    return WizardFormSectionCard
    (
      title:       'Residenza',
      leadingIcon: const WizardStaticAvatar(icon: Icons.home_rounded),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Indirizzo',
          inputWidget: Row
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              Expanded
              (
                flex:  3,
                child: WizardAnimatedTextField
                (
                  controller: _tipoViaCtrl, 
                  hint:       'Via/Strada/...',
                  errorText:  _formErrors['tipoVia'],
                  onChanged:  (_) => setState(() => _formErrors.remove('tipoVia')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded
              (
                flex:  5,
                child: WizardAnimatedTextField
                (
                  controller: _indirizzoNomeCtrl, 
                  hint:       'Nome',
                  errorText:  _formErrors['indirizzoNome'],
                  onChanged:  (_) => setState(() => _formErrors.remove('indirizzoNome')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded
              (
                flex:  2,
                child: WizardAnimatedTextField
                (
                  controller: _civicoCtrl, 
                  hint:       'N°',
                  errorText:  _formErrors['civico'],
                  onChanged:  (_) => setState(() => _formErrors.remove('civico')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Città',
          inputWidget: WizardAnimatedTextField
          (
            controller: _cittaResidenzaCtrl, 
            hint:       'Es. Thiene',
            errorText:  _formErrors['cittaResidenza'],
            onChanged:  (_) => setState(() => _formErrors.remove('cittaResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Provincia',
          inputWidget: WizardAnimatedTextField
          (
            controller: _provResidenzaCtrl, 
            hint:       'Es. VI',
            errorText:  _formErrors['provResidenza'],
            onChanged:  (_) => setState(() => _formErrors.remove('provResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'CAP',
          inputWidget: WizardAnimatedTextField
          (
            controller:   _capCtrl, 
            hint:         'Es. 36016', 
            keyboardType: TextInputType.number,
            errorText:    _formErrors['cap'],
            onChanged:    (_) => setState(() => _formErrors.remove('cap')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardContatti() 
  {
    return WizardFormSectionCard
    (
      title:       'Contatti',
      leadingIcon: const WizardStaticAvatar(icon: Icons.alternate_email_rounded),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Email',
          inputWidget: WizardAnimatedTextField
          (
            controller:   _emailCtrl, 
            hint:         'Es. mario.rossi@email.com', 
            keyboardType: TextInputType.emailAddress,
            errorText:    _formErrors['email'],
            onChanged:    (_) => setState(() => _formErrors.remove('email')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Telefono',
          inputWidget: WizardAnimatedTextField
          (
            controller:   _telefonoCtrl, 
            hint:         'Es. 3331234567', 
            keyboardType: TextInputType.phone,
            errorText:    _formErrors['telefono'],
            onChanged:    (_) => setState(() => _formErrors.remove('telefono')),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() 
  {
    bool isLastStep;
    
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

    return Padding
    (
      padding: const EdgeInsets.only(top: 24, bottom: 80),
      child: Row
      (
        mainAxisAlignment: MainAxisAlignment.center,
        children: 
        [
          if (_currentStep == 0) 
            SizedBox
            (
              width: 240, 
              child: WizardAnimatedActionButton
              (
                text:       'ANNULLA', 
                icon:       Icons.close_rounded, 
                baseColor:  const Color(0xFFE53935), 
                hoverColor: const Color(0xFFEF5350), 
                onPressed:  _showCancelConfirmation,
              ),
            )
          else 
            SizedBox
            (
              width: 240, 
              child: WizardOutlinedActionButton
              (
                text:      'INDIETRO', 
                icon:      Icons.arrow_back_rounded, 
                onPressed: _onBack,
              ),
            ),
          const SizedBox(width: 24),
          SizedBox
          (
            width: 240, 
            child: WizardAnimatedActionButton
            (
              text:       _isSubmitting ? 'SALVATAGGIO...' : (isLastStep ? 'CREA PERSONA' : 'AVANTI'), 
              icon:       isLastStep ? Icons.check_circle_outline : Icons.arrow_forward_rounded, 
              baseColor:  const Color(0xFF003C82), 
              hoverColor: const Color(0xFF004D99), 
              onPressed:  _isSubmitting ? () {} : _onNext,
            ),
          ),
        ],
      ),
    );
  }
}