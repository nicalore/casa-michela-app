import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/layout/dense_text_scale.dart';
import 'core/platform/app_platform.dart';
import 'core/platform/visual_effects.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/splash_bridge.dart';
import 'features/auth/reset_link.dart';
import 'features/notifications/device_notifications.dart';
import 'features/notifications/notification_board.dart';
import 'features/notifications/widgets/notification_toast.dart';
import 'mobile/features/notifications/mobile_notification_destinations.dart';
import 'mobile/mobile_app.dart';
import 'routing/app_router.dart';
import 'routing/dialog_history_guard.dart';
import 'routing/notification_destinations.dart';
import 'services/api_service.dart';
import 'services/seen_tours.dart';
import 'shared/widgets/dialog_components.dart';

void main() async 
{
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts bundled in assets/fonts: an unbundled weight fails at startup, not by reflowing later.
  GoogleFonts.config.allowRuntimeFetching = false;

  if (kIsWeb)
  {
    WebResetLink.capture();
  }

  usePathUrlStrategy();
  await ApiService().restoreSession();

  if (AppPlatform.isNativeMobile)
  {
    SeenTours.mobile.follow();
    NotificationBoard.instance.follow = followMobileNotification;
    DeviceNotifications.follow();

    // Edge to edge on every Android version, as iOS always is.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    runApp(const MobileApp());

    return;
  }

  if (kIsWeb)
  {
    DialogHistoryGuard.install(appRouter);
  }

  SeenTours.desktop.follow();
  NotificationBoard.instance.follow = followNotification;
  DeviceNotifications.follow();

  await VisualEffects.load();

  runApp(const CasaMichelaApp());

  WidgetsBinding.instance.addPostFrameCallback((_) 
  {
    Future.delayed(const Duration(milliseconds: 250), hideInitialSplash);
  });
}

class CasaMichelaApp extends StatelessWidget 
{
  const CasaMichelaApp({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return MaterialApp.router(
      title: 'Associazione Casa Michela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) 
      {
        return DenseTextScale(
          child: _ScrollTooltipDismisser(
            child: Theme(
              data: Theme.of(context).copyWith(
                tooltipTheme: Theme.of(context).tooltipTheme.copyWith(
                  exitDuration: Duration.zero,
                ),
              ),
              child: VisualEffects.scope(
                // Over every page and dialog, outside what dialogs blur behind them.
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(key: dialogBackdropKey, child: child!),
                    const NotificationToastLayer(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScrollTooltipDismisser extends StatelessWidget 
{
  final Widget child;

  const _ScrollTooltipDismisser({required this.child});

  @override
  Widget build(BuildContext context) 
  {
    return Listener(
      onPointerSignal: (event) 
      {
        if (event is PointerScrollEvent) 
        {
          Tooltip.dismissAllToolTips();
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) 
        {
          Tooltip.dismissAllToolTips();
          return false;
        },
        child: child,
      ),
    );
  }
}