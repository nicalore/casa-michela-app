import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../services/api_service.dart';
import '../../shared/navigation/mobile_destinations.dart';
import '../../shared/widgets/mobile_birthday_confetti.dart';
import '../../shared/widgets/mobile_handover.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_role_sheet.dart';
import '../association/mobile_association_page.dart';
import '../availability/mobile_availability_page.dart';
import '../calendar/mobile_calendar_page.dart';
import '../home/mobile_teacher_home_page.dart';
import '../profile/mobile_own_page.dart';
import '../settings/mobile_settings_page.dart';
import '../subjects/mobile_subjects_page.dart';
import 'mobile_placeholder_page.dart';

const String _teacherRole = 'TEACHER';
const String _subjectsSlug = 'subjects';
const String _availabilitySlug = 'availability';
const String _calendarSlug = 'calendar';
const String _associationSlug = 'association';

// How far a section chosen from the open menu sinks with it as it closes.
const double _curtainDrop = 20;

// Past this the section comes in with its wheel rather than keep the menu waiting.
const Duration _holdCap = Duration(seconds: 3);

// Switching role, the old area leaves upwards and the new one rises after it.
const Duration _roleTurnDuration = Duration(milliseconds: 800);

class MobileRoleShell extends StatefulWidget
{
  const MobileRoleShell({super.key});

  @override
  State<MobileRoleShell> createState() => _MobileRoleShellState();
}

class _MobileRoleShellState extends State<MobileRoleShell> with SingleTickerProviderStateMixin
{
  final ApiService _apiService = ApiService();

  // The role and section on screen; while switching, the identity already has the new role.
  String? _role;
  String _destination = kMobileHomeSlug;

  // Built out of sight until it has its data: a section chosen from the menu, or a new role's home.
  String? _arrivingRole;
  String? _arrivingSlug;
  Completer<void>? _arrival;
  Timer? _cap;
  final ValueNotifier<int> _holds = ValueNotifier<int>(0);

  // From the role request until its home is in.
  String? _switchingTo;

  late final AnimationController _turn = AnimationController(vsync: this, duration: _roleTurnDuration)
    ..addStatusListener(_onTurn);
  String? _leavingRole;
  String? _leavingSlug;

  // From choosing a section until the menu closes; reopening it leaves the page still.
  bool _sinking = false;

  // Sign-out clears the identity before the handover, while this area is still shown.
  MeResponse? _lastUser;

  @override
  void initState()
  {
    super.initState();
    MobileNavSheet.openness.addListener(_onSheetMoved);
  }

  @override
  void dispose()
  {
    _stopWaiting();
    _holds.dispose();
    _turn.dispose();
    MobileNavSheet.openness.removeListener(_onSheetMoved);
    super.dispose();
  }

  void _onSheetMoved()
  {
    if (MobileNavSheet.openness.value <= 0)
    {
      _sinking = false;
    }
  }

  // Completes once the section has its data.
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

  // Completes once the section is in, swapped under the still open menu.
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
      onChoose: _switchRole,
    );
  }

  // Completes once the new role's home is in: the sheet then closes as the areas turn.
  Future<void> _switchRole(String role) async
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

    await _prepare(role, kMobileHomeSlug);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _leavingRole = _role;
      _leavingSlug = _destination;
      _role = role;
      _destination = kMobileHomeSlug;
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
      return role == _teacherRole
          ? const MobileTeacherHomePage()
          : const MobilePlaceholderPage(title: 'Home');
    }

    if (slug == kMobileOwnPageSlug)
    {
      return MobileOwnPage(user: user);
    }

    if (slug == kMobileSettingsSlug)
    {
      return MobileSettingsPage(user: user);
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
      return const MobileCalendarPage();
    }

    if (current.slug == _associationSlug && role == _teacherRole)
    {
      return const MobileAssociationPage();
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
          _role = user.activeRole;
          _destination = kMobileHomeSlug;
        }

        final String role = _role!;
        final List<MobileDestination> destinations = _destinationsFor(user, role);
        final List<MobileDestination> userDestinations = mobileUserDestinationsFor(user.firstName);

        // A role switch leaves a destination the new role does not have.
        if (![...destinations, ...userDestinations].any((d) => d.slug == _destination))
        {
          _destination = kMobileHomeSlug;
        }

        final MobileDestination current = [...destinations, ...userDestinations]
            .firstWhere((d) => d.slug == _destination);

        final double height = MediaQuery.sizeOf(context).height;

        // Each section under its own scope, so the one loading out of sight
        // keeps its element when it comes in.
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              MobileHandoverRise(
                child: ValueListenableBuilder<double>(
                  valueListenable: MobileNavSheet.openness,
                  builder: (context, open, page) => Transform.translate(
                    offset: Offset(0, _sinking ? -_curtainDrop * open : 0),
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
            ],
          ),
        );
      },
    );
  }
}
