import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/people/widgets/person_detail_widgets.dart';
import '../../../features/settings/models/session_item.dart';
import '../../../features/settings/utils/settings_strings.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/device_files.dart';
import '../../shared/widgets/mobile_confirm_sheet.dart';
import '../../shared/widgets/mobile_danger_button.dart';
import '../../shared/widgets/mobile_dismiss_button.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../profile/widgets/mobile_detail_card.dart';
import 'widgets/mobile_about.dart';
import 'widgets/mobile_appearance_cards.dart';
import 'widgets/mobile_password_sheet.dart';
import 'widgets/mobile_problem_report_sheet.dart';
import 'widgets/mobile_sessions.dart';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _stripGap = 14;

// Room between the strip's rule and the first card.
const double _topRoom = 16;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

const double _buttonGap = 22;
const double _reportGap = 20;
const double _creditsGap = 34;

const String _confirmTitle = 'Confermi?';

// Mobile only: the desktop opens the regulation in a tab instead.
const String _regulationSaved = 'Il regolamento è stato scaricato.';
const String _regulationSaveFailed = 'Non è stato possibile salvare il regolamento.';

// Page data lives here: the pages are not kept alive.
class MobileSettingsPage extends StatefulWidget
{
  final MeResponse user;

  // The time now; a probe fixes it.
  final DateTime Function() clock;

  const MobileSettingsPage({super.key, required this.user, this.clock = DateTime.now});

  @override
  State<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<MobileSettingsPage>
{
  final ApiService _apiService = ApiService();
  final PageController _pages = PageController();

  // Null while loading.
  List<SessionItem>? _sessions;
  bool _sessionsFailed = false;
  int _sessionsRequest = 0;

  bool _revokingOthers = false;
  bool _savingRegulation = false;

  @override
  void initState()
  {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose()
  {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({bool quiet = false}) async
  {
    final int request = ++_sessionsRequest;

    try
    {
      final List<SessionItem> sessions = await _apiService.getSessions();

      if (!mounted || request != _sessionsRequest)
      {
        return;
      }

      setState(()
      {
        _sessions = sessions;
        _sessionsFailed = false;
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle sessioni');

      if (!mounted || request != _sessionsRequest)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(() => _sessionsFailed = !quiet || _sessions == null);
    }
  }

  // The shell rebuilds this page with the identity it reads back.
  Future<void> _refreshAccount() async
  {
    try
    {
      await _apiService.me();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: "il caricamento dell'account");
    }
  }

  List<SessionItem> _ordered(List<SessionItem> sessions)
  {
    return [
      ...sessions.where((session) => session.isCurrent),
      ...sessions.where((session) => !session.isCurrent),
    ];
  }

  Future<void> _openSession(SessionItem session)
  {
    return showMobileSessionSheet(context: context, session: session, onRevoke: (sheet) => _revoke(sheet, session));
  }

  Future<void> _revoke(BuildContext sheet, SessionItem session) async
  {
    final bool confirmed = await showMobileConfirmSheet(
      context: sheet,
      eyebrow: kSessionEyebrow,
      title: _confirmTitle,
      message: revokeSessionWarning(
        session,
        deviceStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
      confirmLabel: kRevokeSessionLabel,
      confirmIcon: Icons.logout_rounded,
    );

    if (!confirmed || !mounted)
    {
      return;
    }

    if (sheet.mounted)
    {
      closeMobileSheet(sheet);
    }

    try
    {
      await _apiService.revokeSession(session.sessionId);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _sessions = [
          for (final kept in _sessions ?? const <SessionItem>[])
            if (kept.sessionId != session.sessionId) kept,
        ];
      });

      MobileNotice.show(context, kSessionRevoked);
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
  }

  Future<void> _revokeOthers() async
  {
    if (_revokingOthers)
    {
      return;
    }

    final bool confirmed = await showMobileConfirmSheet(
      context: context,
      eyebrow: kSessionsEyebrow,
      title: _confirmTitle,
      message: const TextSpan(text: kRevokeOthersWarning),
      confirmLabel: kRevokeSessionLabel,
      confirmIcon: Icons.logout_rounded,
    );

    if (!confirmed || !mounted)
    {
      return;
    }

    setState(() => _revokingOthers = true);

    try
    {
      await _apiService.revokeOtherSessions();

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _sessions = [
          for (final kept in _sessions ?? const <SessionItem>[])
            if (kept.isCurrent) kept,
        ];
      });

      MobileNotice.show(context, kOtherSessionsRevoked);
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
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

  Future<void> _saveRegulation() async
  {
    if (_savingRegulation)
    {
      return;
    }

    setState(() => _savingRegulation = true);

    try
    {
      final ApiFile regulation = await _apiService.fetchRegulation();
      final bool saved = await saveToDevice(regulation.bytes, fileName: regulation.fileName);

      if (saved && mounted)
      {
        MobileNotice.show(context, _regulationSaved);
      }
    }
    on PlatformException catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il salvataggio del regolamento');

      if (mounted)
      {
        MobileNotice.show(context, _regulationSaveFailed, error: true);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _savingRegulation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          child: Text(
            kSettingsTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 36 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.05,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: _stripGap),
        MobilePageStrip(
          labels: const [kAppearanceSection, kAccessSection, kDevicesSection, kInfoSection],
          controller: _pages,
          scrollMargin: margin,
        ),
      ],
    );

    Widget page(List<Widget> children, {Future<void> Function()? onRefresh})
    {
      return _SettingsPage(
        margin: margin,
        bottom: bottom,
        onRefresh: onRefresh,
        children: children,
      );
    }

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        body: PageView(
          controller: _pages,
          // Not kept alive: every mounted scroll view answers the header's scroll.
          children: [
            page([MobileAppearanceCards(tablet: tablet)]),
            page(_buildAccess(tablet: tablet), onRefresh: _refreshAccount),
            page(_buildDevices(tablet: tablet), onRefresh: () => _loadSessions(quiet: true)),
            page(_buildInfo(tablet: tablet)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAccess({required bool tablet})
  {
    final MeResponse user = widget.user;

    return [
      MobileDetailCard(
        icon: Icons.manage_accounts_rounded,
        title: kAccessSection,
        rows: [
          DetailRowData(kUsernameLabel, user.username),
          DetailRowData(kLastLoginLabel, formatLastLogin(user.lastLogin)),
        ],
      ),
      const SizedBox(height: _buttonGap),
      _ButtonWidth(
        tablet: tablet,
        child: MobileGoldButton(
          label: kChangePasswordLabel,
          icon: Icons.key_rounded,
          onPressed: () => showMobilePasswordSheet(context),
        ),
      ),
    ];
  }

  List<Widget> _buildDevices({required bool tablet})
  {
    final List<SessionItem>? sessions = _sessions;

    return [
      MobileLoadSwitcher(
        child: sessions == null
            ? (_sessionsFailed ? const _Status(kSessionsLoadFailed) : const MobileWaiting())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MobileSessionList(sessions: _ordered(sessions), onOpen: _openSession),
                  if (sessions.any((session) => !session.isCurrent)) ...[
                    const SizedBox(height: _buttonGap),
                    _ButtonWidth(
                      tablet: tablet,
                      child: MobileDangerButton(
                        label: kRevokeOthersLabel,
                        icon: Icons.logout_rounded,
                        onPressed: _revokeOthers,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    ];
  }

  List<Widget> _buildInfo({required bool tablet})
  {
    return [
      MobileDocumentsCard(onRegulation: _saveRegulation, regulationBusy: _savingRegulation),
      const SizedBox(height: _reportGap),
      _ButtonWidth(
        tablet: tablet,
        child: MobileDismissButton(
          label: kReportProblemLabel,
          icon: Icons.flag_rounded,
          onPressed: () => showMobileProblemReportSheet(context),
        ),
      ),
      const SizedBox(height: _creditsGap),
      MobileAppCredits(year: widget.clock().year),
    ];
  }
}

// Margin inside the scroll view so card shadows are not clipped while paging.
class _SettingsPage extends StatelessWidget
{
  final double margin;
  final double bottom;
  final Future<void> Function()? onRefresh;
  final List<Widget> children;

  const _SettingsPage({
    required this.margin,
    required this.bottom,
    required this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget list = ListView(
      clipBehavior: Clip.none,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(margin, _topRoom, margin, bottom),
      children: children,
    );

    final Future<void> Function()? onRefresh = this.onRefresh;

    return MobileSwipePage(
      child: onRefresh == null
          ? list
          : RefreshIndicator(
              color: AppTheme.trialGold,
              backgroundColor: AppTheme.trialDeepWater,
              onRefresh: onRefresh,
              child: list,
            ),
    );
  }
}

class _ButtonWidth extends StatelessWidget
{
  final bool tablet;
  final Widget child;

  const _ButtonWidth({required this.tablet, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return tablet ? Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: child)) : child;
  }
}

class _Status extends StatelessWidget
{
  final String text;

  const _Status(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
