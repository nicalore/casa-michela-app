import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/splash_bridge.dart';
import 'routing/app_router.dart';
import 'services/api_service.dart';

void main() async 
{
  WidgetsFlutterBinding.ensureInitialized();
  
  usePathUrlStrategy();
  await ApiService().restoreSession();

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
        return _ScrollTooltipDismisser(
          child: Theme(
            data: Theme.of(context).copyWith(
              tooltipTheme: Theme.of(context).tooltipTheme.copyWith(
                exitDuration: Duration.zero,
              ),
            ),
            child: child!,
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