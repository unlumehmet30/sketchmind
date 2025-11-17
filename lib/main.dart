// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) .env'i önce yükle — uygulama başında erişilecek tüm env değişkenleri için gerekli
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env loaded');
  } catch (e) {
    print('❌ .env load failed: $e');
    // İsterseniz burada uygulamayı durdurabilirsiniz:
    // return;
  }

  // 2) Firebase'i başlat
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  runApp(const SketchMindApp());
}

class SketchMindApp extends StatelessWidget {
  const SketchMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SketchMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      routerConfig: router,
    );
  }
}
