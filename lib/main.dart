// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';

// Splash ve Home ekranları
import "../presentation/home/splah_screen.dart";
import "../presentation/home/home_view_model.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ .env dosyasını yükle
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Dotenv loaded');
  } catch (e) {
    print('❌ Dotenv loading failed: $e');
  }

  // 2️⃣ Firebase'i başlat
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

// 🔹 GoRouter yapılandırması
final GoRouter router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    // İleride ekleyeceğin diğer sayfalar
  ],
);

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
