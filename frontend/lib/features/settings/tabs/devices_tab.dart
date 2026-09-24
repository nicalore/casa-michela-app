import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/session_item.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _confirmWidth = 480;

const double _rowButtonHeight = 44;
const double _rowButtonFontSize = 13;
const double _rowButtonPadding = 18;

const String _unknownDeviceLabel = 'Dispositivo sconosciuto';

final DateFormat _timestampFormat = DateFormat('dd/MM/yyyy, HH:mm');

class DevicesTab extends StatefulWidget
{
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab>
{
  final ApiService _apiService = ApiService();

  // Null while loading.
  List<SessionItem>? _sessions;
  bool _failed = false;
  final Set<String> _revoking = {};
  bool _revokingOthers = false;

  @override
  void initState()
  {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async
  {
    try
    {
      final sessions = await _apiService.getSessions();

      if (mounted)
      {
        setState(() => _sessions = sessions);
      }
    }
    catch (_)
    {
      if (mounted)
      {
        setState(() => _failed = true);
      }
    }
  }

  void _confirmRevoke(SessionItem session)
  {
    _askConfirmation(
      eyebrow: 'Sessione',
      message: [
        const TextSpan(text: 'La sessione su '),
        TextSpan(
          text: session.deviceName ?? _unknownDeviceLabel,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        const TextSpan(
          text: ' verrà interrotta: dovrai effettuare nuovamente l\'accesso su quel dispositivo.',
        ),
      ],
      onConfirm: () => _revokeSession(session),
    );
  }

  void _confirmRevokeOthers()
  {
    _askConfirmation(
      eyebrow: 'Sessioni',
      message: const [
        TextSpan(
          text: 'Tutte le sessioni tranne questa verranno interrotte: '
              'dovrai effettuare nuovamente l\'accesso sugli altri dispositivi.',
        ),
      ],
      onConfirm: _revokeOthers,
    );
  }

  void _askConfirmation({
    required String eyebrow,
    required List<InlineSpan> message,
    required VoidCallback onConfirm,
  })
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmSessionRevocation',
      builder: (confirmContext) => AppDialogStack(
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
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'DISATTIVA',
            icon: Icons.logout_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              onConfirm();
            },
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
  }

  Future<void> _revokeSession(SessionItem session) async
  {
    setState(() => _revoking.add(session.sessionId));

    try
    {
      await _apiService.revokeSession(session.sessionId);

      if (mounted)
      {
        setState(() => _sessions?.removeWhere((s) => s.sessionId == session.sessionId));
        CustomSnackBar.show(context: context, message: 'Sessione disattivata', isError: false);
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
        setState(() => _revoking.remove(session.sessionId));
      }
    }
  }

  Future<void> _revokeOthers() async
  {
    setState(() => _revokingOthers = true);

    try
    {
      await _apiService.revokeOtherSessions();

      if (mounted)
      {
        setState(() => _sessions?.removeWhere((s) => !s.isCurrent));
        CustomSnackBar.show(
          context: context,
          message: 'Le altre sessioni sono state disattivate',
          isError: false,
        );
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
        setState(() => _revokingOthers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final sessions = _sessions;

    // Part of the section handover, else these paint over the section still leaving.
    if (_failed)
    {
      return PageTransitionItem(
        slot: PageTransitionItem.header,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child: Text(
              'Errore durante il caricamento delle sessioni. Riprova più tardi.',
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

    if (sessions == null)
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
                  title: 'Sessioni attive',
                  compact: true,
                  selectable: false,
                  leading: const AppCardBadge(
                    icon: Icons.devices_rounded,
                    compact: true,
                  ),
                  // The page scrolls, never the card: one bar, not two.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < sessions.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
                          ),
                        _SessionRow(
                          session: sessions[i],
                          busy: _revoking.contains(sessions[i].sessionId),
                          onRevoke: () => _confirmRevoke(sessions[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: AppGradientButton(
                    label: 'DISATTIVA LE ALTRE SESSIONI',
                    icon: Icons.logout_rounded,
                    gradient: AppTheme.dangerGradient,
                    accent: AppTheme.trialDanger,
                    busy: _revokingOthers,
                    disabledReason: sessions.any((s) => !s.isCurrent)
                        ? null
                        : 'Nessun\'altra sessione attiva',
                    onPressed: _confirmRevokeOthers,
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

class _SessionRow extends StatelessWidget
{
  final SessionItem session;

  final bool busy;

  final VoidCallback onRevoke;

  const _SessionRow({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  IconData get _icon => switch (session.deviceType)
  {
    SessionDeviceType.desktop => Icons.computer_rounded,
    SessionDeviceType.phone => Icons.smartphone_rounded,
    SessionDeviceType.tablet => Icons.tablet_mac_rounded,
    SessionDeviceType.unknown => Icons.devices_other_rounded,
  };

  @override
  Widget build(BuildContext context)
  {
    final TextStyle detailStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppTheme.trialMutedText,
    );

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          session.deviceName ?? _unknownDeviceLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 4),
        Text('Accesso: ${_timestampFormat.format(session.loggedInAt)}', style: detailStyle),
        Text('Ultima attività: ${_timestampFormat.format(session.lastUsedAt)}', style: detailStyle),
      ],
    );

    final Widget action = session.isCurrent
        ? const _CurrentSessionChip()
        : AppGradientButton(
            label: 'DISATTIVA',
            icon: Icons.logout_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _rowButtonHeight,
            fontSize: _rowButtonFontSize,
            horizontalPadding: _rowButtonPadding,
            busy: busy,
            onPressed: onRevoke,
          );

    final Widget icon = Icon(_icon, size: 28, color: AppTheme.trialTealDeep);

    if (AppBreakpoints.of(context).isCompact)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: details),
            ],
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: action),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 16),
        Expanded(child: details),
        const SizedBox(width: 16),
        action,
      ],
    );
  }
}

class _CurrentSessionChip extends StatelessWidget
{
  const _CurrentSessionChip();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.trialTurquoise, width: 1.5),
      ),
      child: Text(
        'Questa sessione',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }
}
