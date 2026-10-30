import 'dart:convert';

import 'package:carinderia_app/models/category.dart';
import 'package:carinderia_app/models/create_order_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../models/order.dart';

class ApiService {
  // Use 'http://localhost:5113' for Windows/macOS desktop or iOS simulator.
  // Use 'http://10.0.2.2:5113' if running on an Android Emulator.
  static const String baseUrl = 'http://localhost:5113/api';

  Future<List<Category>> getActiveMenu() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/menu'));

      if (response.statusCode == 200) {
        Iterable jsonList = json.decode(response.body);
        return jsonList.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load menu: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  Future<bool> placeOrder({
    required int tableNumber,
    required int paymentMethod,
    required List<CreateOrderItem> items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/order'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'tableNumber': tableNumber,
          'paymentMethod': paymentMethod,
          'items': items.map((item) => item.toJson()).toList(),
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error placing order: $e');
      return false;
    }
  }

  Future<List<Order>> getActiveKitchenOrders() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/orders/kitchen'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((dynamic item) => Order.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load kitchen orders');
      }
    } catch (e) {
      debugPrint('Error fetching kitchen orders: $e');
      return [];
    }
  }

  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }
}
