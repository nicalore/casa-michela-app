import 'dart:typed_data';
import 'dart:ui' as ui;

Future<ui.Image> shrinkProfilePhotoImpl(Uint8List bytes, int? side)
{
  throw UnsupportedError('Profile photos are shrunk by the browser only on the web');
}
