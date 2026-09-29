import 'splash_bridge_stub.dart' if (dart.library.js_interop) 'splash_bridge_web.dart';

// Contract with index.html: fades #splash-overlay once the first frame is painted.
void hideInitialSplash() => hideInitialSplashImpl();
