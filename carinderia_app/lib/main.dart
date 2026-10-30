import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // Add this import

import 'screens/cashier_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/kitchen_screen.dart';

void main() {
  usePathUrlStrategy(); // Cleans up the URL (removes #/)
  runApp(const CarinderiaApp());
}

class CarinderiaApp extends StatelessWidget {
  const CarinderiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carinderia Management System',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const MenuScreen(),
        '/kitchen': (context) => const KitchenScreen(),
        '/cashier': (context) => const CashierScreen(),
      },
    );
  }
}
