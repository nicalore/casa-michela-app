import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_text_field.dart';

const double _maxWidth = 560;

const double _grabberWidth = 38;
const double _grabberHeight = 5;

const double _topPadding = 14;
const double _bottomPadding = 24;

// Backdrop left showing above a sheet that has grown to its tallest.
const double _topClearance = 24;

Future<void> showMobilePasswordRecoverySheet(BuildContext context)
{
  // Read here: the sheet route strips the top padding.
  final double statusBar = MediaQuery.paddingOf(context).top;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppTheme.trialDeepWater.withValues(alpha: 0.42),
    constraints: const BoxConstraints(maxWidth: _maxWidth),
    builder: (context) => _RecoverySheet(statusBar: statusBar),
  );
}

class _RecoverySheet extends StatefulWidget
{
  final double statusBar;

  const _RecoverySheet({required this.statusBar});

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

        Navigator.of(context).pop();
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

  Widget _buildBody(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppTheme.trialInk.withValues(alpha: 0.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final MediaQueryData media = MediaQuery.of(context);
    final double keyboard = media.viewInsets.bottom;

    // Glass runs under the keyboard: no edge shows through a translucent one, no jump.
    final double bottom = (keyboard > 0 ? keyboard : media.padding.bottom) + _bottomPadding;
    final double maxHeight = media.size.height - widget.statusBar - _topClearance - _topPadding - bottom;

    return MobileGlassPanel.sheet(
      padding: EdgeInsets.fromLTRB(24, _topPadding, 24, bottom),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: _grabberWidth,
                    height: _grabberHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.trialOcean.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(_grabberHeight / 2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accesso'.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.9,
                              color: AppTheme.trialTealDeep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recupero password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.25,
                              color: AppTheme.trialInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    MobileSheetCloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBody(
                  'Inserisci il nome utente associato al tuo account. Se esiste, ti '
                  "invieremo un link di recupero all'indirizzo email registrato.",
                ),
                const SizedBox(height: 10),
                _buildBody("Se non ricordi il tuo nome utente, contatta l'Associazione."),
                const SizedBox(height: 24),
                MobileTextField(
                  controller: _usernameController,
                  label: 'Nome utente',
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.send,
                  autofillHints: const [AutofillHints.username],
                  onSubmitted: (_) => _handleSend(),
                ),
                const SizedBox(height: 24),
                MobileGoldButton(
                  label: 'Invia link',
                  icon: Icons.send_rounded,
                  busy: _isSending,
                  onPressed: _handleSend,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
