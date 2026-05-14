// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';

class ApiService {
  static const String _baseUrl = 'http://localhost:3000/api';
  static final ApiService _instance = ApiService._internal();
  
  String? _token;
  final _client = http.Client();

  // Private constructor
  ApiService._internal();

  // Factory constructor for singleton
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

  // ==================== Authentication ====================

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers(),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return data;
      } else {
        throw 'Login failed: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Login error: $e';
    }
  }

  Future<Map<String, dynamic>> verifyToken() async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/verify'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw 'Verification failed';
      }
    } catch (e) {
      throw 'Token verification error: $e';
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
      } else {
        throw 'Token refresh failed';
      }
    } catch (e) {
      throw 'Token refresh error: $e';
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
        final patients = (data['data'] as List)
            .map((p) => Patient.fromJson(p))
            .toList();
        return patients;
      } else if (response.statusCode == 401) {
        throw 'Unauthorized - Please login again';
      } else {
        throw 'Failed to fetch patients: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Get patients error: $e';
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
        return Patient.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        throw 'Patient not found';
      } else {
        throw 'Failed to fetch patient: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Get patient error: $e';
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
        return Patient.fromJson(data['data']);
      } else if (response.statusCode == 403) {
        throw 'Permission denied: ${response.body}';
      } else {
        throw 'Failed to create patient: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Create patient error: $e';
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
        return Patient.fromJson(data['data']);
      } else if (response.statusCode == 403) {
        throw 'Permission denied: ${response.body}';
      } else if (response.statusCode == 404) {
        throw 'Patient not found';
      } else {
        throw 'Failed to update patient: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Update patient error: $e';
    }
  }

  Future<void> deletePatient(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/patients/$id'),
        headers: _headers(),
      );

      if (response.statusCode != 200) {
        throw 'Failed to delete patient: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Delete patient error: $e';
    }
  }

  // ==================== Panic Wipe ====================

  Future<Map<String, dynamic>> checkPanicWipeStatus() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/panic-wipe/status'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw 'Failed to check panic wipe status';
      }
    } catch (e) {
      throw 'Panic wipe status error: $e';
    }
  }

  Future<Map<String, dynamic>> executePanicWipe(String panicPin) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/panic-wipe/execute'),
        headers: _headers(),
        body: jsonEncode({'panicPin': panicPin}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403) {
        throw 'Invalid panic PIN';
      } else {
        final data = jsonDecode(response.body);
        throw data['error'] ?? 'Failed to execute panic wipe';
      }
    } catch (e) {
      throw 'Panic wipe error: $e';
    }
  }

  // ==================== Audit ====================

  Future<List<dynamic>> getAuditLogs({int limit = 100, int offset = 0}) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/audit/logs?limit=$limit&offset=$offset'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        throw 'Failed to fetch audit logs';
      }
    } catch (e) {
      throw 'Get audit logs error: $e';
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
        return data['data'] ?? [];
      } else {
        throw 'Failed to fetch activity';
      }
    } catch (e) {
      throw 'Get activity error: $e';
    }
  }
}
