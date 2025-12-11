import 'package:dio/dio.dart';
import '../models/item.dart';
import '../models/sale.dart';
import '../models/app_user.dart';
import '../models/report_summary.dart';

class ApiClient {
  static const String baseUrl =
      'http://localhost:5001/umkm-inventory/asia-southeast2/api';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<List<Item>> getItems() async {
    final response = await _dio.get('/items');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Item> createItem(Map<String, dynamic> data) async {
    final resp = await _dio.post('/items', data: data);
    final json = resp.data;

    return Item.fromJson(json); // sesuaikan dengan konstruktor model mu
  }

  Future<Item> updateItem(String id, Map<String, dynamic> data) async {
    final resp = await _dio.put('/items/$id', data: data);
    final json = resp.data;

    return Item.fromJson(json);
  }

  Future<List<Sale>> getSales() async {
  final response = await _dio.get('/sales');
  final List data = response.data['data'] ?? [];
  return data
      .map((e) => Sale.fromJson(Map<String, dynamic>.from(e)))
      .toList();
  }

  Future<Map<String, dynamic>> createSale(List<Map<String, dynamic>> items) async {
    final res = await _dio.post('/sales', data: {
      "items": items,
    });

    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSaleFromItems(
    List<Map<String, dynamic>> itemsPayload) async {
  final res = await _dio.post('/sales', data: {
    'items': itemsPayload,
  });

  return Map<String, dynamic>.from(res.data);
  }

  Future<void> deleteItem(String id) async {
    await _dio.delete('/items/$id');
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/login', data: {
        'email': email,
        'password': password,
      });

      if (res.data['success'] == true && res.data['user'] != null) {
        return AppUser.fromJson(
          Map<String, dynamic>.from(res.data['user']),
        );
      } else {
        throw Exception(res.data['error'] ?? 'Login gagal');
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ??
          e.response?.data['message'] ??
          'Login gagal';
      throw Exception(msg);
    }
  }

  Future<ReportSummary> getReportSummary() async {
    final res = await _dio.get('/reports/summary');
    if (res.data['success'] == true) {
      return ReportSummary.fromJson(
        Map<String, dynamic>.from(res.data),
      );
    } else {
      throw Exception(res.data['error'] ?? 'Gagal memuat laporan');
    }
  }
}