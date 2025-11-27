import 'package:dio/dio.dart';
import '../models/item.dart';

class ApiClient {
  // GANTI <PROJECT_ID> dengan projectId Firebase kamu
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

  Future<void> deleteItem(String id) async {
    await _dio.delete('/items/$id');
  }
}