import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/snackbar.dart';

import '../association/models/association_subject_item.dart';
import '../association/models/study_program_item.dart';
import '../association/models/school_item.dart';
import './models/person_item.dart';
import '../../services/api_service.dart';

import 'person_wizard_components.dart';

class MinorCreationDialog extends StatefulWidget 
{
  final List<SchoolItem>             allSchools;
  final List<StudyProgramItem>       allPrograms;
  final List<AssociationSubjectItem> allSubjects;

  const MinorCreationDialog
  ({
    super.key,
    required this.allSchools,
    required this.allPrograms,
    required this.allSubjects,
  });

  @override
  State<MinorCreationDialog> createState() => _MinorCreationDialogState();
}

class _MinorCreationDialogState extends State<MinorCreationDialog> 
{
  int  _currentStep         = 0;
  int  _involvementType     = -1;
  bool _movingForward       = true;
  bool _card1MovingForward  = true;
  bool _card2MovingForward  = true;
  bool _isSubmitting        = false;
  bool _isCheckingCf        = false;

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
      'id':    'CORSISTA', 
      'label': 'Corsista', 
      'desc':  'Partecipa ai corsi organizzati dall\'Associazione, come yoga o pilates.', 
      'icon':  Icons.self_improvement_rounded
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
  final TextEditingController _nazioneNascitaCtrl    = TextEditingController();
  final TextEditingController _tipoViaCtrl          = TextEditingController();
  final TextEditingController _indirizzoNomeCtrl    = TextEditingController();
  final TextEditingController _civicoCtrl           = TextEditingController();
  final TextEditingController _cittaResidenzaCtrl   = TextEditingController();
  final TextEditingController _provResidenzaCtrl    = TextEditingController();
  final TextEditingController _capCtrl              = TextEditingController();
  final TextEditingController _emailCtrl            = TextEditingController();
  final TextEditingController _telefonoCtrl         = TextEditingController();

  int _currentStep2CardIndex = 0;
  
  final List<WizardEnrollmentRowData> _enrollmentRows = [];
  final List<WizardSchoolRowData>     _schoolRows     = [];

  final TextEditingController _scadenzaCertificatoCtrl = TextEditingController();
  String?                     _tipoCorso;
  final TextEditingController _ibanCtrl                = TextEditingController();
  String?                     _tipoCollaborazione;
  final TextEditingController _studiScolasticiCtrl     = TextEditingController();

  String?                     _modalitaPagamento;
  final TextEditingController _altraModalitaPagamentoCtrl = TextEditingController();

  bool                         _aderisceSostegnoPsicologico = false;
  final TextEditingController  _dataInizioSostegnoPsicologicoCtrl = TextEditingController
  (
    text: '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
  );

  final TextEditingController _contattoEmergenzaNomeCtrl     = TextEditingController();
  final TextEditingController _contattoEmergenzaTelefonoCtrl = TextEditingController();
  final TextEditingController _allergieCtrl                  = TextEditingController();
  final TextEditingController _farmaciCtrl                   = TextEditingController();

  String?                     _tipoCertificazione = 'No';
  final TextEditingController _altraCertificazioneCtrl        = TextEditingController();
  bool                         _presaVisioneIncontriPsicologa = false;

  bool _statutoAccettato              = false;
  bool _regolamentoAccettato          = false;
  bool _videosorveglianzaPresaVisione = false;
  bool _consensoDatiParticolari       = false;
  bool _consensoNewsletter            = false;

  //DefaultNo_IlMinoreVaPrelevatoDaUnGenitoreSalvoDiversaIndicazione_CoerenteConServerDefaultFalse
  bool _uscitaAnticipata = false;

  final TextEditingController _searchSubjectsCtrl         = TextEditingController();
  String                      _searchSubjectsText         = '';
  String                      _sortSubjectsBy             = 'name_asc';
  String?                     _filterSubjectsArea;
  final Map<int, bool>        _subjectToggles             = {};
  final Map<int, Set<int>>    _selectedProgramsForSubject = {};

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
    _nazioneNascitaCtrl.dispose();
    _tipoViaCtrl.dispose();
    _indirizzoNomeCtrl.dispose();
    _civicoCtrl.dispose();
    _cittaResidenzaCtrl.dispose();
    _provResidenzaCtrl.dispose();
    _capCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _scadenzaCertificatoCtrl.dispose();
    _ibanCtrl.dispose();
    _studiScolasticiCtrl.dispose();
    _altraModalitaPagamentoCtrl.dispose();
    _dataInizioSostegnoPsicologicoCtrl.dispose();
    _contattoEmergenzaNomeCtrl.dispose();
    _contattoEmergenzaTelefonoCtrl.dispose();
    _allergieCtrl.dispose();
    _farmaciCtrl.dispose();
    _altraCertificazioneCtrl.dispose();
    _searchSubjectsCtrl.dispose();
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

  String? _toIsoDate(String? itaDate) 
  {
    if (itaDate == null || itaDate.isEmpty) return null;
    final parts = itaDate.split('/');
    if (parts.length != 3) return null;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
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
      _nazioneNascitaCtrl.text = _nazioneNascitaCtrl.text.trim();
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
      addError('cf', 'Codice fiscale non valido', 0);
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
          int age = now.year - date.year;
          if (now.month < date.month || (now.month == date.month && now.day < date.day)) 
          {
            age--;
          }
          if (age >= 18) 
          {
            addError('dataNascita', 'La persona creata tramite questo menù deve essere minorenne', 1);
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

    if (_nazioneNascitaCtrl.text.isEmpty) addError('nazioneNascita', 'Campo obbligatorio', 1);

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
      addError('cap', 'Deve contenere 5 numeri', 2);
    }

    if (_emailCtrl.text.isNotEmpty && !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(_emailCtrl.text)) 
    {
      addError('email', 'Formato indirizzo email non valido', 3);
    }

    if (_telefonoCtrl.text.isNotEmpty && !RegExp(r'^\d+$').hasMatch(_telefonoCtrl.text)) 
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

  Future<bool> _checkCodiceFiscaleEsistente() async 
  {
    setState(() => _isCheckingCf = true);

    try 
    {
      final bool esiste = await ApiService().checkFiscalCodeExists(_cfCtrl.text.trim().toUpperCase());

      if (esiste) 
      {
        setState(() 
        {
          _formErrors['cf']      = 'Codice fiscale già presente';
          _card1MovingForward    = 0 >= _currentFormCardIndex;
          _currentFormCardIndex  = 0;
        });

        if (mounted) 
        {
          CustomSnackBar.show(context: context, message: 'Esiste già una persona con questo codice fiscale.', isError: true);
        }
      }

      return esiste;
    } 
    catch (_) 
    {
      if (mounted) 
      {
        CustomSnackBar.show(context: context, message: 'Impossibile verificare il codice fiscale. Riprova.', isError: true);
      }
      return true;
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() => _isCheckingCf = false);
      }
    }
  }

  bool _validateDatiSpecifici() 
  {
    _scadenzaCertificatoCtrl.text          = _scadenzaCertificatoCtrl.text.trim();
    _ibanCtrl.text                         = _ibanCtrl.text.replaceAll(' ', '').toUpperCase();
    _studiScolasticiCtrl.text              = _studiScolasticiCtrl.text.trim();
    _altraModalitaPagamentoCtrl.text       = _altraModalitaPagamentoCtrl.text.trim();
    _dataInizioSostegnoPsicologicoCtrl.text = _dataInizioSostegnoPsicologicoCtrl.text.trim();
    _contattoEmergenzaNomeCtrl.text        = _contattoEmergenzaNomeCtrl.text.trim();
    _contattoEmergenzaTelefonoCtrl.text    = _contattoEmergenzaTelefonoCtrl.text.replaceAll(' ', '');
    _allergieCtrl.text                     = _allergieCtrl.text.trim();
    _farmaciCtrl.text                      = _farmaciCtrl.text.trim();
    _altraCertificazioneCtrl.text          = _altraCertificazioneCtrl.text.trim();

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

    final bool isStaff    = _selectedRoles.contains('DOCENTE');
    final bool isCorsista = _selectedRoles.contains('CORSISTA');
    final bool isStudente = _selectedRoles.contains('STUDENTE');

    int currentMappedIndex = 0;

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
        addError('enrollmentYear_$i', 'Obbligatorio', currentMappedIndex);
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
          addError('enrollmentYear_$i', 'Anno futuro non permesso', currentMappedIndex);
          showFutureYearError = true;
        }
        else
        {
          yearValid = true;
        }
      }
      
      if (row.dateCtrl.text.trim().isEmpty) 
      {
        addError('enrollmentDate_$i', 'Obbligatorio', currentMappedIndex);
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
    if (isStudente || isCorsista)
    {
      if (_modalitaPagamento == 'Altro' && _altraModalitaPagamentoCtrl.text.isEmpty)
      {
        addError('altraModalitaPagamento', 'Specificare la modalità', currentMappedIndex);
      }
    }
    currentMappedIndex++;

    if (isStudente || isCorsista)
    {
      currentMappedIndex++;
    }

    //DisponibileAChiunqueSiaAssociato_QuiSempreVeroPerDefinizioneDelDialog
    if (_aderisceSostegnoPsicologico)
    {
      if (_dataInizioSostegnoPsicologicoCtrl.text.isEmpty)
      {
        addError('dataInizioSostegnoPsicologico', 'Campo obbligatorio', currentMappedIndex);
      }
      else if (!_isValidDate(_dataInizioSostegnoPsicologicoCtrl.text))
      {
        addError('dataInizioSostegnoPsicologico', 'Formato data non valido', currentMappedIndex);
      }
    }
    currentMappedIndex++;

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
      if (_tipoCorso == null) 
      {
        addError('tipoCorso', 'Campo obbligatorio', currentMappedIndex);
      }
      currentMappedIndex++;
    }
    
    if (isStudente) 
    {
      if (_tipoCertificazione == 'Altro' && _altraCertificazioneCtrl.text.isEmpty)
      {
        addError('altraCertificazione', 'Specificare il tipo', currentMappedIndex);
      }
      if (_tipoCertificazione != 'No' && !_presaVisioneIncontriPsicologa)
      {
        addError('presaVisioneIncontri', 'Presa visione obbligatoria', currentMappedIndex);
      }
      currentMappedIndex++;
    }

    if (isStudente)
    {
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

    //SempreVero_UnMinoreCreatoQuiEPerDefinizioneMinorenne_NessunControllo_IsMinor_Necessario
    //TuttiICampiSonoFacoltativi_NessunaValidazioneRichiesta_CoerenteConSezione10DelModuloCartaceo
    currentMappedIndex++;

    if (!_statutoAccettato)
    {
      addError('statutoAccettato', 'Presa visione obbligatoria', currentMappedIndex);
    }
    if (!_regolamentoAccettato)
    {
      addError('regolamentoAccettato', 'Accettazione obbligatoria', currentMappedIndex);
    }
    if (!_videosorveglianzaPresaVisione)
    {
      addError('videosorveglianzaPresaVisione', 'Presa visione obbligatoria', currentMappedIndex);
    }
    if (!_consensoDatiParticolari)
    {
      addError('consensoDatiParticolari', 'Consenso obbligatorio', currentMappedIndex);
    }
    if (!_consensoNewsletter)
    {
      addError('consensoNewsletter', 'Consenso obbligatorio', currentMappedIndex);
    }
    currentMappedIndex++;

    setState(() 
    {
      _formErrors = newErrors;
      if (!isValid && firstInvalidCard != null) 
      {
        _card2MovingForward    = firstInvalidCard! >= _currentStep2CardIndex;
        _currentStep2CardIndex = firstInvalidCard!;
      }
    });

    if (!isValid) 
    {
      if (showFutureYearError)
      {
        CustomSnackBar.show(context: context, message: 'Non è possibile inserire iscrizioni per anni futuri.', isError: true);
      }
      else
      {
        CustomSnackBar.show(context: context, message: 'Ci sono errori nei dati inseriti. Correggi i campi.', isError: true);
      }
    }

    return isValid;
  }

  void _submitForm()
  {
    final List<String> finalRoles = _selectedRoles.toList();
    if (_involvementType == 1) 
    {
      finalRoles.add('ASSOCIATO');
    } 
    else if (!finalRoles.contains('GENITORE')) 
    {
      finalRoles.add('ASSOCIATO');
    }
    
    List<Map<String, dynamic>> membershipsData = [];
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

    //QuiIlMemberEsisteSempre_NonSoloQuandoMembershipsDataNonEVuoto_PortaConsensi_PagamentoESicurezzaMinore
    String? paymentMethod;
    if (_modalitaPagamento == 'Contanti') paymentMethod = 'CASH';
    if (_modalitaPagamento == 'Bonifico bancario') paymentMethod = 'BANK_TRANSFER';
    if (_modalitaPagamento == 'Altro') paymentMethod = 'OTHER';

    final Map<String, dynamic> memberData = 
    {
      "memberships":                       membershipsData,
      "payment_method":                    paymentMethod,
      "payment_method_other":              paymentMethod == 'OTHER' ? _altraModalitaPagamentoCtrl.text.trim() : null,
      "statute_acknowledged":              _statutoAccettato,
      "regulation_acknowledged":           _regolamentoAccettato,
      "video_surveillance_acknowledged":   _videosorveglianzaPresaVisione,
      "special_category_data_consent":     _consensoDatiParticolari,
      "newsletter_consent":                _consensoNewsletter,
      "consents_signed_at":                DateTime.now().toIso8601String().split('T').first,
      "emergency_contact_name":            _contattoEmergenzaNomeCtrl.text.isNotEmpty ? _contattoEmergenzaNomeCtrl.text.trim() : null,
      "emergency_contact_phone":           _contattoEmergenzaTelefonoCtrl.text.isNotEmpty ? _contattoEmergenzaTelefonoCtrl.text.trim() : null,
      "allergies_notes":                   _allergieCtrl.text.isNotEmpty ? _allergieCtrl.text.trim() : null,
      "medications_notes":                 _farmaciCtrl.text.isNotEmpty ? _farmaciCtrl.text.trim() : null,
    };

    Map<String, dynamic>? staffData;
    Map<String, dynamic>? teacherData;
    Map<String, dynamic>? courseParticipantData;
    Map<String, dynamic>? psychologicalSupportData;
    Map<String, dynamic>? studentData;

    if (_selectedRoles.contains('DOCENTE')) 
    {
      String collType = 'VOLUNTEER';
      if (_tipoCollaborazione == 'Retribuito') collType = 'PAID';
      if (_tipoCollaborazione == 'FSL (Ex PCT0)') collType = 'PCTO';

      staffData = 
      {
        "collaboration_type": collType,
        "iban":               _ibanCtrl.text.isNotEmpty ? _ibanCtrl.text.trim().toUpperCase() : null,
      };

      teacherData = 
      {
        "school_education":     _studiScolasticiCtrl.text.isNotEmpty ? _studiScolasticiCtrl.text.trim() : null,
        // Un minore non può per definizione avere un percorso universitario: campo non richiesto in questo wizard.
        "university_education": null,
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

    if (_selectedRoles.contains('CORSISTA')) 
    {
      String? courseType;
      if (_tipoCorso == 'Yoga') courseType = 'YOGA';
      if (_tipoCorso == 'Pilates') courseType = 'PILATES';

      courseParticipantData = 
      {
        "medical_certificate_expiration": _toIsoDate(_scadenzaCertificatoCtrl.text.trim()),
        "course_type":                    courseType,
      };
    }

    if (_aderisceSostegnoPsicologico)
    {
      psychologicalSupportData = 
      {
        "start_date": _dataInizioSostegnoPsicologicoCtrl.text.trim().split('/').reversed.join('-'),
      };
    }

    if (_selectedRoles.contains('STUDENTE')) 
    {
      String? certificationType;
      if (_tipoCertificazione == 'DSA') certificationType = 'DSA';
      if (_tipoCertificazione == 'BES') certificationType = 'BES';
      if (_tipoCertificazione == 'ADHD') certificationType = 'ADHD';
      if (_tipoCertificazione == 'Altro') certificationType = 'OTHER';

      studentData = 
      {
        "authorized_early_exit":                 _uscitaAnticipata,
        "certification_type":                    certificationType,
        "certification_other_detail":            certificationType == 'OTHER' ? _altraCertificazioneCtrl.text.trim() : null,
        "mandatory_psych_meetings_acknowledged": certificationType != null ? _presaVisioneIncontriPsicologa : false,
        "school_enrollments": _schoolRows.map((r) => 
        {
          "start_year":                 int.parse(r.yearCtrl.text.trim()),
          "school_id":                  r.selectedSchool!.id,
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
        "birth_date":              _toIsoDate(_dataNascitaCtrl.text.trim()),
        "birth_city":              _cittaNascitaCtrl.text.trim(),
        "birth_nation":            _nazioneNascitaCtrl.text.trim(),
        "birth_province":          _provNascitaCtrl.text.trim().toUpperCase(),
        "residence_type":          _tipoViaCtrl.text.trim(),
        "residence_address":       _indirizzoNomeCtrl.text.trim(),
        "residence_street_number": _civicoCtrl.text.trim(),
        "residence_city":          _cittaResidenzaCtrl.text.trim(),
        "residence_province":      _provResidenzaCtrl.text.trim().toUpperCase(),
        "postal_code":             _capCtrl.text.trim(),
        "email":                   _emailCtrl.text.isNotEmpty ? _emailCtrl.text.trim() : null,
        "phone":                   _telefonoCtrl.text.isNotEmpty ? _telefonoCtrl.text.replaceAll(' ', '') : null,
      },
      "roles":                       finalRoles,
      "member_data":                 memberData,
      "staff_data":                  staffData,
      "teacher_data":                teacherData,
      "course_participant_data":     courseParticipantData,
      "psychological_support_data":  psychologicalSupportData,
      "student_data":                studentData,
      "relationships": 
      {
        "minors_tax_codes":  [], 
        "parents_tax_codes": [], 
      }
    };

    final newMinor = PersonItem
    (
      fiscalCode: _cfCtrl.text.trim().toUpperCase(),
      firstName:  _nomeCtrl.text.trim(),
      lastName:   _cognomeCtrl.text.trim(),
      roles:      finalRoles.map((r) => r.substring(0, 1).toUpperCase() + r.substring(1).toLowerCase()).toList(),
      createdAt:  DateTime.now(),
      city:       _cittaResidenzaCtrl.text.trim(),
      birthDate:  DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text.trim()),
    );

    if (mounted) 
    {
      Navigator.of(context).pop({'person': newMinor, 'payload': payload, 'imageBytes': _fotoProfilo});
    }
  }

  Future<void> _onNext() async 
  {
    if (_currentStep == 0) 
    {
      if (_involvementType == -1) 
      {
        CustomSnackBar.show(context: context, message: 'Seleziona una categoria per procedere.', isError: true);
        return;
      }
      
      if (_involvementType == 1) 
      {
        _selectedRoles.clear(); 
        setState(() 
        {
          _movingForward        = true;
          _currentStep          = 2;
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
      if (_selectedRoles.isEmpty) 
      {
        CustomSnackBar.show(context: context, message: 'Seleziona almeno un ruolo per procedere.', isError: true);
        return;
      }
      setState(() 
      { 
        _movingForward        = true; 
        _currentStep          = 2; 
        _currentFormCardIndex = 0; 
        _card1MovingForward   = true; 
      });
      return;
    }

    if (_currentStep == 2) 
    {
      if (!_validateDatiGenerali()) return;

      final bool cfEsistente = await _checkCodiceFiscaleEsistente();
      if (cfEsistente) return;
      
      if (_activeStep2Cards.isEmpty)
      {
        _submitForm();
      }
      else
      {
        setState(() 
        { 
          _movingForward         = true; 
          _currentStep           = 3; 
          _currentStep2CardIndex = 0; 
          _card2MovingForward    = true; 
        });
      }
      return;
    }

    if (_currentStep == 3) 
    {
      if (!_validateDatiSpecifici()) return;
      
      if (_selectedRoles.contains('DOCENTE')) 
      {
        setState(() 
        { 
          _movingForward = true; 
          _currentStep   = 4; 
        });
      } 
      else 
      {
        _submitForm();
      }
      return;
    }

    if (_currentStep == 4) 
    {
      bool hasAtLeastOneSubject = _subjectToggles.values.any((isSelected) => isSelected == true);
      
      if (!hasAtLeastOneSubject) 
      {
        CustomSnackBar.show(context: context, message: 'Seleziona almeno una disciplina insegnata.', isError: true);
        return;
      }
      
      _submitForm();
      return;
    }
  }

  void _onBack() 
  {
    setState(() => _movingForward = false);
    if (_currentStep == 4) setState(() => _currentStep = 3);
    else if (_currentStep == 3) setState(() => _currentStep = 2);
    else if (_currentStep == 2) 
    {
      if (_involvementType == 1) 
      {
        setState(() => _currentStep = 0);
      }
      else
      {
        setState(() => _currentStep = 1);
      }
    }
    else if (_currentStep == 1) setState(() => _currentStep = 0);
  }

  Widget _buildStep0Type() 
  {
    return SizedBox
    (
      key:   const ValueKey('step0_m'),
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
                Text('Qual è il rapporto del minore con l\'Associazione?', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                const SizedBox(height: 8),
                Text('Scegli la categoria che descrive meglio la sua posizione.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
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
                      subtitle:   'Partecipa alla vita dell\'Associazione e svolge uno o più ruoli.', 
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
      key:   const ValueKey('step1_m'),
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
                  'Quali ruoli ricopre il minore all\'interno dell\'Associazione?',
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

  List<Widget> get _activeStep2Cards 
  {
    final List<Widget> cards = [];
    
    cards.add(_buildFormCardIscrizione());

    if (_selectedRoles.contains('STUDENTE') || _selectedRoles.contains('CORSISTA'))
    {
      cards.add(_buildFormCardModalitaPagamento());
    }

    //DisponibileAChiunqueSiaAssociato_QuiSempreVeroPerDefinizioneDelDialog
    cards.add(_buildFormCardSostegnoPsicologico());

    if (_selectedRoles.contains('DOCENTE')) 
    {
      cards.add(WizardFormSectionCard
      (
        title:       'Dati Collaborazione',
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
              items:     const ['Volontario', 'Retribuito', 'FSL (Ex PCT0)'],
              hint:      'Seleziona',
              errorText: _formErrors['tipoCollaborazione'],
              onChanged: (val) => setState(() 
              { 
                _tipoCollaborazione = val; 
                _formErrors.remove('tipoCollaborazione'); 
              }),
            ),
          ),
        ]
      ));
      
      cards.add(WizardFormSectionCard
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
        ]
      ));
    }

    if (_selectedRoles.contains('CORSISTA')) 
    {
      cards.add(WizardFormSectionCard
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
            inputWidget: WizardAnimatedOverlayDropdown
            (
              value:     _tipoCorso,
              items:     const ['Yoga', 'Pilates'],
              hint:      'Seleziona',
              errorText: _formErrors['tipoCorso'],
              onChanged: (val) => setState(() 
              { 
                _tipoCorso = val; 
                _formErrors.remove('tipoCorso'); 
              }),
            ),
          ),
        ]
      ));
    }

    if (_selectedRoles.contains('STUDENTE')) 
    {
      cards.add(WizardFormSectionCard
      (
        title:       'Dettagli Studente',
        leadingIcon: const WizardStaticAvatar(icon: Icons.menu_book_outlined),
        children: 
        [
          WizardFormInputRow
          (
            label:       'Uscita anticipata',
            inputWidget: Align
            (
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch
              (
                value:     _uscitaAnticipata,
                onChanged: (val) => setState(() => _uscitaAnticipata = val),
              ),
            ),
          ),
          const SizedBox(height: 16),
          WizardFormInputRow
          (
            label:       'Certificazione',
            inputWidget: WizardAnimatedOverlayDropdown
            (
              value:     _tipoCertificazione,
              items:     const ['No', 'DSA', 'BES', 'ADHD', 'Altro'],
              hint:      'Seleziona',
              errorText: _formErrors['tipoCertificazione'],
              onChanged: (val) => setState(() 
              { 
                _tipoCertificazione = val; 
                _formErrors.remove('tipoCertificazione'); 
                _formErrors.remove('presaVisioneIncontri');
              }),
            ),
          ),
          if (_tipoCertificazione == 'Altro') ...[
            const SizedBox(height: 16),
            WizardFormInputRow
            (
              label:       'Specifica',
              inputWidget: WizardAnimatedTextField
              (
                controller: _altraCertificazioneCtrl, 
                hint:       'Inserisci il tipo', 
                errorText:  _formErrors['altraCertificazione'],
                onChanged:  (_) => setState(() => _formErrors.remove('altraCertificazione')),
              ),
            ),
          ],
          if (_tipoCertificazione != 'No') ...[
            const SizedBox(height: 16),
            WizardFormInputRow
            (
              label:       'Presa visione incontri',
              inputWidget: Align
              (
                alignment: Alignment.centerLeft,
                child: WizardYesNoSwitch
                (
                  value:     _presaVisioneIncontriPsicologa,
                  isError:   _formErrors['presaVisioneIncontri'] != null,
                  onChanged: (val) => setState(() 
                  {
                    _presaVisioneIncontriPsicologa = val;
                    _formErrors.remove('presaVisioneIncontri');
                  }),
                ),
              ),
            ),
          ],
        ]
      ));

      cards.add(_buildFormCardIscrizioniScolastiche());
    }

    //SempreVero_UnMinoreCreatoQuiEPerDefinizioneMinorenne
    cards.add(_buildFormCardSicurezzaMinore());

    //SempreUltima_RispecchiaLeDichiarazioniInFondoAlModuloCartaceo
    cards.add(_buildFormCardConsensi());

    return cards;
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
                int maxYear = 0;
                for (var r in _enrollmentRows)
                {
                  int y = int.tryParse(r.yearCtrl.text) ?? 0;
                  if (y > maxYear) maxYear = y;
                }
                lastYear = maxYear > 0 ? maxYear : lastYear;
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

  Widget _buildFormCardModalitaPagamento()
  {
    return WizardFormSectionCard
    (
      title:       'Modalità di Pagamento',
      leadingIcon: const WizardStaticAvatar(icon: Icons.payments_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Modalità di pagamento',
          inputWidget: WizardAnimatedOverlayDropdown
          (
            value:     _modalitaPagamento,
            items:     const ['Contanti', 'Bonifico bancario', 'Altro'],
            hint:      'Seleziona',
            errorText: _formErrors['modalitaPagamento'],
            onChanged: (val) => setState(() 
            { 
              _modalitaPagamento = val; 
              _formErrors.remove('modalitaPagamento'); 
            }),
          ),
        ),
        if (_modalitaPagamento == 'Altro') ...[
          const SizedBox(height: 16),
          WizardFormInputRow
          (
            label:       'Specifica modalità',
            inputWidget: WizardAnimatedTextField
            (
              controller: _altraModalitaPagamentoCtrl, 
              hint:       'Inserisci la modalità', 
              errorText:  _formErrors['altraModalitaPagamento'],
              onChanged:  (_) => setState(() => _formErrors.remove('altraModalitaPagamento')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormCardSostegnoPsicologico()
  {
    return WizardFormSectionCard
    (
      title:       'Sostegno Psicologico',
      leadingIcon: const WizardStaticAvatar(icon: Icons.psychology_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Aderisce al servizio',
          inputWidget: Align
          (
            alignment: Alignment.centerLeft,
            child: WizardYesNoSwitch
            (
              value:     _aderisceSostegnoPsicologico,
              onChanged: (val) => setState(() => _aderisceSostegnoPsicologico = val),
            ),
          ),
        ),
        if (_aderisceSostegnoPsicologico) ...[
          const SizedBox(height: 16),
          WizardFormInputRow
          (
            label:       'Data di inizio',
            inputWidget: WizardAnimatedTextField
            (
              controller:      _dataInizioSostegnoPsicologicoCtrl,
              hint:            'gg/mm/aaaa',
              keyboardType:    TextInputType.number,
              inputFormatters: [WizardDateInputFormatter()],
              errorText:       _formErrors['dataInizioSostegnoPsicologico'],
              onChanged:       (_) => setState(() => _formErrors.remove('dataInizioSostegnoPsicologico')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormCardIscrizioniScolastiche()
  {
    return WizardFormSectionCard
    (
      title:       'Iscrizioni Scolastiche',
      leadingIcon: const WizardStaticAvatar(icon: Icons.school_outlined),
      children: 
      [
        ...List.generate(_schoolRows.length, (index)
        {
          final r = _schoolRows[index];
          final List<String> schoolNames = widget.allSchools.map((s) => '${s.name} (${s.city})').toList();
          
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
                  if (widget.allPrograms.any((allP) => allP.name == p.name) && !programNames.contains(p.name)) 
                  {
                    programNames.add(p.name);
                  }

                  if (r.selectedProgram != null && p.name == r.selectedProgram!.name)
                  {
                    final globalProgram = widget.allPrograms.firstWhere((gp) => gp.id == r.selectedProgram!.id);

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

          //StessoCriterioResponsivoDiPersonWizardPage_ImpilaSottoSoglia_TrovatoMancanteInUnControlloSuccessivo
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
                r.selectedSchool  = widget.allSchools.firstWhere((s) => '${s.name} (${s.city})' == val);
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
                r.selectedProgram = widget.allPrograms.firstWhere((p) => p.name == val);
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

  Widget _buildFormCardSicurezzaMinore()
  {
    return WizardFormSectionCard
    (
      title:       'Sicurezza del Minore',
      leadingIcon: const WizardStaticAvatar(icon: Icons.health_and_safety_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Contatto emergenza',
          inputWidget: WizardAnimatedTextField
          (
            controller: _contattoEmergenzaNomeCtrl, 
            hint:       'Nome e cognome', 
            errorText:  _formErrors['contattoEmergenzaNome'],
            onChanged:  (_) => setState(() => _formErrors.remove('contattoEmergenzaNome')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Telefono emergenza',
          inputWidget: WizardAnimatedTextField
          (
            controller:   _contattoEmergenzaTelefonoCtrl, 
            hint:         'Es. 3331234567', 
            keyboardType: TextInputType.phone,
            errorText:    _formErrors['contattoEmergenzaTelefono'],
            onChanged:    (_) => setState(() => _formErrors.remove('contattoEmergenzaTelefono')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Allergie / intolleranze',
          inputWidget: WizardAnimatedTextField
          (
            controller: _allergieCtrl, 
            hint:       'Es. Polline, lattosio', 
            errorText:  _formErrors['allergie'],
            onChanged:  (_) => setState(() => _formErrors.remove('allergie')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Farmaci / note',
          inputWidget: WizardAnimatedTextField
          (
            controller: _farmaciCtrl, 
            hint:       'Es. Ventolin al bisogno', 
            errorText:  _formErrors['farmaci'],
            onChanged:  (_) => setState(() => _formErrors.remove('farmaci')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardConsensi()
  {
    return WizardFormSectionCard
    (
      title:       'Dichiarazioni e Consensi',
      leadingIcon: const WizardStaticAvatar(icon: Icons.fact_check_outlined),
      children: 
      [
        WizardFormInputRow
        (
          label:       'Statuto',
          inputWidget: Padding
          (
            padding: const EdgeInsets.only(left: 16),
            child: Align
            (
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch
              (
                value:     _statutoAccettato,
                isError:   _formErrors['statutoAccettato'] != null,
                onChanged: (val) => setState(() 
                {
                  _statutoAccettato = val;
                  _formErrors.remove('statutoAccettato');
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Regolamento',
          inputWidget: Padding
          (
            padding: const EdgeInsets.only(left: 16),
            child: Align
            (
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch
              (
                value:     _regolamentoAccettato,
                isError:   _formErrors['regolamentoAccettato'] != null,
                onChanged: (val) => setState(() 
                {
                  _regolamentoAccettato = val;
                  _formErrors.remove('regolamentoAccettato');
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Videosorveglianza',
          inputWidget: Padding
          (
            padding: const EdgeInsets.only(left: 16),
            child: Align
            (
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch
              (
                value:     _videosorveglianzaPresaVisione,
                isError:   _formErrors['videosorveglianzaPresaVisione'] != null,
                onChanged: (val) => setState(() 
                {
                  _videosorveglianzaPresaVisione = val;
                  _formErrors.remove('videosorveglianzaPresaVisione');
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Dati particolari',
          inputWidget: Padding
          (
            padding: const EdgeInsets.only(left: 16),
            child: Align
            (
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch
              (
                value:     _consensoDatiParticolari,
                isError:   _formErrors['consensoDatiParticolari'] != null,
                onChanged: (val) => setState(() 
                {
                  _consensoDatiParticolari = val;
                  _formErrors.remove('consensoDatiParticolari');
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow
        (
          label:       'Notiziari periodici',
          inputWidget: Padding
          (
            padding: const EdgeInsets.only(left: 16),
            child: Align
            (
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch
              (
                value:     _consensoNewsletter,
                isError:   _formErrors['consensoNewsletter'] != null,
                onChanged: (val) => setState(() 
                {
                  _consensoNewsletter = val;
                  _formErrors.remove('consensoNewsletter');
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepWidget(int step) 
  {
    if (step == 0) return _buildStep0Type();
    if (step == 1) return _buildStep1Roles();
    
    if (step == 2) 
    {
      Widget currentCard = const SizedBox.shrink();
      
      switch (_currentFormCardIndex) 
      {
        case 0:
          currentCard = WizardFormSectionCard
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
          break;
        case 1:
          currentCard = WizardFormSectionCard
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
              const SizedBox(height: 16),
              WizardFormInputRow
              (
                label:       'Nazione di nascita',
                inputWidget: WizardAnimatedTextField
                (
                  controller: _nazioneNascitaCtrl, 
                  hint:       'Es. Italia', 
                  errorText:  _formErrors['nazioneNascita'], 
                  onChanged:  (_) => setState(() => _formErrors.remove('nazioneNascita')),
                ),
              ),
            ],
          );
          break;
        case 2:
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
          break;
        case 3:
          currentCard = WizardFormSectionCard
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
          break;
      }

      return SizedBox
      (
        key:   const ValueKey('step2_m'),
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
                  Text('Informazioni Personali Minore', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  const SizedBox(height: 8),
                  Text('Compila i dati del minore.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
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
                      Offset beginOffset = _card1MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
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
                      Offset beginOffset = _card1MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
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
                                WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentFormCardIndex == 0, onTap: () => setState(() { _card1MovingForward = false; _currentFormCardIndex--; })),
                                const SizedBox(width: 24),
                                WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentFormCardIndex == 3, onTap: () => setState(() { _card1MovingForward = true; _currentFormCardIndex++; })),
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
                            WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentFormCardIndex == 0, onTap: () => setState(() { _card1MovingForward = false; _currentFormCardIndex--; })),
                            const SizedBox(width: 32),
                            Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: desktopAnimatedCard)),
                            const SizedBox(width: 32),
                            WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentFormCardIndex == 3, onTap: () => setState(() { _card1MovingForward = true; _currentFormCardIndex++; })),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (step == 3) 
    {
      final cards = _activeStep2Cards;
      final Widget currentCardStep3 = cards.isNotEmpty ? cards[_currentStep2CardIndex] : const SizedBox.shrink();

      return SizedBox
      (
        key:   const ValueKey('step3_m'),
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
                  Text('Informazioni Associative Minore', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
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
                    duration:       const Duration(milliseconds: 300),
                    switchInCurve:  Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder:  (currentChild, previousChildren) => Stack(alignment: Alignment.center, children: [...previousChildren, if (currentChild != null) currentChild]),
                    transitionBuilder: (child, animation) 
                    {
                      final isEntering   = (child.key as ValueKey<int>).value == _currentStep2CardIndex;
                      Offset beginOffset = _card2MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                      return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                    },
                    child: KeyedSubtree(key: ValueKey(_currentStep2CardIndex), child: currentCardStep3),
                  );

                  final Widget compactAnimatedCards = AnimatedSwitcher
                  (
                    duration:       const Duration(milliseconds: 300),
                    switchInCurve:  Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder:  (currentChild, previousChildren) => Stack(alignment: Alignment.topCenter, children: [...previousChildren, if (currentChild != null) currentChild]),
                    transitionBuilder: (child, animation) 
                    {
                      final isEntering   = (child.key as ValueKey<int>).value == _currentStep2CardIndex;
                      Offset beginOffset = _card2MovingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                      return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                    },
                    child: KeyedSubtree
                    (
                      key:   ValueKey(_currentStep2CardIndex),
                      //NoFixedHeightAnymore_TakesWhateverHeightTheOuterExpandedGivesIt
                      child: SizedBox
                      (
                        width:  constraints.maxWidth,
                        child:  SingleChildScrollView(child: currentCardStep3),
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
                                WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentStep2CardIndex == 0, onTap: () => setState(() { _card2MovingForward = false; _currentStep2CardIndex--; })),
                                const SizedBox(width: 24),
                                WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentStep2CardIndex >= cards.length - 1, onTap: () => setState(() { _card2MovingForward = true; _currentStep2CardIndex++; })),
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
                            WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentStep2CardIndex == 0, onTap: () => setState(() { _card2MovingForward = false; _currentStep2CardIndex--; })),
                            const SizedBox(width: 32),
                            Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: desktopAnimatedCards)),
                            const SizedBox(width: 32),
                            WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentStep2CardIndex >= cards.length - 1, onTap: () => setState(() { _card2MovingForward = true; _currentStep2CardIndex++; })),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (step == 4) 
    {
      List<AssociationSubjectItem> validSubjects = widget.allSubjects.where((subject) 
      {
        List<StudyProgramItem> programs = [];
        
        for (final prog in widget.allPrograms) 
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
          
          if (hasMatch) programs.add(prog);
        }
        if (programs.isEmpty) return false;
        
        final query         = _searchSubjectsText.toLowerCase();
        final matchesSearch = subject.name.toLowerCase().contains(query);
        final matchesArea   = _filterSubjectsArea == null || subject.area == _filterSubjectsArea;
        
        return matchesSearch && matchesArea;
      }).toList();

      validSubjects.sort((a, b) 
      {
        if (_sortSubjectsBy == 'name_asc') return a.name.compareTo(b.name);
        if (_sortSubjectsBy == 'name_desc') return b.name.compareTo(a.name);
        if (_sortSubjectsBy == 'date_asc') return a.createdAt.compareTo(b.createdAt);
        if (_sortSubjectsBy == 'date_desc') return b.createdAt.compareTo(a.createdAt);
        return 0;
      });

      return SizedBox
      (
        key:   const ValueKey('step4_m'),
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
                  Text('Discipline Insegnate', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  const SizedBox(height: 8),
                  Text('Seleziona le discipline in cui il minore farà da tutor.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold_NotAlwaysSplit
            //ErroreCorretto_LaVersionePrecedenteSpezzavaSempreLaRigaAncheSuSchermiLarghi
            Center
            (
              child: ConstrainedBox
              (
                constraints: const BoxConstraints(maxWidth: 500),
                child: _ResponsiveSearchFilterRow
                (
                  breakpoint: 380,
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
                      ]
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded
            (
              child: SingleChildScrollView
              (
                padding: const EdgeInsets.only(bottom: 40),
                child: Wrap
                (
                  spacing:    16, 
                  runSpacing: 16, 
                  alignment:  WrapAlignment.center,
                  children: validSubjects.map((subject) 
                  {
                    final isSelected    = _subjectToggles[subject.id] ?? false;
                    final selectedCount = (_selectedProgramsForSubject[subject.id] ?? {}).length;
                    
                    return WizardSubjectGridCard
                    (
                      subject:       subject, 
                      isSelected:    isSelected, 
                      selectedCount: selectedCount,
                      onTap: () 
                      {
                        List<StudyProgramItem> programs = [];
                        
                        for (final prog in widget.allPrograms) 
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
                          
                          if (hasMatch) programs.add(prog);
                        }
                        
                        showGeneralDialog
                        (
                          context:            context, 
                          barrierDismissible: true, 
                          barrierLabel:       'Programs', 
                          barrierColor:       Colors.black.withValues(alpha: .15), 
                          transitionDuration: const Duration(milliseconds: 240),
                          pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
                          transitionBuilder:  (context, animation, secondaryAnimation, child) 
                          {
                            return BackdropFilter
                            (
                              filter: ImageFilter.blur(sigmaX: animation.value * 8.0, sigmaY: animation.value * 8.0),
                              child: FadeTransition
                              (
                                opacity: animation,
                                child: ScaleTransition
                                (
                                  scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
                                  child: WizardProgramsSelectionDialog
                                  (
                                    subject:         subject, 
                                    programs:        programs, 
                                    initialSelected: _selectedProgramsForSubject[subject.id] ?? {},
                                    onSave: (selected) 
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
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) 
  {
    bool isLastStep;
    
    if (_currentStep == 4) 
    {
      isLastStep = true;
    } 
    else if (_currentStep == 3 && !_selectedRoles.contains('DOCENTE')) 
    {
      isLastStep = true;
    } 
    else if (_currentStep == 2 && _activeStep2Cards.isEmpty && !_selectedRoles.contains('DOCENTE')) 
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
                          'Nuovo Minore',
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
                          final isEntering   = (child.key as ValueKey<String>).value == 'step${_currentStep}_m';
                          Offset beginOffset = _movingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                          
                          return FadeTransition
                          (
                            opacity: animation, 
                            child:   SlideTransition
                            (
                              position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), 
                              child:    child,
                            ),
                          );
                        },
                        child: _buildStepWidget(_currentStep),
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
                              onPressed:  () => Navigator.of(context).pop(),
                            )
                          : WizardOutlinedActionButton
                            (
                              text:      'INDIETRO', 
                              icon:      Icons.arrow_back_rounded, 
                              onPressed: _onBack,
                            ),
                      primaryButton: WizardAnimatedActionButton
                      (
                        text:       _isCheckingCf ? 'VERIFICA...' : (_isSubmitting ? 'SALVATAGGIO...' : (isLastStep ? 'CREA MINORE' : 'AVANTI')), 
                        icon:       isLastStep ? Icons.check_circle_outline : Icons.arrow_forward_rounded, 
                        baseColor:  const Color(0xFF003C82), 
                        hoverColor: const Color(0xFF004D99), 
                        onPressed:  (_isSubmitting || _isCheckingCf) ? () {} : _onNext,
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
}

//DecideRowVsColumnBasedOnActualAvailableWidth_NeverLetsTheButtonsStretchToFillTheSpace
//StessoCriterioDiPersonWizardPage_ConLarghezzaFissa200CoerenteConQuestoDialog
class _ResponsiveWizardBottomBar extends StatelessWidget
{
  final Widget secondaryButton;
  final Widget primaryButton;

  const _ResponsiveWizardBottomBar
  ({
    required this.secondaryButton,
    required this.primaryButton,
  });

  static const double _kButtonWidth = 200;
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
//AggiuntoInUnControlloSuccessivo_MancavaInQuestoFileNonostanteLaCard"DettagliStudente"LoUsi
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
                hint:       '',
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