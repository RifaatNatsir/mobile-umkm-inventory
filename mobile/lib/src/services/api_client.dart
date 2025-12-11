import 'package:dio/dio.dart';

import '../models/item.dart';
import '../models/sale.dart';
import '../models/app_user.dart';
import '../models/report_summary.dart';

class ApiClient {
  // Sesuaikan kalau base URL‑nya berubah
  static const String baseUrl =
      'http://localhost:5001/umkm-inventory/asia-southeast2/api';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // ================= ITEMS =================

  Future<List<Item>> getItems() async {
    final res = await _dio.get('/items');
    final List data = res.data['data'] ?? [];
    return data
        .map((e) => Item.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Item> createItem(Map<String, dynamic> data) async {
    final res = await _dio.post('/items', data: data);
    // backend mengembalikan { id: ..., ...dataItem }
    return Item.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<Item> updateItem(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/items/$id', data: data);
    return Item.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<void> deleteItem(String id) async {
    await _dio.delete('/items/$id');
  }

  // ================= SALES =================

  Future<List<Sale>> getSales() async {
    final res = await _dio.get('/sales');
    final List data = res.data['data'] ?? [];
    return data
        .map((e) => Sale.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Kirim transaksi dengan beberapa item (keranjang).
  /// Backend: POST /sales body { items: [ { itemId, quantity }, ... ] }
  /// Response: { success: true, lowStockItems: [...] }
  Future<Map<String, dynamic>> createSale(
      List<Map<String, dynamic>> items) async {
    final res = await _dio.post('/sales', data: {
      'items': items,
    });

    return Map<String, dynamic>.from(res.data);
  }

  /// Alias kalau kamu mau pakai nama lain (opsional).
  Future<Map<String, dynamic>> createSaleFromItems(
      List<Map<String, dynamic>> itemsPayload) async {
    final res = await _dio.post('/sales', data: {
      'items': itemsPayload,
    });

    return Map<String, dynamic>.from(res.data);
  }

  // ================= LOGIN (ROLE) =================

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
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (data is Map && data['message'] != null)
              ? data['message'].toString()
              : 'Login gagal';
      throw Exception(msg);
    }
  }

  // ================= REPORTS =================

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