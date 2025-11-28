import 'package:dio/dio.dart';
import '../models/item.dart';
import '../models/sale.dart';

class ApiClient {
  static const String baseUrl =
      'http://localhost:5001/umkm-inventory/asia-southeast2/api';

  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));

  Future<List<Item>> getItems() async {
    final response = await _dio.get('/items');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Item> createItem(Item item) async {
    final response = await _dio.post('/items', data: item.toJson());
    return Item.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Item> updateItem(Item item) async {
    final response = await _dio.put(
      '/items/${item.id}',
      data: item.toJson(),
    );
    return Item.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Sale>> getSales() async {
  final response = await _dio.get('/sales');
  final List data = response.data['data'] ?? [];
  return data
      .map((e) => Sale.fromJson(Map<String, dynamic>.from(e)))
      .toList();
  }

  Future<bool> createSale({
  required String itemId,
  required int quantity,
  }) async {
  final res = await _dio.post('/sales', data: {
    "itemId": itemId,
    "quantity": quantity
  });

  return res.statusCode == 201 || res.data['success'] == true;
  }

  Future<bool> createSaleFromItems(
    List<Map<String, dynamic>> itemsPayload) async {
  final res = await _dio.post('/sales', data: {
    'items': itemsPayload,
  });

  return res.statusCode == 201 || res.data['success'] == true;
  }

  Future<void> deleteItem(String id) async {
    await _dio.delete('/items/$id');
  }
}