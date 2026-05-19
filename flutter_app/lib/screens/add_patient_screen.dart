// lib/screens/add_patient_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _bankController = TextEditingController();
  final _balanceController = TextEditingController();

  String _selectedCountryCode = '+91';
  final List<Map<String, String>> _cashEntries = [];
  bool _isSubmitting = false;

  static const List<Map<String, Object>> _countryCodeOptions = [
    {'label': 'India', 'code': '+91', 'length': 10},
    {'label': 'USA', 'code': '+1', 'length': 10},
    {'label': 'UK', 'code': '+44', 'length': 10},
    {'label': 'Australia', 'code': '+61', 'length': 9},
    {'label': 'Canada', 'code': '+1', 'length': 10},
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _packageController.dispose();
    _bankController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).user?.role ?? UserRole.secretary;

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
              if (userRole != UserRole.accountant) ...[
                _buildDateField(),
                const SizedBox(height: 16),
              ],
              _buildTextField(
                'Patient Name',
                _nameController,
                canEdit: true,
                required: true,
              ),
              const SizedBox(height: 16),
              if (userRole != UserRole.accountant) ...[
                _buildPhoneField(),
                const SizedBox(height: 16),
                _buildTextField(
                  'Address',
                  _addressController,
                  canEdit: true,
                ),
                const SizedBox(height: 16),
              ],
              _buildNumericField(
                'Package',
                _packageController,
                canEdit: true,
                onChanged: (_) => _recalculateBalance(),
                required: true,
              ),
              const SizedBox(height: 16),
              if (userRole != UserRole.secretary) ...[
                _buildCashEntriesSection(),
                const SizedBox(height: 16),
                _buildNumericField(
                  'Bank',
                  _bankController,
                  canEdit: true,
                  onChanged: (_) => _recalculateBalance(),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                ),
                const SizedBox(height: 16),
                _buildReadOnlyField('Balance', _balanceController.text),
                const SizedBox(height: 16),
              ],
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

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date *',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dateController,
          readOnly: true,
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Date is required';
            }
            return null;
          },
          onTap: _pickDate,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
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
                color: Colors.white,
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
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCountryCode = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final expectedLength = _countryCodeOptions
                          .firstWhere((option) => option['code'] == _selectedCountryCode)['length'] as int;
                  if (value.trim().length != expectedLength) {
                    return 'Phone must be $expectedLength digits for $_selectedCountryCode';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Enter phone number',
                ),
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildNumericField(
    String label,
    TextEditingController controller, {
    bool canEdit = true,
    bool required = false,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: inputFormatters ?? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
          onChanged: onChanged,
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
          child: Text(value.isEmpty ? '0.00' : value),
        ),
      ],
    );
  }

  Widget _buildCashEntriesSection() {
    final total = _cashEntries.fold<double>(0, (sum, entry) => sum + double.tryParse(entry['amount'] ?? '0')!);

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
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _cashEntries.remove(entry);
                      _recalculateBalance();
                    });
                  },
                ),
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role ?? UserRole.secretary;

    setState(() {
      _isSubmitting = true;
    });

    final patientData = <String, dynamic>{};

    if (userRole != UserRole.accountant) {
      if (_dateController.text.isNotEmpty) patientData['date'] = _dateController.text;
      if (_phoneController.text.isNotEmpty) {
        patientData['countryCode'] = _selectedCountryCode;
        patientData['phone'] = _phoneController.text;
      }
      if (_addressController.text.isNotEmpty) patientData['address'] = _addressController.text;
    }

    if (_nameController.text.isNotEmpty) patientData['patientName'] = _nameController.text;
    if (_packageController.text.isNotEmpty) patientData['package'] = _packageController.text;

    if (userRole != UserRole.secretary) {
      if (_bankController.text.isNotEmpty) patientData['bank'] = _bankController.text;
      if (_cashEntries.isNotEmpty) {
        patientData['cashEntries'] = _cashEntries
            .map((entry) => {
                  'entryDate': entry['entryDate'],
                  'amount': entry['amount'],
                })
            .toList();
      }
    }

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
