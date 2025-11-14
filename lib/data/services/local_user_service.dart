// lib/data/services/local_user_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LocalUserService {
  static const _keySelectedUserId = 'selectedUserId';
  static const _keyUserDatabase = 'userDatabase'; 
  static const _registeredUsersKey = 'registeredUsernamesList'; 
  static const _userAvatarPrefix = 'userAvatar_'; 
  static const _defaultUserId = 'misafir_user'; 

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // --- Veritabanı Yöneticisi ---
  Future<Map<String, String>> _getUserDatabase() async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(_keyUserDatabase) ?? '{}';
    try {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
        return {};
    }
  }

  Future<void> _saveUserDatabase(Map<String, String> db) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyUserDatabase, jsonEncode(db));
  }
  
  // --- KRİTİK KONTROL METOTLARI ---

  // Kayıtlı tüm kullanıcı adlarını döndürür
  Future<List<String>> getAllRegisteredUsernames() async {
    final prefs = await _getPrefs();
    final List<String> usernames = prefs.getStringList(_registeredUsersKey) ?? [];
    return usernames.where((name) => name != _defaultUserId).toList();
  }
  
  // EKLENDİ: Hiç kayıtlı kullanıcı var mı kontrol eder (Hata çözen metot)
  Future<bool> anyUserRegistered() async {
    final users = await getAllRegisteredUsernames();
    return users.isNotEmpty;
  }
  
  // --- KAYIT VE GİRİŞ İŞLEMLERİ ---

  Future<bool> registerUser(String username, String password) async {
    final db = await _getUserDatabase();
    if (db.containsKey(username)) {
      return false; 
    }
    
    db[username] = _hashPassword(password);
    await _saveUserDatabase(db);
    
    final prefs = await _getPrefs();
    List<String> registeredUsers = prefs.getStringList(_registeredUsersKey) ?? [];
    
    if (!registeredUsers.contains(username)) {
      registeredUsers.add(username);
      await prefs.setStringList(_registeredUsersKey, registeredUsers);
    }
    
    await setSelectedUserId(username);
    return true;
  }

  Future<bool> loginUser(String username, String password) async {
    final db = await _getUserDatabase();
    final hashedPassword = _hashPassword(password);
    
    if (db[username] == hashedPassword) {
      return true;
    }
    return false;
  }

  // --- OTURUM VE AVATAR YÖNETİMİ ---

  Future<String> getSelectedUserId() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keySelectedUserId) ?? _defaultUserId;
  }

  Future<void> setSelectedUserId(String userId) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keySelectedUserId, userId);
  }

  Future<void> logoutUser() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keySelectedUserId);
  }

  Future<void> setSelectedUserAvatar(String userId, String avatarUrl) async {
    if (userId.isEmpty || userId == _defaultUserId || avatarUrl.isEmpty) return;
    
    final prefs = await _getPrefs();
    final key = '$_userAvatarPrefix$userId';
    await prefs.setString(key, avatarUrl);
  }

  Future<String?> getSelectedUserAvatar(String userId) async {
    if (userId == _defaultUserId) return null;
    
    final prefs = await _getPrefs();
    final key = '$_userAvatarPrefix$userId';
    return prefs.getString(key);
  }

  static String get defaultUserId => _defaultUserId;
}