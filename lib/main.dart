// lib/main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'firebase_options.dart'; 
import 'router/app_router.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Gerekli servislerin ön yüklemesi
  try {
    // Dotenv ve Firebase başlatma
    await dotenv.load(fileName: ".env");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // KRİTİK: SharedPreferences'ı GoRouter redirect'ten önce başlatıyoruz
    await SharedPreferences.getInstance(); 
    print('✅ SharedPreferences initialized');
    
  } catch (e) {
    print('❌ Initial service loading failed: $e');
  }

  runApp(const SketchMindApp());
}

class SketchMindApp extends StatelessWidget {
  const SketchMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GoRouter kullandığımız için MaterialApp.router kullanılır.
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