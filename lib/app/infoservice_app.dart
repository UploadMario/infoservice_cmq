import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/splash/presentation/splash_screen.dart';

class InfoserviceApp extends StatefulWidget {
  const InfoserviceApp({super.key});

  @override
  State<InfoserviceApp> createState() => _InfoserviceAppState();
}

class _InfoserviceAppState extends State<InfoserviceApp>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () {
      FirebaseAuth.instance.signOut();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startInactivityTimer();
    } else if (state == AppLifecycleState.paused) {
      _inactivityTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infoservice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
