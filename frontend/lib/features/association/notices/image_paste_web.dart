import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'image_paste.dart';

const String _png = 'image/png';
const String _jpeg = 'image/jpeg';
const double _jpegQuality = 0.85;

// The browser's own paste event: it needs no permission, unlike reading the clipboard.
VoidCallback listenForPastedImagesImpl({
  required bool Function() active,
  required int maxSide,
  required PastedImageHandler onImage,
  required VoidCallback onUnreadable,
})
{
  void handle(web.Event event)
  {
    final web.DataTransfer? data = (event as web.ClipboardEvent).clipboardData;

    if (!active() || data == null)
    {
      return;
    }

    // Office copies text with a picture of it: the text is what was meant.
    if (data.getData('text/plain').trim().isNotEmpty)
    {
      return;
    }

    final web.File? image = _firstImage(data.files);

    if (image == null)
    {
      return;
    }

    event
      ..preventDefault()
      ..stopPropagation();

    _shrunk(image, maxSide).then((shrunk) => onImage(shrunk.$1, shrunk.$2), onError: (Object _) => onUnreadable());
  }

  final web.EventListener listener = handle.toJS;

  web.document.addEventListener('paste', listener, web.AddEventListenerOptions(capture: true));

  return () => web.document.removeEventListener('paste', listener, web.EventListenerOptions(capture: true));
}

web.File? _firstImage(web.FileList files)
{
  for (var i = 0; i < files.length; i++)
  {
    final web.File? file = files.item(i);

    if (file != null && file.type.startsWith('image/'))
    {
      return file;
    }
  }

  return null;
}

Future<Uint8List> _bytesOf(web.Blob blob) async => (await blob.arrayBuffer().toDart).toDart.asUint8List();

// Only what is larger than [maxSide] is redrawn; a screenshot stays a PNG, sharp.
Future<(Uint8List, String)> _shrunk(web.File file, int maxSide) async
{
  final web.ImageBitmap bitmap = await web.window.createImageBitmap(file).toDart;
  final int longest = math.max(bitmap.width, bitmap.height);

  if (longest <= maxSide)
  {
    bitmap.close();

    return (await _bytesOf(file), file.type);
  }

  final double scale = maxSide / longest;
  final String type = file.type == _png ? _png : _jpeg;
  final web.HTMLCanvasElement canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
    ..width = (bitmap.width * scale).round()
    ..height = (bitmap.height * scale).round();

  (canvas.getContext('2d')! as web.CanvasRenderingContext2D)
    ..imageSmoothingQuality = 'high'
    ..drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();

  final Completer<web.Blob?> drawn = Completer();

  canvas.toBlob(((web.Blob? blob) => drawn.complete(blob)).toJS, type, _jpegQuality.toJS);

  final web.Blob? blob = await drawn.future;

  return blob == null ? (await _bytesOf(file), file.type) : (await _bytesOf(blob), type);
}
