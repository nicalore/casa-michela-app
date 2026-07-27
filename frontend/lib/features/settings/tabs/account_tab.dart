import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/password_policy_checklist.dart';
import '../../../shared/widgets/settings_card.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';

// Both values are short, so the labels only need the room the longer of the two
// asks for.
const double _labelWidth = 170;

// Side by side at the foot of the dialog, so both stand at the height and the
// type size the role dialog gives its own.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// The date the app writes everywhere, and the clock this country reads.
final DateFormat _lastLoginFormat = DateFormat('dd/MM/yyyy, HH:mm');

// It is written at every successful login, so on a session that just started it
// says now. Absent only for an account that has never been through the login
// screen at all.
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
      padding: const EdgeInsets.only(top: 16, left: 32, right: 32, bottom: 32),
      child: Center(
        // Narrow: the card carries two values, and stretched to the width of the
        // profile's cards it would be mostly empty paper.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCard(
                title: 'Credenziali di accesso',
                compact: true,
                leading: const SettingsCardBadge(
                  icon: Icons.manage_accounts_rounded,
                  compact: true,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsInfoRow(
                      label: 'Nome utente',
                      value: me.username,
                      labelWidth: _labelWidth,
                    ),
                    const SizedBox(height: 16),
                    SettingsInfoRow(
                      label: 'Ultimo accesso',
                      value: _formatLastLogin(me.lastLogin),
                      labelWidth: _labelWidth,
                    ),
                  ],
                ),
              ),
              // Out of the card and in the middle of the page: it is the one
              // thing this section is for, and inside the card it read as a
              // footnote to the username above it.
              const SizedBox(height: 40),
              Center(
                child: AppGradientButton(
                  label: 'MODIFICA PASSWORD',
                  onPressed: () => _showChangePasswordDialog(context),
                ),
              ),
            ],
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

  // Rebuilds so the meter follows the new password and the two fields can say
  // whether they agree, both as they are typed.
  void _onTypedPasswordChanged()
  {
    setState(() {});
  }

  // Nothing to say until there is something to compare: an empty confirmation is
  // a field waiting to be filled in, not a mismatch.
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The same small tracked line the bar puts over a name and
                      // the role dialog over a role, so the two windows read as
                      // one family rather than as distant relatives.
                      Text(
                        'ACCOUNT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                          height: 1.2,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Modifica password',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: AppTheme.trialOcean,
                        ),
                      ),
                    ],
                  ),
                  // The same close the role dialog carries, so the two windows
                  // are dismissed by the same button rather than by two that
                  // merely look alike.
                  FadeHoverIconButton(
                    icon: Icons.close,
                    color: AppTheme.trialTealDeep,
                    hoverColor: AppTheme.trialGoldSurface,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: AppTheme.trialLine),
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
                  const SizedBox(height: 8),
                  // Answered while typing rather than after pressing save: the
                  // two fields disagreeing is the one mistake here you can be
                  // told about before you have finished making it. The row keeps
                  // its height whether or not it has anything to say, so the
                  // buttons under it never move.
                  _buildMatchHint(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 32),
              child: Row(
                children: [
                  // Violet to back out and the brand ramp to go through with it.
                  // Neither is red: nothing here is destroyed, and the app keeps
                  // red for the answers that destroy something.
                  Expanded(
                    child: AppGradientButton(
                      label: 'ANNULLA',
                      icon: Icons.close_rounded,
                      gradient: AppTheme.dismissGradient,
                      accent: AppTheme.trialViolet,
                      height: _dialogButtonHeight,
                      fontSize: _dialogButtonFontSize,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppGradientButton(
                      label: 'SALVA',
                      icon: Icons.check_rounded,
                      busy: _isSaving,
                      height: _dialogButtonHeight,
                      fontSize: _dialogButtonFontSize,
                      onPressed: _handleSave,
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
