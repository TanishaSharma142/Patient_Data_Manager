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
  late TextEditingController _balanceController;

  bool _isEditing = false;
  Patient? _patient;
  late List<Map<String, String>> _cashEntries;
  late List<Map<String, String>> _bankEntries;
  String _selectedCountryCode = '+91';
  String? _phoneErrorText;

  // Focus nodes for tap‑to‑edit
  late FocusNode _nameFocus;
  late FocusNode _packageFocus;
  late FocusNode _phoneFocus;
  late FocusNode _addressFocus;
  late FocusNode _dateFocus;

  static const List<Map<String, Object>> _countryCodeOptions = [
    {'label': 'India', 'code': '+91', 'length': 10},
    {'label': 'USA', 'code': '+1', 'length': 10},
    {'label': 'UK', 'code': '+44', 'length': 10},
    {'label': 'Australia', 'code': '+61', 'length': 9},
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initFocusNodes();
    _cashEntries = [];
    _bankEntries = [];
    _loadPatient();
  }

  void _initializeControllers() {
    _dateController = TextEditingController();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _packageController = TextEditingController();
    _balanceController = TextEditingController();
  }

  void _initFocusNodes() {
    _nameFocus = FocusNode();
    _packageFocus = FocusNode();
    _phoneFocus = FocusNode();
    _addressFocus = FocusNode();
    _dateFocus = FocusNode();
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
    _balanceController.text = patient.balance ?? '';
    _cashEntries = patient.cashEntries?.map((entry) => {
          'entryDate': entry.entryDate,
          'amount': entry.amount,
        }).toList() ??
        [];
    _bankEntries = patient.bankEntries?.map((entry) => {
          'entryDate': entry.entryDate,
          'amount': entry.amount,
        }).toList() ??
        [];
    _validatePhone(); // validate after loading
  }

  @override
  void dispose() {
    _dateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _packageController.dispose();
    _balanceController.dispose();
    _nameFocus.dispose();
    _packageFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------
  // Phone validation helpers
  // --------------------------------------------------------------
  int _getRequiredPhoneLength() {
    final option = _countryCodeOptions.firstWhere(
      (opt) => opt['code'] == _selectedCountryCode,
      orElse: () => _countryCodeOptions.first,
    );
    return option['length'] as int;
  }

  void _validatePhone() {
    final phone = _phoneController.text.trim();
    final requiredLength = _getRequiredPhoneLength();
    if (phone.isEmpty) {
      setState(() => _phoneErrorText = null);
    } else if (phone.length != requiredLength) {
      setState(() => _phoneErrorText = 'Phone number must be $requiredLength digits');
    } else {
      setState(() => _phoneErrorText = null);
    }
  }

  // --------------------------------------------------------------
  // Tap‑to‑edit: enable edit mode and focus the tapped field
  // --------------------------------------------------------------
  void _enableEditAndFocus(TextEditingController controller, FocusNode focusNode) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userRole = auth.user?.role ?? UserRole.secretary;
    // Only owners can edit basic fields
    if (!_isEditing && userRole == UserRole.owner) {
      setState(() {
        _isEditing = true;
      });
      // Focus after frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(focusNode);
        }
      });
    }
  }

  // --------------------------------------------------------------
  // Core logic (balance, save, delete, etc.)
  // --------------------------------------------------------------
  void _recalculateBalance() {
    final packageValue = double.tryParse(_packageController.text) ?? 0;
    final cashTotal = _cashEntries.fold<double>(
        0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
    final bankTotal = _bankEntries.fold<double>(
        0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
    final balance = packageValue - (cashTotal + bankTotal);
    setState(() {
      _balanceController.text = balance.toStringAsFixed(2);
    });
  }

  Future<void> _saveChanges() async {
    final provider = Provider.of<PatientProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userRole = auth.user?.role ?? UserRole.secretary;

    // Validate phone before saving (only if owner and phone is provided)
    if (userRole == UserRole.owner && _phoneController.text.isNotEmpty) {
      _validatePhone();
      if (_phoneErrorText != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_phoneErrorText!), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final updates = <String, dynamic>{};

    if (userRole == UserRole.owner) {
      if (_dateController.text != (_patient?.date ?? ''))
        updates['date'] = _dateController.text;
      if (_nameController.text != (_patient?.patientName ?? ''))
        updates['patientName'] = _nameController.text;
      if (_phoneController.text != (_patient?.phone ?? '')) {
        updates['countryCode'] = _selectedCountryCode;
        updates['phone'] = _phoneController.text;
      }
      if (_addressController.text != (_patient?.address ?? ''))
        updates['address'] = _addressController.text;
      if (_packageController.text != (_patient?.package ?? ''))
        updates['package'] = _packageController.text;
      updates['cashEntries'] = _cashEntries
          .map((e) => {'entryDate': e['entryDate'], 'amount': e['amount']})
          .toList();
      updates['bankEntries'] = _bankEntries
          .map((e) => {'entryDate': e['entryDate'], 'amount': e['amount']})
          .toList();
    } else if (userRole == UserRole.accountant) {
      updates['cashEntries'] = _cashEntries
          .map((e) => {'entryDate': e['entryDate'], 'amount': e['amount']})
          .toList();
      updates['bankEntries'] = _bankEntries
          .map((e) => {'entryDate': e['entryDate'], 'amount': e['amount']})
          .toList();
    }

    if (updates.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    final success = await provider.updatePatient(widget.patientId, updates, userRole);
    if (success && mounted) {
      setState(() => _isEditing = false);
      _loadPatient();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record updated'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Update failed'), backgroundColor: Colors.red),
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
        title: const Text('Delete Record'),
        content: const Text('This cannot be undone. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
          const SnackBar(content: Text('Record deleted'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Delete failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --------------------------------------------------------------
  // UI Builders (updated with tap‑to‑edit and validation)
  // --------------------------------------------------------------
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

  Widget _buildInfoCard(String label, String value, {IconData? icon}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF00695C).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: const Color(0xFF00695C), size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                '$label: $value',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Generic text field with optional FocusNode and tap‑to‑edit
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool editable = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
    void Function(String)? onChanged,
    FocusNode? focusNode,
    String? errorText,
  }) {
    final field = TextField(
      controller: controller,
      enabled: editable,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF00695C), size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: editable ? Colors.white : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        errorText: errorText,
      ),
    );

    if (editable) return field;
    return GestureDetector(
      onTap: () => _enableEditAndFocus(controller, focusNode ?? FocusNode()),
      child: AbsorbPointer(child: field),
    );
  }

  // Date field with tap‑to‑edit
  Widget _buildDateField(bool editable) {
    final field = TextField(
      controller: _dateController,
      enabled: false,
      readOnly: true,
      onTap: editable ? _pickDate : null,
      decoration: InputDecoration(
        labelText: 'Date',
        prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF00695C), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: editable ? Colors.white : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    if (editable) return field;
    return GestureDetector(
      onTap: () => _enableEditAndFocus(_dateController, _dateFocus),
      child: AbsorbPointer(child: field),
    );
  }

  // Phone field with country code dropdown and inline validation
  Widget _buildPhoneField(bool editable) {
    final phoneField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: editable ? Colors.white : Colors.grey[100],
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
                onChanged: editable
                    ? (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCountryCode = value;
                            _validatePhone();
                          });
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                enabled: editable,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _validatePhone(),
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: editable ? Colors.white : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  errorText: _phoneErrorText,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (editable) return phoneField;
    return GestureDetector(
      onTap: () => _enableEditAndFocus(_phoneController, _phoneFocus),
      child: AbsorbPointer(child: phoneField),
    );
  }

  // Cash / Bank entries sections (unchanged but kept for completeness)
  Widget _buildCashEntriesSection(bool canAdd, bool canDelete) {
    final total = _cashEntries.fold<double>(
        0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.money, color: Color(0xFF00695C), size: 20),
            const SizedBox(width: 8),
            const Text('Cash Payments', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (canAdd)
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
                    Text('₹ ${entry['amount']}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (canDelete)
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

  Widget _buildBankEntriesSection(bool canAdd, bool canDelete) {
    final total = _bankEntries.fold<double>(
        0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance, color: Color(0xFF00695C), size: 20),
            const SizedBox(width: 8),
            const Text('Bank Transfers', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (canAdd)
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
                    Text('₹ ${entry['amount']}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (canDelete)
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
        const Text('Outstanding Balance: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(
          '₹ ${_balanceController.text}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: double.tryParse(_balanceController.text) == 0
                ? Colors.green
                : Colors.orange,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------
  // Dialogs for adding cash/bank entries (unchanged)
  // --------------------------------------------------------------
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
                      child: Text(validationError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                        setDialogState(() {
                          dateController.text = entryDate!.toString().split(' ')[0];
                        });
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                  ),
                  onPressed: () {
                    setDialogState(() {
                      validationError = null;
                      if (dateController.text.isEmpty || amountController.text.isEmpty) {
                        validationError = 'Please fill in all fields';
                        return;
                      }
                      final entryDateObj = DateTime.tryParse(dateController.text);
                      final patientDateObj = _patient?.date != null
                          ? DateTime.tryParse(_patient!.date!)
                          : null;
                      if (entryDateObj != null &&
                          patientDateObj != null &&
                          entryDateObj.isBefore(patientDateObj)) {
                        validationError =
                            'Entry date cannot be before patient registration date';
                        return;
                      }
                      final packageAmount =
                          double.tryParse(_packageController.text) ?? 0;
                      final entryAmount =
                          double.tryParse(amountController.text) ?? 0;
                      final currentCashTotal = _cashEntries.fold<double>(
                          0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
                      final currentBankTotal = _bankEntries.fold<double>(
                          0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
                      final totalAfterEntry =
                          currentCashTotal + currentBankTotal + entryAmount;
                      if (totalAfterEntry > packageAmount) {
                        validationError = 'Entry would exceed plan amount';
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
                      child: Text(validationError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                        setDialogState(() {
                          dateController.text = entryDate!.toString().split(' ')[0];
                        });
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                  ),
                  onPressed: () {
                    setDialogState(() {
                      validationError = null;
                      if (dateController.text.isEmpty || amountController.text.isEmpty) {
                        validationError = 'Please fill in all fields';
                        return;
                      }
                      final entryDateObj = DateTime.tryParse(dateController.text);
                      final patientDateObj = _patient?.date != null
                          ? DateTime.tryParse(_patient!.date!)
                          : null;
                      if (entryDateObj != null &&
                          patientDateObj != null &&
                          entryDateObj.isBefore(patientDateObj)) {
                        validationError =
                            'Entry date cannot be before patient registration date';
                        return;
                      }
                      final packageAmount =
                          double.tryParse(_packageController.text) ?? 0;
                      final entryAmount =
                          double.tryParse(amountController.text) ?? 0;
                      final currentCashTotal = _cashEntries.fold<double>(
                          0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
                      final currentBankTotal = _bankEntries.fold<double>(
                          0, (sum, e) => sum + (double.tryParse(e['amount'] ?? '0') ?? 0));
                      final totalAfterEntry =
                          currentCashTotal + currentBankTotal + entryAmount;
                      if (totalAfterEntry > packageAmount) {
                        validationError = 'Entry would exceed plan amount';
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

  // --------------------------------------------------------------
  // Main build method (uses all new builders)
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.user?.role ?? UserRole.secretary;
    final isOwner = userRole == UserRole.owner;
    final isAccountant = userRole == UserRole.accountant;
    final isSecretary = userRole == UserRole.secretary;

    if (_patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Permissions:
    final canEdit = !isSecretary;
    final canEditBasic = isOwner && _isEditing;
    final canEditEntries = _isEditing && (isOwner || isAccountant);
    final canDeleteEntries = _isEditing && isOwner;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00695C),
        title: const Text('Record Details'),
        actions: [
          if (canEdit && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
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
            // ID Card (read‑only)
            _buildInfoCard(
              'Record ID',
              _patient!.id,
              icon: Icons.tag,
            ),
            const SizedBox(height: 16),

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
                    _buildDateField(canEditBasic),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'Name',
                      controller: _nameController,
                      editable: canEditBasic,
                      icon: Icons.person,
                      focusNode: _nameFocus,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'Plan',
                      controller: _packageController,
                      editable: canEditBasic,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalculateBalance(),
                      icon: Icons.assignment,
                      focusNode: _packageFocus,
                    ),
                  ],
                ),
              ),
            ),

            // CONTACT SECTION (only non‑accountant)
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
                      _buildPhoneField(canEditBasic),
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: 'Address',
                        controller: _addressController,
                        editable: canEditBasic,
                        maxLines: 2,
                        icon: Icons.location_on,
                        focusNode: _addressFocus,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // FINANCIAL SECTION (only non‑secretary)
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
                      _buildCashEntriesSection(canEditEntries, canDeleteEntries),
                      const Divider(height: 24),
                      _buildBankEntriesSection(canEditEntries, canDeleteEntries),
                      const Divider(height: 24),
                      _buildBalanceDisplay(),
                    ],
                  ),
                ),
              ),
            ],

            // ACTIONS
            const SizedBox(height: 32),
            if (_isEditing && !isSecretary) ...[
              Row(
                children: [
                  if (isOwner)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  if (isOwner) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ],
            if (!_isEditing && isOwner) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _deletePatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Record'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}