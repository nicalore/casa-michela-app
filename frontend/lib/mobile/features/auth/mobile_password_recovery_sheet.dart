import 'package:flutter/material.dart';

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
      MobileNotice.show(context, 'Inserisci il tuo nome utente', error: true);
      return;
    }

    setState(() => _isSending = true);

    try
    {
      await _apiService.requestPasswordReset(username: username);

      if (mounted)
      {
        // Non-committal on purpose: confirming the username exists would leak accounts.
        MobileNotice.show(context, 'Se il nome utente è corretto, riceverai un link via email.');

        finishMobileSheet(context);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        final message = isConnectionFailure(e)
            ? connectionFailureMessage
            : "Errore durante l'invio. Riprova più tardi.";

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
        eyebrow: 'Accesso',
        title: 'Recupero password',
        aboveKeyboard: true,
        unsaved: () => _usernameController.text.trim().isEmpty ? MobileUnsaved.none : MobileUnsaved.text,
        saving: _isSending,
        body: [
          const SizedBox(height: 12),
          const MobileSheetText(
            'Inserisci il nome utente associato al tuo account. Se esiste, ti '
            "invieremo un link di recupero all'indirizzo email registrato.",
          ),
          const SizedBox(height: 10),
          const MobileSheetText("Se non ricordi il tuo nome utente, contatta l'Associazione."),
          const SizedBox(height: 24),
          MobileTextField(
            controller: _usernameController,
            label: 'Nome utente',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.username],
            onSubmitted: (_) => _handleSend(),
          ),
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileGoldButton(
            label: 'Invia link',
            icon: Icons.send_rounded,
            busy: _isSending,
            onPressed: _handleSend,
          ),
        ),
      ),
    );
  }
}
