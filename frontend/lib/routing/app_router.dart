import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/association/association_page.dart';
import '../features/auth/force_password_change_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/home/role_home_page.dart';
import '../features/home/role_unavailable_page.dart';
import '../features/home/section_placeholder_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/lessons/lessons_page.dart';
import '../features/people/people_page.dart';
import '../features/people/person_detail_page.dart';
import '../features/settings/settings_page.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../shared/widgets/not_found_page.dart';
import '../shared/widgets/page_transition.dart';
import 'role_sections.dart';

final apiService = ApiService();

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

const String adminHome = '/dashboard';

const String adminOwnPage = '/profile';

// One landing page per role, the administrator's being the shell behind /dashboard. Must mirror RoleService.ROLES_WITH_UI on the server.
const Map<String, String> homeByRole = <String, String>{
  'ADMIN': adminHome,
  'TEACHER': '/teacher',
  'PARENT': '/parent',
  'STUDENT': '/student',
};

// Psychologists and course participants have no area yet and land here.
const String unavailableHome = '/area-non-disponibile';

// Walked through once, right after the forced password change.
const String onboardingRoute = '/primo-accesso';

String homeForRole(String? role) => homeByRole[role] ?? unavailableHome;

bool canSwitchTo(String role) => homeByRole.containsKey(role);

// Single-role areas; the administrator's home is excluded, being the entrance to the shell.
final Set<String> _roleOnlyHomes = <String>{
  for (final entry in homeByRole.entries)
    if (entry.value != adminHome) entry.value,
  unavailableHome,
  onboardingRoute,
};

bool _isUnder(String path, String home) => path == home || path.startsWith('$home/');

// The role a page belongs to, read off its path: a role's area lies under
// its home, everything else with a bar is the administrator's shell. Null
// for the pages that belong to no role, like the one a role without an
// area lands on.
String? roleOfPath(String path)
{
  if (path.isEmpty || path == unavailableHome || path == onboardingRoute)
  {
    return null;
  }

  for (final entry in homeByRole.entries)
  {
    if (entry.value != adminHome && _isUnder(path, entry.value))
    {
      return entry.key;
    }
  }

  return 'ADMIN';
}

// A role reaches its own area and nothing else; the administrator reaches
// everything but the role areas.
bool _isReachable(String path, String home)
{
  if (home != adminHome)
  {
    return _isUnder(path, home);
  }

  return !_roleOnlyHomes.any((other) => _isUnder(path, other));
}

Page<void> _buildPage(GoRouterState state, Widget child)
{
  return buildAppTransitionPage(key: state.pageKey, child: child);
}

StatefulShellBranch _destination(String path, Widget page, {List<RouteBase> routes = const []})
{
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: page),
        routes: routes,
      ),
    ],
  );
}

// A role's area: its home and every section its bar can lead to, kept alive
// side by side like the administrator's modules. Sections a given person
// does not see (a pupil's payments) exist all the same; the bar just leaves
// them out.
StatefulShellRoute _roleArea(String role)
{
  final String home = homeByRole[role]!;

  return StatefulShellRoute(
    navigatorContainerBuilder: (context, navigationShell, children) => ShellDestinations(
      currentIndex: navigationShell.currentIndex,
      children: children,
    ),
    pageBuilder: (context, state, navigationShell) => _buildPage(state, navigationShell),
    branches: [
      _destination(home, RoleHomePage(role: role)),
      for (final section in allSectionsOf(role))
        _destination('$home/${section.slug}', RoleSectionPage(role: role, section: section)),
    ],
  );
}

final appRouter = GoRouter(
  initialLocation: adminHome,
  navigatorKey: _rootNavigatorKey,
  // The identity carries the active role: a switch must re-run the redirect like a session change.
  refreshListenable: Listenable.merge([apiService.authState, apiService.identity]),
  errorBuilder: (context, state) => NotFoundPage(
    requestedLocation: state.uri.toString(),
  ),
  redirect: (context, state)
  {
    final authState = apiService.authState.value;
    final path = state.uri.path;

    // Authenticated by the token in the URL, not the session: reachable in any authState.
    if (path == '/reset-password')
    {
      return null;
    }

    final isPublicRoute = path == '/login';

    if (authState == AuthState.unauthenticated)
    {
      if (isPublicRoute)
      {
        return null;
      }

      return '/login';
    }

    if (authState == AuthState.passwordChangeRequired)
    {
      if (path == '/force-password-change')
      {
        return null;
      }

      return '/force-password-change';
    }

    if (authState == AuthState.authenticated)
    {
      // The first access owns the whole app until it is walked through.
      if (apiService.lastKnownIdentity?.onboardingRequired ?? false)
      {
        return path == onboardingRoute ? null : onboardingRoute;
      }

      final home = homeForRole(apiService.lastKnownIdentity?.activeRole);

      if (isPublicRoute || path == '/' || path == '/force-password-change')
      {
        return home;
      }

      return _isReachable(path, home) ? null : home;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _buildPage(state, const LoginPage()),
    ),
    GoRoute(
      path: '/force-password-change',
      pageBuilder: (context, state) => _buildPage(state, const ForcePasswordChangePage()),
    ),
    GoRoute(
      path: '/reset-password',
      pageBuilder: (context, state)
      {
        final token = state.uri.queryParameters['token'];

        if (token == null || token.isEmpty)
        {
          return _buildPage(state, const LoginPage());
        }

        return _buildPage(state, ResetPasswordPage(token: token));
      },
    ),
    _roleArea('TEACHER'),
    _roleArea('PARENT'),
    _roleArea('STUDENT'),
    GoRoute(
      path: onboardingRoute,
      pageBuilder: (context, state) => _buildPage(state, const OnboardingPage()),
    ),
    GoRoute(
      path: unavailableHome,
      pageBuilder: (context, state) => _buildPage(state, const RoleUnavailablePage()),
    ),
    StatefulShellRoute(
      navigatorContainerBuilder: (context, navigationShell, children) => ShellDestinations(
        currentIndex: navigationShell.currentIndex,
        children: children,
      ),
      pageBuilder: (context, state, navigationShell) => _buildPage(state, navigationShell),
      branches: [
        _destination(adminHome, const DashboardPage()),
        _destination('/association', const AssociationPage()),
        _destination('/lessons', const LessonsPage()),
        _destination(
          '/people',
          const PeoplePage(),
          routes: [
            GoRoute(
              path: ':fiscalCode',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state)
              {
                final fiscalCode = state.pathParameters['fiscalCode']!;

                return _buildPage(
                  state,
                  PersonDetailPage(
                    fiscalCode: fiscalCode,
                    origin: state.uri.queryParameters['from'],
                  ),
                );
              },
            ),
          ],
        ),
        _destination(adminOwnPage, const AdminOwnPage()),
        _destination('/settings', const SettingsPage()),
      ],
    ),
  ],
);
