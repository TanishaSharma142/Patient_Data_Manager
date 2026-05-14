// lib/screens/add_patient_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';


class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({Key? key}) : super(key: key);

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _packageController = TextEditingController();
  final _cashController = TextEditingController();
  final _bankController = TextEditingController();
  final _balanceController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _dateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _packageController.dispose();
    _cashController.dispose();
    _bankController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).user!.role;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        title: const Text('Add Patient'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                'Date',
                _dateController,
                canEdit: userRole != UserRole.accountant,
                hidden: userRole == UserRole.accountant,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Patient Name',
                _nameController,
                canEdit: true,
                required: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Phone',
                _phoneController,
                canEdit: userRole != UserRole.accountant,
                hidden: userRole == UserRole.accountant,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Address',
                _addressController,
                canEdit: userRole != UserRole.accountant,
                hidden: userRole == UserRole.accountant,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Package',
                _packageController,
                canEdit: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Cash',
                _cashController,
                canEdit: userRole != UserRole.secretary,
                hidden: userRole == UserRole.secretary,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Bank',
                _bankController,
                canEdit: userRole != UserRole.secretary,
                hidden: userRole == UserRole.secretary,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Balance',
                _balanceController,
                canEdit: userRole != UserRole.secretary,
                hidden: userRole == UserRole.secretary,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add Patient'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool canEdit = true,
    bool hidden = false,
    bool required = false,
  }) {
    if (hidden) {
      return const SizedBox.shrink();
    }

    if (!canEdit) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (required ? ' *' : ''),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: required
              ? (value) {
                  if (value?.isEmpty ?? true) {
                    return '$label is required';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userRole = Provider.of<AuthProvider>(context, listen: false).user!.role;

    setState(() {
      _isSubmitting = true;
    });

    final patientData = <String, dynamic>{};

    if (userRole != UserRole.accountant) {
      if (_dateController.text.isNotEmpty) patientData['date'] = _dateController.text;
      if (_phoneController.text.isNotEmpty) patientData['phone'] = _phoneController.text;
      if (_addressController.text.isNotEmpty) patientData['address'] = _addressController.text;
    }

    if (userRole != UserRole.secretary) {
      if (_cashController.text.isNotEmpty) patientData['cash'] = _cashController.text;
      if (_bankController.text.isNotEmpty) patientData['bank'] = _bankController.text;
      if (_balanceController.text.isNotEmpty) patientData['balance'] = _balanceController.text;
    }


    // Everyone can add name and package
    if (_nameController.text.isNotEmpty) patientData['patientName'] = _nameController.text;
    if (_packageController.text.isNotEmpty) patientData['package'] = _packageController.text;

    final provider = Provider.of<PatientProvider>(context, listen: false);
    final createdPatient = await provider.createPatient(patientData, userRole);

    setState(() {
      _isSubmitting = false;
    });

    if (createdPatient != null && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to add patient'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
