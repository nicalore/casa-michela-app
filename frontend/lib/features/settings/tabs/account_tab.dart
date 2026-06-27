import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_service.dart';
import '../../../services/session_service.dart';
import '../../auth/models/me_response.dart';
import '../../../shared/widgets/casa_michela_loader.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';

class AccountTab extends StatefulWidget
{
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab>
{
  final ApiService _apiService = ApiService();
  
  MeResponse? _me;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState()
  {
    super.initState();
    _fetchAccount();
  }

  Future<void> _fetchAccount() async
  {
    try
    {
      final meResponse = await _apiService.me();
      
      if (mounted)
      {
        setState(()
        {
          _me = meResponse;
          _isLoading = false;
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(()
        {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context, String username)
  {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ChangePassword',
      barrierColor: Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
              child: _ChangePasswordDialogContent(username: username),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (_isLoading)
    {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40.0),
          child: CasaMichelaLoader(),
        ),
      );
    }

    if (_errorMessage != null || _me == null)
    {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Text(
            'Errore nel caricamento dell\'account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFC62828),
            ),
          ),
        ),
      );
    }

    final me = _me!;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: 16,
        left: 32,
        right: 32,
        bottom: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset(0, 4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8EEF7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.manage_accounts_rounded,
                          size: 44,
                          color: Color(0xFF003C82),
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      Expanded(
                        child: Text(
                          'Credenziali di accesso',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF003C82),
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        'Nome utente',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF7A7A7A),
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: Text(
                        me.username,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2A2A2A),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 260,
                    child: AnimatedActionButton(
                      text: 'MODIFICA PASSWORD',
                      icon: Icons.lock_reset_rounded,
                      baseColor: const Color(0xFF003C82),
                      hoverColor: const Color(0xFF002B5E),
                      onPressed: () => _showChangePasswordDialog(context, me.username),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialogContent extends StatefulWidget
{
  final String username;

  const _ChangePasswordDialogContent({
    required this.username,
  });

  @override
  State<_ChangePasswordDialogContent> createState() => _ChangePasswordDialogContentState();
}

class _ChangePasswordDialogContentState extends State<_ChangePasswordDialogContent>
{
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
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
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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

  Future<void> _handleSave() async
  {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Compila tutti i campi',
        isError: true,
      );
      return;
    }

    if (oldPassword == newPassword)
    {
      CustomSnackBar.show(
        context: context,
        message: 'La nuova password non può essere uguale alla vecchia',
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
      final refreshToken = await SessionService.getRefreshToken();
      
      if (refreshToken == null)
      {
        throw Exception('Sessione non valida');
      }

      await ApiService().changePassword(
        currentPassword: oldPassword,
        newPassword: newPassword,
        refreshToken: refreshToken,
      );

      //Silent login to fetch new valid tokens preventing the 401 error
      await ApiService().login(
        username: widget.username,
        password: newPassword,
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Password cambiata con successo',
          isError: false,
        );
        Navigator.of(context).pop();
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
        setState(()
        {
          _isSaving = false;
        });
      }
    }
  }

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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
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
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Modifica Password',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF003C82),
                    ),
                  ),
                  StaticHoverIconButton(
                    icon: Icons.close,
                    color: const Color(0xFF003C82),
                    hoverColor: const Color(0xFFE3F2FD),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Password attuale'),
                  TextField(
                    controller: _oldPasswordController,
                    obscureText: _obscureOld,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Inserisci password attuale',
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
                          _obscureOld ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: const Color(0xFF6B7280),
                        ),
                        onPressed: () => setState(() => _obscureOld = !_obscureOld),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                    ),
                  ),
                  
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
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
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
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 32),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedActionButton(
                      text: 'ANNULLA',
                      icon: Icons.cancel_outlined,
                      baseColor: const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isSaving ? 'SALVATAGGIO...' : 'SALVA',
                      icon: Icons.save_outlined,
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
    );
  }
}