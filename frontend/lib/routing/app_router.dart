import 'package:go_router/go_router.dart';

import '../features/auth/force_password_change_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/splash_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';

final apiService = ApiService();

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: apiService.authState,
  redirect: (context, state)
  {
    final authState = apiService.authState.value;
    final location = state.matchedLocation;

    //Restrict access during session verification
    if (authState == AuthState.loading)
    {
      return location == '/' ? null : '/';
    }

    //Handle unauthenticated state
    if (authState == AuthState.unauthenticated)
    {
      if (location == '/' || location == '/login')
      {
        return null;
      }

      return '/login';
    }

    //Handle authenticated state
    if (authState == AuthState.authenticated)
    {
      if (location == '/' || location == '/login')
      {
        return '/dashboard';
      }

      return null;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/force-password-change',
      redirect: (context, state)
      {
        if (ApiService.forcePasswordChangeCompleted)
        {
          return '/dashboard';
        }

        return null;
      },
      builder: (context, state)
      {
        final data = state.extra as Map<String, dynamic>?;

        //Fallback to login on direct route access
        if (data == null)
        {
          return const LoginPage();
        }

        return ForcePasswordChangePage(
          refreshToken: data['refreshToken'] as String,
          currentPassword: data['currentPassword'] as String,
        );
      },
    ),
  ],
);