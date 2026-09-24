import 'browser_tablet_flag_stub.dart' if (dart.library.js_interop) 'browser_tablet_flag_web.dart';

// Contract with index.html, which works out on load whether the browser runs
// on a tablet: iPadOS Safari presents itself as a Mac, so the page's answer is
// the only one worth sending. Native builds have no page and get false.
bool browserReportsTablet() => browserReportsTabletImpl();
