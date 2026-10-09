import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../settings/utils/settings_strings.dart';
import '../models/person_account_item.dart';
import '../models/person_item.dart';
import '../widgets/create_account_dialog.dart';
import '../widgets/person_detail_widgets.dart';
import 'person_account_shared.dart';

const double _cardsWidth = 1200;

const double _labelWidth = 185;

// Two cards whose value column still fits "Richiesto al prossimo accesso" (~261 px) on one line.
const double _pairBreakpoint = 1056;

const String _statusLabel = 'Stato';
const String _active = 'Attivo';
const String _suspended = 'Sospeso';
const String _revokedMembership = 'Iscrizione revocata';
const String _expiredMembership = 'Iscrizione scaduta';
const String _noEnrolledChild = 'Nessun figlio iscritto';

const String _securityTitle = 'Sicurezza';
const String _passwordChangeLabel = 'Cambio password';
const String _passwordChangeNotRequired = 'Non richiesto';
const String _passwordChangeRequired = 'Richiesto al prossimo accesso';
const String _lockLabel = 'Blocco';
const String _noLock = 'Nessuno';

const String _autonomousBookingsTitle = 'Prenotazioni autonome';

const String _forceChangeLabel = 'Forza cambio password';
const String _recoveryEmailLabel = 'Invia email di recupero password';
const String _unlockLabel = 'Sblocca account';
const String _suspendLabel = 'Sospendi account';
const String _reactivateLabel = 'Riattiva account';

const String _passwordChangeRequested = 'Cambio password richiesto!';
const String _recoveryEmailSent = 'Email di recupero inviata!';
const String _accountUnlocked = 'Account sbloccato!';
const String _autonomousBookingsOn = 'Prenotazioni autonome attivate!';
const String _autonomousBookingsOff = 'Prenotazioni autonome disattivate!';
const String _accountSuspended = 'Account sospeso!';
const String _accountReactivated = 'Account riattivato!';

final DateFormat _clock = DateFormat('HH:mm');

class PersonAccountTab extends StatefulWidget
{
  final PersonItem person;

  // Null while the person has no account: the tab then offers only its creation.
  final PersonAccountController? controller;

  final bool isOwnProfile;

  final VoidCallback onAccountCreated;

  const PersonAccountTab({
    super.key,
    required this.person,
    required this.controller,
    required this.isOwnProfile,
    required this.onAccountCreated,
  });

  @override
  State<PersonAccountTab> createState() => _PersonAccountTabState();
}

class _PersonAccountTabState extends State<PersonAccountTab> with PersonAccountActions
{
  final ApiService _apiService = ApiService();

  // Shown at once on a tap; dropped when the server answers.
  bool? _autonomousShown;

  bool _creating = false;

  @override
  PersonItem get accountPerson => widget.person;

  @override
  PersonAccountController get accountController => widget.controller!;

  String get _fiscalCode => widget.person.fiscalCode;

  @override
  void initState()
  {
    super.initState();
    widget.controller?.ensureLoaded();
  }

  @override
  void didUpdateWidget(PersonAccountTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    widget.controller?.ensureLoaded();
  }

  Future<void> _createAccount() async
  {
    if (_creating)
    {
      return;
    }

    final bool created = await runAccountCreation(
      context,
      widget.person,
      onBusy: (busy)
      {
        if (mounted)
        {
          setState(() => _creating = busy);
        }
      },
    );

    if (created && mounted)
    {
      widget.onAccountCreated();
    }
  }

  Future<void> _confirmForceChange() async
  {
    final confirmed = await askAccountConfirmation(
      eyebrow: 'Password',
      message: [
        const TextSpan(text: 'Al prossimo accesso '),
        boldSpan(personFullName),
        const TextSpan(
          text: ' dovrà scegliere una nuova password. Tutte le sue sessioni verranno interrotte.',
        ),
      ],
      confirmLabel: 'FORZA CAMBIO',
      confirmIcon: Icons.lock_reset_rounded,
      danger: true,
    );

    if (confirmed)
    {
      await runAccountAction(
        PersonAccountAction.forceChange,
        () => _apiService.forcePasswordChange(_fiscalCode),
        _passwordChangeRequested,
      );
    }
  }

  Future<void> _confirmRecoveryEmail() async
  {
    final confirmed = await askAccountConfirmation(
      eyebrow: 'Recupero password',
      message: [
        const TextSpan(text: 'Invieremo a '),
        boldSpan(widget.person.email ?? ''),
        const TextSpan(text: ' il link per reimpostare la password, valido per 1 ora.'),
      ],
      confirmLabel: 'INVIA',
      confirmIcon: Icons.forward_to_inbox_rounded,
      danger: false,
    );

    if (confirmed)
    {
      await runAccountAction(
        PersonAccountAction.recoveryEmail,
        () => _apiService.sendPasswordResetEmail(_fiscalCode),
        _recoveryEmailSent,
      );
    }
  }

  Future<void> _confirmSuspension() async
  {
    final confirmed = await askAccountConfirmation(
      eyebrow: 'Account',
      message: [
        const TextSpan(text: "L'account di "),
        boldSpan(personFullName),
        const TextSpan(
          text: ' verrà sospeso: non potrà più accedere e tutte le sue sessioni verranno interrotte.',
        ),
      ],
      confirmLabel: 'SOSPENDI',
      confirmIcon: Icons.block_rounded,
      danger: true,
    );

    if (confirmed)
    {
      await runAccountAction(
        PersonAccountAction.suspension,
        () => _apiService.suspendAccount(_fiscalCode),
        _accountSuspended,
      );
    }
  }

  Future<void> _reactivate()
  {
    return runAccountAction(
      PersonAccountAction.suspension,
      () => _apiService.reactivateAccount(_fiscalCode),
      _accountReactivated,
    );
  }

  Future<void> _unlock()
  {
    return runAccountAction(
      PersonAccountAction.unlock,
      () => _apiService.unlockAccount(_fiscalCode),
      _accountUnlocked,
    );
  }

  Future<void> _setAutonomousBookings(bool enabled) async
  {
    if (busyAction != null)
    {
      return;
    }

    setState(() => _autonomousShown = enabled);

    await runAccountAction(
      PersonAccountAction.autonomousBookings,
      () => _apiService.setAutonomousBookings(_fiscalCode, enabled: enabled),
      enabled ? _autonomousBookingsOn : _autonomousBookingsOff,
    );

    if (mounted)
    {
      setState(() => _autonomousShown = null);
    }
  }

  Widget _buildCreation()
  {
    return Center(
      child: PageTransitionItem(
        slot: PageTransitionItem.header,
        child: PersonLoneButton(
          label: 'CREA ACCOUNT',
          icon: Icons.person_add_alt_1_rounded,
          busy: _creating,
          onPressed: _createAccount,
        ),
      ),
    );
  }

  // A manual suspension alone needs no reason.
  String? _suspensionReason(PersonAccountItem account)
  {
    if (account.isRevoked)
    {
      return _revokedMembership;
    }

    return switch (account.lapse)
    {
      'MEMBERSHIP' => _expiredMembership,
      'CHILDREN' => _noEnrolledChild,
      _ => null,
    };
  }

  Widget _buildValue(String text, {String? detail})
  {
    final Widget value = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );

    if (detail == null)
    {
      return value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        value,
        const SizedBox(height: 3),
        Text(
          detail,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }

  String _failedAttemptsText(PersonAccountItem account)
  {
    final String attempts = '${account.failedLoginAttempts} tentativi falliti';
    final DateTime? last = account.lastFailedLoginAttempt;

    return last == null ? attempts : "$attempts, l'ultimo alle ${_clock.format(last)}";
  }

  Widget _buildCards(PersonAccountItem account)
  {
    final DateTime? lockedUntil = account.lockedUntil;

    return PersonDetailCardPair(
      breakpoint: _pairBreakpoint,
      first: PersonDetailCard(
        title: kAccessSection,
        selectable: false,
        icon: Icons.manage_accounts_rounded,
        labelWidth: _labelWidth,
        rows: [
          DetailRowData(kUsernameLabel, account.username),
          DetailRowData(kLastLoginLabel, formatLastLogin(account.lastLogin)),
          DetailRowData.drawn(
            _statusLabel,
            account.isSuspended
                ? _buildValue(_suspended, detail: _suspensionReason(account))
                : _buildValue(_active),
          ),
        ],
      ),
      second: PersonDetailCard(
        title: _securityTitle,
        selectable: false,
        icon: Icons.shield_rounded,
        labelWidth: _labelWidth,
        rows: [
          DetailRowData.drawn(
            _passwordChangeLabel,
            account.passwordChangeRequired
                ? _buildValue(_passwordChangeRequired)
                : _buildValue(_passwordChangeNotRequired),
          ),
          DetailRowData.drawn(
            _lockLabel,
            lockedUntil == null
                ? _buildValue(_noLock)
                : _buildValue(
                    'Fino alle ${_clock.format(lockedUntil)}',
                    detail: _failedAttemptsText(account),
                  ),
          ),
          // Keeps the rows of the two cards level.
          null,
        ],
      ),
    );
  }

  Widget _buildAutonomousBookings(PersonAccountItem account)
  {
    return AppCard(
      title: _autonomousBookingsTitle,
      selectable: false,
      leading: const AppCardBadge(icon: Icons.event_available_rounded),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Vuoi permettere a ${widget.person.firstName} '
              'di prenotare autonomamente le lezioni?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppTheme.trialInk,
              ),
            ),
          ),
          const SizedBox(width: 24),
          AppSegmentedSwitch(
            value: _autonomousShown ?? account.autonomousBookings,
            hugContent: true,
            onChanged: _setAutonomousBookings,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(PersonAccountItem account)
  {
    if (account.isSuspended)
    {
      return const [];
    }

    if (account.isLocked)
    {
      return [
        AppGradientButton(
          label: _unlockLabel.toUpperCase(),
          icon: Icons.lock_open_rounded,
          busy: busyAction == PersonAccountAction.unlock,
          onPressed: _unlock,
        ),
      ];
    }

    return [
      if (!account.passwordChangeRequired && !widget.isOwnProfile)
        AppGradientButton(
          label: _forceChangeLabel.toUpperCase(),
          icon: Icons.lock_reset_rounded,
          busy: busyAction == PersonAccountAction.forceChange,
          onPressed: _confirmForceChange,
        ),
      AppGradientButton(
        label: _recoveryEmailLabel.toUpperCase(),
        icon: Icons.forward_to_inbox_rounded,
        busy: busyAction == PersonAccountAction.recoveryEmail,
        onPressed: _confirmRecoveryEmail,
      ),
    ];
  }

  // Only a manual suspension is lifted here.
  List<Widget> _buildSuspension(PersonAccountItem account)
  {
    return [
      if (account.isDisabled)
        AppGradientButton(
          label: _reactivateLabel.toUpperCase(),
          icon: Icons.how_to_reg_rounded,
          busy: busyAction == PersonAccountAction.suspension,
          onPressed: _reactivate,
        ),
      if (!widget.isOwnProfile && !account.isSuspended)
        AppGradientButton(
          label: _suspendLabel.toUpperCase(),
          icon: Icons.block_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          busy: busyAction == PersonAccountAction.suspension,
          onPressed: _confirmSuspension,
        ),
    ];
  }

  Widget _buildButtons(List<Widget> buttons)
  {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: buttons,
      ),
    );
  }

  Widget _buildAccount(PersonAccountItem account)
  {
    final List<Widget> actions = _buildActions(account);
    final List<Widget> suspension = _buildSuspension(account);

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _cardsWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                _buildCards(account),
                if (account.answeredFor && !account.isSuspended) ...[
                  const SizedBox(height: kPersonCardGap),
                  _buildAutonomousBookings(account),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  _buildButtons(actions),
                ],
                if (suspension.isNotEmpty) ...[
                  SizedBox(height: actions.isEmpty ? 40 : kPersonSectionGap),
                  _buildButtons(suspension),
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
    final PersonAccountController? controller = widget.controller;

    if (controller == null)
    {
      return _buildCreation();
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => accountPlaceholder(controller) ?? _buildAccount(controller.account!),
    );
  }
}
