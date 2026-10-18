import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/password_policy_checklist.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';
import '../../notifications/device_notifications.dart';
import '../../notifications/notification_item.dart';
import '../../notifications/notification_kinds.dart';
import '../../notifications/notification_look.dart';
import '../../notifications/notification_strings.dart';
import '../utils/settings_strings.dart';
import '../widgets/settings_panel.dart';

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

    // The new sign-ins switch is one of the kinds: read again, another device may have changed it.
    DeviceNotifications.refresh();
    NotificationKinds.instance.load();
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

  Future<void> _chooseNewDevice(List<NotificationKindChoice> choices, bool on) async
  {
    try
    {
      await DeviceNotifications.chooseKinds([
        for (final choice in choices) choice.kind == NotificationKind.newDevice ? choice.turned(on) : choice,
      ]);
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  Widget _value(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialInk,
      ),
    );
  }

  // Only while this device shows notifications, as the other kinds.
  Widget? _buildNewDevice()
  {
    final List<NotificationKindChoice>? choices = NotificationKinds.instance.choices;
    final NotificationKindChoice? choice =
        choices?.where((choice) => choice.kind == NotificationKind.newDevice).firstOrNull;

    if (choices == null || choice == null)
    {
      return null;
    }

    final (String title, String line) = kNotificationKindLabels[NotificationKind.newDevice]!;
    final bool deviceOn = DeviceNotifications.state.value == NotificationSwitch.on;

    final NotificationLook look = NotificationLook.of(NotificationKind.newDevice);

    return SettingsRow(
      icon: look.icon,
      tint: look.color,
      title: title,
      subtitle: deviceOn ? line : kNotificationKindsTurnOnFirst,
      trailing: deviceOn
          ? AppSegmentedSwitch(
              value: choice.enabled,
              hugContent: true,
              onChanged: (on) => _chooseNewDevice(choices, on),
            )
          : null,
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

    return ListenableBuilder(
      listenable: Listenable.merge([DeviceNotifications.state, NotificationKinds.instance]),
      builder: (context, _) => SettingsColumn(
        children: [
          SettingsPanel(
            heading: kAccountGroup,
            rows: [
              SettingsRow(icon: Icons.person_rounded, title: kUsernameLabel, trailing: _value(me.username)),
              SettingsRow(
                icon: Icons.history_rounded,
                title: kLastLoginLabel,
                trailing: _value(formatLastLogin(me.lastLogin)),
              ),
            ],
          ),
          SettingsPanel(
            heading: kSecurityHeading,
            rows: [
              SettingsRow(
                icon: Icons.key_rounded,
                title: kPasswordLabel,
                trailing: AppGradientButton(
                  label: kChangePasswordLabel.toUpperCase(),
                  height: kSettingsButtonHeight,
                  radius: kSettingsButtonHeight / 2,
                  fontSize: kSettingsButtonFontSize,
                  onPressed: () => _showChangePasswordDialog(context),
                ),
              ),
              ?_buildNewDevice(),
            ],
          ),
        ],
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
