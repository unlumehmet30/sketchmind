// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // HAFTA 4
import 'firebase_options.dart'; // FlutterFire configure ile oluşan dosya
import 'router/app_router.dart'; // HAFTA 2: GoRouter'ı kullanmak için
import 'data/services/auth_service.dart'; // HAFTA 6: Yeni Auth Servis

final _authService = AuthService(); // Auth servisini başlat

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // HAFTA 4: .env dosyasını yükle
  await dotenv.load(fileName: ".env");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
    
    // HAFTA 6: Uygulama başlamadan önce Anonim Girişi zorunlu kıl
    final userId = await _authService.getCurrentUserId();
    print('✅ User signed in anonymously with ID: $userId');

  } catch (e) {
    print('❌ Firebase initialization failed or Auth failed: $e');
  }

  // GoRouter'ı başlatmak için AppRouter'ı kullanıyoruz.
  runApp(const SketchMindApp());
}

class SketchMindApp extends StatelessWidget {
  const SketchMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GoRouter'ı kullanmak için MaterialApp.router kullanıyoruz.
    return MaterialApp.router(
      title: 'SketchMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      routerConfig: router, // HAFTA 2: Router yapılandırması
    );
  }
}