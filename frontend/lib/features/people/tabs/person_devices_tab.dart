import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../settings/models/session_item.dart';
import '../../settings/utils/settings_strings.dart';
import '../../settings/widgets/session_card.dart';
import '../models/person_account_item.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';
import 'person_account_shared.dart';

const double _contentWidth = 1200;

const String _noSessions = 'Nessuna sessione attiva.';

const String _revokeAllLabel = 'Disattiva tutte le sessioni';

const String _sessionRevoked = 'Sessione disattivata!';
const String _sessionsRevoked = 'Sessioni disattivate!';

class PersonDevicesTab extends StatefulWidget
{
  final PersonItem person;

  final PersonAccountController controller;

  final bool isOwnProfile;

  const PersonDevicesTab({
    super.key,
    required this.person,
    required this.controller,
    required this.isOwnProfile,
  });

  @override
  State<PersonDevicesTab> createState() => _PersonDevicesTabState();
}

class _PersonDevicesTabState extends State<PersonDevicesTab> with PersonAccountActions
{
  final ApiService _apiService = ApiService();

  final Set<String> _revoking = {};

  @override
  PersonItem get accountPerson => widget.person;

  @override
  PersonAccountController get accountController => widget.controller;

  String get _fiscalCode => widget.person.fiscalCode;

  @override
  void initState()
  {
    super.initState();
    widget.controller.ensureLoaded();
  }

  @override
  void didUpdateWidget(PersonDevicesTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    widget.controller.ensureLoaded();
  }

  Future<void> _confirmRevoke(SessionItem session) async
  {
    final confirmed = await askAccountConfirmation(
      eyebrow: kSessionEyebrow,
      message: [
        const TextSpan(text: 'La sessione su '),
        boldSpan(sessionDeviceName(session)),
        TextSpan(
          text: ' verrà interrotta: $personFullName dovrà effettuare nuovamente '
              "l'accesso su quel dispositivo.",
        ),
      ],
      confirmLabel: kRevokeSessionLabel.toUpperCase(),
      confirmIcon: Icons.logout_rounded,
      danger: true,
    );

    if (confirmed)
    {
      await _revoke(session);
    }
  }

  Future<void> _revoke(SessionItem session) async
  {
    setState(() => _revoking.add(session.sessionId));

    try
    {
      await _apiService.revokePersonSession(_fiscalCode, session.sessionId);
      await widget.controller.reload();

      showOutcome(_sessionRevoked, isError: false);
    }
    catch (e)
    {
      showOutcome(readableApiError(e), isError: true);
    }
    finally
    {
      if (mounted)
      {
        setState(() => _revoking.remove(session.sessionId));
      }
    }
  }

  Future<void> _confirmRevokeAll() async
  {
    final confirmed = await askAccountConfirmation(
      eyebrow: kSessionsEyebrow,
      message: [
        const TextSpan(text: 'Tutte le sessioni di '),
        boldSpan(personFullName),
        const TextSpan(
          text: " verranno interrotte: dovrà effettuare nuovamente l'accesso su ogni dispositivo.",
        ),
      ],
      confirmLabel: kRevokeSessionLabel.toUpperCase(),
      confirmIcon: Icons.logout_rounded,
      danger: true,
    );

    if (confirmed)
    {
      await runAccountAction(
        PersonAccountAction.revokeAll,
        () => _apiService.revokePersonSessions(_fiscalCode),
        _sessionsRevoked,
      );
    }
  }

  Widget _buildSessions(List<SessionItem> sessions)
  {
    if (sessions.isEmpty)
    {
      return const PersonEmptyState(message: _noSessions);
    }

    // Centred as a block, so a short last row still starts on the left.
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double cardWidth = math.min(kSessionCardWidth, constraints.maxWidth);
        final int columns = sessionGridColumns(constraints.maxWidth, cardWidth, sessions.length);

        return Center(
          child: SizedBox(
            width: columns * cardWidth + (columns - 1) * kSessionCardGap,
            child: Wrap(
              spacing: kSessionCardGap,
              runSpacing: kSessionCardGap,
              children: [
                for (final session in sessions)
                  SessionCard(
                    session: session,
                    width: cardWidth,
                    busy: _revoking.contains(session.sessionId),
                    onRevoke: () => _confirmRevoke(session),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildActions(PersonAccountItem account)
  {
    // The settings, not this tab, end one's other sessions.
    final bool canRevokeAll =
        !widget.isOwnProfile && account.sessions.any((session) => !session.isCurrent);

    return [
      if (canRevokeAll)
        AppGradientButton(
          label: _revokeAllLabel.toUpperCase(),
          icon: Icons.logout_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          busy: busyAction == PersonAccountAction.revokeAll,
          onPressed: _confirmRevokeAll,
        ),
    ];
  }

  Widget _buildDevices(PersonAccountItem account)
  {
    final List<Widget> actions = _buildActions(account);

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                _buildSessions(account.sessions),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: actions,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) =>
          accountPlaceholder(widget.controller) ?? _buildDevices(widget.controller.account!),
    );
  }
}
