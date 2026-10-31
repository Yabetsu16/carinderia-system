import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import '../widgets/order_card.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final ApiService _apiService = ApiService();
  late SignalRService _signalRService;
  List<Order> _orders = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _initSignalR();

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchOrders(isBackgroundRefresh: true);
    });
  }

  @override
  void dispose() {
    // 4. Always cancel the timer and disconnect SignalR when leaving the screen to prevent memory leaks
    _pollingTimer?.cancel();
    _signalRService.disconnect();
    super.dispose();
  }

  Future<void> _initSignalR() async {
    _signalRService = SignalRService();

    await _signalRService.connect(
      ApiService.serverRootUrl,
      onOrderUpdate: (arguments) {
        debugPrint("SignalR RAW callback fired! Arguments: $arguments");
        if (mounted) {
          _fetchOrders();
        }
      },
    );
  }

  Future<void> _fetchOrders({bool isBackgroundRefresh = false}) async {
    final orders = await _apiService.getActiveKitchenOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      if (!isBackgroundRefresh) {
        _isLoading = false;
      }
    });
  }

  Future<void> _handleStatusChanged(int orderId, String newStatus) async {
    if (newStatus == 'Archived') {
      bool success = await _apiService.archiveOrder(orderId);
      if (success) {
        _fetchOrders();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order archived successfully.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to archive order.')),
        );
      }
      return;
    }

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
      _fetchOrders();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update order status.')),
      );
    }
  }

  void _showArchivedOrdersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archived Orders'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: FutureBuilder<List<Order>>(
            future: _apiService.getOrderHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No archived orders found.');
              }

              final archivedOrders = snapshot.data!;
              return ListView.builder(
                itemCount: archivedOrders.length,
                itemBuilder: (context, index) {
                  final order = archivedOrders[index];
                  return ListTile(
                    leading: const Icon(Icons.archive, color: Colors.grey),
                    title: Text(
                      'Order #${order.id} - Table #${order.tableNumber}',
                    ),
                    subtitle: Text(
                      'Items: ${order.items.length} | Status: ${order.status}',
                    ),
                    trailing: Text(
                      order.createdAt.toLocal().toString().substring(11, 16),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archived Orders',
            onPressed: () => _showArchivedOrdersDialog(context),
          ),
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
