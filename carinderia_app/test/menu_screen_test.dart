import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carinderia_app/screens/menu_screen.dart';

void main() {
  testWidgets('MenuScreen displays title and table dropdown', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: MenuScreen()));

    // Verify that the AppBar title is displayed.
    expect(find.text('Karenderya Menu'), findsOneWidget);

    // Verify that the table number dropdown is present.
    expect(find.byType(DropdownButton<int>), findsOneWidget);

    // Verify that the empty cart state message is shown initially.
    expect(find.text('Your cart is empty'), findsOneWidget);
  });
}
