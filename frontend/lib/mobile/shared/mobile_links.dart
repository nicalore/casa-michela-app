import 'package:flutter/widgets.dart';

// From the https://<site>/reset-password?token=… app link; held until its page is left.
abstract final class MobileResetLink
{
  static final ValueNotifier<String?> token = ValueNotifier(null);

  static String? tokenOf(Uri? uri)
  {
    if (uri == null || uri.path != '/reset-password')
    {
      return null;
    }

    final String? token = uri.queryParameters['token'];

    return token == null || token.isEmpty ? null : token;
  }
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
    final String? token = MobileResetLink.tokenOf(uri);

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
