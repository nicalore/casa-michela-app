import 'browser_tablet_flag_stub.dart' if (dart.library.js_interop) 'browser_tablet_flag_web.dart';

// Contract with index.html's tablet check: iPadOS Safari poses as a Mac, so only the page knows.
bool browserReportsTablet() => browserReportsTabletImpl();
