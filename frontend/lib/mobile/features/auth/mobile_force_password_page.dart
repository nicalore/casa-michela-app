import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/settings/utils/settings_strings.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_flow_page.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_password_fields.dart';

const String _title = 'Aggiorna password';

const String _why =
    'Al primo accesso, o in particolari situazioni, è obbligatorio impostare una nuova password.';

const String _mustChange =
    'Devi cambiare la password per procedere, oppure torna alla schermata di login.';

const String _changed = 'Password aggiornata con successo!';

// The recent sign-in stands for the current password, which is not asked.
class MobileForcePasswordPage extends StatefulWidget
{
  const MobileForcePasswordPage({super.key});

  @override
  State<MobileForcePasswordPage> createState() => _MobileForcePasswordPageState();
}

class _MobileForcePasswordPageState extends State<MobileForcePasswordPage>
{
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _busy = false;
  bool _leaving = false;

  @override
  void dispose()
  {
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _leave() async
  {
    setState(() => _leaving = true);

    // The page is swapped for the sign-in as the session ends.
    await _apiService.logout();
  }

  // Refuses on tap with a reason, never through a disabled button.
  Future<void> _save() async
  {
    if (_busy || _leaving)
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
      // On success the session moves on by itself: first access or home.
      await _apiService.changePassword(newPassword: _next.text);

      TextInput.finishAutofillContext();

      if (mounted)
      {
        MobileNotice.show(context, _changed);
      }
    }
    catch (e)
    {
      // Too long after sign-in the session is gone and the sign-in page says why.
      if (mounted && _apiService.isAuthenticated)
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
          MobileNotice.show(context, _mustChange, error: true);
        }
      },
      child: MobileFlowScaffold(
        tablet: tablet,
        footer: MobileFlowFooter(
          label: 'Salva e accedi',
          icon: Icons.login_rounded,
          busy: _busy,
          onPressed: _save,
        ),
        body: MobileFlowForm(
          tablet: tablet,
          children: [
            MobileFlowHead(
              eyebrow: 'Nuovo accesso',
              title: _title,
              tablet: tablet,
              capsule: MobileFlowCapsule(onTap: _leave, busy: _leaving),
            ),
            const SizedBox(height: 12),
            const _Why(),
            const SizedBox(height: 22),
            MobileGlassPanel(
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: MobilePasswordFields(
                  next: _next,
                  confirmation: _confirmation,
                  onSubmitted: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Why extends StatelessWidget
{
  const _Why();

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.lock_reset_rounded, size: 22, color: AppTheme.trialGold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _why,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
        ),
      ],
    );
  }
}
