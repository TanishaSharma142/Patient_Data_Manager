// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';

class ApiService {
  // BUG 1 FIXED: use the current page host so the web app works over localhost and network IP.
  static String get _baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
    final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
    return '$scheme://$host:3001/api';
  }

  // Use the environment override when deploying to a different backend.
  // Example: flutter build web --dart-define=API_BASE_URL=https://my-api.example.com/api
  // If you need a specific local IP on mobile or another machine, set API_BASE_URL too.

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

  // ─── Generic error extractor ─────────────────────────────────────────────
  // BUG 2 FIXED: previously all catch blocks re-wrapped the error in a new
  // string, so the real server message was buried. Now we extract it properly.
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
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers(),
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Safely extract token
          final token = data['token'];
          if (token is! String || token.isEmpty) {
            throw 'Invalid or missing token in response';
          }
          
          // Safely extract user object
          final userMap = data['user'];
          if (userMap is! Map<String, dynamic>) {
            throw 'Invalid or missing user data in response';
          }
          
          // Store token
          _token = token;
          
          // Return response with validated data
          return {
            'success': true,
            'token': token,
            'user': userMap,
          };
        } catch (e) {
          throw 'Failed to parse login response: $e';
        }
      }
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> verifyToken() async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/verify'),
        headers: _headers(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<String> refreshToken() async {
    try {
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
    } catch (e) {
      throw e.toString();
    }
  }

  // ==================== Patients ====================

  Future<List<Patient>> getAllPatients() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/patients'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // BUG 3 FIXED: backend returns data under 'data' key, but if
        // the response shape ever changes to 'patients' this handles both.
        final raw = data['data'] ?? data['patients'] ?? [];
        return (raw as List).map((p) => Patient.fromJson(p)).toList();
      }

      if (response.statusCode == 401) throw 'Session expired — please login again';
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Patient> getPatientById(String id) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/patients/$id'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // BUG 4 FIXED: same as above — handle both 'data' and direct object
        final patientJson = data['data'] ?? data;
        return Patient.fromJson(patientJson);
      }

      if (response.statusCode == 404) throw 'Patient not found';
      if (response.statusCode == 401) throw 'Session expired — please login again';
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Patient> createPatient(Map<String, dynamic> patientData) async {
    try {
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
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Patient> updatePatient(String id, Map<String, dynamic> updates) async {
    try {
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
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> deletePatient(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/patients/$id'),
        headers: _headers(),
      );

      // BUG 5 FIXED: some backends return 204 No Content on delete, not 200.
      // Accepting both so delete doesn't falsely fail.
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw _extractError(response);
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Patient> addBankEntry(String patientId, String entryDate, String amount) async {
    try {
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
    } catch (e) {
      throw e.toString();
    }
  }

  // ==================== Panic Wipe ====================

  Future<Map<String, dynamic>> checkPanicWipeStatus() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/panic-wipe/status'),
        headers: _headers(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> executePanicWipe(String panicPin) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/panic-wipe/execute'),
        headers: _headers(),
        body: jsonEncode({'panicPin': panicPin}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      if (response.statusCode == 403) throw 'Invalid panic PIN';
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }

  // ==================== Audit ====================

  // BUG FIXED: audit logs use 'logs' key not 'data' key (matches auditRoutes.ts)
  Future<List<dynamic>> getAllAuditLogs({int limit = 200, int offset = 0}) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/audit/logs?limit=$limit&offset=$offset'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['logs'] ?? data['data'] ?? [];
      }
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<dynamic>> getMyActivity({int limit = 50, int offset = 0}) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/audit/my-activity?limit=$limit&offset=$offset'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['logs'] ?? data['data'] ?? [];
      }
      throw _extractError(response);
    } catch (e) {
      throw e.toString();
    }
  }
}