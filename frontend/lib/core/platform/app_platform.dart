import 'package:flutter/foundation.dart';

abstract final class AppPlatform
{
  // Browsers keep the desktop UI on any device, hence kIsWeb first.
  static bool get isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
