// lib/data/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Mevcut kullanıcının ID'sini döndürür. Yoksa Anonim giriş yapar.
  Future<String> getCurrentUserId() async {
    // 1. Mevcut bir oturum var mı kontrol et
    User? user = _auth.currentUser;

    if (user != null) {
      // Mevcut kullanıcı ID'sini döndür
      return user.uid;
    } else {
      // 2. Oturum yoksa, anonim olarak giriş yap
      return await signInAnonymously();
    }
  }

  // Anonim olarak giriş yapar ve kullanıcı ID'sini döndürür
  Future<String> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      // Başarılı girişten sonra kullanıcı ID'sini döndür
      return userCredential.user!.uid;
    } on FirebaseAuthException catch (e) {
      print("Anonim giriş hatası: ${e.code}");
      // Hata durumunda boş string döndürülebilir veya hata fırlatılabilir
      throw Exception('Anonim oturum açılamadı: ${e.message}');
    }
  }
}