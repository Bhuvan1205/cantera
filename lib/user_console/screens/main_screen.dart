import 'package:flutter/material.dart';

import 'app_flow_screen.dart';

/// User-facing shell. Only ever shown to non-admin users,
/// because routing is decided in main.dart before this widget is mounted.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MenuPage();
  }
}
