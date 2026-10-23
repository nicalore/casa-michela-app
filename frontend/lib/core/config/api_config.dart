import 'package:flutter/foundation.dart';

abstract final class ApiConfig
{
  // Native release builds need --dart-define=API_BASE_URL; the browser uses its own origin.
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _productionBaseUrl = '/api';

  // Store reviewers' accounts live on the demo server, with fictitious people only.
  static const String _demoBaseUrl = String.fromEnvironment(
    'DEMO_API_BASE_URL',
    defaultValue: 'https://dev.app.casamichela.it/api',
  );

  static const String _demoUsernamePrefix = 'demo.';

  // Set while a demo account is signed in; the browser always talks to its own origin.
  static bool demo = false;

  static bool isDemoUsername(String username)
  {
    return !kIsWeb && username.trim().toLowerCase().startsWith(_demoUsernamePrefix);
  }

  // The Android emulator reaches the host on 10.0.2.2; iOS simulator and browser share its loopback.
  static String get _developmentBaseUrl =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

  static String get baseUrl
  {
    if (demo)
    {
      return _demoBaseUrl;
    }

    if (_definedBaseUrl.isNotEmpty)
    {
      return _definedBaseUrl;
    }

    // Relative URLs resolve only in a browser; native keeps the dev host to fail on request, not at startup.
    if (!kIsWeb)
    {
      return _developmentBaseUrl;
    }

    return kDebugMode ? _developmentBaseUrl : _productionBaseUrl;
  }

  static String buildUrl(String path) => '$baseUrl$path';
}
