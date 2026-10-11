import 'weak_graphics_stub.dart' if (dart.library.js_interop) 'weak_graphics_web.dart';

// Signs before the first frame that this machine cannot keep up with the effects.
bool hasWeakGraphics() => hasWeakGraphicsImpl();
