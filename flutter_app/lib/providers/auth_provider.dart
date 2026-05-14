// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorageService _storageService = SecureStorageService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize authentication (check if token exists)
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      if (token != null) {
        _apiService.setToken(token);
        // Verify token is still valid
        final result = await _apiService.verifyToken();
        _user = User.fromJson(result['user']);
        _isAuthenticated = true;
      }
    } catch (e) {
      print('Initialization error: $e');
      await logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with username and password
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.login(username, password);

      if (result['token'] != null) {
        final token = result['token'];
        _user = User.fromJson(result['user']);

        // Save token securely
        await _storageService.saveToken(token);
        _apiService.setToken(token);

        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw 'No token received';
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh authentication token
  Future<bool> refreshToken() async {
    try {
      final newToken = await _apiService.refreshToken();
      await _storageService.saveToken(newToken);
      _apiService.setToken(newToken);
      return true;
    } catch (e) {
      print('Token refresh failed: $e');
      await logout();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _storageService.deleteToken();
    await _storageService.deleteUserData();
    _apiService.clearToken();

    _user = null;
    _isAuthenticated = false;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
