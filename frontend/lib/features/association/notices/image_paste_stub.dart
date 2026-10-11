import 'package:flutter/foundation.dart';

import 'image_paste.dart';

// Only browsers paste images: the editor is a desktop one.
VoidCallback listenForPastedImagesImpl({
  required bool Function() active,
  required int maxSide,
  required PastedImageHandler onImage,
  required VoidCallback onUnreadable,
}) => () {};
