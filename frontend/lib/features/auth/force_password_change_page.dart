import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/shared_components.dart';
import '../../shared/widgets/snackbar.dart';

class ForcePasswordChangePage extends StatefulWidget
{
  final String username;
  final String refreshToken;
  final String currentPassword;

  const ForcePasswordChangePage({
    super.key,
    required this.username,
    required this.refreshToken,
    required this.currentPassword,
  });

  @override
  State<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage>
{
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _hasMinLength = false;
  bool _hasLower = false;
  bool _hasUpper = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;

  bool _isSaving = false;

  @override
  void initState()
  {
    super.initState();
    _newPasswordController.addListener(_validatePolicies);
  }

  @override
  void dispose()
  {
    _newPasswordController.removeListener(_validatePolicies);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  //ValidateSecurityPolicies
  void _validatePolicies()
  {
    final text = _newPasswordController.text;
    
    setState(()
    {
      _hasMinLength = text.length >= 12;
      _hasLower = RegExp(r'[a-z]').hasMatch(text);
      _hasUpper = RegExp(r'[A-Z]').hasMatch(text);
      _hasDigit = RegExp(r'\d').hasMatch(text);
      _hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(text);
    });
  }

//HandlePasswordChange
  Future<void> _handleSave() async
  {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Compila tutti i campi',
        isError: true,
      );
      
      return;
    }

    if (newPassword != confirmPassword)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Le password non coincidono',
        isError: true,
      );
      
      return;
    }

    if (!_hasMinLength || !_hasLower || !_hasUpper || !_hasDigit || !_hasSpecial)
    {
      CustomSnackBar.show(
        context: context,
        message: 'La password non rispetta i criteri di sicurezza',
        isError: true,
      );
      
      return;
    }

    setState(()
    {
      _isSaving = true;
    });

    try
    {
      // 1. Esegue il cambio password
      await _apiService.changePassword(
        currentPassword: widget.currentPassword,
        newPassword: newPassword,
        refreshToken: widget.refreshToken,
      );
      
      await _apiService.login(
         username: widget.username,
        password: newPassword,
      );
      
      ApiService.forcePasswordChangeCompleted = true;

      if (!mounted) return;
      
      CustomSnackBar.show(
        context: context,
        message: 'Password aggiornata con successo!',
        isError: false,
      );

      context.replace('/dashboard');
    }
    catch (e)
    {
      if (!mounted) return;
      
      CustomSnackBar.show(
        context: context,
        message: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
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

  //BuildFieldLabel
  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 16),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF003C82),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  //BuildPolicyRow
  Widget _buildPolicyRow(String text, bool isValid)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isValid ? const Color(0xFF4CAF50) : const Color(0xFFB3B3B3),
            size: 18,
          ),
          
          const SizedBox(width: 8),
          
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isValid ? const Color(0xFF4CAF50) : const Color(0xFF8A8A8A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final viewportWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result)
      {
        if (!didPop)
        {
          CustomSnackBar.show(
            context: context,
            message: 'Devi cambiare la password per procedere.',
            isError: true,
          );
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF4F7F9),
          child: Stack(
            children: [
              Positioned(
                right: -800,
                top: -800,
                child: IgnorePointer(
                  child: Container(
                    width: 1600,
                    height: 1600,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
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
              Positioned(
                left: -800,
                bottom: -800,
                child: IgnorePointer(
                  child: Container(
                    width: 1600,
                    height: 1600,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
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
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.04,
                        child: Image.asset(
                          'assets/images/house_watermark.png',
                          width: 800,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            offset: Offset(0, 8),
                            blurRadius: 24,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 32, right: 32, left: 32, bottom: 16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.lock_reset_rounded,
                                  size: 56,
                                  color: Color(0xFF003C82),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                Text(
                                  'Aggiorna Password',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF003C82),
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                Text(
                                  'Al primo accesso o dopo un reset amministrativo è obbligatorio impostare una nuova password personale.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    color: const Color(0xFF6B7280),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF0F0F0),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Nuova password'),
                                TextField(
                                  controller: _newPasswordController,
                                  obscureText: _obscureNew,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Inserisci nuova password',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      color: const Color(0xFFB3B3B3),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFF003C82), width: 2),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: const Color(0xFF6B7280),
                                      ),
                                      onPressed: ()
                                      {
                                        setState(()
                                        {
                                          _obscureNew = !_obscureNew;
                                        });
                                      },
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildPolicyRow('Almeno 12 caratteri', _hasMinLength),
                                      _buildPolicyRow('Almeno una lettera minuscola', _hasLower),
                                      _buildPolicyRow('Almeno una lettera maiuscola', _hasUpper),
                                      _buildPolicyRow('Almeno un numero', _hasDigit),
                                      _buildPolicyRow('Almeno un carattere speciale', _hasSpecial),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                _buildFieldLabel('Conferma password'),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ripeti nuova password',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      color: const Color(0xFFB3B3B3),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFF003C82), width: 2),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: const Color(0xFF6B7280),
                                      ),
                                      onPressed: ()
                                      {
                                        setState(()
                                        {
                                          _obscureConfirm = !_obscureConfirm;
                                        });
                                      },
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                                
                                SizedBox(
                                  width: double.infinity,
                                  child: AnimatedActionButton(
                                    text: _isSaving ? 'SALVATAGGIO...' : 'SALVA E ACCEDI',
                                    icon: Icons.login_rounded,
                                    baseColor: const Color(0xFF003C82),
                                    hoverColor: const Color(0xFF004D99),
                                    onPressed: _isSaving ? () {} : _handleSave,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}