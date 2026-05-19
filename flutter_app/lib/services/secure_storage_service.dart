// lib/services/secure_storage_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// dart:html is only imported on web builds
// ignore: avoid_web_libraries_in_flutter
import 'secure_storage_web.dart' if (dart.library.io) 'secure_storage_stub.dart';

class SecureStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ==================== Token ====================

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      webStorageWrite(_tokenKey, token);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      return webStorageRead(_tokenKey);
    }
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      webStorageDelete(_tokenKey);
    } else {
      await _storage.delete(key: _tokenKey);
    }
  }

  // ==================== User Data ====================

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    // Store as JSON string so it can be read back properly
    final jsonStr = userData.entries
        .map((e) => '"${e.key}":"${e.value}"')
        .join(',');
    final value = '{$jsonStr}';

    if (kIsWeb) {
      webStorageWrite(_userKey, value);
    } else {
      await _storage.write(key: _userKey, value: value);
    }
  }

  Future<String?> getUserData() async {
    if (kIsWeb) {
      return webStorageRead(_userKey);
    }
    return await _storage.read(key: _userKey);
  }

  Future<void> deleteUserData() async {
    if (kIsWeb) {
      webStorageDelete(_userKey);
    } else {
      await _storage.delete(key: _userKey);
    }
  }

  // ==================== Cleanup ====================

  Future<void> clear() async {
    if (kIsWeb) {
      webStorageClear();
    } else {
      await _storage.deleteAll();
    }
  }
}