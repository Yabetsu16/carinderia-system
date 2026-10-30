import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';

class PendingPaymentsDialog extends StatefulWidget {
  const PendingPaymentsDialog({super.key});

  @override
  State<PendingPaymentsDialog> createState() => _PendingPaymentsDialogState();
}

class _PendingPaymentsDialogState extends State<PendingPaymentsDialog> {
  final ApiService _apiService = ApiService();
  late Future<List<Order>> _pendingOrdersFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _pendingOrdersFuture = _apiService.getPendingPaymentOrders();
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
      _refreshList();
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
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Pending QR Payments'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshList),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: FutureBuilder<List<Order>>(
          future: _pendingOrdersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No pending QR payments.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            final pendingOrders = snapshot.data!;
            return ListView.builder(
              itemCount: pendingOrders.length,
              itemBuilder: (context, index) {
                final order = pendingOrders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orangeAccent,
                      child: Icon(Icons.qr_code_2, color: Colors.white),
                    ),
                    title: Text(
                      'Table #${order.tableNumber} — Order #${order.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Items: ${order.items.length} | Created: ${order.createdAt.toLocal().toString().substring(11, 16)}',
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () => _handleConfirmPayment(order.id),
                      icon: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Confirm Payment',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
