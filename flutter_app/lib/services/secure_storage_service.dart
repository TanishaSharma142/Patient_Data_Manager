// lib/services/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  final _storage = const FlutterSecureStorage();

  // ==================== Token ====================

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ==================== User Data ====================

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: _userKey, value: userData.toString());
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: _userKey);
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: _userKey);
  }

  // ==================== Cleanup ====================

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
