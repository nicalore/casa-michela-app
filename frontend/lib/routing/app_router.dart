import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/association/association_page.dart';
import '../features/auth/force_password_change_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/splash_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../shared/widgets/casa_michela_loader.dart';

final apiService = ApiService();

CustomTransitionPage _buildLogoTransitionPage({
  required LocalKey key,
  required Widget   child,
})
{
  return CustomTransitionPage(
    key: key,
    child: child,
    opaque: false,
    transitionDuration: const Duration(milliseconds: 1200),
    transitionsBuilder: (context, animation, secondaryAnimation, child)
    {
      //Animation sequences
      final overlayAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
          weight: 35,
        ),
      ]).animate(animation);

      final pageOpacity = TweenSequence<double>([
        TweenSequenceItem(
          tween: ConstantTween(0.0),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0),
          weight: 10,
        ),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: 50,
        ),
      ]).animate(animation);

      return AnimatedBuilder(
        animation: overlayAnimation,
        builder: (context, _)
        {
          final double blurIntensity     = overlayAnimation.value * 20.0;
          final double backgroundOpacity = overlayAnimation.value * 0.65;

          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: pageOpacity,
                child: child,
              ),
              if (overlayAnimation.value > 0)
                IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurIntensity > 0.1 ? blurIntensity : 0.1,
                          sigmaY: blurIntensity > 0.1 ? blurIntensity : 0.1,
                        ),
                        child: Container(
                          color: Colors.white.withOpacity(backgroundOpacity),
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

//Router configuration
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: apiService.authState,
  redirect: (context, state)
  {
    final authState = apiService.authState.value;
    final location  = state.matchedLocation;

    if (authState == AuthState.loading)
    {
      return location == '/' ? null : '/';
    }

    if (authState == AuthState.unauthenticated)
    {
      if (location == '/' || location == '/login')
      {
        return null;
      }
      return '/login';
    }

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
      pageBuilder: (context, state) => _buildLogoTransitionPage(
        key: state.pageKey,
        child: const SplashPage(),
      ),
    ),
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
      path: '/force-password-change',
      redirect: (context, state)
      {
        if (ApiService.forcePasswordChangeCompleted)
        {
          return '/dashboard';
        }
        return null;
      },
      pageBuilder: (context, state)
      {
        final data = state.extra as Map<String, dynamic>?;

        if (data == null)
        {
          return _buildLogoTransitionPage(
            key: state.pageKey,
            child: const LoginPage(),
          );
        }

        return _buildLogoTransitionPage(
          key: state.pageKey,
          child: ForcePasswordChangePage(
            refreshToken: data['refreshToken'] as String,
            currentPassword: data['currentPassword'] as String,
          ),
        );
      },
    ),
  ],
);
