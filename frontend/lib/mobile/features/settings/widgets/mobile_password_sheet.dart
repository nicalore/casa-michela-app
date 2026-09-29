import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_password_fields.dart';
import '../../../shared/widgets/mobile_sheet.dart';

Future<void> showMobilePasswordSheet(BuildContext context)
{
  return showMobileSheet<void>(context: context, builder: (_) => const _PasswordSheet());
}

class _PasswordSheet extends StatefulWidget
{
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet>
{
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  bool _busy = false;

  @override
  void dispose()
  {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  // Refuses on tap with a reason, never through a disabled button.
  Future<void> _save() async
  {
    if (_busy)
    {
      return;
    }

    final String? problem = passwordChangeProblem(
      current: _current.text,
      next: _next.text,
      confirmation: _confirmation.text,
    );

    if (problem != null)
    {
      MobileNotice.show(context, problem, error: true);
      return;
    }

    setState(() => _busy = true);

    try
    {
      // The session in use stays; every other one is ended by the server.
      await ApiService().changePassword(currentPassword: _current.text, newPassword: _next.text);

      if (mounted)
      {
        // Only a password that took is offered to the password manager.
        TextInput.finishAutofillContext();
        MobileNotice.show(context, kPasswordChanged);
        Navigator.of(context).pop();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: MobileSheet(
          eyebrow: kPasswordEyebrow,
          title: kPasswordTitle,
          aboveKeyboard: true,
          body: [
            const SizedBox(height: 18),
            MobilePasswordFields(
              current: _current,
              next: _next,
              confirmation: _confirmation,
              onSubmitted: _save,
            ),
          ],
          footer: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: MobileGoldButton(
              label: kSavePasswordLabel,
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: _save,
            ),
          ),
        ),
      ),
    );
  }
}

