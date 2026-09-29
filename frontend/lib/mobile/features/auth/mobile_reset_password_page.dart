import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/settings/utils/settings_strings.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/mobile_links.dart';
import '../../shared/widgets/mobile_flow_page.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_password_fields.dart';

const String _invalidLink = 'Il link non è più valido. Richiedine uno nuovo.';
const String _done = 'Password reimpostata con successo! Ora puoi accedere.';

// App-link target; a spent or expired link leaves as cancelling does.
class MobileResetPasswordPage extends StatefulWidget
{
  final String token;

  const MobileResetPasswordPage({super.key, required this.token});

  @override
  State<MobileResetPasswordPage> createState() => _MobileResetPasswordPageState();
}

class _MobileResetPasswordPageState extends State<MobileResetPasswordPage>
{
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _checking = true;
  bool _busy = false;

  @override
  void initState()
  {
    super.initState();
    _check();
  }

  @override
  void dispose()
  {
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _check() async
  {
    try
    {
      await _apiService.validateResetToken(token: widget.token);

      if (mounted)
      {
        setState(() => _checking = false);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        _leave(notice: isConnectionFailure(e) ? connectionFailureMessage : _invalidLink, error: true);
      }
    }
  }

  // The notice goes up first: it lives in the root overlay and outlasts the page.
  void _leave({String? notice, bool error = false})
  {
    if (notice != null)
    {
      MobileNotice.show(context, notice, error: error);
    }

    MobileResetLink.token.value = null;
  }

  // Refuses on tap with a reason, never through a disabled button.
  Future<void> _save() async
  {
    if (_busy)
    {
      return;
    }

    final String? problem = passwordChangeProblem(next: _next.text, confirmation: _confirmation.text);

    if (problem != null)
    {
      MobileNotice.show(context, problem, error: true);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);

    try
    {
      await _apiService.confirmPasswordReset(token: widget.token, newPassword: _next.text);

      // Only a password that took is offered to the password manager.
      TextInput.finishAutofillContext();

      // Closes any session on this phone, maybe another account's, as the desktop does.
      await _apiService.logout();

      if (mounted)
      {
        _leave(notice: _done);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _busy = false);
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _)
      {
        if (!didPop)
        {
          _leave();
        }
      },
      child: MobileFlowScaffold(
        tablet: tablet,
        footer: _checking
            ? null
            : MobileFlowFooter(
                label: kSavePasswordLabel,
                icon: Icons.check_rounded,
                busy: _busy,
                onPressed: _save,
              ),
        body: MobileFlowForm(
          tablet: tablet,
          children: [
            MobileFlowHead(
              eyebrow: 'Recupero',
              title: 'Nuova password',
              tablet: tablet,
              capsule: MobileFlowCapsule(onTap: _leave),
            ),
            const SizedBox(height: 22),
            MobileLoadSwitcher(
              child: _checking
                  ? const MobileWaiting()
                  : MobileGlassPanel(
                      child: AutofillGroup(
                        onDisposeAction: AutofillContextAction.cancel,
                        child: MobilePasswordFields(
                          next: _next,
                          confirmation: _confirmation,
                          onSubmitted: _save,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
