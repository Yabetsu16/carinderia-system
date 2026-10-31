import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final ApiService _apiService = ApiService();
  late SignalRService _signalRService;
  List<Order> _pendingOrders = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchPendingOrders();
    _initSignalR();

    // 3. Start a periodic timer to automatically refresh pending payments every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchPendingOrders(isBackgroundRefresh: true);
    });
  }

  @override
  void dispose() {
    // 4. Always cancel the timer and disconnect SignalR to prevent memory leaks
    _pollingTimer?.cancel();
    _signalRService.disconnect();
    super.dispose();
  }

  Future<void> _initSignalR() async {
    _signalRService = SignalRService();

    // Connect and bind the listener simultaneously before the handshake finishes
    await _signalRService.connect(
      ApiService.serverRootUrl,
      onOrderUpdate: (arguments) {
        debugPrint(
          "SignalR RAW callback fired on CashierScreen! Arguments: $arguments",
        );
        if (mounted) {
          _fetchPendingOrders(
            isBackgroundRefresh: true,
          ); // Instantly refresh UI when broadcast hits
        }
      },
    );

    // Join the Kitchen group so that new orders/updates broadcast to the cashier screen too
    await _signalRService.joinKitchen();
  }

  Future<void> _fetchPendingOrders({bool isBackgroundRefresh = false}) async {
    if (!isBackgroundRefresh) {
      setState(() => _isLoading = true);
    }

    final orders = await _apiService.getPendingPaymentOrders();
    if (!mounted) return;

    setState(() {
      _pendingOrders = orders;
      _isLoading = false;
    });
  }

  Future<void> _handleConfirmPayment(int orderId) async {
    bool success = await _apiService.confirmPayment(orderId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmed! Order sent to kitchen board.'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchPendingOrders(); // Refresh list immediately after action
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to confirm payment.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier - Pending QR Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchPendingOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingOrders.isEmpty
          ? const Center(
              child: Text(
                'No pending QR payments to verify.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 350,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _pendingOrders.length,
                itemBuilder: (context, index) {
                  final order = _pendingOrders[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Table & Order ID badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(
                                  'Table #${order.tableNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.orange.shade100,
                              ),
                              Text(
                                '#${order.id}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          // Items list inside the order card
                          Expanded(
                            child: ListView.builder(
                              itemCount: order.items.length,
                              itemBuilder: (context, itemIndex) {
                                final item = order.items[itemIndex];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.quantity}x ${item.menuItemName}',
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const Divider(height: 20),

                          // Total Amount and Action Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '₱${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _handleConfirmPayment(order.id),
                              icon: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Confirm Payment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
