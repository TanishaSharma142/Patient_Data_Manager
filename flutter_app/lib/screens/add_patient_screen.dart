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
  final _balanceController = TextEditingController();

  String _selectedCountryCode = '+91';
  final List<Map<String, String>> _cashEntries = [];
  final List<Map<String, String>> _bankEntries = [];
  bool _isSubmitting = false;

  static const List<Map<String, Object>> _countryCodeOptions = [
    {'label': 'India', 'code': '+91', 'length': 10},
    {'label': 'USA', 'code': '+1', 'length': 10},
    {'label': 'UK', 'code': '+44', 'length': 10},
    {'label': 'Australia', 'code': '+61', 'length': 9},
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _packageController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.user?.role ?? UserRole.secretary;
    final isOwner = userRole == UserRole.owner;
    final isAccountant = userRole == UserRole.accountant;
    final isSecretary = userRole == UserRole.secretary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00695C),
        title: const Text('New Record'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BASIC INFORMATION SECTION
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date – only for non‑accountant
                      if (!isAccountant) ...[
                        _buildDateField(),
                        const SizedBox(height: 12),
                      ],
                      _buildTextField(
                        label: 'Name',
                        controller: _nameController,
                        required: true,
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        label: 'Plan',
                        controller: _packageController,
                        required: true,
                        onChanged: (_) => _recalculateBalance(),
                        icon: Icons.assignment,
                      ),
                    ],
                  ),
                ),
              ),

              // CONTACT SECTION – only non‑accountant
              if (!isAccountant) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Contact'),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildPhoneField(),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Address',
                          controller: _addressController,
                          maxLines: 2,
                          icon: Icons.location_on,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // FINANCIAL SECTION – only non‑secretary
              if (!isSecretary) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Financial Details'),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildCashEntriesSection(),
                        const Divider(height: 24),
                        _buildBankEntriesSection(),
                        const Divider(height: 24),
                        _buildBalanceDisplay(),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Save Record'),
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

  // ──────────────────────────────────────────────────────────────────────────
  //  UI BUILDERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00695C),
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dateController,
          readOnly: true,
          validator: (value) => (value?.isEmpty ?? true) ? 'Date is required' : null,
          onTap: _pickDate,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF00695C), size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: required ? (v) => (v?.isEmpty ?? true) ? '$label is required' : null : null,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF00695C), size: 20) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildNumericField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    void Function(String)? onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
          onChanged: onChanged,
          validator: required ? (v) => (v?.isEmpty ?? true) ? '$label is required' : null : null,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF00695C), size: 20) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                    .map((o) => DropdownMenuItem<String>(
                          value: o['code'] as String,
                          child: Text(o['code'] as String),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCountryCode = value);
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
                  if (value == null || value.trim().isEmpty) return null;
                  final expectedLength = _countryCodeOptions
                      .firstWhere((o) => o['code'] == _selectedCountryCode)['length'] as int;
                  if (value.trim().length != expectedLength) {
                    return 'Must be $expectedLength digits for $_selectedCountryCode';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: '${_countryCodeOptions.firstWhere((o) => o['code'] == _selectedCountryCode)['length']} digits',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCashEntriesSection() {
    final total = _cashEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.money, color: Color(0xFF00695C), size: 20),
            const SizedBox(width: 8),
            const Text('Cash Payments', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addCashEntry,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00695C)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_cashEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No cash entries', style: TextStyle(color: Colors.grey)),
          ),
        ..._cashEntries.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                dense: true,
                title: Text(entry['entryDate'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹ ${entry['amount']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          _cashEntries.remove(entry);
                          _recalculateBalance();
                        });
                      },
                    ),
                  ],
                ),
              ),
            )),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total Cash: ₹ ${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildBankEntriesSection() {
    final total = _bankEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance, color: Color(0xFF00695C), size: 20),
            const SizedBox(width: 8),
            const Text('Bank Transfers', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addBankEntry,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00695C)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_bankEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No bank entries', style: TextStyle(color: Colors.grey)),
          ),
        ..._bankEntries.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                dense: true,
                title: Text(entry['entryDate'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹ ${entry['amount']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          _bankEntries.remove(entry);
                          _recalculateBalance();
                        });
                      },
                    ),
                  ],
                ),
              ),
            )),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total Bank: ₹ ${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue)),
        ),
      ],
    );
  }

  Widget _buildBalanceDisplay() {
    return Row(
      children: [
        const Icon(Icons.account_balance_wallet, color: Color(0xFF00695C)),
        const SizedBox(width: 8),
        const Text('Outstanding Balance: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(
          '₹ ${_balanceController.text}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: double.tryParse(_balanceController.text) == 0 ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  LOGIC (unchanged)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      setState(() {
        _dateController.text = selectedDate.toString().split(' ')[0];
      });
    }
  }

  Future<void> _addCashEntry() async {
    final dateController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? entryDate;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Cash Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (validationError != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(validationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
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
                        dateController.text = entryDate!.toString().split(' ')[0];
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Entry Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C)),
                  onPressed: () {
                    setDialogState(() {
                      validationError = null;
                      if (dateController.text.isEmpty || amountController.text.isEmpty) {
                        validationError = 'Please fill in all fields';
                        return;
                      }
                      final entryDateObj = DateTime.tryParse(dateController.text);
                      final patientDateObj = _dateController.text.isNotEmpty
                          ? DateTime.tryParse(_dateController.text)
                          : null;
                      if (entryDateObj != null && patientDateObj != null && entryDateObj.isBefore(patientDateObj)) {
                        validationError = 'Entry date cannot be before patient registration date';
                        return;
                      }
                      final packageAmount = double.tryParse(_packageController.text) ?? 0;
                      final entryAmount = double.tryParse(amountController.text) ?? 0;
                      final currentCashTotal = _cashEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));
                      final currentBankTotal = _bankEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));
                      final totalAfterEntry = currentCashTotal + currentBankTotal + entryAmount;
                      if (totalAfterEntry > packageAmount) {
                        validationError = 'Entry would make balance negative';
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
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addBankEntry() async {
    final dateController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? entryDate;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Bank Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (validationError != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(validationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
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
                        dateController.text = entryDate!.toString().split(' ')[0];
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Entry Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C)),
                  onPressed: () {
                    setDialogState(() {
                      validationError = null;
                      if (dateController.text.isEmpty || amountController.text.isEmpty) {
                        validationError = 'Please fill in all fields';
                        return;
                      }
                      final entryDateObj = DateTime.tryParse(dateController.text);
                      final patientDateObj = _dateController.text.isNotEmpty
                          ? DateTime.tryParse(_dateController.text)
                          : null;
                      if (entryDateObj != null && patientDateObj != null && entryDateObj.isBefore(patientDateObj)) {
                        validationError = 'Entry date cannot be before patient registration date';
                        return;
                      }
                      final packageAmount = double.tryParse(_packageController.text) ?? 0;
                      final entryAmount = double.tryParse(amountController.text) ?? 0;
                      final currentCashTotal = _cashEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));
                      final currentBankTotal = _bankEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));
                      final totalAfterEntry = currentCashTotal + currentBankTotal + entryAmount;
                      if (totalAfterEntry > packageAmount) {
                        validationError = 'Entry would make balance negative';
                        return;
                      }
                      setState(() {
                        _bankEntries.add({
                          'entryDate': dateController.text,
                          'amount': amountController.text,
                        });
                        _recalculateBalance();
                      });
                      Navigator.pop(context);
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _recalculateBalance() {
    final packageValue = double.tryParse(_packageController.text) ?? 0;
    final cashTotal = _cashEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));
    final bankTotal = _bankEntries.fold<double>(0, (sum, entry) => sum + (double.tryParse(entry['amount'] ?? '0') ?? 0));
    final balance = packageValue - (cashTotal + bankTotal);
    setState(() {
      _balanceController.text = balance.toStringAsFixed(2);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role ?? UserRole.secretary;
    setState(() => _isSubmitting = true);

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
      if (_cashEntries.isNotEmpty) {
        patientData['cashEntries'] = _cashEntries
            .map((entry) => {'entryDate': entry['entryDate'], 'amount': entry['amount']})
            .toList();
      }
      if (_bankEntries.isNotEmpty) {
        patientData['bankEntries'] = _bankEntries
            .map((entry) => {'entryDate': entry['entryDate'], 'amount': entry['amount']})
            .toList();
      }
    }

    final provider = Provider.of<PatientProvider>(context, listen: false);
    final createdPatient = await provider.createPatient(patientData, userRole);

    setState(() => _isSubmitting = false);

    if (createdPatient != null && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record added'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to add record'), backgroundColor: Colors.red),
      );
    }
  }
}