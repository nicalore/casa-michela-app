import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/models/me_response.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import 'features/auth/mobile_force_password_page.dart';
import 'features/auth/mobile_reset_password_page.dart';
import 'features/auth/mobile_sign_in_handover.dart';
import 'features/onboarding/mobile_onboarding_page.dart';
import 'layout/mobile_orientation_policy.dart';
import 'layout/mobile_rotation_veil.dart';
import 'shared/mobile_links.dart';
import 'shared/widgets/mobile_background.dart';
import 'shared/widgets/mobile_entrance_motion.dart';
import 'shared/widgets/mobile_load_switcher.dart';

// Past this the page comes in with its wheel rather than keep the button spinning.
const Duration _holdCap = Duration(seconds: 3);

// Scaffolds stay transparent over one backdrop that outlives the pages.
class MobileApp extends StatefulWidget
{
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp>
{
  static final ThemeData _theme = AppTheme.light.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
  );

  // Started before the app's navigator exists, so links reach it first.
  final MobileLinkListener _links = MobileLinkListener();

  @override
  void initState()
  {
    super.initState();
    _links.start();
  }

  @override
  void dispose()
  {
    _links.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileOrientationPolicy(
      child: MaterialApp(
        title: 'Associazione Casa Michela',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        builder: (context, child) => MobileBackground(child: MobileRotationVeil(child: child)),
        // An app link names a site route; the gate reads it itself.
        onGenerateInitialRoutes: (_) => [_entrance()],
        onGenerateRoute: (_) => _entrance(),
      ),
    );
  }
}

Route<void> _entrance() => MaterialPageRoute<void>(builder: (_) => const _AuthGate());

enum _Entrance { waiting, signIn, reset, passwordChange, firstAccess, home }

// No router yet, so the entrance is swapped in place; a reset link wins over the session.
class _AuthGate extends StatelessWidget
{
  const _AuthGate();

  @override
  Widget build(BuildContext context)
  {
    final ApiService api = ApiService();

    return ListenableBuilder(
      listenable: Listenable.merge([api.authState, api.identity, MobileResetLink.token]),
      builder: (context, _)
      {
        final String? token = MobileResetLink.token.value;
        final MeResponse? identity = api.identity.value;

        final _Entrance entrance = token != null
            ? _Entrance.reset
            : switch (api.authState.value)
              {
                AuthState.loading => _Entrance.waiting,
                AuthState.unauthenticated => _Entrance.signIn,
                AuthState.passwordChangeRequired => _Entrance.passwordChange,
                AuthState.authenticated =>
                  identity?.onboardingRequired ?? false ? _Entrance.firstAccess : _Entrance.home,
              };

        final Widget page = switch (entrance)
        {
          _Entrance.waiting => const Scaffold(),
          _Entrance.signIn => const MobileSignInHandover(signedIn: false),
          _Entrance.reset => MobileResetPasswordPage(token: token!),
          _Entrance.passwordChange => const MobileForcePasswordPage(),
          _Entrance.firstAccess => const MobileOnboardingPage(),
          _Entrance.home => const MobileSignInHandover(signedIn: true),
        };

        // One key for sign-in and home: the handover morphs between them itself.
        final Key key = switch (entrance)
        {
          _Entrance.reset => ValueKey(token),
          _Entrance.signIn || _Entrance.home => const ValueKey('signInHandover'),
          _ => ValueKey(entrance),
        };

        return _EntranceSwitcher(
          pageKey: key,
          page: page,
          placeholder: entrance == _Entrance.waiting,
        );
      },
    );
  }
}

class _EntranceSwitcher extends StatefulWidget
{
  final Key pageKey;
  final Widget page;

  // The first real page replaces a placeholder without moving.
  final bool placeholder;

  const _EntranceSwitcher({required this.pageKey, required this.page, required this.placeholder});

  @override
  State<_EntranceSwitcher> createState() => _EntranceSwitcherState();
}

class _EntranceSwitcherState extends State<_EntranceSwitcher> with SingleTickerProviderStateMixin
{
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: kMobileEntranceDuration,
    value: 1,
  )..addStatusListener(_onStatus);

  Key? _leavingKey;
  Widget? _leaving;

  final ValueNotifier<int> _holds = ValueNotifier<int>(0);

  // The arriving page built out of sight until it has its data.
  bool _waiting = false;
  Timer? _cap;

  // Replacing the launch placeholder: once loaded, the page simply appears.
  bool _cut = false;

  // Opening straight onto a page: the system's launch screen stays up until it has its data.
  bool _deferring = false;

  @override
  void initState()
  {
    super.initState();

    if (widget.placeholder)
    {
      return;
    }

    _cut = true;
    _waiting = true;
    _motion.value = 0;
    _deferring = true;
    WidgetsBinding.instance.deferFirstFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWhenLoaded());
  }

  @override
  void didUpdateWidget(_EntranceSwitcher oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.pageKey == oldWidget.pageKey)
    {
      return;
    }

    _stopWaiting();

    // Returning to the page still leaving: no motion.
    if (widget.pageKey == _leavingKey)
    {
      _leavingKey = null;
      _leaving = null;
      _motion.value = 1;
      _allowFirstFrame();

      return;
    }

    // The keyboard would cover the buttons coming in.
    FocusManager.instance.primaryFocus?.unfocus();

    _leavingKey = oldWidget.pageKey;
    _leaving = oldWidget.page;
    // A page never drawn is not seen leaving either.
    _cut = oldWidget.placeholder || _deferring;
    _motion.value = 0;
    _waiting = true;

    // After the arriving page's first build, when its pages have asked to be waited for.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWhenLoaded());
  }

  @override
  void dispose()
  {
    _stopWaiting();
    _allowFirstFrame();
    _holds.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _allowFirstFrame()
  {
    if (_deferring)
    {
      _deferring = false;
      WidgetsBinding.instance.allowFirstFrame();
    }
  }

  void _startWhenLoaded()
  {
    if (!mounted || !_waiting)
    {
      return;
    }

    if (_holds.value == 0)
    {
      _start();

      return;
    }

    _holds.addListener(_onHolds);
    _cap = Timer(_holdCap, _start);
  }

  void _onHolds()
  {
    if (_holds.value == 0)
    {
      _start();
    }
  }

  void _stopWaiting()
  {
    _waiting = false;
    _holds.removeListener(_onHolds);
    _cap?.cancel();
    _cap = null;
  }

  void _start()
  {
    if (!mounted || !_waiting)
    {
      return;
    }

    if (_cut)
    {
      setState(()
      {
        _stopWaiting();
        _leavingKey = null;
        _leaving = null;
      });
      _motion.value = 1;
      _allowFirstFrame();

      return;
    }

    setState(_stopWaiting);
    _motion.forward(from: 0);
    _allowFirstFrame();
  }

  // The start comes from didUpdateWidget, which builds anyway.
  void _onStatus(AnimationStatus status)
  {
    if (status.isCompleted)
    {
      setState(()
      {
        _leavingKey = null;
        _leaving = null;
      });
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool moving = _motion.isAnimating;
    final Key? leavingKey = _leavingKey;
    final Widget? leaving = _leaving;

    return MobileHoldScope(
      holds: _holds,
      waiting: _waiting,
      child: IgnorePointer(
        ignoring: moving || _waiting,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (leavingKey != null && leaving != null)
              KeyedSubtree(
                key: leavingKey,
                child: MobileEntranceMotion(
                  progress: _motion,
                  leaving: true,
                  moving: moving,
                  waiting: _waiting,
                  child: leaving,
                ),
              ),
            KeyedSubtree(
              key: widget.pageKey,
              child: MobileEntranceMotion(
                progress: _motion,
                leaving: false,
                moving: moving,
                waiting: _waiting,
                child: widget.page,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
