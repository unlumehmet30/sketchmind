// lib/data/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> getCurrentUserOrNull() async {
    return _auth.currentUser;
  }

  Future<String?> getCurrentUserIdOrNull() async {
    return _auth.currentUser?.uid;
  }

  // Mevcut kullanıcının ID'sini döndürür. Yoksa anonim giriş açar.
  Future<String> getCurrentUserId() async {
    final user = _auth.currentUser;
    if (user != null) {
      return user.uid;
    }
    return signInAnonymously();
  }

  // Anonim olarak giriş yapar ve kullanıcı ID'sini döndürür
  Future<String> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      // Başarılı girişten sonra kullanıcı ID'sini döndür
      return userCredential.user!.uid;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint("Anonim giris hatasi: ${e.code}");
      debugPrint('Anonim giris stack trace: $stackTrace');
      throw Exception('Anonim oturum açılamadı. Lütfen tekrar deneyin.');
    }
  }

  Future<String> ensureSignedInAnonymously() async {
    return getCurrentUserId();
  }
}
