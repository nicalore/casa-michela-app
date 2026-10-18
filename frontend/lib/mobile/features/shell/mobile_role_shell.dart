import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/reports/reports_board.dart';
import '../../../services/api_service.dart';
import '../../shared/navigation/mobile_destinations.dart';
import '../../shared/widgets/mobile_birthday_confetti.dart';
import '../../shared/widgets/mobile_halloween_bats.dart';
import '../../shared/widgets/mobile_handover.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_role_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../association/mobile_association_page.dart';
import '../availability/mobile_availability_page.dart';
import '../bookings/mobile_bookings_page.dart';
import '../calendar/mobile_calendar_page.dart';
import '../calendar/mobile_pupil_calendar_page.dart';
import '../children/mobile_children_page.dart';
import '../home/mobile_admin_home_page.dart';
import '../home/mobile_pupil_home_page.dart';
import '../home/mobile_teacher_home_page.dart';
import '../profile/mobile_own_page.dart';
import '../reports/mobile_report_details_sheet.dart';
import '../reports/mobile_reports_page.dart';
import '../settings/mobile_settings_page.dart';
import '../subjects/mobile_subjects_page.dart';
import '../updates/mobile_unread_updates.dart';
import 'mobile_placeholder_page.dart';
import 'mobile_shell_requests.dart';

const String _adminRole = 'ADMIN';
const String _teacherRole = 'TEACHER';
const String _parentRole = 'PARENT';
const Set<String> _pupilRoles = {_parentRole, 'STUDENT'};
const String _subjectsSlug = 'subjects';
const String _availabilitySlug = 'availability';
const String _calendarSlug = 'calendar';
const String _associationSlug = 'association';
const String _childrenSlug = 'children';
const String _bookingsSlug = 'bookings';

// How far a section chosen from the open menu sinks with it as it closes.
const double _curtainDrop = 20;

// Past this the section comes in with its wheel rather than keep the menu waiting.
const Duration _holdCap = Duration(seconds: 3);

const Duration _roleTurnDuration = Duration(milliseconds: 800);

class MobileRoleShell extends StatefulWidget
{
  const MobileRoleShell({super.key});

  @override
  State<MobileRoleShell> createState() => _MobileRoleShellState();
}

class _MobileRoleShellState extends State<MobileRoleShell> with TickerProviderStateMixin
{
  final ApiService _apiService = ApiService();

  // While switching, the identity already has the new role.
  String? _role;
  String _destination = kMobileHomeSlug;

  // Built out of sight until it has its data.
  String? _arrivingRole;
  String? _arrivingSlug;
  Completer<void>? _arrival;
  Timer? _cap;
  final ValueNotifier<int> _holds = ValueNotifier<int>(0);

  String? _switchingTo;

  late final AnimationController _turn = AnimationController(vsync: this, duration: _roleTurnDuration)
    ..addStatusListener(_onTurn);
  String? _leavingRole;
  String? _leavingSlug;

  // From choosing a section until the menu closes; reopening it leaves the page still.
  bool _sinking = false;

  // The menu closing without the menu, for a section a notification asks for: 1 open, 0 closed.
  late final AnimationController _fall = AnimationController(vsync: this)..addListener(_onCurtainMoved);

  // Whichever of the two the page follows down.
  late final Listenable _curtain = Listenable.merge([MobileNavSheet.openness, _fall]);

  // Sign-out clears the identity before the handover, while this area is still shown.
  MeResponse? _lastUser;

  bool _menuSeen = false;

  @override
  void initState()
  {
    super.initState();
    MobileNavSheet.openness.addListener(_onCurtainMoved);
    MobileShellRequests.section.addListener(_onRequest);
    MobileShellRequests.report.addListener(_onReportRequest);

    // A tap that opened the app asked before the area was built.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      _onRequest();
      _onReportRequest();
    });

    // The menu's count, ready before it opens.
    unawaited(ReportsBoard.instance.refresh(_apiService.lastKnownIdentity));
  }

  @override
  void dispose()
  {
    _stopWaiting();
    _holds.dispose();
    _turn.dispose();
    _fall.dispose();
    MobileNavSheet.openness.removeListener(_onCurtainMoved);
    MobileShellRequests.section.removeListener(_onRequest);
    MobileShellRequests.report.removeListener(_onReportRequest);
    super.dispose();
  }

  // A report's notification: the report over whatever page is shown.
  void _onReportRequest()
  {
    if (!mounted || MobileShellRequests.report.value == null || _lastUser == null)
    {
      return;
    }

    final int id = MobileShellRequests.takeReport()!;

    unawaited(showMobileReport(context, id));
  }

  // A notification asking for a section: the role it concerns first, if another.
  void _onRequest()
  {
    final MeResponse? user = _lastUser;

    if (!mounted || MobileShellRequests.section.value == null || _role == null || user == null)
    {
      return;
    }

    final ({String role, String slug}) request = MobileShellRequests.take()!;

    if (!user.availableRoles.contains(request.role))
    {
      return;
    }

    if (request.role != _role)
    {
      unawaited(_switchRole(request.role, slug: request.slug));
    }
    else if (request.slug != _destination)
    {
      unawaited(_dropInto(request.slug));
    }
  }

  // As a section chosen from the menu, without the menu: the new page sinks into place as it would close.
  Future<void> _dropInto(String slug) async
  {
    final String role = _role!;

    await _prepare(role, slug);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _destination = slug;
      _arrivingRole = null;
      _arrivingSlug = null;
      _sinking = true;
    });

    _fall.value = 1;
    _fall.animateWith(SpringSimulation(MobileNavSheet.spring, 1, 0, 0)).whenComplete(()
    {
      if (mounted && !_fall.isAnimating)
      {
        _fall.value = 0;
      }
    });
  }

  void _onCurtainMoved()
  {
    // Opening the menu reads the count again.
    final bool open = MobileNavSheet.openness.value > 0;

    if (open && !_menuSeen)
    {
      unawaited(ReportsBoard.instance.refresh(_lastUser));
    }

    _menuSeen = open;

    if (MobileNavSheet.openness.value <= 0 && _fall.value <= 0)
    {
      _sinking = false;
    }
  }

  Future<void> _prepare(String role, String slug)
  {
    final Completer<void> arrival = Completer<void>();

    _arrival = arrival;
    setState(()
    {
      _arrivingRole = role;
      _arrivingSlug = slug;
    });

    // After the section's first build, when its pages have asked to be waited for.
    WidgetsBinding.instance.addPostFrameCallback((_) => _readyWhenLoaded());

    return arrival.future;
  }

  void _readyWhenLoaded()
  {
    if (!mounted || _arrivingSlug == null)
    {
      return;
    }

    if (_holds.value == 0)
    {
      _ready();

      return;
    }

    _holds.addListener(_onHolds);
    _cap = Timer(_holdCap, _ready);
  }

  void _onHolds()
  {
    if (_holds.value == 0)
    {
      _ready();
    }
  }

  void _stopWaiting()
  {
    _holds.removeListener(_onHolds);
    _cap?.cancel();
    _cap = null;
  }

  void _ready()
  {
    _stopWaiting();
    _arrival?.complete();
    _arrival = null;
  }

  Future<void> _onDestination(String slug) async
  {
    final String? role = _role;

    if (role == null)
    {
      return;
    }

    await _prepare(role, slug);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _destination = slug;
      _arrivingRole = null;
      _arrivingSlug = null;
      _sinking = true;
    });
  }

  List<MobileDestination> _destinationsFor(MeResponse user, String role)
  {
    return mobileDestinationsFor(role, hasParentalResponsibility: user.hasParentalResponsibility);
  }

  Future<void> _onAction(MeResponse user, MobileNavAction action) async
  {
    switch (action)
    {
      case MobileNavAction.changeRole:
        await _changeRole(user);

      case MobileNavAction.logout:
        await _apiService.logout();
    }
  }

  Future<void> _changeRole(MeResponse user)
  {
    return showMobileRoleSheet(
      context: context,
      activeRole: user.activeRole,
      availableRoles: user.availableRoles,
      feminine: user.gender == 'F',
      onChoose: _switchRole,
    );
  }

  Future<void> _switchRole(String role, {String slug = kMobileHomeSlug}) async
  {
    _switchingTo = role;

    try
    {
      await _apiService.setActiveRole(role);
    }
    catch (e)
    {
      _switchingTo = null;

      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }

      return;
    }

    if (!mounted)
    {
      return;
    }

    await _prepare(role, slug);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _leavingRole = _role;
      _leavingSlug = _destination;
      _role = role;
      _destination = slug;
      _arrivingRole = null;
      _arrivingSlug = null;
      _switchingTo = null;
    });

    _turn.forward(from: 0);
  }

  void _onTurn(AnimationStatus status)
  {
    if (status.isCompleted)
    {
      setState(()
      {
        _leavingRole = null;
        _leavingSlug = null;
      });
    }
  }

  // In shares of the screen height, downwards.
  double _turnShift(String role, String slug)
  {
    if (_leavingRole == null)
    {
      return 0;
    }

    final double t = _turn.value;

    if (role == _leavingRole && slug == _leavingSlug)
    {
      return -Curves.easeInOutCubic.transform((t / 0.6).clamp(0.0, 1.0));
    }

    if (role == _role && slug == _destination)
    {
      return 1 - Curves.easeOutCubic.transform(((t - 0.15) / 0.75).clamp(0.0, 1.0));
    }

    return 0;
  }

  Widget _buildPage(MeResponse user, String role, String slug)
  {
    if (slug == kMobileHomeSlug)
    {
      if (role == _teacherRole)
      {
        return MobileTeacherHomePage(user: user);
      }

      if (role == _adminRole)
      {
        return MobileAdminHomePage(user: user);
      }

      return _pupilRoles.contains(role)
          ? MobilePupilHomePage(role: role, user: user)
          : const MobileUnreadUpdatesTrigger(child: MobilePlaceholderPage(title: 'Home'));
    }

    if (slug == kMobileOwnPageSlug)
    {
      return MobileOwnPage(user: user);
    }

    if (slug == kMobileSettingsSlug)
    {
      return MobileSettingsPage(user: user);
    }

    if (slug == kMobileReportsSlug)
    {
      return MobileReportsPage(user: user);
    }

    final MobileDestination current = _destinationsFor(user, role).firstWhere((d) => d.slug == slug);

    if (current.slug == _subjectsSlug && role == _teacherRole)
    {
      return const MobileSubjectsPage();
    }

    if (current.slug == _availabilitySlug && role == _teacherRole)
    {
      return const MobileAvailabilityPage();
    }

    if (current.slug == _calendarSlug && role == _teacherRole)
    {
      return MobileCalendarPage(user: user);
    }

    if (current.slug == _calendarSlug && _pupilRoles.contains(role))
    {
      return MobilePupilCalendarPage(user: user, role: role);
    }

    if (current.slug == _associationSlug && (role == _teacherRole || _pupilRoles.contains(role)))
    {
      return MobileAssociationPage(role: role);
    }

    if (current.slug == _childrenSlug && role == _parentRole)
    {
      return MobileChildrenPage(user: user);
    }

    if (current.slug == _bookingsSlug && _pupilRoles.contains(role))
    {
      return MobileBookingsPage(user: user, role: role);
    }

    return MobilePlaceholderPage(title: current.label);
  }

  @override
  Widget build(BuildContext context)
  {
    return ValueListenableBuilder<MeResponse?>(
      valueListenable: _apiService.identity,
      builder: (context, identity, _)
      {
        final MeResponse? user = identity ?? _lastUser;

        if (user == null)
        {
          return const Scaffold();
        }

        _lastUser = user;

        // A role changed elsewhere than the role sheet: the area follows at once.
        if (_role == null ||
            (user.activeRole != _role && user.activeRole != _switchingTo && _leavingRole == null))
        {
          // A tap's request may have come while the area did not know its role yet.
          if (_role == null)
          {
            WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest());
          }

          _role = user.activeRole;
          _destination = kMobileHomeSlug;
        }

        final String role = _role!;
        final List<MobileDestination> destinations = _destinationsFor(user, role);
        final List<MobileDestination> userDestinations = mobileUserDestinationsFor(
          user.firstName,
          reports: user.readsReports ? ReportsBoard.instance.unread : null,
        );

        // A role switch leaves a destination the new role does not have.
        if (![...destinations, ...userDestinations].any((d) => d.slug == _destination))
        {
          _destination = kMobileHomeSlug;
        }

        final MobileDestination current = [...destinations, ...userDestinations]
            .firstWhere((d) => d.slug == _destination);

        final double height = MediaQuery.sizeOf(context).height;

        // Own scope per section, so the one loading out of sight keeps its element when shown.
        Widget section(String sectionRole, String slug, {bool arriving = false})
        {
          return KeyedSubtree(
            key: ValueKey('$sectionRole/$slug'),
            child: AnimatedBuilder(
              animation: _turn,
              builder: (context, page) => Transform.translate(
                offset: Offset(0, _turnShift(sectionRole, slug) * height),
                child: page,
              ),
              child: MobileHoldScope(
                holds: _holds,
                waiting: arriving,
                child: Offstage(offstage: arriving, child: _buildPage(user, sectionRole, slug)),
              ),
            ),
          );
        }

        final String? leavingRole = _leavingRole;
        final String? leavingSlug = _leavingSlug;
        final String? arrivingRole = _arrivingRole;
        final String? arrivingSlug = _arrivingSlug;

        return Scaffold(
          // Fields live in sheets above the keyboard; resizing relaid the page every frame.
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              MobileHandoverRise(
                child: AnimatedBuilder(
                  animation: _curtain,
                  builder: (context, page) => Transform.translate(
                    offset: Offset(
                      0,
                      _sinking ? -_curtainDrop * math.max(MobileNavSheet.openness.value, _fall.value) : 0,
                    ),
                    child: page,
                  ),
                  child: IgnorePointer(
                    ignoring: leavingRole != null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (leavingRole != null && leavingSlug != null) section(leavingRole, leavingSlug),
                        section(role, _destination),
                        if (arrivingRole != null && arrivingSlug != null)
                          section(arrivingRole, arrivingSlug, arriving: true),
                      ],
                    ),
                  ),
                ),
              ),
              // Outside the page switcher, so a page change never restarts the shower.
              const MobileBirthdayConfetti(),
              MobileHalloweenBats(onHome: _destination == kMobileHomeSlug),
              MobileHandoverBar(
                head: MobileNavHead(destination: current),
                child: MobileNavSheet(
                  user: user,
                  destinations: destinations,
                  userDestinations: userDestinations,
                  current: _destination,
                  onDestination: _onDestination,
                  onAction: (action) => _onAction(user, action),
                ),
              ),
              MobileTourLayer(ready: leavingRole == null && arrivingSlug == null),
            ],
          ),
        );
      },
    );
  }
}
