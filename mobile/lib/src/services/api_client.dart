import 'package:dio/dio.dart';

class ApiClient {
  static const String baseUrl =
      'http://localhost:5001/umkm-inventory/asia-southeast2/api';

  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));

  Future<String> healthCheck() async {
    final response = await _dio.get('/health');
    return response.data['message'] ?? 'No message';
  }
}