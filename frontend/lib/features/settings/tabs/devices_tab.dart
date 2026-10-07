import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/session_item.dart';
import '../utils/settings_strings.dart';
import '../widgets/session_card.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _confirmWidth = 480;


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
      eyebrow: kSessionEyebrow,
      message: [
        revokeSessionWarning(
          session,
          deviceStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ],
      onConfirm: () => _revokeSession(session),
    );
  }

  void _confirmRevokeOthers()
  {
    _askConfirmation(
      eyebrow: kSessionsEyebrow,
      message: const [TextSpan(text: kRevokeOthersWarning)],
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
            label: kRevokeSessionLabel.toUpperCase(),
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
        CustomSnackBar.show(context: context, message: kSessionRevoked, isError: false);
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
          message: kOtherSessionsRevoked,
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
              kSessionsLoadFailed,
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
        child: LayoutBuilder(
          builder: (context, constraints)
          {
            final double cardWidth = math.min(kSessionCardWidth, constraints.maxWidth);
            final int columns =
                sessionGridColumns(constraints.maxWidth, cardWidth, sessions.length);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Centred as a block, so a short last row still starts on the left.
                Center(
                  child: SizedBox(
                    width: columns * cardWidth + (columns - 1) * kSessionCardGap,
                    child: Wrap(
                      spacing: kSessionCardGap,
                      runSpacing: kSessionCardGap,
                      children: [
                        for (final session in sessions)
                          PageTransitionItem.wave(
                            child: SessionCard(
                              session: session,
                              width: cardWidth,
                              busy: _revoking.contains(session.sessionId),
                              onRevoke: () => _confirmRevoke(session),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (sessions.any((s) => !s.isCurrent)) ...[
                  const SizedBox(height: 40),
                  PageTransitionItem(
                    slot: PageTransitionItem.list + (sessions.length - 1) ~/ columns + columns,
                    child: Center(
                      child: AppGradientButton(
                        label: kRevokeOthersLabel.toUpperCase(),
                        icon: Icons.logout_rounded,
                        gradient: AppTheme.dangerGradient,
                        accent: AppTheme.trialDanger,
                        busy: _revokingOthers,
                        onPressed: _confirmRevokeOthers,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
