import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/password_field.dart';
import '../../shared/widgets/password_policy_checklist.dart';
import '../../shared/widgets/shared_components.dart';
import '../../shared/widgets/snackbar.dart';

class ForcePasswordChangePage extends StatefulWidget
{
  const ForcePasswordChangePage({super.key});

  @override
  State<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage>
{
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
      // changePassword also updates apiService.authState internally: as soon as
      // it turns to authenticated, the global router redirect takes the user to
      // the dashboard without a second login.
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

  Widget _buildHeader()
  {
    return Padding(
      padding: const EdgeInsets.only(top: 32, right: 32, left: 32, bottom: 16),
      child: Column(
        children: [
          const Icon(Icons.lock_reset_rounded, size: 56, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            'Aggiorna Password',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Al primo accesso o in particolari situazioni è obbligatorio impostare una nuova password.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: AppTheme.secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm()
  {
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PasswordField(
            controller: _currentPasswordController,
            label: 'Password attuale',
            hintText: 'Inserisci la password attuale',
          ),
          PasswordField(
            controller: _newPasswordController,
            label: 'Nuova password',
            hintText: 'Inserisci nuova password',
          ),
          const SizedBox(height: 24),
          PasswordPolicyChecklist(status: _policyStatus),
          const SizedBox(height: 8),
          PasswordField(
            controller: _confirmPasswordController,
            label: 'Conferma password',
            hintText: 'Ripeti nuova password',
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: AnimatedActionButton(
                  text: _isCancelling ? 'USCITA...' : 'TORNA AL LOGIN',
                  icon: Icons.logout_rounded,
                  baseColor: AppTheme.danger,
                  hoverColor: AppTheme.dangerHover,
                  onPressed: _isBusy ? () {} : _handleCancel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedActionButton(
                  text: _isSaving ? 'SALVATAGGIO...' : 'SALVA E ACCEDI',
                  icon: Icons.login_rounded,
                  baseColor: AppTheme.primary,
                  hoverColor: AppTheme.primaryHover,
                  onPressed: _isBusy ? () {} : _handleSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // The password change is mandatory, so the back gesture is intercepted and
    // answered with an explanation instead of leaving the page.
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
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppTheme.pageBackground,
          child: Stack(
            children: [
              const CornerGlow(corner: GlowCorner.topRight),
              const CornerGlow(corner: GlowCorner.bottomLeft),
              const PageWatermark(),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: AppTheme.dialogShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(),
                          const Divider(height: 1, thickness: 1, color: AppTheme.divider),
                          _buildForm(),
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