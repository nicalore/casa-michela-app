import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
import '../utils/settings_strings.dart';

const double _labelWidth = 170;

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

class AccessTab extends StatefulWidget
{
  const AccessTab({super.key});

  @override
  State<AccessTab> createState() => _AccessTabState();
}

class _AccessTabState extends State<AccessTab>
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
    // Part of the section handover, else these paint over the section still leaving.
    if (_isLoading)
    {
      return const PageTransitionItem(
        slot: PageTransitionItem.header,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: 40.0),
            child: CircularProgressIndicator(color: AppTheme.trialTealDeep),
          ),
        ),
      );
    }

    if (_errorMessage != null || _me == null)
    {
      return PageTransitionItem(
        slot: PageTransitionItem.header,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child: Text(
              kAccountLoadFailed,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
        ),
      );
    }

    final me = _me!;

    return PageTransitionScrollView(
      child: Padding(
        // Side padding adds to the page margin, so it is dropped when compact.
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
                  title: kAccessSection,
                  compact: true,
                  selectable: false,
                  leading: const AppCardBadge(
                    icon: Icons.manage_accounts_rounded,
                    compact: true,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppInfoRow(
                        label: kUsernameLabel,
                        value: me.username,
                        labelWidth: _labelWidth,
                      ),
                      const SizedBox(height: 16),
                      AppInfoRow(
                        label: kLastLoginLabel,
                        value: formatLastLogin(me.lastLogin),
                        labelWidth: _labelWidth,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: AppGradientButton(
                    label: kChangePasswordLabel.toUpperCase(),
                    onPressed: () => _showChangePasswordDialog(context),
                  ),
                ),
              ]),
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
            matches ? kPasswordsMatch : kPasswordsDiffer,
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

    final String? problem = passwordChangeProblem(
      current: oldPassword,
      next: newPassword,
      confirmation: confirmPassword,
    );

    if (problem != null)
    {
      CustomSnackBar.show(context: context, message: problem, isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try
    {
      // Keeps this refresh token and revokes every other one, so no re-login is needed.
      await ApiService().changePassword(
        currentPassword: oldPassword,
        newPassword: newPassword,
      );

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: kPasswordChanged, isError: false);
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
      eyebrow: kPasswordEyebrow,
      title: kPasswordTitle,
      maxWidth: 560,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kSavePasswordLabel.toUpperCase(),
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
            label: kCurrentPasswordLabel,
            hintText: kCurrentPasswordHint,
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
                label: kNewPasswordLabel,
                hintText: kNewPasswordHint,
              ),
              const SizedBox(height: 16),
              PasswordPolicyChecklist(
                status: PasswordPolicyStatus.of(_newPasswordController.text),
              ),
              PasswordField(
                controller: _confirmPasswordController,
                label: kConfirmPasswordLabel,
                hintText: kConfirmPasswordHint,
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
