import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/snackbar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import './models/person_item.dart';
import 'person_wizard_components.dart';

class ParentCreationDialog extends StatefulWidget
{
  const ParentCreationDialog({super.key});

  @override
  State<ParentCreationDialog> createState() => _ParentCreationDialogState();
}

class _ParentCreationDialogState extends State<ParentCreationDialog>
{
  int _currentStep = 0;
  bool _movingForward = true;
  bool _genitoreIsAssociato = false;
  int _currentFormCardIndex = 0;
  Map<String, String> _formErrors = {};
  Uint8List? _fotoProfilo;
  bool _isSubmitting = false;
  bool _isCheckingCf = false;
  bool _cardMovingForward = true;

  final TextEditingController _nomeCtrl = TextEditingController();
  final TextEditingController _cognomeCtrl = TextEditingController();
  String? _sesso;
  final TextEditingController _cfCtrl = TextEditingController();
  final TextEditingController _dataNascitaCtrl = TextEditingController();
  final TextEditingController _cittaNascitaCtrl = TextEditingController();
  final TextEditingController _provNascitaCtrl = TextEditingController();
  final TextEditingController _nazioneNascitaCtrl = TextEditingController();
  final TextEditingController _tipoViaCtrl = TextEditingController();
  final TextEditingController _indirizzoNomeCtrl = TextEditingController();
  final TextEditingController _civicoCtrl = TextEditingController();
  final TextEditingController _cittaResidenzaCtrl = TextEditingController();
  final TextEditingController _provResidenzaCtrl = TextEditingController();
  final TextEditingController _capCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final List<WizardEnrollmentRowData> _enrollmentRows = [];

  int _currentStep2CardIndex = 0;
  bool _card2MovingForward = true;

  bool _aderisceSostegnoPsicologico = false;
  final TextEditingController _dataInizioSostegnoPsicologicoCtrl = TextEditingController(
    text:
        '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
  );

  bool _statutoAccettato = false;
  bool _regolamentoAccettato = false;
  bool _videosorveglianzaPresaVisione = false;
  bool _consensoDatiParticolari = false;
  bool _consensoNewsletter = false;

  @override
  void initState()
  {
    super.initState();
    final now = DateTime.now();
    _enrollmentRows.add(
      WizardEnrollmentRowData(
        yearCtrl: TextEditingController(text: now.year.toString()),
        dateCtrl: TextEditingController(
          text:
              '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}',
        ),
      ),
    );
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
    _dataInizioSostegnoPsicologicoCtrl.dispose();
    for (final row in _enrollmentRows)
    {
      row.yearCtrl.dispose();
      row.dateCtrl.dispose();
    }
    super.dispose();
  }

  bool _isValidDate(String dateStr)
  {
    try
    {
      final parts = dateStr.split('/');
      if (parts.length != 3)
      {
        return false;
      }

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final date = DateTime(year, month, day);

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
      if (parts.length != 2)
      {
        return false;
      }

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(yearStr);
      final date = DateTime(year, month, day);

      return date.year == year && date.month == month && date.day == day;
    }
    catch (_)
    {
      return false;
    }
  }

  String? _toIsoDate(String? itaDate)
  {
    if (itaDate == null || itaDate.isEmpty)
    {
      return null;
    }
    final parts = itaDate.split('/');
    if (parts.length != 3)
    {
      return null;
    }
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  bool _isCodiceFiscaleValid(String cf)
  {
    if (!RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(cf))
    {
      return false;
    }
    const oddValues = {
      '0': 1,
      '1': 0,
      '2': 5,
      '3': 7,
      '4': 9,
      '5': 13,
      '6': 15,
      '7': 17,
      '8': 19,
      '9': 21,
      'A': 1,
      'B': 0,
      'C': 5,
      'D': 7,
      'E': 9,
      'F': 13,
      'G': 15,
      'H': 17,
      'I': 19,
      'J': 21,
      'K': 2,
      'L': 4,
      'M': 18,
      'N': 20,
      'O': 11,
      'P': 3,
      'Q': 6,
      'R': 8,
      'S': 12,
      'T': 14,
      'U': 16,
      'V': 10,
      'W': 22,
      'X': 25,
      'Y': 24,
      'Z': 23,
    };
    const evenValues = {
      '0': 0,
      '1': 1,
      '2': 2,
      '3': 3,
      '4': 4,
      '5': 5,
      '6': 6,
      '7': 7,
      '8': 8,
      '9': 9,
      'A': 0,
      'B': 1,
      'C': 2,
      'D': 3,
      'E': 4,
      'F': 5,
      'G': 6,
      'H': 7,
      'I': 8,
      'J': 9,
      'K': 10,
      'L': 11,
      'M': 12,
      'N': 13,
      'O': 14,
      'P': 15,
      'Q': 16,
      'R': 17,
      'S': 18,
      'T': 19,
      'U': 20,
      'V': 21,
      'W': 22,
      'X': 23,
      'Y': 24,
      'Z': 25,
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
    if (cf.length != 16)
    {
      return false;
    }
    final parts = dateStr.split('/');
    if (parts.length != 3)
    {
      return false;
    }

    final year = parts[2].substring(2, 4);
    if (cf.substring(6, 8) != year)
    {
      return false;
    }

    const monthCodes = {
      '01': 'A',
      '02': 'B',
      '03': 'C',
      '04': 'D',
      '05': 'E',
      '06': 'H',
      '07': 'L',
      '08': 'M',
      '09': 'P',
      '10': 'R',
      '11': 'S',
      '12': 'T',
    };
    if (cf.substring(8, 9) != monthCodes[parts[1]])
    {
      return false;
    }

    int day = int.parse(parts[0]);
    if (gender == 'F')
    {
      day += 40;
    }
    final dayStr = day.toString().padLeft(2, '0');
    if (cf.substring(9, 11) != dayStr)
    {
      return false;
    }

    return true;
  }

  bool _validateDatiGenerali()
  {
    setState(()
    {
      _formErrors.clear();
      _nomeCtrl.text = _nomeCtrl.text.trim();
      _cognomeCtrl.text = _cognomeCtrl.text.trim();
      _cfCtrl.text = _cfCtrl.text.trim().toUpperCase();
      _dataNascitaCtrl.text = _dataNascitaCtrl.text.trim();
      _cittaNascitaCtrl.text = _cittaNascitaCtrl.text.trim();
      _provNascitaCtrl.text = _provNascitaCtrl.text.trim().toUpperCase();
      _nazioneNascitaCtrl.text = _nazioneNascitaCtrl.text.trim();
      _tipoViaCtrl.text = _tipoViaCtrl.text.trim();
      _indirizzoNomeCtrl.text = _indirizzoNomeCtrl.text.trim();
      _civicoCtrl.text = _civicoCtrl.text.trim();
      _cittaResidenzaCtrl.text = _cittaResidenzaCtrl.text.trim();
      _provResidenzaCtrl.text = _provResidenzaCtrl.text.trim().toUpperCase();
      _capCtrl.text = _capCtrl.text.trim();
      _emailCtrl.text = _emailCtrl.text.trim();
      _telefonoCtrl.text = _telefonoCtrl.text.replaceAll(' ', '');
    });

    bool isValid = true;
    int? firstInvalidCard;
    Map<String, String> newErrors = {};

    void addError(String field, String message, int cardIndex)
    {
      newErrors[field] = message;
      isValid = false;
      if (firstInvalidCard == null || cardIndex < firstInvalidCard!)
      {
        firstInvalidCard = cardIndex;
      }
    }

    if (_nomeCtrl.text.isEmpty)
    {
      addError('nome', 'Campo obbligatorio', 0);
    }
    if (_cognomeCtrl.text.isEmpty)
    {
      addError('cognome', 'Campo obbligatorio', 0);
    }
    if (_sesso == null)
    {
      addError('sesso', 'Campo obbligatorio', 0);
    }

    if (_cfCtrl.text.isEmpty)
    {
      addError('cf', 'Campo obbligatorio', 0);
    }
    else if (!_isCodiceFiscaleValid(_cfCtrl.text))
    {
      addError('cf', 'Codice fiscale non valido', 0);
    }
    else if (_sesso != null &&
        _dataNascitaCtrl.text.isNotEmpty &&
        _isValidDate(_dataNascitaCtrl.text))
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
        final parts = _dataNascitaCtrl.text.split('/');
        final date = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
        final now = DateTime.now();
        final minDate = DateTime(1900, 1, 1);

        if (date.isBefore(minDate) || date.isAfter(now))
        {
          addError('dataNascita', 'Data di nascita non consentita', 1);
        }
        else
        {
          int age = now.year - date.year;
          if (now.month < date.month ||
              (now.month == date.month && now.day < date.day))
          {
            age--;
          }
          if (age < 18)
          {
            addError('dataNascita', 'Il genitore deve avere almeno 18 anni', 1);
          }
        }
      }
    }

    if (_cittaNascitaCtrl.text.isEmpty)
    {
      addError('cittaNascita', 'Campo obbligatorio', 1);
    }

    if (_provNascitaCtrl.text.isEmpty)
    {
      addError('provNascita', 'Campo obbligatorio', 1);
    }
    else if (!RegExp(r'^[A-Z]{2}$').hasMatch(_provNascitaCtrl.text))
    {
      addError('provNascita', 'Inserire 2 lettere (es. VI)', 1);
    }

    if (_nazioneNascitaCtrl.text.isEmpty)
    {
      addError('nazioneNascita', 'Campo obbligatorio', 1);
    }

    if (_tipoViaCtrl.text.isEmpty)
    {
      addError('tipoVia', 'Campo obbligatorio', 2);
    }
    if (_indirizzoNomeCtrl.text.isEmpty)
    {
      addError('indirizzoNome', 'Campo obbligatorio', 2);
    }
    if (_civicoCtrl.text.isEmpty)
    {
      addError('civico', 'Campo obbligatorio', 2);
    }
    if (_cittaResidenzaCtrl.text.isEmpty)
    {
      addError('cittaResidenza', 'Campo obbligatorio', 2);
    }

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
        _cardMovingForward = firstInvalidCard! >= _currentFormCardIndex;
        _currentFormCardIndex = firstInvalidCard!;
      }
    });

    if (!isValid)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Ci sono errori nei dati inseriti. Correggi i campi.',
        isError: true,
      );
    }

    return isValid;
  }

  Future<bool> _checkCodiceFiscaleEsistente() async
  {
    setState(() => _isCheckingCf = true);

    try
    {
      final bool esiste = await ApiService().checkFiscalCodeExists(
        _cfCtrl.text.trim().toUpperCase(),
      );

      if (esiste)
      {
        setState(()
        {
          _formErrors['cf'] = 'Codice fiscale già presente';
          _cardMovingForward = 0 >= _currentFormCardIndex;
          _currentFormCardIndex = 0;
        });

        if (mounted)
        {
          CustomSnackBar.show(
            context: context,
            message: 'Esiste già una persona con questo codice fiscale.',
            isError: true,
          );
        }
      }

      return esiste;
    }
    catch (_)
    {
      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Impossibile verificare il codice fiscale. Riprova.',
          isError: true,
        );
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

  bool _validateIscrizioni()
  {
    _dataInizioSostegnoPsicologicoCtrl.text =
        _dataInizioSostegnoPsicologicoCtrl.text.trim();

    bool isValid = true;
    int? firstInvalidCard;
    Map<String, String> newErrors = Map.from(_formErrors);

    void addError(String field, String message, int targetCardLogicIndex)
    {
      newErrors[field] = message;
      isValid = false;
      if (firstInvalidCard == null || targetCardLogicIndex < firstInvalidCard!)
      {
        firstInvalidCard = targetCardLogicIndex;
      }
    }

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
      else if (yearValid &&
          !_isValidDayMonthYear(
            row.dateCtrl.text.trim(),
            row.yearCtrl.text.trim(),
          ))
      {
        addError('enrollmentDate_$i', 'Data non valida', currentMappedIndex);
      }
      else if (!yearValid &&
          !RegExp(r'^\d{2}/\d{2}$').hasMatch(row.dateCtrl.text.trim()))
      {
        addError('enrollmentDate_$i', 'Formato gg/mm', currentMappedIndex);
      }
    }
    currentMappedIndex++;

    // The following consents apply only when the parent joins the association.
    if (_genitoreIsAssociato)
    {
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
    }

    setState(()
    {
      _formErrors = newErrors;
      if (!isValid && firstInvalidCard != null)
      {
        _card2MovingForward = firstInvalidCard! >= _currentStep2CardIndex;
        _currentStep2CardIndex = firstInvalidCard!;
      }
    });

    if (!isValid)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Ci sono errori nelle informazioni associative.',
        isError: true,
      );
    }

    return isValid;
  }

  Future<void> _submitForm() async
  {
    setState(() => _isSubmitting = true);

    try
    {
      final List<String> finalRoles = ['GENITORE'];
      Map<String, dynamic>? memberData;
      Map<String, dynamic>? psychologicalSupportData;

      if (_genitoreIsAssociato)
      {
        finalRoles.add('ASSOCIATO');

        List<Map<String, dynamic>> membershipsData = [];
        for (final row in _enrollmentRows)
        {
          final parts = row.dateCtrl.text.trim().split('/');
          final isoDate = '${row.yearCtrl.text.trim()}-${parts[1]}-${parts[0]}';

          membershipsData.add({
            "year": int.parse(row.yearCtrl.text.trim()),
            "start_date": isoDate,
            "end_date": "${row.yearCtrl.text.trim()}-12-31",
            "renewal_period_days": 30,
            "revocation": "NO",
          });
        }

        // Any member carries the consents and may opt into psychological support.
        memberData = {
          "memberships": membershipsData,
          "payment_method": null,
          "payment_method_other": null,
          "statute_acknowledged": _statutoAccettato,
          "regulation_acknowledged": _regolamentoAccettato,
          "video_surveillance_acknowledged": _videosorveglianzaPresaVisione,
          "special_category_data_consent": _consensoDatiParticolari,
          "newsletter_consent": _consensoNewsletter,
          "consents_signed_at": DateTime.now().toIso8601String().split('T').first,
          "emergency_contact_name": null,
          "emergency_contact_phone": null,
          "allergies_notes": null,
          "medications_notes": null,
        };

        if (_aderisceSostegnoPsicologico)
        {
          psychologicalSupportData = {
            "start_date": _dataInizioSostegnoPsicologicoCtrl.text.trim().split('/').reversed.join('-'),
          };
        }
      }

      final payload = {
        "general_data": {
          "first_name": _nomeCtrl.text.trim(),
          "last_name": _cognomeCtrl.text.trim(),
          "tax_code": _cfCtrl.text.trim().toUpperCase(),
          "gender": _sesso,
          "birth_date": _toIsoDate(_dataNascitaCtrl.text.trim()),
          "birth_city": _cittaNascitaCtrl.text.trim(),
          "birth_nation": _nazioneNascitaCtrl.text.trim(),
          "birth_province": _provNascitaCtrl.text.trim().toUpperCase(),
          "residence_type": _tipoViaCtrl.text.trim(),
          "residence_address": _indirizzoNomeCtrl.text.trim(),
          "residence_street_number": _civicoCtrl.text.trim(),
          "residence_city": _cittaResidenzaCtrl.text.trim(),
          "residence_province": _provResidenzaCtrl.text.trim().toUpperCase(),
          "postal_code": _capCtrl.text.trim(),
          "email": _emailCtrl.text.trim(),
          "phone": _telefonoCtrl.text.replaceAll(' ', ''),
        },
        "roles": finalRoles,
        "member_data": memberData,
        "psychological_support_data": psychologicalSupportData,
        "relationships": {"minors_tax_codes": [], "parents_tax_codes": []},
      };

      final newParent = PersonItem(
        fiscalCode: _cfCtrl.text.trim().toUpperCase(),
        firstName: _nomeCtrl.text.trim(),
        lastName: _cognomeCtrl.text.trim(),
        roles: finalRoles
            .map(
              (r) =>
                  r.substring(0, 1).toUpperCase() +
                  r.substring(1).toLowerCase(),
            )
            .toList(),
        createdAt: DateTime.now(),
        city: _cittaResidenzaCtrl.text.trim(),
        birthDate: DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text.trim()),
      );

      if (mounted)
      {
        Navigator.of(context).pop({
          'person': newParent,
          'payload': payload,
          'imageBytes': _fotoProfilo,
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: readableApiError(e),
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

  Future<void> _onNext() async
  {
    if (_currentStep == 0)
    {
      setState(()
      {
        _movingForward = true;
        _currentStep = 1;
      });
      return;
    }

    if (_currentStep == 1)
    {
      if (!_validateDatiGenerali())
      {
        return;
      }

      final bool cfEsistente = await _checkCodiceFiscaleEsistente();
      if (cfEsistente)
      {
        return;
      }

      if (_genitoreIsAssociato)
      {
        setState(()
        {
          _movingForward = true;
          _currentStep = 2;
          _currentStep2CardIndex = 0;
          _card2MovingForward = true;
        });
      }
      else
      {
        _submitForm();
      }
      return;
    }

    if (_currentStep == 2)
    {
      if (!_validateIscrizioni())
      {
        return;
      }
      _submitForm();
      return;
    }
  }

  void _onBack()
  {
    setState(() => _movingForward = false);
    if (_currentStep == 2)
    {
      setState(() => _currentStep = 1);
    }
    else if (_currentStep == 1)
    {
      setState(() => _currentStep = 0);
    }
  }

  Widget _buildStep0Association()
  {
    return SizedBox(
      key: const ValueKey('step0_p'),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  'Iscrizione all\'Associazione',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Il genitore può iscrivere il proprio figlio senza diventare socio.\nScegli se desidera aderire anche personalmente.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: [
                    WizardSelectionCard(
                      title: 'Sì',
                      subtitle:
                          'Il genitore aderisce all\'Associazione e versa la quota annuale.',
                      icon: Icons.person_outlined,
                      isSelected: _genitoreIsAssociato == true,
                      onTap: () => setState(() => _genitoreIsAssociato = true),
                    ),
                    WizardSelectionCard(
                      title: 'No',
                      subtitle:
                          'Il genitore viene registrato solo come tutore del minore.',
                      icon: Icons.person_off_outlined,
                      isSelected: _genitoreIsAssociato == false,
                      onTap: () => setState(() => _genitoreIsAssociato = false),
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

  Widget _buildFormCardIdentita()
  {
    return WizardFormSectionCard(
      isCompact: true,
      title: 'Identità',
      leadingIcon: const WizardStaticAvatar(icon: Icons.badge_outlined),
      children: [
        WizardFormInputRow(
          label: 'Foto profilo',
          inputWidget: WizardProfilePhotoUploader(
            imageBytes: _fotoProfilo,
            onImagePicked: (bytes) => setState(() => _fotoProfilo = bytes),
          ),
        ),
        const SizedBox(height: 24),
        WizardFormInputRow(
          label: 'Nome',
          inputWidget: WizardAnimatedTextField(
            controller: _nomeCtrl,
            hint: 'Es. Mario',
            errorText: _formErrors['nome'],
            onChanged: (_) => setState(() => _formErrors.remove('nome')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Cognome',
          inputWidget: WizardAnimatedTextField(
            controller: _cognomeCtrl,
            hint: 'Es. Rossi',
            errorText: _formErrors['cognome'],
            onChanged: (_) => setState(() => _formErrors.remove('cognome')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Sesso',
          inputWidget: WizardAnimatedOverlayDropdown(
            value: _sesso,
            items: const ['M', 'F'],
            hint: 'Seleziona',
            errorText: _formErrors['sesso'],
            onChanged: (val) => setState(()
            {
              _sesso = val;
              _formErrors.remove('sesso');
            }),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Codice fiscale',
          inputWidget: WizardAnimatedTextField(
            controller: _cfCtrl,
            hint: 'Es. RSSMRA80A01L157H',
            errorText: _formErrors['cf'],
            onChanged: (_) => setState(() => _formErrors.remove('cf')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardAnagrafica()
  {
    return WizardFormSectionCard(
      isCompact: true,
      title: 'Dati anagrafici',
      leadingIcon: const WizardStaticAvatar(icon: Icons.cake_rounded),
      children: [
        WizardFormInputRow(
          label: 'Data di nascita',
          inputWidget: WizardAnimatedTextField(
            controller: _dataNascitaCtrl,
            hint: 'gg/mm/aaaa',
            keyboardType: TextInputType.number,
            inputFormatters: [WizardDateInputFormatter()],
            errorText: _formErrors['dataNascita'],
            onChanged: (_) => setState(() => _formErrors.remove('dataNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Città di nascita',
          inputWidget: WizardAnimatedTextField(
            controller: _cittaNascitaCtrl,
            hint: 'Es. Thiene',
            errorText: _formErrors['cittaNascita'],
            onChanged: (_) =>
                setState(() => _formErrors.remove('cittaNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Provincia',
          inputWidget: WizardAnimatedTextField(
            controller: _provNascitaCtrl,
            hint: 'Es. VI',
            errorText: _formErrors['provNascita'],
            onChanged: (_) => setState(() => _formErrors.remove('provNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Nazione di nascita',
          inputWidget: WizardAnimatedTextField(
            controller: _nazioneNascitaCtrl,
            hint: 'Es. Italia',
            errorText: _formErrors['nazioneNascita'],
            onChanged: (_) =>
                setState(() => _formErrors.remove('nazioneNascita')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardResidenza()
  {
    return WizardFormSectionCard(
      isCompact: true,
      title: 'Residenza',
      leadingIcon: const WizardStaticAvatar(icon: Icons.home_rounded),
      children: [
        WizardFormInputRow(
          label: 'Indirizzo',
          // Stacks the address fields below the width breakpoint.
          inputWidget: WizardAddressFieldsRow(
            tipoViaCtrl: _tipoViaCtrl,
            tipoViaError: _formErrors['tipoVia'],
            onTipoViaChanged: (_) =>
                setState(() => _formErrors.remove('tipoVia')),
            nomeCtrl: _indirizzoNomeCtrl,
            nomeError: _formErrors['indirizzoNome'],
            onNomeChanged: (_) =>
                setState(() => _formErrors.remove('indirizzoNome')),
            civicoCtrl: _civicoCtrl,
            civicoError: _formErrors['civico'],
            onCivicoChanged: (_) =>
                setState(() => _formErrors.remove('civico')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Città',
          inputWidget: WizardAnimatedTextField(
            controller: _cittaResidenzaCtrl,
            hint: 'Es. Thiene',
            errorText: _formErrors['cittaResidenza'],
            onChanged: (_) =>
                setState(() => _formErrors.remove('cittaResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Provincia',
          inputWidget: WizardAnimatedTextField(
            controller: _provResidenzaCtrl,
            hint: 'Es. VI',
            errorText: _formErrors['provResidenza'],
            onChanged: (_) =>
                setState(() => _formErrors.remove('provResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'CAP',
          inputWidget: WizardAnimatedTextField(
            controller: _capCtrl,
            hint: 'Es. 36016',
            keyboardType: TextInputType.number,
            errorText: _formErrors['cap'],
            onChanged: (_) => setState(() => _formErrors.remove('cap')),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardContatti()
  {
    return WizardFormSectionCard(
      isCompact: true,
      title: 'Contatti',
      leadingIcon: const WizardStaticAvatar(
        icon: Icons.alternate_email_rounded,
      ),
      children: [
        WizardFormInputRow(
          label: 'Email',
          inputWidget: WizardAnimatedTextField(
            controller: _emailCtrl,
            hint: 'Es. mario.rossi@email.com',
            keyboardType: TextInputType.emailAddress,
            errorText: _formErrors['email'],
            onChanged: (_) => setState(() => _formErrors.remove('email')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label: 'Telefono',
          inputWidget: WizardAnimatedTextField(
            controller: _telefonoCtrl,
            hint: 'Es. 3331234567',
            keyboardType: TextInputType.phone,
            errorText: _formErrors['telefono'],
            onChanged: (_) => setState(() => _formErrors.remove('telefono')),
          ),
        ),
      ],
    );
  }

  List<Widget> get _activeStep2Cards
  {
    final List<Widget> cards = [];

    cards.add(_buildFormCardIscrizione());

    // Both cards are shown only when the parent joins the association.
    if (_genitoreIsAssociato)
    {
      cards.add(_buildFormCardSostegnoPsicologico());
      cards.add(_buildFormCardConsensi());
    }

    return cards;
  }

  Widget _buildFormCardIscrizione()
  {
    return WizardFormSectionCard(
      title: 'Iscrizioni',
      leadingIcon: const WizardStaticAvatar(
        icon: Icons.assignment_ind_outlined,
      ),
      children: [
        // Stacks the enrollment fields below the width breakpoint.
        ...List.generate(_enrollmentRows.length, (index)
        {
          final row = _enrollmentRows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: WizardEnrollmentFieldRow(
              yearCtrl: row.yearCtrl,
              dateCtrl: row.dateCtrl,
              yearError: _formErrors['enrollmentYear_$index'],
              dateError: _formErrors['enrollmentDate_$index'],
              onYearChanged: (_) => setState(
                () => _formErrors.remove('enrollmentYear_$index'),
              ),
              onDateChanged: (_) => setState(
                () => _formErrors.remove('enrollmentDate_$index'),
              ),
              onRemove: index > 0
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
        Align(
          alignment: Alignment.centerRight,
          child: WizardTextLinkButton(
            text: 'Aggiungi iscrizione',
            icon: Icons.add_rounded,
            onTap: ()
            {
              int lastYear = DateTime.now().year;
              if (_enrollmentRows.isNotEmpty)
              {
                lastYear =
                    int.tryParse(_enrollmentRows.last.yearCtrl.text) ??
                    lastYear;
              }
              setState(()
              {
                _enrollmentRows.add(
                  WizardEnrollmentRowData(
                    yearCtrl: TextEditingController(
                      text: (lastYear - 1).toString(),
                    ),
                    dateCtrl: TextEditingController(),
                  ),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardSostegnoPsicologico()
  {
    return WizardFormSectionCard(
      title: 'Sostegno Psicologico',
      leadingIcon: const WizardStaticAvatar(icon: Icons.psychology_outlined),
      children: [
        WizardFormInputRow(
          label: 'Aderisce al servizio',
          inputWidget: Align(
            alignment: Alignment.centerLeft,
            child: WizardYesNoSwitch(
              value: _aderisceSostegnoPsicologico,
              onChanged: (val) =>
                  setState(() => _aderisceSostegnoPsicologico = val),
            ),
          ),
        ),
        if (_aderisceSostegnoPsicologico) ...[
          const SizedBox(height: 16),
          WizardFormInputRow(
            label: 'Data di inizio',
            inputWidget: WizardAnimatedTextField(
              controller: _dataInizioSostegnoPsicologicoCtrl,
              hint: 'gg/mm/aaaa',
              keyboardType: TextInputType.number,
              inputFormatters: [WizardDateInputFormatter()],
              errorText: _formErrors['dataInizioSostegnoPsicologico'],
              onChanged: (_) => setState(
                () => _formErrors.remove('dataInizioSostegnoPsicologico'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormCardConsensi()
  {
    return WizardFormSectionCard(
      title: 'Dichiarazioni e Consensi',
      leadingIcon: const WizardStaticAvatar(icon: Icons.fact_check_outlined),
      children: [
        WizardFormInputRow(
          label: 'Statuto',
          inputWidget: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch(
                value: _statutoAccettato,
                isError: _formErrors['statutoAccettato'] != null,
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
        WizardFormInputRow(
          label: 'Regolamento',
          inputWidget: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch(
                value: _regolamentoAccettato,
                isError: _formErrors['regolamentoAccettato'] != null,
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
        WizardFormInputRow(
          label: 'Videosorveglianza',
          inputWidget: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch(
                value: _videosorveglianzaPresaVisione,
                isError: _formErrors['videosorveglianzaPresaVisione'] != null,
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
        WizardFormInputRow(
          label: 'Dati particolari',
          inputWidget: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch(
                value: _consensoDatiParticolari,
                isError: _formErrors['consensoDatiParticolari'] != null,
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
        WizardFormInputRow(
          label: 'Notiziari periodici',
          inputWidget: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WizardYesNoSwitch(
                value: _consensoNewsletter,
                isError: _formErrors['consensoNewsletter'] != null,
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

  Widget _buildStep2Iscrizioni()
  {
    final cards = _activeStep2Cards;
    final Widget currentCardStep2 =
        cards.isNotEmpty ? cards[_currentStep2CardIndex] : const SizedBox.shrink();

    return SizedBox(
      key: const ValueKey('step2_p'),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  'Iscrizioni Associative',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inserisci le iscrizioni all\'Associazione per il genitore.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints)
              {
                final bool isCompact = constraints.maxWidth < 900;

                final Widget desktopAnimatedCards = AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  ),
                  transitionBuilder: (child, animation)
                  {
                    final isEntering =
                        (child.key as ValueKey<int>).value ==
                        _currentStep2CardIndex;
                    Offset beginOffset = _card2MovingForward
                        ? (isEntering
                              ? const Offset(0.05, 0)
                              : const Offset(-0.05, 0))
                        : (isEntering
                              ? const Offset(-0.05, 0)
                              : const Offset(0.05, 0));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: beginOffset,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentStep2CardIndex),
                    child: currentCardStep2,
                  ),
                );

                final Widget compactAnimatedCards = AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  ),
                  transitionBuilder: (child, animation)
                  {
                    final isEntering =
                        (child.key as ValueKey<int>).value ==
                        _currentStep2CardIndex;
                    Offset beginOffset = _card2MovingForward
                        ? (isEntering
                              ? const Offset(0.05, 0)
                              : const Offset(-0.05, 0))
                        : (isEntering
                              ? const Offset(-0.05, 0)
                              : const Offset(0.05, 0));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: beginOffset,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentStep2CardIndex),
                    // Takes whatever height the outer Expanded provides.
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: SingleChildScrollView(child: currentCardStep2),
                    ),
                  ),
                );

                return isCompact
                    ? Column(
                        children: [
                          // Expanded gives the card exactly the residual height.
                          Expanded(
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: compactAnimatedCards,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              WizardCarouselArrowButton(
                                icon: Icons.chevron_left_rounded,
                                isDisabled: _currentStep2CardIndex == 0,
                                onTap: () => setState(()
                                {
                                  _card2MovingForward = false;
                                  _currentStep2CardIndex--;
                                }),
                              ),
                              const SizedBox(width: 24),
                              WizardCarouselArrowButton(
                                icon: Icons.chevron_right_rounded,
                                isDisabled:
                                    _currentStep2CardIndex >= cards.length - 1,
                                onTap: () => setState(()
                                {
                                  _card2MovingForward = true;
                                  _currentStep2CardIndex++;
                                }),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          WizardCarouselArrowButton(
                            icon: Icons.chevron_left_rounded,
                            isDisabled: _currentStep2CardIndex == 0,
                            onTap: () => setState(()
                            {
                              _card2MovingForward = false;
                              _currentStep2CardIndex--;
                            }),
                          ),
                          const SizedBox(width: 32),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: desktopAnimatedCards,
                            ),
                          ),
                          const SizedBox(width: 32),
                          WizardCarouselArrowButton(
                            icon: Icons.chevron_right_rounded,
                            isDisabled:
                                _currentStep2CardIndex >= cards.length - 1,
                            onTap: () => setState(()
                            {
                              _card2MovingForward = true;
                              _currentStep2CardIndex++;
                            }),
                          ),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    Widget currentCard = const SizedBox.shrink();
    if (_currentStep == 1)
    {
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
      }
    }

    final bool isLastStep =
        _currentStep == 2 || (_currentStep == 1 && !_genitoreIsAssociato);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration(
          color: AppTheme.pageBackground,
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              offset: Offset(0, 12),
              blurRadius: 36,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              Positioned(
                right: -400,
                top: -400,
                child: IgnorePointer(
                  child: Container(
                    width: 800,
                    height: 800,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -400,
                bottom: -400,
                child: IgnorePointer(
                  child: Container(
                    width: 800,
                    height: 800,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 24,
                      right: 24,
                      left: 32,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nuovo Genitore',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        WizardHoverCloseButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 32,
                    thickness: 1,
                    color: AppTheme.slate200,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
                        transitionBuilder: (child, animation)
                        {
                          final isEntering =
                              (child.key as ValueKey<String>).value ==
                              'step${_currentStep}_p';
                          Offset beginOffset = _movingForward
                              ? (isEntering
                                    ? const Offset(0.05, 0)
                                    : const Offset(-0.05, 0))
                              : (isEntering
                                    ? const Offset(-0.05, 0)
                                    : const Offset(0.05, 0));
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: beginOffset,
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _currentStep == 0
                            ? _buildStep0Association()
                            : _currentStep == 1
                            ? SizedBox(
                                key: const ValueKey('step1_p'),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Informazioni Personali Genitore',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Compila i dati del genitore. Dopo la creazione, sarà possibile modificare solo la residenza e i contatti.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.slate500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints)
                                        {
                                          final bool isCompact =
                                              constraints.maxWidth < 900;

                                          final Widget desktopAnimatedCard = AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            layoutBuilder:
                                                (currentChild, previousChildren) =>
                                                    Stack(
                                                      alignment: Alignment.center,
                                                      children: [
                                                        ...previousChildren,
                                                        ?currentChild,
                                                      ],
                                                    ),
                                            transitionBuilder: (child, animation)
                                            {
                                              final isEntering =
                                                  (child.key as ValueKey<int>)
                                                      .value ==
                                                  _currentFormCardIndex;
                                              Offset beginOffset =
                                                  _cardMovingForward
                                                  ? (isEntering
                                                        ? const Offset(0.05, 0)
                                                        : const Offset(-0.05, 0))
                                                  : (isEntering
                                                        ? const Offset(-0.05, 0)
                                                        : const Offset(0.05, 0));
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: beginOffset,
                                                    end: Offset.zero,
                                                  ).animate(animation),
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: KeyedSubtree(
                                              key: ValueKey(_currentFormCardIndex),
                                              child: currentCard,
                                            ),
                                          );

                                          // Takes the height from the outer Expanded, scrolling internally if it still overflows.
                                          final Widget compactAnimatedCard = AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            layoutBuilder:
                                                (currentChild, previousChildren) =>
                                                    Stack(
                                                      alignment:
                                                          Alignment.topCenter,
                                                      children: [
                                                        ...previousChildren,
                                                        ?currentChild,
                                                      ],
                                                    ),
                                            transitionBuilder: (child, animation)
                                            {
                                              final isEntering =
                                                  (child.key as ValueKey<int>)
                                                      .value ==
                                                  _currentFormCardIndex;
                                              Offset beginOffset =
                                                  _cardMovingForward
                                                  ? (isEntering
                                                        ? const Offset(0.05, 0)
                                                        : const Offset(-0.05, 0))
                                                  : (isEntering
                                                        ? const Offset(-0.05, 0)
                                                        : const Offset(0.05, 0));
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: beginOffset,
                                                    end: Offset.zero,
                                                  ).animate(animation),
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: KeyedSubtree(
                                              key: ValueKey(_currentFormCardIndex),
                                              child: SizedBox(
                                                width: constraints.maxWidth,
                                                child: SingleChildScrollView(
                                                  child: currentCard,
                                                ),
                                              ),
                                            ),
                                          );

                                          return isCompact
                                              ? Column(
                                                  children: [
                                                    // Expanded gives the card exactly the residual height.
                                                    Expanded(
                                                      child: SizedBox(
                                                        width: constraints.maxWidth,
                                                        child: compactAnimatedCard,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        WizardCarouselArrowButton(
                                                          icon: Icons
                                                              .chevron_left_rounded,
                                                          isDisabled:
                                                              _currentFormCardIndex ==
                                                              0,
                                                          onTap: () => setState(()
                                                          {
                                                            _cardMovingForward =
                                                                false;
                                                            _currentFormCardIndex--;
                                                          }),
                                                        ),
                                                        const SizedBox(width: 24),
                                                        WizardCarouselArrowButton(
                                                          icon: Icons
                                                              .chevron_right_rounded,
                                                          isDisabled:
                                                              _currentFormCardIndex ==
                                                              3,
                                                          onTap: () => setState(()
                                                          {
                                                            _cardMovingForward =
                                                                true;
                                                            _currentFormCardIndex++;
                                                          }),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    WizardCarouselArrowButton(
                                                      icon: Icons
                                                          .chevron_left_rounded,
                                                      isDisabled:
                                                          _currentFormCardIndex ==
                                                          0,
                                                      onTap: () => setState(()
                                                      {
                                                        _cardMovingForward = false;
                                                        _currentFormCardIndex--;
                                                      }),
                                                    ),
                                                    const SizedBox(width: 32),
                                                    Flexible(
                                                      child: ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxWidth: 800,
                                                            ),
                                                        child: desktopAnimatedCard,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 32),
                                                    WizardCarouselArrowButton(
                                                      icon: Icons
                                                          .chevron_right_rounded,
                                                      isDisabled:
                                                          _currentFormCardIndex ==
                                                          3,
                                                      onTap: () => setState(()
                                                      {
                                                        _cardMovingForward = true;
                                                        _currentFormCardIndex++;
                                                      }),
                                                    ),
                                                  ],
                                                );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _buildStep2Iscrizioni(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32),
                    // Stacks the two fixed-width buttons when the dialog is too narrow to fit them side by side.
                    child: WizardResponsiveBottomBar(
                      secondaryButton: _currentStep == 0
                          ? WizardAnimatedActionButton(
                              text: 'ANNULLA',
                              icon: Icons.close_rounded,
                              baseColor: AppTheme.danger,
                              hoverColor: AppTheme.dangerHover,
                              onPressed: () => Navigator.of(context).pop(),
                            )
                          : WizardOutlinedActionButton(
                              text: 'INDIETRO',
                              icon: Icons.arrow_back_rounded,
                              onPressed: _onBack,
                            ),
                      primaryButton: WizardAnimatedActionButton(
                        text: _isCheckingCf
                            ? 'VERIFICA...'
                            : (_isSubmitting
                                  ? 'SALVATAGGIO...'
                                  : (isLastStep ? 'CREA GENITORE' : 'AVANTI')),
                        icon: isLastStep
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward_rounded,
                        baseColor: AppTheme.primary,
                        hoverColor: AppTheme.primaryHover,
                        onPressed: (_isSubmitting || _isCheckingCf)
                            ? () {}
                            : _onNext,
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
