import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

// The engine's own resize samples without filtering, so the browser shrinks faces.
Future<ui.Image> shrinkProfilePhotoImpl(Uint8List bytes, int? side) async
{
  final web.Blob blob = web.Blob(<JSAny>[bytes.toJS].toJS);
  web.ImageBitmap bitmap = await web.window.createImageBitmap(blob).toDart;

  if (side == null || side < 1)
  {
    return ui_web.createImageFromImageBitmap(bitmap);
  }

  // The centre square BoxFit.cover shows, so the face is drawn one to one with no half-pixel crop.
  final int square = math.min(bitmap.width, bitmap.height);

  bitmap = await _replace(
    bitmap,
    web.window.createImageBitmap(
      bitmap,
      ((bitmap.width - square) ~/ 2).toJS,
      (bitmap.height - square) ~/ 2,
      square,
      square,
    ),
  );

  // One resize to side x 2^n (enlarged when smaller: always drawn one to one), then halvings
  // that average exact 2x2 blocks; one long step samples too few pixels and leaves grain.
  int target = side;

  while (target * 2 <= bitmap.width)
  {
    target *= 2;
  }

  if (bitmap.width != target)
  {
    bitmap = await _resize(bitmap, target, 'high');
  }

  while (bitmap.width > side)
  {
    bitmap = await _resize(bitmap, bitmap.width ~/ 2, 'low');
  }

  return ui_web.createImageFromImageBitmap(bitmap);
}

Future<web.ImageBitmap> _resize(web.ImageBitmap bitmap, int side, String quality)
{
  return _replace(
    bitmap,
    web.window.createImageBitmap(
      bitmap,
      web.ImageBitmapOptions(resizeWidth: side, resizeHeight: side, resizeQuality: quality),
    ),
  );
}

Future<web.ImageBitmap> _replace(web.ImageBitmap old, JSPromise<web.ImageBitmap> next) async
{
  final web.ImageBitmap result = await next.toDart;

  old.close();

  return result;
}
