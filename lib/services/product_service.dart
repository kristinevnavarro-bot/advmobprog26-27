import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/product.dart';

class ProductService {
  Future<List<Product>> getAllProducts() async {
    // limit=0 tells dummyjson to return all products instead of the
    // default page of 30, so items past that page (e.g. iPhone 6) show up.
    final response = await http.get(Uri.parse('$host/products?limit=0'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List productsJson = data['products'] ?? [];
      return productsJson.map((json) => Product.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<Product> getProductById(int productId) async {
    final response = await http.get(Uri.parse('$host/products/$productId'));

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      Map<String, dynamic>? productJson;

      if (data is Map<String, dynamic>) {
        productJson = data.containsKey('product')
            ? Map<String, dynamic>.from(data['product'])
            : data;
      } else if (data is Map) {
        productJson = Map<String, dynamic>.from(data['product'] ?? data);
      }

      if (productJson == null || productJson.isEmpty) {
        throw Exception('Product not found');
      }

      return Product.fromJson(productJson);
    } else {
      throw Exception('Failed to load product $productId');
    }
  }
}