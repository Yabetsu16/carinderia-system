import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/order_card.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final ApiService _apiService = ApiService();
  List<Order> _orders = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Poll every 10 seconds for real-time kitchen updates from MS SQL
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchOrders(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    final orders = await _apiService.getActiveKitchenOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  Future<void> _handleStatusChanged(int orderId, String newStatus) async {
    int statusInt = 0;

    if (newStatus == 'Preparing') {
      statusInt = 1;
    } else if (newStatus == 'Ready') {
      statusInt = 2;
    } else if (newStatus == 'Completed') {
      statusInt = 3;
    }

    bool success = await _apiService.updateOrderStatus(orderId, statusInt);

    if (success) {
      _fetchOrders(); // Refresh list immediately
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update order status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchOrders),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(
              child: Text(
                'No active orders in the kitchen.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 300,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  return OrderCard(
                    order: _orders[index],
                    onStatusChanged: _handleStatusChanged,
                  );
                },
              ),
            ),
    );
  }
}
