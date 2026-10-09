import 'dart:typed_data';

import 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart';

// Any kind of file, saved under its own name; false when nothing was saved.
Future<bool> downloadFile(Uint8List bytes, {required String fileName, required String mimeType}) =>
    downloadFileImpl(bytes, fileName: fileName, mimeType: mimeType);
