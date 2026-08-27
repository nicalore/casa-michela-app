import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/association/association_page.dart';
import '../features/auth/force_password_change_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/lessons/lessons_page.dart';
import '../features/people/people_page.dart';
import '../features/people/person_detail_page.dart';
import '../features/settings/settings_page.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../shared/widgets/not_found_page.dart';
import '../shared/widgets/page_transition.dart';

final apiService = ApiService();

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

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

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  navigatorKey: _rootNavigatorKey,
  refreshListenable: apiService.authState,
  errorBuilder: (context, state) => NotFoundPage(
    requestedLocation: state.uri.toString(),
  ),
  redirect: (context, state)
  {
    final authState = apiService.authState.value;
    final path = state.uri.path;

    // The reset link is authenticated by the token in the URL, not the session:
    // it must stay reachable regardless of authState, so it is checked first.
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
      if (isPublicRoute || path == '/' || path == '/force-password-change')
      {
        return '/dashboard';
      }
      return null;
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
    StatefulShellRoute(
      navigatorContainerBuilder: (context, navigationShell, children) => ShellDestinations(
        currentIndex: navigationShell.currentIndex,
        children: children,
      ),
      pageBuilder: (context, state, navigationShell) => _buildPage(state, navigationShell),
      branches: [
        _destination('/dashboard', const DashboardPage()),
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

                return _buildPage(state, PersonDetailPage(fiscalCode: fiscalCode));
              },
            ),
          ],
        ),
        _destination('/settings', const SettingsPage()),
      ],
    ),
  ],
);