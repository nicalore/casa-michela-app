import 'package:flutter/widgets.dart';

import '../../features/auth/reset_link.dart';

// From the https://<site>/reset-password#token=... app link; held until its page is left.
abstract final class MobileResetLink
{
  static final ValueNotifier<String?> token = ValueNotifier(null);
}

// Registered before the navigator, which has no routes and would fail on any link.
class MobileLinkListener with WidgetsBindingObserver
{
  void start()
  {
    WidgetsBinding.instance.addObserver(this);
    _take(Uri.tryParse(WidgetsBinding.instance.platformDispatcher.defaultRouteName));
  }

  void stop()
  {
    WidgetsBinding.instance.removeObserver(this);
  }

  void _take(Uri? uri)
  {
    final String? token = resetTokenOf(uri);

    if (token != null)
    {
      MobileResetLink.token.value = token;
    }
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async
  {
    _take(routeInformation.uri);

    return true;
  }
}
