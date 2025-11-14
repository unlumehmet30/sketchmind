// lib/data/services/local_user_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LocalUserService {
  // Sabit Anahtarlar ve Varsayılan Değerler
  static const _keySelectedUserId = 'selectedUserId';
  static const _keyUserDatabase = 'userDatabase'; 
  static const _registeredUsersKey = 'registeredUsernamesList'; // KRİTİK: Kullanıcı Listesi Anahtarı
  static const _userAvatarPrefix = 'userAvatar_'; 
  static const _defaultUserId = 'default_local_profile';

  // Helper method for SharedPreferences instance
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // --- Veritabanı Yöneticisi (Şifre Hash'i) ---
  Future<Map<String, String>> _getUserDatabase() async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(_keyUserDatabase) ?? '{}';
    try {
        return Map<String, String>.from(jsonDecode(jsonString));
    } catch (_) {
        return {};
    }
  }

  Future<void> _saveUserDatabase(Map<String, String> db) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyUserDatabase, jsonEncode(db));
  }
  
  // --- KAYIT VE GİRİŞ İŞLEMLERİ ---

  Future<bool> registerUser(String username, String password) async {
    final db = await _getUserDatabase();
    if (db.containsKey(username)) {
      return false; 
    }
    
    // Şifre ve veritabanı kaydı
    db[username] = _hashPassword(password);
    await _saveUserDatabase(db);
    
    // KRİTİK DÜZELTME: Kullanıcı adını listeye ekle
    final prefs = await _getPrefs();
    List<String> registeredUsers = prefs.getStringList(_registeredUsersKey) ?? [];
    
    if (!registeredUsers.contains(username)) {
      registeredUsers.add(username);
      // setStringList ile listeyi kaydet
      await prefs.setStringList(_registeredUsersKey, registeredUsers);
    }
    
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

  // HATA ÇÖZÜMÜ: Kayıtlı tüm kullanıcı adlarını döndüren metot
  Future<List<String>> getAllRegisteredUsernames() async {
    final prefs = await _getPrefs();
    // setStringList ile kaydedilen listeyi geri döndürür.
    return prefs.getStringList(_registeredUsersKey) ?? [];
  }
  
  // --- OTURUM YÖNETİMİ ---

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

  // --- AVATAR YÖNETİMİ ---

  Future<void> setSelectedUserAvatar(String userId, String avatarUrl) async {
    if (userId.isEmpty || userId == _defaultUserId || avatarUrl.isEmpty) return;
    
    final prefs = await _getPrefs();
    final key = '$_userAvatarPrefix$userId';
    await prefs.setString(key, avatarUrl);
  }

  Future<String?> getSelectedUserAvatar(String userId) async {
    if (userId.isEmpty || userId == _defaultUserId) return null;
    
    final prefs = await _getPrefs();
    final key = '$_userAvatarPrefix$userId';
    return prefs.getString(key);
  }

  static String get defaultUserId => _defaultUserId;
}