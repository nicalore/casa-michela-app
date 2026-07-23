import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/password_field.dart';
import '../../shared/widgets/password_policy_checklist.dart';
import '../../shared/widgets/shared_components.dart';
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

      // The reset link is an out of band action, unrelated to this browser. Any
      // session already open here (possibly another account, on a shared
      // device) has to be closed explicitly, otherwise the router redirect
      // would still see AuthState.authenticated and send the user straight into
      // that session's dashboard instead of the login screen.
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

  Widget _buildCard()
  {
    return Container(
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
            padding: const EdgeInsets.only(top: 24, right: 16, left: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nuova Password',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
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
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 32),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedActionButton(
                    text: 'TORNA AL LOGIN',
                    icon: Icons.logout_rounded,
                    baseColor: AppTheme.danger,
                    hoverColor: AppTheme.dangerHover,
                    onPressed: () => context.go('/login'),
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
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: Stack(
        children: [
          const CornerGlow(corner: GlowCorner.topRight),
          const CornerGlow(corner: GlowCorner.bottomLeft),
          Center(
            child: _isValidating
                ? const CircularProgressIndicator(color: AppTheme.primary)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildCard(),
                  ),
          ),
        ],
      ),
    );
  }
}