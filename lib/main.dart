import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/infoservice_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error inicializando Firebase: $e');
  }
  runApp(const InfoserviceApp());
}
