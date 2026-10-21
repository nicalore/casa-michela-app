// The token travels after '#', which browsers never send to a server or its logs;
// links mailed before that still carry it as ?token=.
String? resetTokenOf(Uri? uri)
{
  if (uri == null || uri.path != '/reset-password')
  {
    return null;
  }

  final String? token =
      Uri.splitQueryString(uri.fragment)['token'] ?? uri.queryParameters['token'];

  return token == null || token.isEmpty ? null : token;
}

// The web routes drop the '#' part, so the address is read once, before the router starts.
abstract final class WebResetLink
{
  static String? atStart;

  static void capture()
  {
    atStart = resetTokenOf(Uri.base);
  }
}
