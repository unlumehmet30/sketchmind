// lib/data/services/local_user_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LocalUserService {
  static const _keySelectedUserId = 'selectedUserId';
  static const _keyUserDatabase = 'userDatabase';
  static const _defaultUserId = 'default_local_profile'; // Giriş yapılmadığını gösterir

  // Şifreyi SHA256 ile hashler
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // Yerel kullanıcı veritabanını (username: hashed_password) çeker
  Future<Map<String, String>> _getUserDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyUserDatabase) ?? '{}';
    // Hata olmadığından emin olmak için try-catch kullanmak iyi bir pratiktir
    try {
        return Map<String, String>.from(jsonDecode(jsonString));
    } catch (_) {
        return {};
    }
  }

  // Kullanıcı veritabanını kaydeder
  Future<void> _saveUserDatabase(Map<String, String> db) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserDatabase, jsonEncode(db));
  }
  
  // Yeni kullanıcı kaydeder (Kayıt Olma)
  Future<bool> registerUser(String username, String password) async {
    final db = await _getUserDatabase();
    if (db.containsKey(username)) {
      return false; // Kullanıcı zaten var
    }
    db[username] = _hashPassword(password);
    await _saveUserDatabase(db);
    // Kayıttan sonra otomatik giriş yap
    await setSelectedUserId(username); 
    return true;
  }

  // Kullanıcı girişi yapar (Giriş Yapma)
  Future<bool> loginUser(String username, String password) async {
    final db = await _getUserDatabase();
    final hashedPassword = _hashPassword(password);
    
    if (db[username] == hashedPassword) {
      await setSelectedUserId(username); // Başarılı girişte ID'yi kaydet
      return true;
    }
    return false;
  }

  // Seçilen yerel kullanıcı ID'sini alır (GoRouter'da kontrol edilir)
  Future<String> getSelectedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedUserId) ?? _defaultUserId;
  }

  // Kullanıcı giriş yaptığında ID'yi kaydeder
  Future<void> setSelectedUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedUserId, userId);
  }

  // Çıkış yap
  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedUserId);
  }

  static String get defaultUserId => _defaultUserId;
}