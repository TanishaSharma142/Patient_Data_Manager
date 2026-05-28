// lib/providers/patient_provider.dart
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class PatientProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Patient> _patients = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Patient> get patients => _patients;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get patientCount => _patients.length;

  /// Load all patients
  Future<void> loadPatients() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _patients = await _apiService.getAllPatients();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get patient by ID
  Future<Patient?> getPatient(String id) async {
    try {
      return await _apiService.getPatientById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Create new patient
  Future<Patient?> createPatient(Map<String, dynamic> data, UserRole role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final patient = await _apiService.createPatient(data);
      _patients.insert(0, patient);
      _isLoading = false;
      notifyListeners();
      return patient;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update patient
  Future<bool> updatePatient(String id, Map<String, dynamic> updates, UserRole role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedPatient = await _apiService.updatePatient(id, updates);
      
      final index = _patients.indexWhere((p) => p.id == id);
      if (index != -1) {
        _patients[index] = updatedPatient;
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete patient (OWNER only)
  Future<bool> deletePatient(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deletePatient(id);
      _patients.removeWhere((p) => p.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Add bank entry to patient
  Future<bool> addBankEntry(String patientId, String entryDate, String amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedPatient = await _apiService.addBankEntry(patientId, entryDate, amount);
      
      final index = _patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        _patients[index] = updatedPatient;
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Search patients by multiple fields
  List<Patient> searchByQuery(String query) {
    if (query.isEmpty) return _patients;
    final lowerQuery = query.toLowerCase();

    return _patients.where((p) {
      return [
        p.id,
        p.patientName,
        p.package,
        p.balance,
      ].any((value) => value != null && value.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh patient list
  Future<void> refresh() async {
    await loadPatients();
  }
}
