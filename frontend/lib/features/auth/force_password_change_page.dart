import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/password_field.dart';
import '../../shared/widgets/password_policy_checklist.dart';
import '../../shared/widgets/app_dialog_footer.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/app_gradient_button.dart';
import 'widgets/auth_pill_page.dart';
import '../../shared/widgets/snackbar.dart';

class ForcePasswordChangePage extends StatefulWidget
{
  const ForcePasswordChangePage({super.key});

  @override
  State<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage>
{
  static const double _buttonHeight = 52;
  static const double _buttonFontSize = 14;

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();

  PasswordPolicyStatus _policyStatus = const PasswordPolicyStatus.empty();

  bool _isSaving = false;
  bool _isCancelling = false;

  bool get _isBusy => _isSaving || _isCancelling;

  @override
  void initState()
  {
    super.initState();
    _newPasswordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose()
  {
    _newPasswordController.removeListener(_onPasswordChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged()
  {
    setState(() => _policyStatus = PasswordPolicyStatus.of(_newPasswordController.text));
  }

  Future<void> _handleCancel() async
  {
    setState(() => _isCancelling = true);

    await _apiService.logout();

    if (!mounted)
    {
      return;
    }

    context.go('/login');
  }

  Future<void> _handleSave() async
  {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Compila tutti i campi', isError: true);
      return;
    }

    if (currentPassword == newPassword)
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

    if (!_policyStatus.isSatisfied)
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
      // changePassword updates authState; the router redirect then takes the
      // user to the dashboard without a second login.
      await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(
        context: context,
        message: 'Password aggiornata con successo!',
        isError: false,
      );

      context.replace('/dashboard');
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
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
    // The change is mandatory, so the back gesture is intercepted.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result)
      {
        if (!didPop)
        {
          CustomSnackBar.show(
            context: context,
            message: 'Devi cambiare la password per procedere, oppure torna alla schermata di login.',
            isError: true,
          );
        }
      },
      child: AuthPillPage(
        eyebrow: 'Accesso',
        title: 'Aggiorna password',
        maxWidth: 560,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'TORNA AL LOGIN',
            icon: Icons.logout_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            busy: _isCancelling,
            height: _buttonHeight,
            fontSize: _buttonFontSize,
            onPressed: _isBusy ? () {} : _handleCancel,
          ),
          primary: AppGradientButton(
            label: 'SALVA E ACCEDI',
            icon: Icons.login_rounded,
            busy: _isSaving,
            height: _buttonHeight,
            fontSize: _buttonFontSize,
            onPressed: _isBusy ? () {} : _handleSave,
          ),
        ),
        children: [
          AppDialogPill(
            expand: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_reset_rounded, size: 28, color: AppTheme.trialTealDeep),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Al primo accesso, o in particolari situazioni, è obbligatorio '
                    'impostare una nuova password.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: AppTheme.trialMutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppDialogPill(
            expand: true,
            child: PasswordField(
              controller: _currentPasswordController,
              label: 'Password attuale',
              hintText: 'Inserisci la password attuale',
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
                PasswordPolicyChecklist(status: _policyStatus),
                PasswordField(
                  controller: _confirmPasswordController,
                  label: 'Conferma password',
                  hintText: 'Ripeti nuova password',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
