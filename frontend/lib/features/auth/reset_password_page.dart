import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_dialog_footer.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/password_field.dart';
import '../../shared/widgets/password_policy_checklist.dart';
import 'widgets/auth_pill_page.dart';
import '../../shared/widgets/snackbar.dart';

class ResetPasswordPage extends StatefulWidget
{
  final String token;

  const ResetPasswordPage({super.key, required this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
{
  static const double _buttonHeight = 52;
  static const double _buttonFontSize = 14;

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();

  PasswordPolicyStatus _policyStatus = const PasswordPolicyStatus.empty();

  bool _isSaving = false;
  bool _isValidating = true;

  @override
  void initState()
  {
    super.initState();
    _newPasswordController.addListener(_onPasswordChanged);
    _validateToken();
  }

  @override
  void dispose()
  {
    _newPasswordController.removeListener(_onPasswordChanged);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged()
  {
    setState(() => _policyStatus = PasswordPolicyStatus.of(_newPasswordController.text));
  }

  Future<void> _validateToken() async
  {
    try
    {
      await _apiService.validateResetToken(token: widget.token);

      if (mounted)
      {
        setState(() => _isValidating = false);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        context.go('/login');
        CustomSnackBar.show(
          context: context,
          message: 'Il link non è più valido. Richiedine uno nuovo.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleSave() async
  {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Compila tutti i campi', isError: true);
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
      await _apiService.confirmPasswordReset(token: widget.token, newPassword: newPassword);

      // Close any session already open in this browser (possibly another
      // account), or the router redirect would enter that session's dashboard.
      await _apiService.logout();

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Password reimpostata con successo! Ora puoi accedere.',
          isError: false,
        );

        context.go('/login');
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
    if (_isValidating)
    {
      return const Scaffold(
        backgroundColor: AppTheme.trialPaper,
        body: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    return AuthPillPage(
      eyebrow: 'Recupero',
      title: 'Nuova password',
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'TORNA AL LOGIN',
          icon: Icons.arrow_back_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: () => context.go('/login'),
        ),
        primary: AppGradientButton(
          label: 'SALVA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: _handleSave,
        ),
      ),
      children: [
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
                nothingAbove: true,
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
    );
  }
}
