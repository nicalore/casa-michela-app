import 'package:flutter/material.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../services/api_service.dart';
import '../../shared/navigation/mobile_destinations.dart';
import '../../shared/widgets/mobile_birthday_confetti.dart';
import '../../shared/widgets/mobile_handover.dart';
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

class MobileRoleShell extends StatefulWidget
{
  const MobileRoleShell({super.key});

  @override
  State<MobileRoleShell> createState() => _MobileRoleShellState();
}

class _MobileRoleShellState extends State<MobileRoleShell>
{
  final ApiService _apiService = ApiService();

  String _destination = kMobileHomeSlug;

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

  void _onDestination(String slug)
  {
    setState(()
    {
      _destination = slug;
      _sinking = true;
    });
  }

  List<MobileDestination> _destinationsFor(MeResponse user)
  {
    return mobileDestinationsFor(
      user.activeRole,
      hasParentalResponsibility: user.hasParentalResponsibility,
    );
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

  Future<void> _changeRole(MeResponse user) async
  {
    final String? role = await showMobileRoleSheet(
      context: context,
      activeRole: user.activeRole,
      availableRoles: user.availableRoles,
    );

    if (role == null || !mounted)
    {
      return;
    }

    try
    {
      await _apiService.setActiveRole(role);
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }

      return;
    }

    if (mounted)
    {
      setState(() => _destination = kMobileHomeSlug);
    }
  }

  Widget _buildPage(MeResponse user, List<MobileDestination> destinations)
  {
    if (_destination == kMobileHomeSlug)
    {
      return user.activeRole == _teacherRole
          ? const MobileTeacherHomePage()
          : const MobilePlaceholderPage(title: 'Home');
    }

    if (_destination == kMobileOwnPageSlug)
    {
      return MobileOwnPage(user: user);
    }

    if (_destination == kMobileSettingsSlug)
    {
      return MobileSettingsPage(user: user);
    }

    final MobileDestination current = destinations.firstWhere((d) => d.slug == _destination);

    if (current.slug == _subjectsSlug && user.activeRole == _teacherRole)
    {
      return const MobileSubjectsPage();
    }

    if (current.slug == _availabilitySlug && user.activeRole == _teacherRole)
    {
      return const MobileAvailabilityPage();
    }

    if (current.slug == _calendarSlug && user.activeRole == _teacherRole)
    {
      return const MobileCalendarPage();
    }

    if (current.slug == _associationSlug && user.activeRole == _teacherRole)
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

        final List<MobileDestination> destinations = _destinationsFor(user);
        final List<MobileDestination> userDestinations = mobileUserDestinationsFor(user.firstName);

        // A role switch leaves a destination the new role does not have.
        if (![...destinations, ...userDestinations].any((d) => d.slug == _destination))
        {
          _destination = kMobileHomeSlug;
        }

        final MobileDestination current = [...destinations, ...userDestinations]
            .firstWhere((d) => d.slug == _destination);

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
                  child: KeyedSubtree(
                    key: ValueKey('${user.activeRole}/$_destination'),
                    child: _buildPage(user, destinations),
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
