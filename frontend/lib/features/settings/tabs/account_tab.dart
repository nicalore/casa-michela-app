import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/password_policy_checklist.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';

const double _labelWidth = 170;

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

final DateFormat _lastLoginFormat = DateFormat('dd/MM/yyyy, HH:mm');

// Null only for an account that has never logged in.
String _formatLastLogin(DateTime? lastLogin)
{
  if (lastLogin == null)
  {
    return '-';
  }

  return _lastLoginFormat.format(lastLogin);
}

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
          child: CircularProgressIndicator(color: AppTheme.trialTealDeep),
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
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
      );
    }

    final me = _me!;

    return SingleChildScrollView(
      // Side padding adds to the page margin, so it is dropped on narrow
      // windows.
      padding: EdgeInsets.only(
        top: 16,
        left: AppBreakpoints.of(context).isCompact ? 0 : 32,
        right: AppBreakpoints.of(context).isCompact ? 0 : 32,
        bottom: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pageTransitionBlocks([
              AppCard(
                title: 'Credenziali di accesso',
                compact: true,
                leading: const AppCardBadge(
                  icon: Icons.manage_accounts_rounded,
                  compact: true,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppInfoRow(
                      label: 'Nome utente',
                      value: me.username,
                      labelWidth: _labelWidth,
                    ),
                    const SizedBox(height: 16),
                    AppInfoRow(
                      label: 'Ultimo accesso',
                      value: _formatLastLogin(me.lastLogin),
                      labelWidth: _labelWidth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: AppGradientButton(
                  label: 'MODIFICA PASSWORD',
                  onPressed: () => _showChangePasswordDialog(context),
                ),
              ),
            ]),
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
    _newPasswordController.addListener(_onTypedPasswordChanged);
    _confirmPasswordController.addListener(_onTypedPasswordChanged);
  }

  @override
  void dispose()
  {
    _newPasswordController.removeListener(_onTypedPasswordChanged);
    _confirmPasswordController.removeListener(_onTypedPasswordChanged);
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onTypedPasswordChanged()
  {
    setState(() {});
  }

  Widget _buildMatchHint()
  {
    final String newPassword = _newPasswordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty)
    {
      return const SizedBox(height: 22);
    }

    final bool matches = newPassword == confirmPassword;

    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Icon(
            matches ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 16,
            color: matches ? AppTheme.trialTurquoise : AppTheme.trialDanger,
          ),
          const SizedBox(width: 8),
          Text(
            matches ? 'Le password coincidono' : 'Le password non coincidono',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: matches ? AppTheme.trialTealDeep : AppTheme.trialDanger,
            ),
          ),
        ],
      ),
    );
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
      // changePassword reuses the current session refresh token; the backend
      // revokes every other one, so the session stays valid and no re-login is
      // needed.
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
    return AppDialogStack(
      eyebrow: 'Account',
      title: 'Modifica password',
      maxWidth: 560,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _handleSave,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: PasswordField(
            controller: _oldPasswordController,
            label: 'Password attuale',
            hintText: 'Inserisci password attuale',
            nothingAbove: true,
          ),
        ),
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 8),
              // Keeps its height even when empty, so the buttons do not move.
              _buildMatchHint(),
            ],
          ),
        ),
      ],
    );
  }
}
