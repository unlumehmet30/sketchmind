import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // FlutterFire configure ile oluşan dosya
import 'router/app_router.dart'; // YENİ: GoRouter yapılandırması

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase başlatılır
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
    // MaterialApp yerine MaterialApp.router kullanılır
    return MaterialApp.router( 
      title: 'SketchMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      // GoRouter yapılandırması atanır
      routerConfig: router, 
    );
  }
}