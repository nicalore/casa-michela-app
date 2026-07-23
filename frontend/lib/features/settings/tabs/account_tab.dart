import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/password_policy_checklist.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';

// No AppTheme equivalent: these tints are specific to the account card.
const Color _avatarBackground = Color(0xFFE8EEF7);
const Color _cardDivider = Color(0xFFF1F5F9);
const Color _labelColor = Color(0xFF7A7A7A);
const Color _valueColor = Color(0xFF2A2A2A);
const Color _changePasswordHover = Color(0xFF002B5E);

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
          _errorMessage = readableApiError(e);
        });
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ChangePassword',
      builder: (context) => const _ChangePasswordDialogContent(),
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
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_errorMessage != null || _me == null)
    {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Text(
            'Errore durante il caricamento dell\'account. Riprova più tardi.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate400,
            ),
          ),
        ),
      );
    }

    final me = _me!;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, left: 32, right: 32, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: AppTheme.cardShadow,
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
                          color: _avatarBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.manage_accounts_rounded,
                          size: 44,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Text(
                          'Credenziali di accesso',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Divider(height: 1, thickness: 1, color: _cardDivider),
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
                          color: _labelColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        me.username,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _valueColor,
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
                      baseColor: AppTheme.primary,
                      hoverColor: _changePasswordHover,
                      onPressed: () => _showChangePasswordDialog(context),
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
  const _ChangePasswordDialogContent();

  @override
  State<_ChangePasswordDialogContent> createState() => _ChangePasswordDialogContentState();
}

class _ChangePasswordDialogContentState extends State<_ChangePasswordDialogContent>
{
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState()
  {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
  }

  @override
  void dispose()
  {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Rebuilds so the policy checklist reflects the new password as it is typed.
  void _onNewPasswordChanged()
  {
    setState(() {});
  }

  Future<void> _handleSave() async
  {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Compila tutti i campi', isError: true);
      return;
    }

    if (oldPassword == newPassword)
    {
      CustomSnackBar.show(
        context: context,
        message: 'La nuova password non può coincidere con quella attuale.',
        isError: true,
      );
      return;
    }

    if (newPassword != confirmPassword)
    {
      CustomSnackBar.show(context: context, message: 'Le password non coincidono', isError: true);
      return;
    }

    if (!PasswordPolicyStatus.of(newPassword).isSatisfied)
    {
      CustomSnackBar.show(
        context: context,
        message: 'La password non rispetta i criteri di sicurezza',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try
    {
      // changePassword reuses the current session refresh token internally. The
      // session stays valid afterwards (the backend revokes every refresh token
      // except the one just used), so no re-login is needed.
      await ApiService().changePassword(
        currentPassword: oldPassword,
        newPassword: newPassword,
      );

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: 'Password cambiata con successo!', isError: false);
        Navigator.of(context).pop();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSaving = false);
      }
    }
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
          boxShadow: AppTheme.dialogShadow,
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
                      color: AppTheme.primary,
                    ),
                  ),
                  StaticHoverIconButton(
                    icon: Icons.close,
                    color: AppTheme.primary,
                    hoverColor: AppTheme.iconHover,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PasswordField(
                    controller: _oldPasswordController,
                    label: 'Password attuale',
                    hintText: 'Inserisci password attuale',
                  ),
                  PasswordField(
                    controller: _newPasswordController,
                    label: 'Nuova password',
                    hintText: 'Inserisci nuova password',
                  ),
                  const SizedBox(height: 16),
                  PasswordPolicyChecklist(
                    status: PasswordPolicyStatus.of(_newPasswordController.text),
                  ),
                  PasswordField(
                    controller: _confirmPasswordController,
                    label: 'Conferma password',
                    hintText: 'Ripeti nuova password',
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
                      baseColor: AppTheme.danger,
                      hoverColor: AppTheme.dangerHover,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isSaving ? 'SALVATAGGIO...' : 'SALVA',
                      icon: Icons.check_circle_outline,
                      baseColor: AppTheme.primary,
                      hoverColor: AppTheme.primaryHover,
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
