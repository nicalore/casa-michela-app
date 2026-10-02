import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../settings/utils/settings_strings.dart';
import '../models/person_account_item.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';

const double _confirmWidth = 480;

// One account read shared by the Accesso and Dispositivi tabs: what one changes, the other shows.
class PersonAccountController extends ChangeNotifier
{
  final String fiscalCode;

  // Null until the first answer.
  PersonAccountItem? account;
  bool failed = false;

  Future<void>? _loading;
  bool _disposed = false;

  PersonAccountController(this.fiscalCode);

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async
  {
    try
    {
      account = await ApiService().getPersonAccount(fiscalCode);
    }
    catch (_)
    {
      failed = true;
    }

    _notify();
  }

  // After an action; a failure is the caller's to report, and what is on screen stays.
  Future<void> reload() async
  {
    account = await ApiService().getPersonAccount(fiscalCode);
    failed = false;

    _notify();
  }

  void _notify()
  {
    if (!_disposed)
    {
      notifyListeners();
    }
  }

  @override
  void dispose()
  {
    _disposed = true;
    super.dispose();
  }
}

enum PersonAccountAction
{
  forceChange,
  recoveryEmail,
  unlock,
  revokeAll,
  autonomousBookings,
  suspension,
}

// Loading and error states, or null once the account is there.
Widget? accountPlaceholder(PersonAccountController controller)
{
  if (controller.failed)
  {
    return PersonEmptyState(message: kAccountLoadFailed);
  }

  if (controller.account == null)
  {
    return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
  }

  return null;
}

mixin PersonAccountActions<T extends StatefulWidget> on State<T>
{
  PersonAccountAction? busyAction;

  PersonItem get accountPerson;

  PersonAccountController get accountController;

  String get personFullName => '${accountPerson.firstName} ${accountPerson.lastName}';

  void showOutcome(String message, {required bool isError})
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: isError);
    }
  }

  // One action at a time; the account is read again before the outcome is told.
  Future<void> runAccountAction(
    PersonAccountAction action,
    Future<void> Function() call,
    String done,
  ) async
  {
    if (busyAction != null)
    {
      return;
    }

    setState(() => busyAction = action);

    try
    {
      await call();
      await accountController.reload();

      showOutcome(done, isError: false);
    }
    catch (e)
    {
      showOutcome(readableApiError(e), isError: true);
    }
    finally
    {
      if (mounted)
      {
        setState(() => busyAction = null);
      }
    }
  }

  TextSpan boldSpan(String text)
  {
    return TextSpan(
      text: text,
      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
    );
  }

  Future<bool> askAccountConfirmation({
    required String eyebrow,
    required List<InlineSpan> message,
    required String confirmLabel,
    required IconData confirmIcon,
    required bool danger,
  }) async
  {
    final confirmed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ConfirmAccountAction',
      builder: (dialogContext) => AppDialogStack(
        eyebrow: eyebrow,
        title: 'Confermi?',
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          primary: AppGradientButton(
            label: confirmLabel,
            icon: confirmIcon,
            gradient: danger ? AppTheme.dangerGradient : AppTheme.brandGradient,
            accent: danger ? AppTheme.trialDanger : AppTheme.trialTealDeep,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(children: message),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );

    return confirmed == true;
  }
}
