import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000',
    ),
  );

  Future<Map<String, dynamic>> getHealth() async {
    final response = await _dio.get('/health');

    return response.data;
  }
}
