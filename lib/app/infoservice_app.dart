import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../screens/admin_dashboard.dart';

class InfoserviceApp extends StatefulWidget {
  const InfoserviceApp({super.key});

  @override
  State<InfoserviceApp> createState() => _InfoserviceAppState();
}

class _InfoserviceAppState extends State<InfoserviceApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infoservice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: kIsWeb ? const AdminDashboard() : const SplashScreen(),
    );
  }
}
