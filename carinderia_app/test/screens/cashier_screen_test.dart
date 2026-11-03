import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carinderia_app/models/order.dart';
import 'package:carinderia_app/screens/cashier_screen.dart';
import 'package:carinderia_app/services/api_service.dart';
import 'package:carinderia_app/services/signalr_service.dart';

class FakeApiService extends Fake implements ApiService {
  List<Order> pendingOrders = [];
  bool confirmPaymentResult = true;

  int fetchCallCount = 0;
  int confirmCallCount = 0;
  int? confirmedOrderId;

  Completer<List<Order>>? fetchCompleter;

  @override
  Future<List<Order>> getPendingPaymentOrders() {
    fetchCallCount++;

    if (fetchCompleter != null) {
      return fetchCompleter!.future;
    }

    return Future.value(pendingOrders);
  }

  @override
  Future<bool> confirmPayment(int orderId) async {
    confirmCallCount++;
    confirmedOrderId = orderId;

    return confirmPaymentResult;
  }
}

class FakeSignalRService extends Fake implements SignalRService {
  Function(List<Object?>?)? onOrderUpdate;

  int connectCallCount = 0;
  int joinKitchenCallCount = 0;
  int disconnectCallCount = 0;

  @override
  Future<void> connect(
    String baseUrl, {
    required Function(List<Object?>?) onOrderUpdate,
  }) async {
    connectCallCount++;
    this.onOrderUpdate = onOrderUpdate;
  }

  @override
  Future<void> joinKitchen() async {
    joinKitchenCallCount++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
  }

  void simulateOrderUpdate() {
    onOrderUpdate?.call(null);
  }
}

Order createTestOrder({
  int id = 1,
  int tableNumber = 1,
  double totalAmount = 150,
  String menuItemName = 'Fried Chicken',
  int quantity = 2,
}) {
  return Order(
    id: id,
    tableNumber: tableNumber,
    totalAmount: totalAmount,
    items: [
      OrderItem(
        id: 1,
        menuItemName: menuItemName,
        quantity: quantity,
        specialInstruction: '',
      ),
    ],
    status: 'PendingPayment',
    paymentMethod: 1,
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget createTestWidget({
  required FakeApiService apiService,
  required FakeSignalRService signalRService,
}) {
  return MaterialApp(
    home: CashierScreen(apiService: apiService, signalRService: signalRService),
  );
}

void main() {
  group('CashierScreen Widget Tests', () {
    late FakeApiService apiService;
    late FakeSignalRService signalRService;

    setUp(() {
      apiService = FakeApiService();
      signalRService = FakeSignalRService();
    });

    testWidgets('Displays initial UI and empty state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cashier - Pending QR Payments'), findsOneWidget);

      expect(find.text('No pending QR payments to verify.'), findsOneWidget);

      expect(apiService.fetchCallCount, 1);
      expect(signalRService.connectCallCount, 1);
      expect(signalRService.joinKitchenCallCount, 1);
    });

    testWidgets('Displays loading indicator while fetching orders', (
      tester,
    ) async {
      apiService.fetchCompleter = Completer<List<Order>>();

      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      apiService.fetchCompleter!.complete([]);

      await tester.pumpAndSettle();

      expect(find.text('No pending QR payments to verify.'), findsOneWidget);
    });

    testWidgets('Displays pending payment orders', (tester) async {
      apiService.pendingOrders = [
        createTestOrder(
          id: 10,
          tableNumber: 3,
          totalAmount: 250,
          menuItemName: 'Fried Chicken',
          quantity: 2,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Table #3'), findsOneWidget);
      expect(find.text('#10'), findsOneWidget);
      expect(find.text('2x Fried Chicken'), findsOneWidget);
      expect(find.text('₱250.00'), findsOneWidget);
      expect(find.text('Confirm Payment'), findsOneWidget);
    });

    testWidgets('Refreshes orders when a SignalR notification is received', (
      tester,
    ) async {
      apiService.pendingOrders = [createTestOrder(id: 10)];

      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('#10'), findsOneWidget);
      expect(apiService.fetchCallCount, 1);

      apiService.pendingOrders = [createTestOrder(id: 20, tableNumber: 5)];

      signalRService.simulateOrderUpdate();

      await tester.pumpAndSettle();

      expect(apiService.fetchCallCount, 2);
      expect(find.text('#20'), findsOneWidget);
      expect(find.text('Table #5'), findsOneWidget);
      expect(find.text('#10'), findsNothing);
    });

    testWidgets('Confirms payment successfully', (tester) async {
      apiService.pendingOrders = [createTestOrder(id: 15)];

      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();

      expect(apiService.confirmCallCount, 1);
      expect(apiService.confirmedOrderId, 15);

      expect(
        find.text('Payment confirmed! Order sent to kitchen board.'),
        findsOneWidget,
      );

      expect(apiService.fetchCallCount, 2);
    });

    testWidgets('Displays error when payment confirmation fails', (
      tester,
    ) async {
      apiService.pendingOrders = [createTestOrder(id: 15)];
      apiService.confirmPaymentResult = false;

      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();

      expect(apiService.confirmCallCount, 1);
      expect(apiService.confirmedOrderId, 15);

      expect(find.text('Failed to confirm payment.'), findsOneWidget);

      expect(apiService.fetchCallCount, 1);
    });

    testWidgets('Manually refreshes pending orders', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pumpAndSettle();

      expect(apiService.fetchCallCount, 1);

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();

      expect(apiService.fetchCallCount, 2);
    });

    testWidgets('Disconnects SignalR when screen is disposed', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          apiService: apiService,
          signalRService: signalRService,
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      await tester.pumpAndSettle();

      expect(signalRService.disconnectCallCount, 1);
    });
  });
}
