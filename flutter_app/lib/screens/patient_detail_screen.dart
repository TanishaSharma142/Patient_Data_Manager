// lib/screens/patient_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late List<Map<String, String>> _cashEntries;
  String _selectedCountryCode = '+91';

  static const List<Map<String, Object>> _countryCodeOptions = [
    {'label': 'India', 'code': '+91', 'length': 10},
    {'label': 'USA', 'code': '+1', 'length': 10},
    {'label': 'UK', 'code': '+44', 'length': 10},
    {'label': 'Australia', 'code': '+61', 'length': 9},
    {'label': 'Canada', 'code': '+1', 'length': 10},
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _cashEntries = [];
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
    _cashEntries = patient.cashEntries?.map((entry) => {
      'entryDate': entry.entryDate,
      'amount': entry.amount,
    }).toList() ?? [];
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
    final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role ?? UserRole.secretary;

    if (_patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Secretary cannot edit existing patients
    final canEdit = userRole != UserRole.secretary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        title: const Text('Patient Details'),
        actions: [
          if (canEdit && !_isEditing)
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
              canEdit: userRole == UserRole.owner && _isEditing,
              isDateField: true,
            ),
            const SizedBox(height: 16),
            _buildField(
              'Patient Name',
              _nameController,
              userRole,
              canEdit: userRole == UserRole.owner && _isEditing,
            ),
            const SizedBox(height: 16),
            if (userRole != UserRole.accountant) ...[
              _buildPhoneField(),
              const SizedBox(height: 16),
              _buildField(
                'Address',
                _addressController,
                userRole,
                canEdit: userRole == UserRole.owner && _isEditing,
              ),
              const SizedBox(height: 16),
              _buildField(
                'Package',
                _packageController,
                userRole,
                canEdit: userRole == UserRole.owner && _isEditing,
                onChanged: (_) => _recalculateBalance(),
              ),
              const SizedBox(height: 16),
            ],
            _buildField(
              'Bank',
              _bankController,
              userRole,
              canEdit: userRole == UserRole.owner && _isEditing,
              hidden: userRole == UserRole.secretary,
              onChanged: (_) => _recalculateBalance(),
            ),
            const SizedBox(height: 16),
            // Cash Entries Section - visible for Owner and Accountant
            if (userRole != UserRole.secretary) ...[
              _buildCashEntriesSection(),
              const SizedBox(height: 16),
            ],
            _buildField(
              'Balance',
              _balanceController,
              userRole,
              canEdit: false,
              hidden: userRole == UserRole.secretary,
            ),
            const SizedBox(height: 32),
            if (_isEditing && userRole != UserRole.secretary)
              Row(
                children: [
                  if (userRole == UserRole.owner)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _cancelEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  if (userRole == UserRole.owner) const SizedBox(width: 16),
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
    bool isDateField = false,
    void Function(String)? onChanged,
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
          readOnly: isDateField && _isEditing && canEdit,
          keyboardType: isDateField ? TextInputType.datetime : TextInputType.text,
          onChanged: onChanged,
          onTap: isDateField && _isEditing && canEdit ? _pickDate : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: _isEditing && canEdit ? Colors.white : Colors.grey[100],
            suffixIcon: isDateField && _isEditing && canEdit ? const Icon(Icons.calendar_today) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role ?? UserRole.secretary;
    
    if (userRole == UserRole.accountant) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phone',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: _isEditing ? Colors.white : Colors.grey[100],
              ),
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                underline: const SizedBox.shrink(),
                items: _countryCodeOptions
                    .map((option) => DropdownMenuItem<String>(
                          value: option['code'] as String,
                          child: Text(option['code'] as String),
                        ))
                    .toList(),
                onChanged: _isEditing ? (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCountryCode = value;
                    });
                  }
                } : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                  hintText: 'Enter phone number',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCashEntriesSection() {
    final total = _cashEntries.fold<double>(0, (sum, entry) => sum + double.tryParse(entry['amount'] ?? '0')!);
    final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role ?? UserRole.secretary;
    final canAddEntries = _isEditing && (userRole == UserRole.owner || userRole == UserRole.accountant);
    final canDeleteEntries = _isEditing && userRole == UserRole.owner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cash Entries',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (canAddEntries)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: _addCashEntry,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_cashEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text('No cash entries yet'),
          ),
        if (_cashEntries.isNotEmpty)
          ..._cashEntries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                title: Text('Date: ${entry['entryDate']}'),
                subtitle: Text('Amount: ${entry['amount']}'),
                trailing: canDeleteEntries ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _cashEntries.remove(entry);
                      _recalculateBalance();
                    });
                  },
                ) : null,
              ),
            );
          }),
        const SizedBox(height: 8),
        _buildReadOnlyField('Cash Total', total.toStringAsFixed(2)),
      ],
    );
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      setState(() {
        _dateController.text = selectedDate.toString().split(' ')[0]; // Store as YYYY-MM-DD only
      });
    }
  }

  Future<void> _addCashEntry() async {
    final dateController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? entryDate;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Cash Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: dateController,
                readOnly: true,
                onTap: () async {
                  entryDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (entryDate != null) {
                    dateController.text = entryDate!.toString().split(' ')[0]; // Store as YYYY-MM-DD only
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Entry Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dateController.text.isEmpty || amountController.text.isEmpty) {
                  return;
                }
                setState(() {
                  _cashEntries.add({
                    'entryDate': dateController.text,
                    'amount': amountController.text,
                  });
                  _recalculateBalance();
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _recalculateBalance() {
    final packageValue = double.tryParse(_packageController.text) ?? 0;
    final bankValue = double.tryParse(_bankController.text) ?? 0;
    final cashTotal = _cashEntries.fold<double>(0, (sum, entry) => sum + double.tryParse(entry['amount'] ?? '0')!);
    final balance = packageValue - (cashTotal + bankValue);
    setState(() {
      _balanceController.text = balance.toStringAsFixed(2);
    });
  }

  Future<void> _saveChanges() async {
  final provider = Provider.of<PatientProvider>(context, listen: false);
  final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role ?? UserRole.secretary;

  final updates = <String, dynamic>{};
  
  if (userRole == UserRole.owner) {
    if (_dateController.text != (_patient?.date ?? '')) {
      updates['date'] = _dateController.text;
    }
    if (_nameController.text != (_patient?.patientName ?? '')) {
      updates['patientName'] = _nameController.text;
    }
    if (_phoneController.text != (_patient?.phone ?? '')) {
      updates['countryCode'] = _selectedCountryCode;
      updates['phone'] = _phoneController.text;
    }
    if (_addressController.text != (_patient?.address ?? '')) {
      updates['address'] = _addressController.text;
    }
    if (_packageController.text != (_patient?.package ?? '')) {
      updates['package'] = _packageController.text;
    }
    if (_bankController.text != (_patient?.bank ?? '')) {
      updates['bank'] = _bankController.text;
    }

    // ✅ ADD THIS — always send cashEntries for owner so adds AND deletes persist
    updates['cashEntries'] = _cashEntries
        .map((entry) => {
              'entryDate': entry['entryDate'],
              'amount': entry['amount'],
            })
        .toList();

  } else if (userRole == UserRole.accountant) {
    // ✅ ALSO FIX THIS — send even if empty, so deletions persist
    updates['cashEntries'] = _cashEntries
        .map((entry) => {
              'entryDate': entry['entryDate'],
              'amount': entry['amount'],
            })
        .toList();
  }

  // rest of the method unchanged...
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
        await provider.refresh();
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
