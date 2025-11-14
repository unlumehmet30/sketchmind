// lib/data/services/local_user_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LocalUserService {
  static const _keySelectedUserId = 'selectedUserId';
  static const _keyUserDatabase = 'userDatabase';
  static const _defaultUserId = 'default_local_profile';

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, String>> _getUserDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyUserDatabase) ?? '{}';
    try {
        return Map<String, String>.from(jsonDecode(jsonString));
    } catch (_) {
        return {};
    }
  }

  Future<void> _saveUserDatabase(Map<String, String> db) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserDatabase, jsonEncode(db));
  }
  
  Future<bool> registerUser(String username, String password) async {
    final db = await _getUserDatabase();
    if (db.containsKey(username)) {
      return false;
    }
    db[username] = _hashPassword(password);
    await _saveUserDatabase(db);
    await setSelectedUserId(username); 
    return true;
  }

  Future<bool> loginUser(String username, String password) async {
    final db = await _getUserDatabase();
    final hashedPassword = _hashPassword(password);
    
    if (db[username] == hashedPassword) {
      await setSelectedUserId(username);
      return true;
    }
    return false;
  }

  // YENİ/GÜNCEL: Kayıtlı tüm kullanıcı adlarını döndürür
  Future<List<String>> getAllRegisteredUsernames() async {
    final db = await _getUserDatabase();
    return db.keys.toList();
  }
  
  Future<String> getSelectedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedUserId) ?? _defaultUserId;
  }

  Future<void> setSelectedUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedUserId, userId);
  }

  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedUserId); 
  }

  static String get defaultUserId => _defaultUserId;
}