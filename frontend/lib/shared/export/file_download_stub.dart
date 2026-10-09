import 'dart:typed_data';

import '../../mobile/shared/device_files.dart';

Future<bool> downloadFileImpl(Uint8List bytes, {required String fileName, required String mimeType}) =>
    saveToDevice(bytes, fileName: fileName, mimeType: mimeType);
