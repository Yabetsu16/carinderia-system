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
    required int tableNumber, // <--- Accept tableNumber here
    required int paymentMethod,
    required List<CreateOrderItem> items,
  }) async {
    try {
      // baseUrl is 'http://localhost:5113/api', so this targets 'http://localhost:5113/api/1/order'
      final url = Uri.parse(
        '${baseUrl.replaceAll('/api', '')}/api/$tableNumber/order',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'paymentMethod': paymentMethod,
          'items': items
              .map((item) => item.toJson())
              .toList(), // Note: no tableNumber in body anymore
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
      final response = await http.get(Uri.parse('$baseUrl/order'));
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

  Future<bool> updateOrderStatus(int orderId, int newStatusInt) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/order/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatusInt}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  Future<bool> archiveOrder(int orderId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/order/$orderId/archive'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error archiving order: $e');
      return false;
    }
  }

  Future<List<Order>> getOrderHistory() async {
    try {
      // Pass includeCompleted=true to fetch history
      final response = await http.get(
        Uri.parse('$baseUrl/order?includeCompleted=true'),
      );
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body
            .map((dynamic item) => Order.fromJson(item))
            .where((o) => o.status == 'Completed')
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  // Fetch orders specifically waiting for payment confirmation
  Future<List<Order>> getPendingPaymentOrders() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/order?status=0'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((json) => Order.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching pending payments: $e');
    }
    return [];
  }

  // Confirm QR payment (changes status from PendingPayment -> Preparing)
  Future<bool> confirmPayment(int orderId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/order/$orderId/confirm-payment'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error confirming payment: $e');
      return false;
    }
  }
}
