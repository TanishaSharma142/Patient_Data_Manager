// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/patient.dart';

class ApiService {
  static String get _baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Dev fallback only — used when no --dart-define is passed (e.g. flutter run locally)
    return 'http://localhost:3001/api';
  }

  static final ApiService _instance = ApiService._internal();

  String? _token;
  final _client = http.Client();

  ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ─── Centralised error handler for all API calls ─────────────────────────
  Future<T> _safeApiCall<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } on http.ClientException catch (_) {
      // Network errors (DNS, refused, timeout, etc.)
      throw 'No internet connection. Please check your network and try again.';
    } on SocketException catch (_) {
      // Additional network error detection (mobile/desktop)
      throw 'No internet connection. Please check your network and try again.';
    } catch (e, stackTrace) {
      // Log the real error for debugging (replace print with your logger)
      print('Unexpected API error: $e\n$stackTrace');
      // User sees only a generic, safe message
      throw 'Something went wrong. Please try again later.';
    }
  }

  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['error'] ?? body['message'] ?? 'Server error ${response.statusCode}';
    } catch (_) {
      return 'Server error ${response.statusCode}';
    }
  }

  // ==================== Authentication ====================

  Future<Map<String, dynamic>> login(String username, String password) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers(),
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final token = data['token'];
          if (token is! String || token.isEmpty) {
            throw const FormatException();
          }
          final userMap = data['user'];
          if (userMap is! Map<String, dynamic>) {
            throw const FormatException();
          }
          _token = token;
          return {
            'success': true,
            'token': token,
            'user': userMap,
          };
        } catch (_) {
          throw 'Unable to sign in. Please try again.';
        }
      }
      throw _extractError(response);
    });
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/change-password'),
        headers: _headers(),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return;
      }

      throw _extractError(response);
    });
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    return _safeApiCall(() async {
      final response = await _client.get(
        Uri.parse('$_baseUrl/users'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['data'];
        if (raw is List) {
          return List<Map<String, dynamic>>.from(raw);
        }
        throw 'Unexpected user list response';
      }

      throw _extractError(response);
    });
  }

  Future<Map<String, dynamic>> createUser(String username, String email, String role) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/users'),
        headers: _headers(),
        body: jsonEncode({
          'username': username,
          'email': email,
          'role': role,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw _extractError(response);
    });
  }

  Future<Map<String, dynamic>> resetUserPassword(String userId) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/users/$userId/reset-password'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw _extractError(response);
    });
  }

  Future<void> deleteUser(String userId) async {
    return _safeApiCall(() async {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return;
      }

      throw _extractError(response);
    });
  }

  Future<Map<String, dynamic>> setBackupEmail(String backupEmail) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/users/backup-email/set'),
        headers: _headers(),
        body: jsonEncode({'backupEmail': backupEmail}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw _extractError(response);
    });
  }

  Future<Map<String, dynamic>> verifyBackupEmail(String verificationCode) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/users/backup-email/verify'),
        headers: _headers(),
        body: jsonEncode({'verificationCode': verificationCode}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw _extractError(response);
    });
  }

  Future<Map<String, dynamic>> verifyToken() async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/verify'),
        headers: _headers(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw _extractError(response);
    });
  }

  Future<String> refreshToken() async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return data['token'];
      }
      throw _extractError(response);
    });
  }

  // ==================== Patients ====================

  Future<List<Patient>> getAllPatients() async {
    return _safeApiCall(() async {
      final response = await _client.get(
        Uri.parse('$_baseUrl/patients'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'] ?? data['patients'] ?? [];
        return (raw as List).map((p) => Patient.fromJson(p)).toList();
      }

      if (response.statusCode == 401) throw 'Session expired — please login again';
      throw _extractError(response);
    });
  }

  Future<Patient> getPatientById(String id) async {
    return _safeApiCall(() async {
      final response = await _client.get(
        Uri.parse('$_baseUrl/patients/$id'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final patientJson = data['data'] ?? data;
        return Patient.fromJson(patientJson);
      }

      if (response.statusCode == 404) throw 'Patient not found';
      if (response.statusCode == 401) throw 'Session expired — please login again';
      throw _extractError(response);
    });
  }

  Future<Patient> createPatient(Map<String, dynamic> patientData) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/patients'),
        headers: _headers(),
        body: jsonEncode(patientData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Patient.fromJson(data['data'] ?? data);
      }

      if (response.statusCode == 403) throw 'Permission denied — only owners/secretaries can add patients';
      throw _extractError(response);
    });
  }

  Future<Patient> updatePatient(String id, Map<String, dynamic> updates) async {
    return _safeApiCall(() async {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/patients/$id'),
        headers: _headers(),
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Patient.fromJson(data['data'] ?? data);
      }

      if (response.statusCode == 403) throw 'Permission denied';
      if (response.statusCode == 404) throw 'Patient not found';
      throw _extractError(response);
    });
  }

  Future<void> deletePatient(String id) async {
    return _safeApiCall(() async {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/patients/$id'),
        headers: _headers(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw _extractError(response);
      }
    });
  }

  Future<Patient> addBankEntry(String patientId, String entryDate, String amount) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/patients/$patientId/bank-entries'),
        headers: _headers(),
        body: jsonEncode({'entryDate': entryDate, 'amount': amount}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Patient.fromJson(data['data'] ?? data);
      }

      if (response.statusCode == 400) throw _extractError(response);
      if (response.statusCode == 403) throw 'Permission denied — only accountant and owner can add bank entries';
      if (response.statusCode == 404) throw 'Patient not found';
      throw _extractError(response);
    });
  }

  // ==================== Panic Wipe ====================

  Future<Map<String, dynamic>> checkPanicWipeStatus() async {
    return _safeApiCall(() async {
      final response = await _client.get(
        Uri.parse('$_baseUrl/panic-wipe/status'),
        headers: _headers(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw _extractError(response);
    });
  }

  Future<Map<String, dynamic>> executePanicWipe(String panicPin) async {
    return _safeApiCall(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/panic-wipe/execute'),
        headers: _headers(),
        body: jsonEncode({'panicPin': panicPin}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      if (response.statusCode == 403) throw 'Invalid panic PIN';
      throw _extractError(response);
    });
  }

  // ==================== Audit ====================

  Future<List<dynamic>> getAllAuditLogs({int limit = 200, int offset = 0}) async {
    return _safeApiCall(() async {
      final response = await _client.get(
        Uri.parse('$_baseUrl/audit/logs?limit=$limit&offset=$offset'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['logs'] ?? data['data'] ?? [];
      }
      throw _extractError(response);
    });
  }

  Future<List<dynamic>> getMyActivity({int limit = 50, int offset = 0}) async {
    return _safeApiCall(() async {
      final response = await _client.get(
        Uri.parse('$_baseUrl/audit/my-activity?limit=$limit&offset=$offset'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['logs'] ?? data['data'] ?? [];
      }
      throw _extractError(response);
    });
  }
}