import 'package:flutter/foundation.dart';

abstract final class ApiConfig
{
  // Native release builds need --dart-define=API_BASE_URL; the browser uses its own origin.
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _productionBaseUrl = '/api';

  // The Android emulator reaches the host on 10.0.2.2; iOS simulator and browser share its loopback.
  static String get _developmentBaseUrl =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

  static String get baseUrl
  {
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
