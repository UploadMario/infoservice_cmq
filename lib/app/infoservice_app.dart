import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/products/presentation/products_screen.dart';

class InfoserviceApp extends StatelessWidget {
  const InfoserviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infoservice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
      routes: {'/products': (context) => const ProductsScreen()},
    );
  }
}
