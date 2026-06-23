import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/snackbar.dart';
import '../../../services/api_service.dart';
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
  int                 _currentFormCardIndex = 0; 
  Map<String, String> _formErrors           = {};
  Uint8List?          _fotoProfilo;
  bool                _isSubmitting         = false;

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

  String? _toIsoDate(String? itaDate) 
  {
    if (itaDate == null || itaDate.isEmpty) return null;
    final parts = itaDate.split('/');
    if (parts.length != 3) return null;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
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
    else if (!RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(_cfCtrl.text))
    {
      addError('cf', 'Codice fiscale non valido', 0);
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
        _currentFormCardIndex = firstInvalidCard!;
      }
    });

    if (!isValid)
    {
      CustomSnackBar.show(context: context, message: 'Ci sono errori nei dati inseriti. Correggi i campi evidenziati.', isError: true);
    }

    return isValid;
  }

  Future<void> _submitForm() async 
  {
    setState(() => _isSubmitting = true);
    
    try 
    {
      final payload = {
        "general_data": {
          "first_name": _nomeCtrl.text.trim(),
          "last_name": _cognomeCtrl.text.trim(),
          "tax_code": _cfCtrl.text.trim().toUpperCase(),
          "gender": _sesso,
          "birth_date": _toIsoDate(_dataNascitaCtrl.text.trim()),
          "birth_city": _cittaNascitaCtrl.text.trim(),
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
        "roles": ["GENITORE", "ASSOCIATO"],
        "relationships": {
          "minors_tax_codes": [], 
          "parents_tax_codes": [], 
        }
      };

      await ApiService().createPersonFromWizard(
        payload, 
        imageBytes: _fotoProfilo,
      );

      final newParent = PersonItem(
        fiscalCode: _cfCtrl.text.trim().toUpperCase(),
        firstName: _nomeCtrl.text.trim(),
        lastName: _cognomeCtrl.text.trim(),
        roles: ['Genitore', 'Associato'],
        createdAt: DateTime.now(),
        city: _cittaResidenzaCtrl.text.trim(),
        birthDate: DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text.trim()),
      );

      if (mounted) 
      {
        Navigator.of(context).pop(newParent);
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
            hint:       'Es. RSSMRA80A01H501Z',
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
            hint:       'Es. Roma',
            errorText:  _formErrors['cittaNascita'],
            onChanged:  (_) => setState(() => _formErrors.remove('cittaNascita')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Prov. di nascita',
          inputWidget: WizardAnimatedTextField(
            controller: _provNascitaCtrl, 
            hint:       'Es. RM',
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
                  hint:       'Es. Via',
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
            hint:       'Es. Milano',
            errorText:  _formErrors['cittaResidenza'],
            onChanged:  (_) => setState(() => _formErrors.remove('cittaResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'Provincia',
          inputWidget: WizardAnimatedTextField(
            controller: _provResidenzaCtrl, 
            hint:       'Es. MI',
            errorText:  _formErrors['provResidenza'],
            onChanged:  (_) => setState(() => _formErrors.remove('provResidenza')),
          ),
        ),
        const SizedBox(height: 16),
        WizardFormInputRow(
          label:       'CAP',
          inputWidget: WizardAnimatedTextField(
            controller:   _capCtrl, 
            hint:         'Es. 20100', 
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
            hint:         'Es. 333 1234567', 
            keyboardType: TextInputType.phone,
            errorText:    _formErrors['telefono'],
            onChanged:    (_) => setState(() => _formErrors.remove('telefono')),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
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
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)], 
                        stops:  [0.0, 1.0]
                      ),
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
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)], 
                        stops:  [0.0, 1.0]
                      ),
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
                          'Nuovo Genitore',
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                Text(
                                  'Dati Generali Genitore', 
                                  textAlign: TextAlign.center, 
                                  style:     GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Compila i dati anagrafici e di contatto del genitore.', 
                                  textAlign: TextAlign.center, 
                                  style:     GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              mainAxisAlignment:  MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                WizardCarouselArrowButton(
                                  icon:       Icons.chevron_left_rounded, 
                                  isDisabled: _currentFormCardIndex == 0, 
                                  onTap:      () => setState(() => _currentFormCardIndex--)
                                ),
                                const SizedBox(width: 32),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 800),
                                  child: AnimatedSwitcher(
                                    duration:       const Duration(milliseconds: 300),
                                    switchInCurve:  Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child:          KeyedSubtree(key: ValueKey(_currentFormCardIndex), child: currentCard),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                WizardCarouselArrowButton(
                                  icon:       Icons.chevron_right_rounded, 
                                  isDisabled: _currentFormCardIndex == 3, 
                                  onTap:      () => setState(() => _currentFormCardIndex++)
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          child: WizardAnimatedActionButton(
                            text:       'ANNULLA', 
                            icon:       Icons.close_rounded, 
                            baseColor:  const Color(0xFFE53935), 
                            hoverColor: const Color(0xFFEF5350), 
                            onPressed:  () => Navigator.of(context).pop()
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 200,
                          child: WizardAnimatedActionButton(
                            text:       _isSubmitting ? 'SALVATAGGIO...' : 'CREA GENITORE', 
                            icon:       Icons.check_circle_outline, 
                            baseColor:  const Color(0xFF003C82), 
                            hoverColor: const Color(0xFF004D99), 
                            onPressed:  _isSubmitting ? () {} : ()
                            {
                              if (_validateDatiGenerali())
                              {
                                _submitForm();
                              }
                            }
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