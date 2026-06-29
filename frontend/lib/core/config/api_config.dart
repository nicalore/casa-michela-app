import 'package:flutter/foundation.dart';


class ApiConfig {
  const ApiConfig._();

  static String get baseUrl {
    if (kDebugMode) {
      return 'http://localhost:8000';
    }

    return '/api';
  }

  static String buildUrl(String path) {
    return '$baseUrl$path';
  }
}
