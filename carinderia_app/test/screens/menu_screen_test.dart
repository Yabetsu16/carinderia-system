import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carinderia_app/models/category.dart';
import 'package:carinderia_app/models/order.dart';
import 'package:carinderia_app/screens/menu_screen.dart';
import 'package:carinderia_app/services/api_service.dart';
import 'package:carinderia_app/services/signalr_service.dart';

// Fake API service
class FakeApiService extends ApiService {
  List<Category> menu = [];
  List<Order> orders = [];

  Completer<List<Category>>? menuCompleter;

  int getActiveMenuCallCount = 0;
  int getTableOrdersCallCount = 0;

  @override
  Future<List<Category>> getActiveMenu() {
    getActiveMenuCallCount++;

    if (menuCompleter != null) {
      return menuCompleter!.future;
    }

    return Future.value(menu);
  }

  @override
  Future<List<Order>> getTableOrders(int tableNumber) async {
    getTableOrdersCallCount++;

    return orders.where((order) => order.tableNumber == tableNumber).toList();
  }
}

// Fake SignalR service
class FakeSignalRService extends SignalRService {
  Function(List<Object?>?)? onOrderUpdateCallback;

  int connectCallCount = 0;
  int joinTableCallCount = 0;

  @override
  Future<void> connect(
    String baseUrl, {
    required Function(List<Object?>?) onOrderUpdate,
  }) async {
    connectCallCount++;
    onOrderUpdateCallback = onOrderUpdate;
  }

  @override
  Future<void> joinTable(int tableNumber) async {
    joinTableCallCount++;
  }

  @override
  Future<void> disconnect() async {}
}

// Helper for creating test orders
Order createTestOrder({
  required int id,
  required int tableNumber,
  required String status,
}) {
  return Order(
    id: id,
    tableNumber: tableNumber,
    paymentMethod: 0,
    status: status,
    totalAmount: 190.0,
    createdAt: DateTime(2026, 11, 3),
    items: [OrderItem(id: id + 100, menuItemName: 'Adobo', quantity: 2)],
  );
}

void configureTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('MenuScreen Widget Tests', () {
    testWidgets('Displays title, table number, and empty cart', (
      WidgetTester tester,
    ) async {
      configureTestView(tester);

      final apiService = FakeApiService();
      final signalRService = FakeSignalRService();

      await tester.pumpWidget(
        MaterialApp(
          home: MenuScreen(
            tableNumber: 1,
            apiService: apiService,
            signalRService: signalRService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Carinderia Menu - Table #1'), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);

      expect(apiService.getActiveMenuCallCount, 1);
      expect(apiService.getTableOrdersCallCount, 1);

      expect(signalRService.connectCallCount, 1);
      expect(signalRService.joinTableCallCount, 1);
    });

    testWidgets('Displays loading indicator while menu is loading', (
      WidgetTester tester,
    ) async {
      configureTestView(tester);

      final apiService = FakeApiService();
      final signalRService = FakeSignalRService();

      apiService.menuCompleter = Completer<List<Category>>();

      await tester.pumpWidget(
        MaterialApp(
          home: MenuScreen(
            tableNumber: 1,
            apiService: apiService,
            signalRService: signalRService,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      apiService.menuCompleter!.complete([]);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Displays active order status after initial orders load', (
      WidgetTester tester,
    ) async {
      configureTestView(tester);

      final apiService = FakeApiService();
      final signalRService = FakeSignalRService();

      apiService.orders = [
        createTestOrder(id: 42, tableNumber: 1, status: 'Preparing'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MenuScreen(
            tableNumber: 1,
            apiService: apiService,
            signalRService: signalRService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Live Order Status'), findsOneWidget);
      expect(find.text('Order #42 (1 items)'), findsOneWidget);
      expect(find.text('👨‍🍳 Preparing in Kitchen'), findsOneWidget);

      expect(apiService.getTableOrdersCallCount, 1);
    });

    testWidgets('Does not display completed orders', (
      WidgetTester tester,
    ) async {
      configureTestView(tester);

      final apiService = FakeApiService();
      final signalRService = FakeSignalRService();

      apiService.orders = [
        createTestOrder(id: 42, tableNumber: 1, status: 'Preparing'),
        createTestOrder(id: 43, tableNumber: 1, status: 'Completed'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MenuScreen(
            tableNumber: 1,
            apiService: apiService,
            signalRService: signalRService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Order #42 (1 items)'), findsOneWidget);
      expect(find.text('Order #43 (1 items)'), findsNothing);

      expect(find.text('Live Order Status'), findsOneWidget);
    });

    testWidgets('Refreshes orders when a SignalR notification is received', (
      WidgetTester tester,
    ) async {
      configureTestView(tester);

      final apiService = FakeApiService();
      final signalRService = FakeSignalRService();

      await tester.pumpWidget(
        MaterialApp(
          home: MenuScreen(
            tableNumber: 1,
            apiService: apiService,
            signalRService: signalRService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial order request
      expect(apiService.getTableOrdersCallCount, 1);
      expect(find.text('Live Order Status'), findsNothing);

      // Simulate a new order becoming available
      apiService.orders = [
        createTestOrder(id: 44, tableNumber: 1, status: 'Ready'),
      ];

      // Simulate SignalR ReceiveOrderUpdate
      signalRService.onOrderUpdateCallback?.call(null);

      await tester.pumpAndSettle();

      // Verify that the screen fetched orders again
      expect(apiService.getTableOrdersCallCount, 2);

      expect(find.text('Order #44 (1 items)'), findsOneWidget);
      expect(find.text('🎉 READY FOR PICKUP!'), findsOneWidget);
    });
  });
}
