import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/dialog_components.dart';

// Swallows browser back/forward while a dialog is open, re-pushing the shown page's entry.
// Installed before the router builds: the first observer to answer a history change wins.
class DialogHistoryGuard with WidgetsBindingObserver
{
  final GoRouter router;

  DialogHistoryGuard._(this.router);

  static DialogHistoryGuard install(GoRouter router)
  {
    final DialogHistoryGuard guard = DialogHistoryGuard._(router);

    WidgetsBinding.instance.addObserver(guard);

    return guard;
  }

  void uninstall() => WidgetsBinding.instance.removeObserver(this);

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async
  {
    if (!isBlurredDialogOpen)
    {
      return false;
    }

    // As the router itself reports it, state included, so the entry restores later.
    final RouteInformation? shown = router.routeInformationParser.restoreRouteInformation(
      router.routerDelegate.currentConfiguration,
    );

    if (shown == null)
    {
      return false;
    }

    await SystemNavigator.routeInformationUpdated(
      uri: shown.uri,
      state: shown.state,
      replace: false,
    );

    return true;
  }
}
