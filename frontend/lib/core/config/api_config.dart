import 'package:flutter/foundation.dart';

abstract final class ApiConfig
{
  static const String _developmentBaseUrl = 'http://localhost:8000';
  static const String _productionBaseUrl = '/api';

  static String get baseUrl =>
      kDebugMode ? _developmentBaseUrl : _productionBaseUrl;

  static String buildUrl(String path) => '$baseUrl$path';
}