// UTF-8 filename* first, quoted filename as fallback; null when neither is present.

final RegExp _encodedFileName = RegExp(r"filename\*=UTF-8''([^;]+)");
final RegExp _quotedFileName = RegExp(r'filename="([^"]*)"');

String? fileNameOf(String? disposition)
{
  if (disposition == null)
  {
    return null;
  }

  final RegExpMatch? encoded = _encodedFileName.firstMatch(disposition);

  if (encoded != null)
  {
    return Uri.decodeComponent(encoded.group(1)!.trim());
  }

  final String? quoted = _quotedFileName.firstMatch(disposition)?.group(1);

  return quoted == null || quoted.isEmpty ? null : quoted;
}
