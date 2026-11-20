import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_text_field.dart';

Future<void> showMobilePasswordRecoverySheet(BuildContext context)
{
  return showMobileSheet<void>(context: context, builder: (_) => const _RecoverySheet());
}

class _RecoverySheet extends StatefulWidget
{
  const _RecoverySheet();

  @override
  State<_RecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends State<_RecoverySheet>
{
  final TextEditingController _usernameController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isSending = false;

  @override
  void dispose()
  {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async
  {
    final username = _usernameController.text.trim();

    if (username.isEmpty)
    {
      MobileNotice.show(context, tr('Inserisci il tuo nome utente', 'Enter your username'), error: true);
      return;
    }

    setState(() => _isSending = true);

    try
    {
      await _apiService.requestPasswordReset(username: username);

      if (mounted)
      {
        // Non-committal on purpose: confirming the username exists would leak accounts.
        MobileNotice.show(
          context,
          tr('Se il nome utente è corretto, riceverai un link via email.', 'If the username is correct, you will receive a link by email.'),
        );

        finishMobileSheet(context);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        final message = isConnectionFailure(e)
            ? connectionFailureMessage
            : tr("Errore durante l'invio. Riprova più tardi.", "Couldn't send it. Please try again later.");

        MobileNotice.show(context, message, error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: tr('Accesso', 'Sign-in'),
        title: tr('Recupero password', 'Password recovery'),
        aboveKeyboard: true,
        unsaved: () => _usernameController.text.trim().isEmpty ? MobileUnsaved.none : MobileUnsaved.text,
        saving: _isSending,
        body: [
          const SizedBox(height: 12),
          MobileSheetText(
            tr(
              'Inserisci il nome utente associato al tuo account. Se esiste, ti '
                  "invieremo un link di recupero all'indirizzo email registrato.",
              'Enter the username of your account. If it exists, we will send a recovery link to the email address '
                  'on record.',
            ),
          ),
          const SizedBox(height: 10),
          MobileSheetText(tr("Se non ricordi il tuo nome utente, contatta l'Associazione.", "If you don't remember your username, contact the Association.")),
          const SizedBox(height: 24),
          MobileTextField(
            controller: _usernameController,
            label: tr('Nome utente', 'Username'),
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.username],
            onSubmitted: (_) => _handleSend(),
          ),
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileGoldButton(
            label: tr('Invia link', 'Send link'),
            icon: Icons.send_rounded,
            busy: _isSending,
            onPressed: _handleSend,
          ),
        ),
      ),
    );
  }
}
