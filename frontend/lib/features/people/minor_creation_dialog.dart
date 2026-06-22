import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/snackbar.dart';
import '../association/models/association_subject_item.dart';
import '../association/models/study_program_item.dart';
import '../association/models/school_item.dart';
import './models/person_item.dart';

import 'person_wizard_components.dart';

class MinorCreationDialog extends StatefulWidget {
  final List<SchoolItem>             allSchools;
  final List<StudyProgramItem>       allPrograms;
  final List<AssociationSubjectItem> allSubjects;

  const MinorCreationDialog({
    super.key,
    required this.allSchools,
    required this.allPrograms,
    required this.allSubjects,
  });

  @override
  State<MinorCreationDialog> createState() => _MinorCreationDialogState();
}

class _MinorCreationDialogState extends State<MinorCreationDialog> {
  int  _currentStep     = 0;
  int  _involvementType = -1;
  bool _movingForward   = true;

  final Set<String> _selectedRoles = {};
  
  final List<Map<String, dynamic>> _availableRoles = [
    {
      'id':    'STUDENTE', 
      'label': 'Frequenta i corsi', 
      'desc':  'Allievo beneficiario dei servizi dell\'associazione.', 
      'icon':  Icons.menu_book_outlined
    },
    {
      'id':    'CORSISTA', 
      'label': 'Corsi serali / brevi', 
      'desc':  'Partecipante ad attività extra (es. Yoga, Pilates).', 
      'icon':  Icons.self_improvement_rounded
    },
    {
      'id':    'DOCENTE', 
      'label': 'Insegna / Tutoraggio', 
      'desc':  'Fornisce supporto didattico attivo e ripetizioni.', 
      'icon':  Icons.school_outlined
    },
  ];

  int                 _currentFormCardIndex = 0; 
  Map<String, String> _formErrors           = {};
  Uint8List?          _fotoProfilo;

  final TextEditingController _nomeCtrl           = TextEditingController();
  final TextEditingController _cognomeCtrl        = TextEditingController();
  String?                     _sesso;
  final TextEditingController _cfCtrl             = TextEditingController();
  final TextEditingController _dataNascitaCtrl    = TextEditingController();
  final TextEditingController _cittaNascitaCtrl   = TextEditingController();
  final TextEditingController _provNascitaCtrl    = TextEditingController();
  final TextEditingController _tipoViaCtrl        = TextEditingController();
  final TextEditingController _indirizzoNomeCtrl  = TextEditingController();
  final TextEditingController _civicoCtrl         = TextEditingController();
  final TextEditingController _cittaResidenzaCtrl = TextEditingController();
  final TextEditingController _provResidenzaCtrl  = TextEditingController();
  final TextEditingController _capCtrl            = TextEditingController();
  final TextEditingController _emailCtrl          = TextEditingController();
  final TextEditingController _telefonoCtrl       = TextEditingController();

  int _currentStep2CardIndex = 0;
  final TextEditingController _annoPrimaIscrizioneCtrl = TextEditingController();
  final TextEditingController _dataIscrizioneCtrl      = TextEditingController();
  final TextEditingController _scadenzaCertificatoCtrl = TextEditingController();
  final TextEditingController _tipoCorsoCtrl           = TextEditingController();
  final TextEditingController _ibanCtrl                = TextEditingController();
  String?                     _tipoCollaborazione;
  final TextEditingController _studiScolasticiCtrl     = TextEditingController();
  final TextEditingController _studiUniversitariCtrl   = TextEditingController();

  String?           _uscitaAnticipata;
  SchoolItem?       _scuolaSelezionata;
  StudyProgramItem? _percorsoStudenteSelezionato;
  String?           _classeFrequentata;

  final TextEditingController _searchSubjectsCtrl         = TextEditingController();
  String                      _searchSubjectsText         = '';
  String                      _sortSubjectsBy             = 'name_asc';
  String?                     _filterSubjectsArea;
  final Map<int, bool>        _subjectToggles             = {};
  final Map<int, Set<int>>    _selectedProgramsForSubject = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _annoPrimaIscrizioneCtrl.text = now.year.toString();
    _dataIscrizioneCtrl.text      = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void dispose() {
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
    _annoPrimaIscrizioneCtrl.dispose();
    _dataIscrizioneCtrl.dispose();
    _scadenzaCertificatoCtrl.dispose();
    _tipoCorsoCtrl.dispose();
    _ibanCtrl.dispose();
    _studiScolasticiCtrl.dispose();
    _studiUniversitariCtrl.dispose();
    _searchSubjectsCtrl.dispose();
    super.dispose();
  }

  String get _currentSchoolYear {
    final now = DateTime.now();
    if (now.month < 9) {
      return '${now.year - 1}/${now.year}';
    } else {
      return '${now.year}/${now.year + 1}';
    }
  }

  bool _isValidDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return false;
      final day   = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year  = int.parse(parts[2]);
      final date  = DateTime(year, month, day);
      return date.year == year && date.month == month && date.day == day;
    } catch (_) {
      return false;
    }
  }

  bool _validateDatiGenerali() {
    setState(() {
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

    void addError(String field, String message, int cardIndex) {
      newErrors[field] = message;
      isValid          = false;
      if (firstInvalidCard == null || cardIndex < firstInvalidCard!) {
        firstInvalidCard = cardIndex;
      }
    }

    if (_nomeCtrl.text.isEmpty) addError('nome', 'Campo obbligatorio', 0);
    if (_cognomeCtrl.text.isEmpty) addError('cognome', 'Campo obbligatorio', 0);
    if (_sesso == null) addError('sesso', 'Campo obbligatorio', 0);
    if (_cfCtrl.text.isEmpty) {
      addError('cf', 'Campo obbligatorio', 0);
    } else if (!RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(_cfCtrl.text)) {
      addError('cf', 'Codice fiscale non valido', 0);
    }

    if (_dataNascitaCtrl.text.isEmpty) {
      addError('dataNascita', 'Campo obbligatorio', 1);
    } else {
      if (!_isValidDate(_dataNascitaCtrl.text)) {
        addError('dataNascita', 'Formato data non valido', 1);
      } else {
        final parts   = _dataNascitaCtrl.text.split('/');
        final date    = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final now     = DateTime.now();
        final minDate = DateTime(1900, 1, 1);
        
        if (date.isBefore(minDate) || date.isAfter(now)) {
          addError('dataNascita', 'Data di nascita non consentita', 1);
        } else {
          int age = now.year - date.year;
          if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
            age--;
          }
          if (age >= 18) {
            addError('dataNascita', 'Il minore deve avere meno di 18 anni', 1);
          }
        }
      }
    }
    
    if (_cittaNascitaCtrl.text.isEmpty) addError('cittaNascita', 'Campo obbligatorio', 1);
    if (_provNascitaCtrl.text.isEmpty) {
      addError('provNascita', 'Campo obbligatorio', 1);
    } else if (!RegExp(r'^[A-Z]{2}$').hasMatch(_provNascitaCtrl.text)) {
      addError('provNascita', 'Inserire 2 lettere (es. VI)', 1);
    }

    if (_tipoViaCtrl.text.isEmpty) addError('tipoVia', 'Campo obbligatorio', 2);
    if (_indirizzoNomeCtrl.text.isEmpty) addError('indirizzoNome', 'Campo obbligatorio', 2);
    if (_civicoCtrl.text.isEmpty) addError('civico', 'Campo obbligatorio', 2);
    if (_cittaResidenzaCtrl.text.isEmpty) addError('cittaResidenza', 'Campo obbligatorio', 2);
    
    if (_provResidenzaCtrl.text.isEmpty) {
      addError('provResidenza', 'Campo obbligatorio', 2);
    } else if (!RegExp(r'^[A-Z]{2}$').hasMatch(_provResidenzaCtrl.text)) {
      addError('provResidenza', 'Inserire 2 lettere (es. VI)', 2);
    }
    
    if (_capCtrl.text.isEmpty) {
      addError('cap', 'Campo obbligatorio', 2);
    } else if (!RegExp(r'^\d{5}$').hasMatch(_capCtrl.text)) {
      addError('cap', 'Deve contenere 5 numeri', 2);
    }

    if (_emailCtrl.text.isEmpty) {
      addError('email', 'Campo obbligatorio', 3);
    } else if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(_emailCtrl.text)) {
      addError('email', 'Formato indirizzo email non valido', 3);
    }

    if (_telefonoCtrl.text.isEmpty) {
      addError('telefono', 'Campo obbligatorio', 3);
    } else if (!RegExp(r'^\d+$').hasMatch(_telefonoCtrl.text)) {
      addError('telefono', 'Ammessi esclusivamente numeri', 3);
    }

    setState(() {
      _formErrors = newErrors;
      if (!isValid && firstInvalidCard != null) {
        _currentFormCardIndex = firstInvalidCard!;
      }
    });

    if (!isValid) {
      CustomSnackBar.show(context: context, message: 'Ci sono errori nei dati inseriti. Correggi i campi evidenziati in rosso.', isError: true);
    }

    return isValid;
  }

  bool _validateDatiSpecifici() {
    _annoPrimaIscrizioneCtrl.text = _annoPrimaIscrizioneCtrl.text.trim();
    _dataIscrizioneCtrl.text      = _dataIscrizioneCtrl.text.trim();
    _scadenzaCertificatoCtrl.text = _scadenzaCertificatoCtrl.text.trim();
    _tipoCorsoCtrl.text           = _tipoCorsoCtrl.text.trim();
    _ibanCtrl.text                = _ibanCtrl.text.replaceAll(' ', '').toUpperCase();
    _studiScolasticiCtrl.text     = _studiScolasticiCtrl.text.trim();
    _studiUniversitariCtrl.text   = _studiUniversitariCtrl.text.trim();

    bool                isValid          = true;
    int?                firstInvalidCard;
    Map<String, String> newErrors        = {};

    void addError(String field, String message, int targetCardLogicIndex) {
      newErrors[field] = message;
      isValid          = false;
      if (firstInvalidCard == null || targetCardLogicIndex < firstInvalidCard!) {
        firstInvalidCard = targetCardLogicIndex;
      }
    }

    final bool isStaff    = _selectedRoles.contains('DOCENTE');
    final bool isCorsista = _selectedRoles.contains('CORSISTA');
    final bool isStudente = _selectedRoles.contains('STUDENTE');

    int currentMappedIndex = 0;

    if (_annoPrimaIscrizioneCtrl.text.isEmpty) {
      addError('annoPrimaIscrizione', 'Campo obbligatorio', currentMappedIndex);
    } else if (!RegExp(r'^\d{4}$').hasMatch(_annoPrimaIscrizioneCtrl.text)) {
      addError('annoPrimaIscrizione', 'Formato anno non valido', currentMappedIndex);
    }
    if (_dataIscrizioneCtrl.text.isEmpty) {
      addError('dataIscrizione', 'Campo obbligatorio', currentMappedIndex);
    } else if (!_isValidDate(_dataIscrizioneCtrl.text)) {
      addError('dataIscrizione', 'Formato data non valido', currentMappedIndex);
    }
    currentMappedIndex++;

    if (isStaff) {
      if (_ibanCtrl.text.isNotEmpty && !RegExp(r'^IT\d{2}[A-Z]\d{10}[A-Z0-9]{12}$').hasMatch(_ibanCtrl.text)) {
        addError('iban', 'Formato IBAN italiano non valido', currentMappedIndex);
      }
      if (_tipoCollaborazione == null) {
        addError('tipoCollaborazione', 'Campo obbligatorio', currentMappedIndex);
      }
      currentMappedIndex++;
      currentMappedIndex++; 
    }

    if (isCorsista) {
      if (_scadenzaCertificatoCtrl.text.isEmpty) {
        addError('scadenzaCertificato', 'Campo obbligatorio', currentMappedIndex);
      } else if (!_isValidDate(_scadenzaCertificatoCtrl.text)) {
        addError('scadenzaCertificato', 'Formato data non valido', currentMappedIndex);
      }
      if (_tipoCorsoCtrl.text.isEmpty) {
        addError('tipoCorso', 'Campo obbligatorio', currentMappedIndex);
      }
      currentMappedIndex++;
    }
    
    if (isStudente) {
      if (_uscitaAnticipata == null) addError('uscitaAnticipata', 'Campo obbligatorio', currentMappedIndex);
      if (_scuolaSelezionata == null) addError('scuolaSelezionata', 'Campo obbligatorio', currentMappedIndex);
      if (_percorsoStudenteSelezionato == null) addError('percorsoStudente', 'Campo obbligatorio', currentMappedIndex);
      if (_classeFrequentata == null) addError('classeFrequentata', 'Campo obbligatorio', currentMappedIndex);
      currentMappedIndex++;
    }

    setState(() {
      _formErrors = newErrors;
      if (!isValid && firstInvalidCard != null) {
        _currentStep2CardIndex = firstInvalidCard!;
      }
    });

    if (!isValid) {
      CustomSnackBar.show(context: context, message: 'Ci sono errori nei dati specifici. Correggi i campi evidenziati in rosso.', isError: true);
    }

    return isValid;
  }

  void _submitForm() {
    final newMinor = PersonItem(
      fiscalCode: _cfCtrl.text.toUpperCase(),
      firstName: _nomeCtrl.text,
      lastName: _cognomeCtrl.text,
      roles: _selectedRoles.toList()..add('ASSOCIATO'),
      createdAt: DateTime.now(),
      city: _cittaResidenzaCtrl.text,
      birthDate: DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text),
    );
    Navigator.of(context).pop(newMinor);
  }

  void _onNext() {
    if (_currentStep == 0) {
      if (_involvementType == -1) {
        CustomSnackBar.show(context: context, message: 'Seleziona una categoria per continuare.', isError: true);
        return;
      }
      if (_involvementType == 1) {
        _selectedRoles.clear();
        _selectedRoles.add('ASSOCIATO');
        setState(() { _movingForward = true; _currentStep = 2; });
      } else {
        _selectedRoles.remove('ASSOCIATO');
        setState(() { _movingForward = true; _currentStep = 1; });
      }
      return;
    }

    if (_currentStep == 1) {
      final activeRoles = _selectedRoles.where((r) => r != 'ASSOCIATO').toList();
      if (activeRoles.isEmpty) {
        CustomSnackBar.show(context: context, message: 'Seleziona almeno un ruolo per procedere.', isError: true);
        return;
      }
      _selectedRoles.add('ASSOCIATO');
      setState(() { _movingForward = true; _currentStep = 2; });
      return;
    }

    if (_currentStep == 2) {
      if (!_validateDatiGenerali()) return;
      final activeRoles = _selectedRoles.where((r) => r != 'ASSOCIATO').toList();
      if (activeRoles.isEmpty) { 
        _submitForm();
      } else {
        setState(() { _movingForward = true; _currentStep = 3; _currentStep2CardIndex = 0; });
      }
      return;
    }

    if (_currentStep == 3) {
      if (!_validateDatiSpecifici()) return;
      if (_selectedRoles.contains('DOCENTE')) {
        setState(() { _movingForward = true; _currentStep = 4; });
      } else {
        _submitForm();
      }
      return;
    }

    if (_currentStep == 4) {
      bool hasAtLeastOneSubject = _subjectToggles.values.any((isSelected) => isSelected == true);
      if (!hasAtLeastOneSubject) {
        CustomSnackBar.show(context: context, message: 'Seleziona almeno una disciplina insegnata.', isError: true);
        return;
      }
      _submitForm();
      return;
    }
  }

  void _onBack() {
    setState(() => _movingForward = false);
    if (_currentStep == 4) {
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_involvementType == 1) {
        setState(() => _currentStep = 0);
      } else {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 0);
    }
  }

  Widget _buildStep0Type() {
    return SizedBox(
      key: const ValueKey('step0_type_m'),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  'Coinvolgimento del Minore',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Definisci la macro-categoria a cui appartiene il minore.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WizardSelectionCard(
                    isCompact: true,
                    title: 'Coinvolto Attivamente', 
                    subtitle: 'Partecipa attivamente ai corsi, ai servizi o come tutor.', 
                    icon: Icons.workspaces_outline, 
                    isSelected: _involvementType == 0, 
                    onTap: () => setState(() => _involvementType = 0),
                  ),
                  const SizedBox(height: 24),
                  WizardSelectionCard(
                    isCompact: true,
                    title: 'Solo Tesserato', 
                    subtitle: 'Ha la tessera associativa ma non partecipa ai servizi.', 
                    icon: Icons.card_membership_rounded, 
                    isSelected: _involvementType == 1, 
                    onTap: () => setState(() => _involvementType = 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Roles() {
    return SizedBox(
      key: const ValueKey('step1_m'),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text('Ruoli del Minore', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                const SizedBox(height: 8),
                Text('Quali ruoli ricopre il minore all\'interno dell\'Associazione?', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _availableRoles.map((role) {
                  final isSelected = _selectedRoles.contains(role['id']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: WizardSelectionCard(
                      isCompact: true,
                      title: role['label'], subtitle: role['desc'], icon: role['icon'], isSelected: isSelected, isHorizontal: true,
                      onTap: () => setState(() => isSelected ? _selectedRoles.remove(role['id']) : _selectedRoles.add(role['id'])),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _activeStep3Cards {
    final List<Widget> cards = [];
    cards.add(WizardFormSectionCard(
      isCompact: true, title: 'Iscrizione', leadingIcon: const WizardStaticAvatar(icon: Icons.assignment_ind_outlined),
      children: [
        WizardFormInputRow(label: 'Anno prima iscr.', inputWidget: WizardAnimatedTextField(controller: _annoPrimaIscrizioneCtrl, hint: 'Es. 2026', keyboardType: TextInputType.number, errorText: _formErrors['annoPrimaIscrizione'], onChanged: (_) => setState(() => _formErrors.remove('annoPrimaIscrizione')))),
        const SizedBox(height: 16),
        WizardFormInputRow(label: 'Data iscrizione', inputWidget: WizardAnimatedTextField(controller: _dataIscrizioneCtrl, hint: 'gg/mm/aaaa', keyboardType: TextInputType.number, inputFormatters: [WizardDateInputFormatter()], errorText: _formErrors['dataIscrizione'], onChanged: (_) => setState(() => _formErrors.remove('dataIscrizione')))),
      ]
    ));

    if (_selectedRoles.contains('DOCENTE')) {
      cards.add(WizardFormSectionCard(
        isCompact: true, title: 'Dati Collaborazione', leadingIcon: const WizardStaticAvatar(icon: Icons.account_balance_outlined),
        children: [
          WizardFormInputRow(label: 'IBAN', inputWidget: WizardAnimatedTextField(controller: _ibanCtrl, hint: 'Es. IT00A...', errorText: _formErrors['iban'], onChanged: (_) => setState(() => _formErrors.remove('iban')))),
          const SizedBox(height: 16),
          WizardFormInputRow(label: 'Collaborazione', inputWidget: WizardAnimatedOverlayDropdown(value: _tipoCollaborazione, items: const ['Volontario', 'Retribuito', 'FSC'], hint: 'Seleziona', errorText: _formErrors['tipoCollaborazione'], onChanged: (val) => setState(() { _tipoCollaborazione = val; _formErrors.remove('tipoCollaborazione'); }))),
        ]
      ));
      cards.add(WizardFormSectionCard(
        isCompact: true, title: 'Studi Docente', leadingIcon: const WizardStaticAvatar(icon: Icons.school_outlined),
        children: [
          WizardFormInputRow(label: 'Studi scolastici', inputWidget: WizardAnimatedTextField(controller: _studiScolasticiCtrl, hint: 'Es. Liceo', errorText: _formErrors['studiScolastici'], onChanged: (_) => setState(() => _formErrors.remove('studiScolastici')))),
          const SizedBox(height: 16),
          WizardFormInputRow(label: 'Studi universitari', inputWidget: WizardAnimatedTextField(controller: _studiUniversitariCtrl, hint: 'Es. Laurea', errorText: _formErrors['studiUniversitari'], onChanged: (_) => setState(() => _formErrors.remove('studiUniversitari')))),
        ]
      ));
    }

    if (_selectedRoles.contains('CORSISTA')) {
      cards.add(WizardFormSectionCard(
        isCompact: true, title: 'Dettagli Corsista', leadingIcon: const WizardStaticAvatar(icon: Icons.self_improvement_rounded),
        children: [
          WizardFormInputRow(label: 'Scadenza cert.', inputWidget: WizardAnimatedTextField(controller: _scadenzaCertificatoCtrl, hint: 'gg/mm/aaaa', keyboardType: TextInputType.number, inputFormatters: [WizardDateInputFormatter()], errorText: _formErrors['scadenzaCertificato'], onChanged: (_) => setState(() => _formErrors.remove('scadenzaCertificato')))),
          const SizedBox(height: 16),
          WizardFormInputRow(label: 'Tipo corso', inputWidget: WizardAnimatedTextField(controller: _tipoCorsoCtrl, hint: 'Es. Pilates', errorText: _formErrors['tipoCorso'], onChanged: (_) => setState(() => _formErrors.remove('tipoCorso')))),
        ]
      ));
    }

    if (_selectedRoles.contains('STUDENTE')) {
      final List<String> schoolNames  = widget.allSchools.map((s) => '${s.name} (${s.city})').toList();
      List<String> programNames = [];
      List<String> gradeOptions = [];

      if (_scuolaSelezionata != null) {
        try {
          dynamic progs;
          try { progs = (_scuolaSelezionata as dynamic).studyPrograms; } catch (_) {}
          if (progs == null) try { progs = (_scuolaSelezionata as dynamic).study_programs; } catch (_) {}
          if (progs != null && progs is Iterable) {
            for (var p in progs) {
              String? pName = (p is Map) ? p['name'] as String? : (p as dynamic).name as String?;
              if (pName != null && pName.isNotEmpty) {
                if (widget.allPrograms.any((allP) => (allP as dynamic).name == pName) && !programNames.contains(pName)) {
                  programNames.add(pName);
                }
              }
            }
          }
        } catch (_) {}
      }

      if (_percorsoStudenteSelezionato != null) {
        try {
          final level = (_percorsoStudenteSelezionato as dynamic).level as String?;
          if (level == 'MIDDLE_SCHOOL' || level == 'MEDIE' || level == 'Medie') {
            gradeOptions = ['I', 'II', 'III'];
          } else {
            gradeOptions = ['I', 'II', 'III', 'IV', 'V'];
          }
        } catch (_) {
          gradeOptions = ['I', 'II', 'III', 'IV', 'V'];
        }
      }

      cards.add(WizardFormSectionCard(
        isCompact: true, title: 'Dettagli Studente', leadingIcon: const WizardStaticAvatar(icon: Icons.menu_book_outlined),
        children: [
          WizardFormInputRow(label: 'Uscita anticipata', inputWidget: WizardAnimatedOverlayDropdown(value: _uscitaAnticipata, items: const ['Sì', 'No'], hint: 'Seleziona', errorText: _formErrors['uscitaAnticipata'], onChanged: (val) => setState(() { _uscitaAnticipata = val; _formErrors.remove('uscitaAnticipata'); }))),
          const SizedBox(height: 16),
          WizardFormInputRow(label: 'Scuola', inputWidget: WizardAnimatedOverlayDropdown(value: _scuolaSelezionata != null ? '${_scuolaSelezionata!.name} (${_scuolaSelezionata!.city})' : null, items: schoolNames, hint: 'Seleziona scuola', errorText: _formErrors['scuolaSelezionata'], onChanged: (val) { setState(() { _scuolaSelezionata = widget.allSchools.firstWhere((s) => '${s.name} (${s.city})' == val); _percorsoStudenteSelezionato = null; _classeFrequentata = null; _formErrors.remove('scuolaSelezionata'); }); })),
          const SizedBox(height: 16),
          WizardFormInputRow(label: 'Percorso', inputWidget: _scuolaSelezionata == null ? const WizardDisabledDropdownPlaceholder(hint: 'Seleziona prima la scuola') : programNames.isEmpty ? const WizardDisabledDropdownPlaceholder(hint: 'Nessun percorso offerto') : WizardAnimatedOverlayDropdown(value: _percorsoStudenteSelezionato != null ? (_percorsoStudenteSelezionato as dynamic).name as String? : null, items: programNames, hint: 'Seleziona percorso', errorText: _formErrors['percorsoStudente'], onChanged: (val) { setState(() { try { _percorsoStudenteSelezionato = widget.allPrograms.firstWhere((p) => (p as dynamic).name == val); } catch (_) { _percorsoStudenteSelezionato = null; } _classeFrequentata = null; _formErrors.remove('percorsoStudente'); }); })),
          const SizedBox(height: 16),
          WizardFormInputRow(label: 'Classe a.s. $_currentSchoolYear', inputWidget: _percorsoStudenteSelezionato == null ? const WizardDisabledDropdownPlaceholder(hint: 'Seleziona prima il percorso') : WizardAnimatedOverlayDropdown(value: _classeFrequentata, items: gradeOptions, hint: 'Seleziona classe', errorText: _formErrors['classeFrequentata'], onChanged: (val) => setState(() { _classeFrequentata = val; _formErrors.remove('classeFrequentata'); }))),
        ]
      ));
    }
    return cards;
  }

  Widget _buildStepWidget(int step) {
    if (step == 0) return _buildStep0Type();
    if (step == 1) return _buildStep1Roles();
    
    if (step == 2) {
      Widget currentCard = const SizedBox.shrink();
      switch (_currentFormCardIndex) {
        case 0:
          currentCard = WizardFormSectionCard(
            isCompact: true, title: 'Identità', leadingIcon: const WizardStaticAvatar(icon: Icons.badge_outlined),
            children: [
              WizardFormInputRow(label: 'Foto profilo', inputWidget: WizardProfilePhotoUploader(imageBytes: _fotoProfilo, onImagePicked: (bytes) => setState(() => _fotoProfilo = bytes))),
              const SizedBox(height: 24),
              WizardFormInputRow(label: 'Nome', inputWidget: WizardAnimatedTextField(controller: _nomeCtrl, hint: 'Es. Mario', errorText: _formErrors['nome'], onChanged: (_) => setState(() => _formErrors.remove('nome')))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Cognome', inputWidget: WizardAnimatedTextField(controller: _cognomeCtrl, hint: 'Es. Rossi', errorText: _formErrors['cognome'], onChanged: (_) => setState(() => _formErrors.remove('cognome')))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Sesso', inputWidget: WizardAnimatedOverlayDropdown(value: _sesso, items: const ['M', 'F'], hint: 'Seleziona', errorText: _formErrors['sesso'], onChanged: (val) => setState(() { _sesso = val; _formErrors.remove('sesso'); }))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Codice fiscale', inputWidget: WizardAnimatedTextField(controller: _cfCtrl, hint: 'Es. RSSMRA80A01H501Z', errorText: _formErrors['cf'], onChanged: (_) => setState(() => _formErrors.remove('cf')))),
            ],
          );
          break;
        case 1:
          currentCard = WizardFormSectionCard(
            isCompact: true, title: 'Dati anagrafici', leadingIcon: const WizardStaticAvatar(icon: Icons.cake_rounded),
            children: [
              WizardFormInputRow(label: 'Data di nascita', inputWidget: WizardAnimatedTextField(controller: _dataNascitaCtrl, hint: 'gg/mm/aaaa', keyboardType: TextInputType.number, inputFormatters: [WizardDateInputFormatter()], errorText: _formErrors['dataNascita'], onChanged: (_) => setState(() => _formErrors.remove('dataNascita')))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Città di nascita', inputWidget: WizardAnimatedTextField(controller: _cittaNascitaCtrl, hint: 'Es. Roma', errorText: _formErrors['cittaNascita'], onChanged: (_) => setState(() => _formErrors.remove('cittaNascita')))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Prov. di nascita', inputWidget: WizardAnimatedTextField(controller: _provNascitaCtrl, hint: 'Es. RM', errorText: _formErrors['provNascita'], onChanged: (_) => setState(() => _formErrors.remove('provNascita')))),
            ],
          );
          break;
        case 2:
          currentCard = WizardFormSectionCard(
            isCompact: true, title: 'Residenza', leadingIcon: const WizardStaticAvatar(icon: Icons.home_rounded),
            children: [
              WizardFormInputRow(label: 'Indirizzo', inputWidget: Row(children: [ Expanded(flex: 3, child: WizardAnimatedTextField(controller: _tipoViaCtrl, hint: 'Es. Via', errorText: _formErrors['tipoVia'], onChanged: (_) => setState(() => _formErrors.remove('tipoVia')))), const SizedBox(width: 8), Expanded(flex: 5, child: WizardAnimatedTextField(controller: _indirizzoNomeCtrl, hint: 'Nome (es. Garibaldi)', errorText: _formErrors['indirizzoNome'], onChanged: (_) => setState(() => _formErrors.remove('indirizzoNome')))), const SizedBox(width: 8), Expanded(flex: 2, child: WizardAnimatedTextField(controller: _civicoCtrl, hint: 'N°', errorText: _formErrors['civico'], onChanged: (_) => setState(() => _formErrors.remove('civico')))) ])),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Città', inputWidget: WizardAnimatedTextField(controller: _cittaResidenzaCtrl, hint: 'Es. Milano', errorText: _formErrors['cittaResidenza'], onChanged: (_) => setState(() => _formErrors.remove('cittaResidenza')))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Provincia', inputWidget: WizardAnimatedTextField(controller: _provResidenzaCtrl, hint: 'Es. MI', errorText: _formErrors['provResidenza'], onChanged: (_) => setState(() => _formErrors.remove('provResidenza')))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'CAP', inputWidget: WizardAnimatedTextField(controller: _capCtrl, hint: 'Es. 20100', keyboardType: TextInputType.number, errorText: _formErrors['cap'], onChanged: (_) => setState(() => _formErrors.remove('cap')))),
            ],
          );
          break;
        case 3:
          currentCard = WizardFormSectionCard(
            isCompact: true, title: 'Contatti', leadingIcon: const WizardStaticAvatar(icon: Icons.alternate_email_rounded),
            children: [
              WizardFormInputRow(label: 'Email', inputWidget: WizardAnimatedTextField(controller: _emailCtrl, hint: 'Es. mario.rossi@email.com', keyboardType: TextInputType.emailAddress, errorText: _formErrors['email'], onChanged: (_) => setState(() => _formErrors.remove('email')))),
              const SizedBox(height: 16),
              WizardFormInputRow(label: 'Telefono', inputWidget: WizardAnimatedTextField(controller: _telefonoCtrl, hint: 'Es. 333 1234567', keyboardType: TextInputType.phone, errorText: _formErrors['telefono'], onChanged: (_) => setState(() => _formErrors.remove('telefono')))),
            ],
          );
          break;
      }

      return SizedBox(
        key: const ValueKey('step2_m'),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text('Dati Generali Minore', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  const SizedBox(height: 8),
                  Text('Compila i dati anagrafici e di contatto del minore.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentFormCardIndex == 0, onTap: () => setState(() => _currentFormCardIndex--)),
                  const SizedBox(width: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(key: ValueKey(_currentFormCardIndex), child: currentCard),
                    ),
                  ),
                  const SizedBox(width: 32),
                  WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentFormCardIndex == 3, onTap: () => setState(() => _currentFormCardIndex++)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (step == 3) {
      final cards = _activeStep3Cards;
      return SizedBox(
        key: const ValueKey('step3_m'),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text('Dati Specifici Minore', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  const SizedBox(height: 8),
                  Text('Compila i dati richiesti dai ruoli selezionati.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentStep2CardIndex == 0, onTap: () => setState(() => _currentStep2CardIndex--)),
                  const SizedBox(width: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(key: ValueKey(_currentStep2CardIndex), child: cards.isNotEmpty ? cards[_currentStep2CardIndex] : const SizedBox.shrink()),
                    ),
                  ),
                  const SizedBox(width: 32),
                  WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentStep2CardIndex >= cards.length - 1, onTap: () => setState(() => _currentStep2CardIndex++)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (step == 4) {
      List<AssociationSubjectItem> validSubjects = widget.allSubjects.where((subject) {
        List<StudyProgramItem> programs = [];
        for (final prog in widget.allPrograms) {
          bool hasMatch = false;
          try {
            final dynamic minSubjects = (prog as dynamic).ministrySubjects;
            if (minSubjects != null && minSubjects is Iterable) {
              for (var m in minSubjects) {
                final dynamic assocSubjects = (m as dynamic).associationSubjects;
                if (assocSubjects != null && assocSubjects is Iterable) {
                  for (var assoc in assocSubjects) {
                    final int? assocId = (assoc is Map) ? assoc['id'] as int? : (assoc as dynamic).id as int?;
                    if (assocId == subject.id) { hasMatch = true; break; }
                  }
                }
                if (hasMatch) break; 
              }
            }
          } catch (_) {}
          if (hasMatch) programs.add(prog);
        }
        if (programs.isEmpty) return false;
        final query = _searchSubjectsText.toLowerCase();
        final matchesSearch = subject.name.toLowerCase().contains(query);
        final matchesArea = _filterSubjectsArea == null || subject.area == _filterSubjectsArea;
        return matchesSearch && matchesArea;
      }).toList();

      validSubjects.sort((a, b) {
        if (_sortSubjectsBy == 'name_asc') return a.name.compareTo(b.name);
        if (_sortSubjectsBy == 'name_desc') return b.name.compareTo(a.name);
        if (_sortSubjectsBy == 'date_asc') return a.createdAt.compareTo(b.createdAt);
        if (_sortSubjectsBy == 'date_desc') return b.createdAt.compareTo(a.createdAt);
        return 0;
      });

      return SizedBox(
        key: const ValueKey('step4_m'),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text('Discipline Insegnate', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  const SizedBox(height: 8),
                  Text('Seleziona le discipline in cui il minore farà da tutor.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: WizardAnimatedSearchBar(controller: _searchSubjectsCtrl, onChanged: (value) => setState(() => _searchSubjectsText = value), hintText: 'Cerca disciplina...'),
                ),
                const SizedBox(width: 16),
                WizardFilterMenu<String>(
                  hint: 'Ordina per', icon: Icons.sort_rounded, value: _sortSubjectsBy, menuWidth: 180, showClearIcon: false, 
                  onChanged: (val) => setState(() => _sortSubjectsBy = val), onClear: () {}, 
                  options: [
                    WizardFilterOption(value: 'name_asc', label: 'Nome (A-Z)'), 
                    WizardFilterOption(value: 'name_desc', label: 'Nome (Z-A)'),
                  ]
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Wrap(
                  spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
                  children: validSubjects.map((subject) {
                    final isSelected = _subjectToggles[subject.id] ?? false;
                    final selectedCount = (_selectedProgramsForSubject[subject.id] ?? {}).length;
                    return WizardSubjectGridCard(
                      subject: subject, isSelected: isSelected, selectedCount: selectedCount,
                      onTap: () {
                        List<StudyProgramItem> programs = [];
                        for (final prog in widget.allPrograms) {
                          bool hasMatch = false;
                          try {
                            final dynamic minSubjects = (prog as dynamic).ministrySubjects;
                            if (minSubjects != null && minSubjects is Iterable) {
                              for (var m in minSubjects) {
                                final dynamic assocSubjects = (m as dynamic).associationSubjects;
                                if (assocSubjects != null && assocSubjects is Iterable) {
                                  for (var assoc in assocSubjects) {
                                    final int? assocId = (assoc is Map) ? assoc['id'] as int? : (assoc as dynamic).id as int?;
                                    if (assocId == subject.id) { hasMatch = true; break; }
                                  }
                                }
                                if (hasMatch) break; 
                              }
                            }
                          } catch (_) {}
                          if (hasMatch) programs.add(prog);
                        }
                        showGeneralDialog(
                          context: context, barrierDismissible: true, barrierLabel: 'Programs', barrierColor: Colors.black.withValues(alpha: .15), transitionDuration: const Duration(milliseconds: 240),
                          pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
                          transitionBuilder: (context, animation, secondaryAnimation, child) {
                            return BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: animation.value * 8.0, sigmaY: animation.value * 8.0),
                              child: FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
                                  child: WizardProgramsSelectionDialog(
                                    subject: subject, programs: programs, initialSelected: _selectedProgramsForSubject[subject.id] ?? {},
                                    onSave: (selected) {
                                      setState(() {
                                        if (selected.isEmpty) { _subjectToggles[subject.id] = false; _selectedProgramsForSubject.remove(subject.id); } 
                                        else { _subjectToggles[subject.id] = true; _selectedProgramsForSubject[subject.id] = selected; }
                                      });
                                    },
                                    onCancel: () { setState(() { _subjectToggles[subject.id] = false; _selectedProgramsForSubject.remove(subject.id); }); }
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
  Widget build(BuildContext context) {
    bool isLastStep;
    if (_currentStep == 4) {
      isLastStep = true;
    } else if (_currentStep == 3 && !_selectedRoles.contains('DOCENTE')) {
      isLastStep = true;
    } else if (_currentStep == 2 && _activeStep3Cards.isEmpty && !_selectedRoles.contains('DOCENTE')) {
      isLastStep = true;
    } else {
      isLastStep = false;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              offset: Offset(0, 12),
              blurRadius: 36,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              Positioned(
                right: -400, top: -400,
                child: IgnorePointer(
                  child: Container(
                    width: 800, height: 800,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0x22003C82), Color(0x00003C82)], stops: [0.0, 1.0]),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -400, bottom: -400,
                child: IgnorePointer(
                  child: Container(
                    width: 800, height: 800,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0x22003C82), Color(0x00003C82)], stops: [0.0, 1.0]),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nuovo Minore',
                          style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) => Stack(alignment: Alignment.center, children: [...previousChildren, if (currentChild != null) currentChild]),
                        transitionBuilder: (child, animation) {
                          final isEntering = (child.key as ValueKey<String>).value == 'step${_currentStep}_m' || (child.key as ValueKey<String>).value == 'step${_currentStep}_type_m';
                          Offset beginOffset = _movingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                          return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                        },
                        child: _buildStepWidget(_currentStep),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentStep == 0)
                          SizedBox(
                            width: 200,
                            child: WizardAnimatedActionButton(text: 'ANNULLA', icon: Icons.close_rounded, baseColor: const Color(0xFFE53935), hoverColor: const Color(0xFFEF5350), onPressed: () => Navigator.of(context).pop()),
                          )
                        else
                          SizedBox(
                            width: 200,
                            child: WizardOutlinedActionButton(text: 'INDIETRO', icon: Icons.arrow_back_rounded, onPressed: _onBack),
                          ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 200,
                          child: WizardAnimatedActionButton(text: isLastStep ? 'CREA' : 'AVANTI', icon: isLastStep ? Icons.check_circle_outline : Icons.arrow_forward_rounded, baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99), onPressed: _onNext),
                        ),
                      ],
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