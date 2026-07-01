import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/snackbar.dart';
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
  int                 _currentStep          = 0;
  bool                _movingForward        = true;
  bool                _genitoreIsAssociato  = false;
  int                 _currentFormCardIndex = 0; 
  Map<String, String> _formErrors           = {};
  Uint8List?          _fotoProfilo;
  bool                _isSubmitting         = false;
  bool                _cardMovingForward    = true;

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
  final List<WizardEnrollmentRowData> _enrollmentRows = [];

  static const double _kCompactCardBoxHeight = 560.0;


  @override
  void initState() 
  {
    super.initState();
    final now = DateTime.now();
    _enrollmentRows.add(WizardEnrollmentRowData(
      yearCtrl: TextEditingController(text: now.year.toString()),
      dateCtrl: TextEditingController(text: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}'),
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
    _tipoViaCtrl.dispose();
    _indirizzoNomeCtrl.dispose();
    _civicoCtrl.dispose();
    _cittaResidenzaCtrl.dispose();
    _provResidenzaCtrl.dispose();
    _capCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
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
    const oddValues = {
      '0': 1, '1': 0, '2': 5, '3': 7, '4': 9, '5': 13, '6': 15, '7': 17, '8': 19, '9': 21,
      'A': 1, 'B': 0, 'C': 5, 'D': 7, 'E': 9, 'F': 13, 'G': 15, 'H': 17, 'I': 19, 'J': 21,
      'K': 2, 'L': 4, 'M': 18, 'N': 20, 'O': 11, 'P': 3, 'Q': 6, 'R': 8, 'S': 12, 'T': 14,
      'U': 16, 'V': 10, 'W': 22, 'X': 25, 'Y': 24, 'Z': 23
    };
    const evenValues = {
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
          if (age < 18)
          {
            addError('dataNascita', 'Il genitore deve avere almeno 18 anni', 1);
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

  bool _validateIscrizioni() 
  {
    bool                isValid   = true;
    Map<String, String> newErrors = Map.from(_formErrors);
    
    if (_enrollmentRows.isEmpty)
    {
      newErrors['enrollmentGeneral'] = 'Aggiungi almeno un\'iscrizione';
      isValid = false;
    }

    for (int i = 0; i < _enrollmentRows.length; i++) 
    {
      final row = _enrollmentRows[i];
      bool yearValid = false;
      
      if (row.yearCtrl.text.trim().isEmpty) 
      {
        newErrors['enrollmentYear_$i'] = 'Campo obbligatorio';
        isValid = false;
      } 
      else if (!RegExp(r'^\d{4}$').hasMatch(row.yearCtrl.text.trim())) 
      {
        newErrors['enrollmentYear_$i'] = 'Anno non valido';
        isValid = false;
      }
      else
      {
        int parsedYear = int.parse(row.yearCtrl.text.trim());
        if (parsedYear > DateTime.now().year)
        {
          newErrors['enrollmentYear_$i'] = 'Anno non futuro';
          isValid = false;
        }
        else
        {
          yearValid = true;
        }
      }
      
      if (row.dateCtrl.text.trim().isEmpty) 
      {
        newErrors['enrollmentDate_$i'] = 'Campo obbligatorio';
        isValid = false;
      } 
      else if (yearValid && !_isValidDayMonthYear(row.dateCtrl.text.trim(), row.yearCtrl.text.trim())) 
      {
        newErrors['enrollmentDate_$i'] = 'Data non valida';
        isValid = false;
      }
      else if (!yearValid && !RegExp(r'^\d{2}/\d{2}$').hasMatch(row.dateCtrl.text.trim()))
      {
        newErrors['enrollmentDate_$i'] = 'Formato gg/mm';
        isValid = false;
      }
    }
    
    setState(() 
    {
      _formErrors = newErrors;
    });
    
    if (!isValid) 
    {
      CustomSnackBar.show(context: context, message: 'Ci sono errori nelle iscrizioni inserite.', isError: true);
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

      if (_genitoreIsAssociato) 
      {
        finalRoles.add('ASSOCIATO');
        
        List<Map<String, dynamic>> membershipsData = [];
        for (final row in _enrollmentRows) 
        {
          final parts   = row.dateCtrl.text.trim().split('/');
          final isoDate = '${row.yearCtrl.text.trim()}-${parts[1]}-${parts[0]}';
          
          membershipsData.add({
            "year":                int.parse(row.yearCtrl.text.trim()),
            "start_date":          isoDate,
            "end_date":            "${row.yearCtrl.text.trim()}-12-31",
            "renewal_period_days": 30,
            "revocation":          "NO"
          });
        }
        
        if (membershipsData.isNotEmpty) 
        {
          memberData = {
            "memberships": membershipsData
          };
        }
      }

      final payload = {
        "general_data": {
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
        "roles":       finalRoles,
        "member_data": memberData,
        "relationships": {
          "minors_tax_codes":  [], 
          "parents_tax_codes": [], 
        }
      };

      final newParent = PersonItem(
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
        Navigator.of(context).pop({'person': newParent, 'payload': payload, 'imageBytes': _fotoProfilo});
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        CustomSnackBar.show(
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

  void _onNext() 
  {
    if (_currentStep == 0) 
    {
      setState(() 
      { 
        _movingForward = true; 
        _currentStep   = 1; 
      });
      return;
    }

    if (_currentStep == 1) 
    {
      if (!_validateDatiGenerali()) return;
      
      if (_genitoreIsAssociato) 
      {
        setState(() 
        { 
          _movingForward = true; 
          _currentStep   = 2; 
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
      if (!_validateIscrizioni()) return;
      _submitForm();
      return;
    }
  }

  void _onBack() 
  {
    setState(() => _movingForward = false);
    if (_currentStep == 2) setState(() => _currentStep = 1);
    else if (_currentStep == 1) setState(() => _currentStep = 0);
  }

  Widget _buildStep0Association() 
  {
    return SizedBox(
      key:   const ValueKey('step0_p'),
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
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Il genitore può iscrivere il proprio figlio senza diventare socio.\nScegli se desidera aderire anche personalmente.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF64748B),
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
                  spacing:    32,
                  runSpacing: 32,
                  alignment:  WrapAlignment.center,
                  children: [
                    WizardSelectionCard(
                      title:      'Sì', 
                      subtitle:   'Il genitore aderisce all\'Associazione e versa la quota annuale.', 
                      icon:       Icons.person_outlined, 
                      isSelected: _genitoreIsAssociato == true, 
                      onTap:      () => setState(() => _genitoreIsAssociato = true),
                    ),
                    WizardSelectionCard(
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

  Widget _buildFormCardIdentita() 
  {
    return WizardFormSectionCard(
      isCompact:   true,
      title:       'Identità',
      leadingIcon: const WizardStaticAvatar(icon: Icons.badge_outlined),
      children: [
        WizardFormInputRow(
          label:       'Foto profilo',
          inputWidget: WizardProfilePhotoUploader(
            imageBytes:    _fotoProfilo,
            onImagePicked: (bytes) => setState(() => _fotoProfilo = bytes),
          ),
        ),
        const SizedBox(height: 24),
        WizardFormInputRow(
          label:       'Nome',
          inputWidget: WizardAnimatedTextField(
            controller: _nomeCtrl, 
            hint:       'Es. Mario',
            errorText:  _formErrors['nome'],
            onChanged:  (_) => setState(() => _formErrors.remove('nome')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Cognome',
          inputWidget: WizardAnimatedTextField(
            controller: _cognomeCtrl, 
            hint:       'Es. Rossi',
            errorText:  _formErrors['cognome'],
            onChanged:  (_) => setState(() => _formErrors.remove('cognome')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Sesso',
          inputWidget: WizardAnimatedOverlayDropdown(
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
        WizardFormInputRow(
          label:       'Codice fiscale',
          inputWidget: WizardAnimatedTextField(
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
    return WizardFormSectionCard(
      isCompact:   true,
      title:       'Dati anagrafici',
      leadingIcon: const WizardStaticAvatar(icon: Icons.cake_rounded),
      children: [
        WizardFormInputRow(
          label:       'Data di nascita',
          inputWidget: WizardAnimatedTextField(
            controller:      _dataNascitaCtrl,
            hint:            'gg/mm/aaaa',
            keyboardType:    TextInputType.number,
            inputFormatters: [WizardDateInputFormatter()],
            errorText:       _formErrors['dataNascita'],
            onChanged:       (_) => setState(() => _formErrors.remove('dataNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Città di nascita',
          inputWidget: WizardAnimatedTextField(
            controller: _cittaNascitaCtrl, 
            hint:       'Es. Thiene',
            errorText:  _formErrors['cittaNascita'],
            onChanged:  (_) => setState(() => _formErrors.remove('cittaNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Provincia',
          inputWidget: WizardAnimatedTextField(
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
    return WizardFormSectionCard(
      isCompact:   true,
      title:       'Residenza',
      leadingIcon: const WizardStaticAvatar(icon: Icons.home_rounded),
      children: [
        WizardFormInputRow(
          label:       'Indirizzo',
          inputWidget: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex:  3,
                child: WizardAnimatedTextField(
                  controller: _tipoViaCtrl, 
                  hint:       'Via/Strada/...',
                  errorText:  _formErrors['tipoVia'],
                  onChanged:  (_) => setState(() => _formErrors.remove('tipoVia')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex:  5,
                child: WizardAnimatedTextField(
                  controller: _indirizzoNomeCtrl, 
                  hint:       'Nome',
                  errorText:  _formErrors['indirizzoNome'],
                  onChanged:  (_) => setState(() => _formErrors.remove('indirizzoNome')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex:  2,
                child: WizardAnimatedTextField(
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
        WizardFormInputRow(
          label:       'Città',
          inputWidget: WizardAnimatedTextField(
            controller: _cittaResidenzaCtrl, 
            hint:       'Es. Thiene',
            errorText:  _formErrors['cittaResidenza'],
            onChanged:  (_) => setState(() => _formErrors.remove('cittaResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Provincia',
          inputWidget: WizardAnimatedTextField(
            controller: _provResidenzaCtrl, 
            hint:       'Es. VI',
            errorText:  _formErrors['provResidenza'],
            onChanged:  (_) => setState(() => _formErrors.remove('provResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'CAP',
          inputWidget: WizardAnimatedTextField(
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
    return WizardFormSectionCard(
      isCompact:   true,
      title:       'Contatti',
      leadingIcon: const WizardStaticAvatar(icon: Icons.alternate_email_rounded),
      children: [
        WizardFormInputRow(
          label:       'Email',
          inputWidget: WizardAnimatedTextField(
            controller:   _emailCtrl, 
            hint:         'Es. mario.rossi@email.com', 
            keyboardType: TextInputType.emailAddress,
            errorText:    _formErrors['email'],
            onChanged:    (_) => setState(() => _formErrors.remove('email')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Telefono',
          inputWidget: WizardAnimatedTextField(
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

  Widget _buildStep2Iscrizioni()
  {
    return SizedBox(
      key:   const ValueKey('step2_p'),
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
                  style:     GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))
                ),
                const SizedBox(height: 8),
                Text(
                  'Inserisci le iscrizioni all\'Associazione per il genitore.', 
                  textAlign: TextAlign.center, 
                  style:     GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: WizardFormSectionCard(
                    title:       'Iscrizioni',
                    leadingIcon: const WizardStaticAvatar(icon: Icons.assignment_ind_outlined),
                    children: [
                      ...List.generate(_enrollmentRows.length, (index) 
                      {
                        final row = _enrollmentRows[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex:  2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (index == 0) ...[
                                      Text(
                                        'Anno',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize:   14, 
                                          fontWeight: FontWeight.w600, 
                                          color:      const Color(0xFF7A7A7A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    WizardAnimatedTextField(
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
                              Expanded(
                                flex:  3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (index == 0) ...[
                                      Text(
                                        'Data inizio',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize:   14, 
                                          fontWeight: FontWeight.w600, 
                                          color:      const Color(0xFF7A7A7A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    WizardAnimatedTextField(
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
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, left: 8),
                                  child: WizardRemoveRowButton(
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: WizardTextLinkButton(
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
                              _enrollmentRows.add(WizardEnrollmentRowData(
                                yearCtrl: TextEditingController(text: (lastYear - 1).toString()),
                                dateCtrl: TextEditingController(),
                              ));
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

    final bool isLastStep = _currentStep == 2 || (_currentStep == 1 && !_genitoreIsAssociato);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container(
        width:       MediaQuery.of(context).size.width * 0.85,
        height:      MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration:  BoxDecoration(
          color:        const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(40),
          boxShadow:    const [
            BoxShadow(
              color:      Color(0x26000000),
              offset:     Offset(0, 12),
              blurRadius: 36,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              Positioned(
                right: -400, 
                top:   -400,
                child: IgnorePointer(
                  child: Container(
                    width:      800, 
                    height:     800,
                    decoration: const BoxDecoration(
                      shape:    BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0x22003C82), Color(0x00003C82)], stops: [0.0, 1.0]),
                    ),
                  ),
                ),
              ),
              Positioned(
                left:   -400, 
                bottom: -400,
                child: IgnorePointer(
                  child: Container(
                    width:      800, 
                    height:     800,
                    decoration: const BoxDecoration(
                      shape:    BoxShape.circle,
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
                        Text('Nuovo Genitore', style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AnimatedSwitcher(
                        duration:       const Duration(milliseconds: 300),
                        switchInCurve:  Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder:  (currentChild, previousChildren) => Stack(alignment: Alignment.center, children: [...previousChildren, if (currentChild != null) currentChild]),
                        transitionBuilder: (child, animation) 
                        {
                          final isEntering   = (child.key as ValueKey<String>).value == 'step${_currentStep}_p';
                          Offset beginOffset = _movingForward ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0)) : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));
                          return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation), child: child));
                        },
                        child: _currentStep == 0 ? _buildStep0Association() :
                              _currentStep == 1 ? SizedBox
                              (
                                key: const ValueKey('step1_p'),
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
                                          Text('Informazioni Personali Genitore', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                                          const SizedBox(height: 8),
                                          Text('Compila i dati del genitore. Dopo la creazione, sarà possibile modificare solo la residenza e i contatti.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
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
                                              child: SizedBox
                                              (
                                                height: _kCompactCardBoxHeight,
                                                width:  constraints.maxWidth,
                                                child:  SingleChildScrollView(child: currentCard),
                                              ),
                                            ),
                                          );

                                          return isCompact
                                              ? Center
                                                (
                                                  child: Column
                                                  (
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: 
                                                    [
                                                      SizedBox(height: _kCompactCardBoxHeight, width: constraints.maxWidth, child: compactAnimatedCard),
                                                      const SizedBox(height: 24),
                                                      Row
                                                      (
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: 
                                                        [
                                                          WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentFormCardIndex == 0, onTap: () => setState(() { _cardMovingForward = false; _currentFormCardIndex--; })),
                                                          const SizedBox(width: 24),
                                                          WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentFormCardIndex == 3, onTap: () => setState(() { _cardMovingForward = true; _currentFormCardIndex++; })),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : Row
                                                (
                                                  mainAxisAlignment:  MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: 
                                                  [
                                                    WizardCarouselArrowButton(icon: Icons.chevron_left_rounded, isDisabled: _currentFormCardIndex == 0, onTap: () => setState(() { _cardMovingForward = false; _currentFormCardIndex--; })),
                                                    const SizedBox(width: 32),
                                                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: desktopAnimatedCard),
                                                    const SizedBox(width: 32),
                                                    WizardCarouselArrowButton(icon: Icons.chevron_right_rounded, isDisabled: _currentFormCardIndex == 3, onTap: () => setState(() { _cardMovingForward = true; _currentFormCardIndex++; })),
                                                  ],
                                                );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ) : _buildStep2Iscrizioni(),
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
                          child: WizardAnimatedActionButton(
                            text:       _isSubmitting ? 'SALVATAGGIO...' : (isLastStep ? 'CREA GENITORE' : 'AVANTI'), 
                            icon:       isLastStep ? Icons.check_circle_outline : Icons.arrow_forward_rounded, 
                            baseColor:  const Color(0xFF003C82), 
                            hoverColor: const Color(0xFF004D99), 
                            onPressed:  _isSubmitting ? () {} : _onNext,
                          ),
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