import 'package:flutter/material.dart';

import 'screens/menu_screen.dart';

void main() {
  runApp(const CarinderiaApp());
}

class CarinderiaApp extends StatelessWidget {
  const CarinderiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karenderya System',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
