import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

// The engine's own resize samples without filtering; the browser's 'high' one averages like the phones.
Future<ui.Image> shrinkProfilePhotoImpl(Uint8List bytes, int? side) async
{
  final web.Blob blob = web.Blob(<JSAny>[bytes.toJS].toJS);
  final web.ImageBitmap full = await web.window.createImageBitmap(blob).toDart;

  // Enlarged too when smaller, so it is always drawn one to one (see ProfilePhotoImage.filterQuality).
  final double scale = side == null ? 1 : side / math.min(full.width, full.height);

  if (scale == 1)
  {
    return ui_web.createImageFromImageBitmap(full);
  }

  final web.ImageBitmap small = await web.window.createImageBitmap(
    full,
    web.ImageBitmapOptions(
      resizeWidth: math.max(1, (full.width * scale).round()),
      resizeHeight: math.max(1, (full.height * scale).round()),
      resizeQuality: 'high',
    ),
  ).toDart;

  full.close();

  return ui_web.createImageFromImageBitmap(small);
}
