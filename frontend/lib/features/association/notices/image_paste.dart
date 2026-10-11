import 'package:flutter/foundation.dart';

import 'image_paste_stub.dart' if (dart.library.js_interop) 'image_paste_web.dart';

typedef PastedImageHandler = void Function(Uint8List bytes, String mimeType);

// Images pasted while [active] holds, shrunk to [maxSide]; the result stops listening.
VoidCallback listenForPastedImages({
  required bool Function() active,
  required int maxSide,
  required PastedImageHandler onImage,
  required VoidCallback onUnreadable,
}) => listenForPastedImagesImpl(active: active, maxSide: maxSide, onImage: onImage, onUnreadable: onUnreadable);
