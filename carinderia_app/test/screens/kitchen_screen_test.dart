import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/order.dart';
import '../../lib/screens/kitchen_screen.dart';
import '../../lib/services/api_service.dart';
import '../../lib/services/signalr_service.dart';

// --------------------------------------------------
// Fake API Service
// --------------------------------------------------

class FakeApiService extends ApiService {
  List<Order> orders = [];
  List<Order> archivedOrders = [];

  Completer<List<Order>>? ordersCompleter;

  int getActiveKitchenOrdersCallCount = 0;
  int getOrderHistoryCallCount = 0;
  int updateOrderStatusCallCount = 0;
  int archiveOrderCallCount = 0;

  int? lastUpdatedOrderId;
  int? lastUpdatedStatus;
  int? lastArchivedOrderId;

  bool updateSuccess = true;
  bool archiveSuccess = true;

  @override
  Future<List<Order>> getActiveKitchenOrders() {
    getActiveKitchenOrdersCallCount++;

    if (ordersCompleter != null) {
      return ordersCompleter!.future;
    }

    return Future.value(List<Order>.from(orders));
  }

  @override
  Future<List<Order>> getOrderHistory() async {
    getOrderHistoryCallCount++;
    return archivedOrders;
  }

  @override
  Future<bool> updateOrderStatus(int orderId, int status) async {
    updateOrderStatusCallCount++;
    lastUpdatedOrderId = orderId;
    lastUpdatedStatus = status;

    if (!updateSuccess) return false;

    final statusNames = {
      0: 'Pending',
      1: 'Preparing',
      2: 'Ready',
      3: 'Completed',
    };

    final index = orders.indexWhere((order) => order.id == orderId);

    if (index != -1 && statusNames.containsKey(status)) {
      final oldOrder = orders[index];

      orders[index] = Order(
        id: oldOrder.id,
        tableNumber: oldOrder.tableNumber,
        paymentMethod: oldOrder.paymentMethod,
        status: statusNames[status]!,
        totalAmount: oldOrder.totalAmount,
        createdAt: oldOrder.createdAt,
        items: oldOrder.items,
      );
    }

    return true;
  }

  @override
  Future<bool> archiveOrder(int orderId) async {
    archiveOrderCallCount++;
    lastArchivedOrderId = orderId;

    if (!archiveSuccess) return false;

    final index = orders.indexWhere((order) => order.id == orderId);

    if (index != -1) {
      archivedOrders.add(orders.removeAt(index));
    }

    return true;
  }
}

// --------------------------------------------------
// Fake SignalR Service
// --------------------------------------------------

class FakeSignalRService extends SignalRService {
  Function(List<Object?>?)? onOrderUpdateCallback;

  int connectCallCount = 0;
  int joinKitchenCallCount = 0;
  int disconnectCallCount = 0;

  @override
  Future<void> connect(
    String baseUrl, {
    required Function(List<Object?>?) onOrderUpdate,
  }) async {
    connectCallCount++;
    onOrderUpdateCallback = onOrderUpdate;
  }

  @override
  Future<void> joinKitchen() async {
    joinKitchenCallCount++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
  }
}

// --------------------------------------------------
// Test Helpers
// --------------------------------------------------

Order createTestOrder({
  int id = 1,
  int tableNumber = 1,
  String status = 'Pending',
}) {
  return Order(
    id: id,
    tableNumber: tableNumber,
    paymentMethod: 0,
    status: status,
    totalAmount: 190,
    createdAt: DateTime(2026, 11, 3, 12, 0),
    items: [
      OrderItem(
        id: 1,
        menuItemName: 'Chicken Adobo',
        quantity: 2,
        specialInstruction: 'No spicy',
      ),
    ],
  );
}

void configureTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget createTestApp({
  required FakeApiService apiService,
  required FakeSignalRService signalRService,
}) {
  return MaterialApp(
    home: KitchenScreen(apiService: apiService, signalRService: signalRService),
  );
}

// --------------------------------------------------
// Kitchen Screen Tests
// --------------------------------------------------

void main() {
  group('KitchenScreen Widget Tests', () {
    late FakeApiService apiService;
    late FakeSignalRService signalRService;

    setUp(() {
      apiService = FakeApiService();
      signalRService = FakeSignalRService();
    });

    testWidgets('Displays the initial Kitchen Screen UI', (tester) async {
      configureTestView(tester);

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kitchen Display System (KDS)'), findsOneWidget);

      expect(find.text('No active orders in the kitchen.'), findsOneWidget);

      expect(apiService.getActiveKitchenOrdersCallCount, 1);
      expect(signalRService.connectCallCount, 1);
      expect(signalRService.joinKitchenCallCount, 1);
    });

    testWidgets('Displays loading indicator while orders are loading', (
      tester,
    ) async {
      configureTestView(tester);

      apiService.ordersCompleter = Completer<List<Order>>();

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      apiService.ordersCompleter!.complete([]);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No active orders in the kitchen.'), findsOneWidget);
    });

    testWidgets('Displays active kitchen orders', (tester) async {
      configureTestView(tester);

      apiService.orders = [
        createTestOrder(id: 10, tableNumber: 1),
        createTestOrder(id: 11, tableNumber: 2, status: 'Preparing'),
      ];

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pumpAndSettle();

      expect(find.text('Table #1'), findsOneWidget);
      expect(find.text('Table #2'), findsOneWidget);

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('PREPARING'), findsOneWidget);

      expect(find.text('2x Chicken Adobo'), findsNWidgets(2));
    });

    testWidgets('Refreshes orders when a SignalR notification is received', (
      tester,
    ) async {
      configureTestView(tester);

      apiService.orders = [createTestOrder(id: 10, tableNumber: 1)];

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pumpAndSettle();

      expect(find.text('Table #1'), findsOneWidget);

      apiService.orders = [
        createTestOrder(id: 20, tableNumber: 3, status: 'Preparing'),
      ];

      signalRService.onOrderUpdateCallback?.call(null);

      await tester.pumpAndSettle();

      expect(apiService.getActiveKitchenOrdersCallCount, 2);
      expect(find.text('Table #1'), findsNothing);
      expect(find.text('Table #3'), findsOneWidget);
      expect(find.text('PREPARING'), findsOneWidget);
    });

    testWidgets('Updates order status when Start Prep is tapped', (
      tester,
    ) async {
      configureTestView(tester);

      apiService.orders = [createTestOrder(id: 25, status: 'Pending')];

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pumpAndSettle();

      expect(find.text('Start Prep'), findsOneWidget);

      await tester.tap(find.text('Start Prep'));
      await tester.pumpAndSettle();

      expect(apiService.updateOrderStatusCallCount, 1);
      expect(apiService.lastUpdatedOrderId, 25);
      expect(apiService.lastUpdatedStatus, 1);

      expect(find.text('PREPARING'), findsOneWidget);
      expect(find.text('Mark Ready'), findsOneWidget);
    });

    testWidgets('Archives a completed order', (tester) async {
      configureTestView(tester);

      apiService.orders = [createTestOrder(id: 30, status: 'Completed')];

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsOneWidget);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(apiService.archiveOrderCallCount, 1);
      expect(apiService.lastArchivedOrderId, 30);

      expect(find.text('No active orders in the kitchen.'), findsOneWidget);
      expect(find.text('Order archived successfully.'), findsOneWidget);
    });

    testWidgets('Manual refresh fetches orders again', (tester) async {
      configureTestView(tester);

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pumpAndSettle();

      expect(apiService.getActiveKitchenOrdersCallCount, 1);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(apiService.getActiveKitchenOrdersCallCount, 2);
    });

    testWidgets('Displays archived orders dialog', (tester) async {
      configureTestView(tester);

      apiService.archivedOrders = [
        createTestOrder(id: 99, tableNumber: 5, status: 'Completed'),
      ];

      await tester.pumpWidget(
        createTestApp(apiService: apiService, signalRService: signalRService),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Archived Orders'));
      await tester.pumpAndSettle();

      expect(find.text('Archived Orders'), findsOneWidget);
      expect(find.text('Order #99 - Table #5'), findsOneWidget);
      expect(apiService.getOrderHistoryCallCount, 1);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Order #99 - Table #5'), findsNothing);
    });
  });
}
