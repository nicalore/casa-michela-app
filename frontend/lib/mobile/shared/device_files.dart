import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('it.casamichela.app/files');

const String kPdfMimeType = 'application/pdf';

// False when the user backs out of the save dialog; PlatformException if the write fails.
Future<bool> saveToDevice(Uint8List bytes, {required String fileName, String mimeType = kPdfMimeType}) async
{
  final bool? saved = await _channel.invokeMethod<bool>('saveFile', {
    'bytes': bytes,
    'fileName': fileName,
    'mimeType': mimeType,
  });

  return saved ?? false;
}
