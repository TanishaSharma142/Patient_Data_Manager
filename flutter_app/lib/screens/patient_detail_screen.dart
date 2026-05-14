// lib/screens/patient_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({
    Key? key,
    required this.patientId,
  }) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late TextEditingController _dateController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _packageController;
  late TextEditingController _cashController;
  late TextEditingController _bankController;
  late TextEditingController _balanceController;

  bool _isEditing = false;
  Patient? _patient;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPatient();
  }

  void _initializeControllers() {
    _dateController = TextEditingController();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _packageController = TextEditingController();
    _cashController = TextEditingController();
    _bankController = TextEditingController();
    _balanceController = TextEditingController();
  }

  Future<void> _loadPatient() async {
    final provider = Provider.of<PatientProvider>(context, listen: false);
    final patient = await provider.getPatient(widget.patientId);
    
    if (patient != null && mounted) {
      setState(() {
        _patient = patient;
        _updateControllers(patient);
      });
    }
  }

  void _updateControllers(Patient patient) {
    _dateController.text = patient.date ?? '';
    _nameController.text = patient.patientName;
    _phoneController.text = patient.phone ?? '';
    _addressController.text = patient.address ?? '';
    _packageController.text = patient.package ?? '';
    _cashController.text = patient.cash ?? '';
    _bankController.text = patient.bank ?? '';
    _balanceController.text = patient.balance ?? '';
  }

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
    final userRole = Provider.of<AuthProvider>(context, listen: false).user!.role;

    if (_patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        title: const Text('Patient Details'),
        actions: [
          if (!_isEditing )
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReadOnlyField('Patient ID', _patient!.id),
            const SizedBox(height: 16),
            _buildField(
              'Date',
              _dateController,
              userRole,
              canEdit: userRole != UserRole.accountant,
            ),
            const SizedBox(height: 16),
            _buildField(
              'Patient Name',
              _nameController,
              userRole,
              canEdit: userRole != UserRole.accountant,
            ),
            
            const SizedBox(height: 16),
            _buildField(
              'Phone',
              _phoneController,
              userRole,
              canEdit: userRole != UserRole.accountant,
              hidden: userRole == UserRole.accountant,
            ),
            const SizedBox(height: 16),
            _buildField(
              'Address',
              _addressController,
              userRole,
              canEdit: userRole != UserRole.accountant,
              hidden: userRole == UserRole.accountant,
            ),
            const SizedBox(height: 16),
            _buildField(
              'Package',
              _packageController,
              userRole,
              canEdit: true,
            ),
            const SizedBox(height: 16),
            _buildField(
              'Cash',
              _cashController,
              userRole,
              canEdit: userRole != UserRole.secretary,
              hidden: userRole == UserRole.secretary,
            ),
            const SizedBox(height: 16),
            _buildField(
              'Bank',
              _bankController,
              userRole,
              canEdit: userRole != UserRole.secretary,
              hidden: userRole == UserRole.secretary,
            ),
            const SizedBox(height: 16),
            _buildField(
              'Balance',
              _balanceController,
              userRole,
              canEdit: userRole != UserRole.secretary,
              hidden: userRole == UserRole.secretary,
            ),
            const SizedBox(height: 32),
            if (_isEditing)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _cancelEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            if (!_isEditing && userRole == UserRole.owner)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _deletePatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Delete Patient'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    UserRole userRole, {
    bool canEdit = false,
    bool hidden = false,
  }) {
    if (hidden) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: _isEditing && canEdit,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: _isEditing && canEdit ? Colors.white : Colors.grey[100],
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    final provider = Provider.of<PatientProvider>(context, listen: false);
    final userRole = Provider.of<AuthProvider>(context, listen: false).user!.role;

    final updates = <String, dynamic>{};
    
    if (userRole != UserRole.accountant) {
      if (_phoneController.text != (_patient?.phone ?? '')) {
        updates['phone'] = _phoneController.text;
      }
      if (_addressController.text != (_patient?.address ?? '')) {
        updates['address'] = _addressController.text;
      }
    }

    if (userRole != UserRole.secretary) {
      if (_cashController.text != (_patient?.cash ?? '')) {
        updates['cash'] = _cashController.text;
      }
      if (_bankController.text != (_patient?.bank ?? '')) {
        updates['bank'] = _bankController.text;
      }
      if (_balanceController.text != (_patient?.balance ?? '')) {
        updates['balance'] = _balanceController.text;
      }
    }

    // Everyone can update name and package
    if (_nameController.text != (_patient?.patientName ?? '')) {
      updates['patientName'] = _nameController.text;
    }
    if (_packageController.text != (_patient?.package ?? '')) {
      updates['package'] = _packageController.text;
    }

    if (updates.isEmpty) {
      setState(() {
        _isEditing = false;
      });
      return;
    }

    final success = await provider.updatePatient(
      widget.patientId,
      updates,
      userRole,
    );

    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      _loadPatient();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to update patient'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _updateControllers(_patient!);
    });
  }

  Future<void> _deletePatient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Patient'),
        content: const Text('Are you sure you want to delete this patient?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<PatientProvider>(context, listen: false);
      final success = await provider.deletePatient(widget.patientId);

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to delete patient'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
