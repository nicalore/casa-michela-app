import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/platform/app_platform.dart';
import '../core/utils/browser_tablet_flag.dart';
import '../mobile/layout/mobile_breakpoints.dart';

// Value of the X-Client-Form-Factor header sent with a sign-in or a refresh,
// which the server prefers to the user agent. Null leaves it to the server: a
// browser that is not a tablet reads fine off its agent, and a native view
// has no size before its first frame.
String? clientFormFactor()
{
  if (kIsWeb)
  {
    return browserReportsTablet() ? 'tablet' : null;
  }

  if (!AppPlatform.isNativeMobile)
  {
    return 'desktop';
  }

  final view = WidgetsBinding.instance.platformDispatcher.implicitView;

  if (view == null || view.physicalSize.isEmpty)
  {
    return null;
  }

  final factor = MobileBreakpoints.fromShortestSide(
    view.physicalSize.shortestSide / view.devicePixelRatio,
  );

  return factor.isTablet ? 'tablet' : 'phone';
}
