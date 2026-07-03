import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/association/association_page.dart';
import '../features/auth/force_password_change_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/people/people_page.dart';
import '../features/people/person_detail_page.dart';
import '../features/people/person_wizard_page.dart';
import '../features/settings/settings_page.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../shared/widgets/casa_michela_loader.dart';
import '../shared/widgets/not_found_page.dart';

final apiService = ApiService();

CustomTransitionPage _buildLogoTransitionPage({
  required LocalKey key,
  required Widget child,
})
{
  return CustomTransitionPage(
    key: key,
    child: child,
    opaque: false,
    transitionDuration: const Duration(milliseconds: 1200),
    transitionsBuilder: (context, animation, secondaryAnimation, child)
    {
      final overlayAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 35,
        ),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 35,
        ),
      ]).animate(animation);

      final pageOpacity = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      ]).animate(animation);

      return AnimatedBuilder(
        animation: overlayAnimation,
        builder: (context, _)
        {
          final double blurIntensity = overlayAnimation.value * 20.0;
          final double backgroundOpacity = overlayAnimation.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: pageOpacity,
                child: child,
              ),
              if (overlayAnimation.value > 0)
                AbsorbPointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurIntensity > 0.1 ? blurIntensity : 0.1,
                          sigmaY: blurIntensity > 0.1 ? blurIntensity : 0.1,
                        ),
                        child: Container(
                          color: Colors.white.withValues(
                            alpha: backgroundOpacity,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: overlayAnimation.value,
                        child: const CasaMichelaLoader(isOverlay: false),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  refreshListenable: apiService.authState,
  errorBuilder: (context, state) => NotFoundPage(
    requestedLocation: state.uri.toString(),
  ),
  redirect: (context, state)
  {
    final authState = apiService.authState.value;
    final path = state.uri.path;

    final isPublicRoute = path == '/login' || path == '/reset-password';

    if (authState == AuthState.unauthenticated)
    {
      if (isPublicRoute)
      {
        return null;
      }

      return '/login';
    }

    // Account con reset password obbligatorio pendente: bloccato ovunque
    // tranne che sulla pagina dedicata, a prescindere da come si è arrivati
    // in questo stato (login appena fatto, resume di sessione, refresh token).
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
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const DashboardPage(),
      ),
    ),
    GoRoute(
      path: '/association',
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const AssociationPage(),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const SettingsPage(),
      ),
    ),
    GoRoute(
      path: '/force-password-change',
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const ForcePasswordChangePage(),
      ),
    ),
    GoRoute(
      path: '/reset-password',
      pageBuilder: (context, state)
      {
        final token = state.uri.queryParameters['token'];

        if (token == null || token.isEmpty)
        {
          return _buildLogoTransitionPage(
            key: state.pageKey,
            child: const LoginPage(),
          );
        }

        return _buildLogoTransitionPage(
          key: state.pageKey,
          child: ResetPasswordPage(token: token),
        );
      },
    ),
    GoRoute(
      path: '/people',
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const PeoplePage(),
      ),
    ),
    GoRoute(
      path: '/people/new',
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const PersonWizardPage(),
      ),
    ),
    GoRoute(
      path: '/people/:fiscalCode',
      pageBuilder: (context, state)
      {
        final fiscalCode = state.pathParameters['fiscalCode']!;

        return _buildLogoTransitionPage(
          key: state.pageKey,
          child: PersonDetailPage(fiscalCode: fiscalCode),
        );
      },
    ),
  ],
);