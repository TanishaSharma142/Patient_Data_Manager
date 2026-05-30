// lib/screens/patient_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';
import '../models/patient.dart';
import '../services/report_service.dart';
import 'package:intl/intl.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({Key? key}) : super(key: key);

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PatientProvider>(context, listen: false).loadPatients();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Patient> _applyFilters(List<Patient> patients) {
    final now = DateTime.now();
    if (_activeFilter != null && _activeFilter != 'all') {
      patients = patients.where((p) {
        if (p.date == null) return false;
        final patientDate = DateTime.tryParse(p.date!);
        if (patientDate == null) return false;
        switch (_activeFilter) {
          case 'today':
            return patientDate.year == now.year &&
                patientDate.month == now.month &&
                patientDate.day == now.day;
          case 'week':
            final weekAgo = now.subtract(const Duration(days: 7));
            return patientDate.isAfter(weekAgo.subtract(const Duration(days: 1))) &&
                patientDate.isBefore(now.add(const Duration(days: 1)));
          case 'month':
            final monthAgo = now.subtract(const Duration(days: 30));
            return patientDate.isAfter(monthAgo.subtract(const Duration(days: 1))) &&
                patientDate.isBefore(now.add(const Duration(days: 1)));
          default:
            return true;
        }
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      patients = patients
          .where((p) =>
              p.patientName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return patients;
  }

  // ─── Report dialog ────────────────────────────────────────────────────────
  void _showReportDialog(BuildContext context, UserRole userRole, List<Patient> allPatients) {
    showDialog(
      context: context,
      builder: (ctx) => _ReportDialog(
        userRole: userRole,
        allPatients: allPatients,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final patientProvider = Provider.of<PatientProvider>(context);
    final userRole = authProvider.user?.role ?? UserRole.secretary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00695C),
        title: const Text('Records'),
        actions: [
          // ── Report button ──
          Consumer<PatientProvider>(
            builder: (ctx, provider, _) => IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Generate Report',
              onPressed: provider.patients.isEmpty
                  ? null
                  : () => _showReportDialog(ctx, userRole, provider.patients),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => patientProvider.refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsMenu(context, authProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00695C)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Date filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildDateChip('All', 'all'),
                const SizedBox(width: 8),
                _buildDateChip('Today', 'today'),
                const SizedBox(width: 8),
                _buildDateChip('This Week', 'week'),
                const SizedBox(width: 8),
                _buildDateChip('This Month', 'month'),
              ],
            ),
          ),

          // Patient grid
          Expanded(
            child: Consumer<PatientProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00695C)),
                    ),
                  );
                }
                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                        const SizedBox(height: 16),
                        Text(provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.refresh(),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00695C)),
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }

                final filtered = _applyFilters(provider.patients);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, color: Colors.grey[400], size: 48),
                        const SizedBox(height: 16),
                        Text('No records match filters',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 1;
                    if (constraints.maxWidth >= 600) crossAxisCount = 2;
                    if (constraints.maxWidth >= 900) crossAxisCount = 3;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 1.4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _PatientCard(
                        patient: filtered[index],
                        userRole: userRole,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: userRole != UserRole.accountant
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00695C),
              onPressed: () async {
                final result = await Navigator.of(context)
                    .pushNamed('/add-patient') as bool?;
                if (result == true && mounted) patientProvider.refresh();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDateChip(String label, String filterValue) {
    final isActive = _activeFilter == filterValue;
    return GestureDetector(
      onTap: () =>
          setState(() => _activeFilter = isActive ? null : filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00695C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF00695C) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isActive ? Colors.white : const Color(0xFF00695C),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF00695C)),
              title: Text('User: ${authProvider.user?.username}'),
              subtitle: Text(
                  'Role: ${authProvider.user?.role.toString().split('.').last}'),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF00695C)),
              title: const Text('Activity Log'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/activity');
              },
            ),
            if (authProvider.user?.isOwner == true)
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: const Text('System Reset',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/panic-wipe');
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                authProvider.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Report Dialog ────────────────────────────────────────────────────────────

class _ReportDialog extends StatefulWidget {
  final UserRole userRole;
  final List<Patient> allPatients;

  const _ReportDialog({
    required this.userRole,
    required this.allPatients,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportFilterType _filterType = ReportFilterType.all;
  ReportType _reportType = ReportType.summary;

  DateTime? _singleDate;
  DateTime? _fromDate;
  DateTime? _toDate;

  final _exactPackageCtrl = TextEditingController();
  final _minPackageCtrl = TextEditingController();
  final _maxPackageCtrl = TextEditingController();

  bool _isGenerating = false;
  String? _resultMessage;
  bool _isError = false;

  final _fmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _exactPackageCtrl.dispose();
    _minPackageCtrl.dispose();
    _maxPackageCtrl.dispose();
    super.dispose();
  }

  String get _fileName {
    final now = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final type = _reportType == ReportType.summary ? 'summary' : 'detail';
    return 'ivf_report_${type}_$now.csv';
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _resultMessage = null;
      _isError = false;
    });

    try {
      // Build filter
      final filter = ReportFilter(
        filterType: _filterType,
        singleDate: _singleDate,
        fromDate: _fromDate,
        toDate: _toDate,
        exactPackage: double.tryParse(_exactPackageCtrl.text),
        minPackage: double.tryParse(_minPackageCtrl.text),
        maxPackage: double.tryParse(_maxPackageCtrl.text),
      );

      // Validate filter inputs
      if (_filterType == ReportFilterType.singleDate && _singleDate == null) {
        throw 'Please select a date';
      }
      if (_filterType == ReportFilterType.dateRange) {
        if (_fromDate == null || _toDate == null) throw 'Please select both dates';
        if (_fromDate!.isAfter(_toDate!)) throw 'From date must be before To date';
      }
      if (_filterType == ReportFilterType.exactPackage &&
          _exactPackageCtrl.text.isEmpty) {
        throw 'Please enter a package amount';
      }
      if (_filterType == ReportFilterType.packageRange) {
        if (_minPackageCtrl.text.isEmpty || _maxPackageCtrl.text.isEmpty) {
          throw 'Please enter both min and max package amounts';
        }
        if ((double.tryParse(_minPackageCtrl.text) ?? 0) >
            (double.tryParse(_maxPackageCtrl.text) ?? 0)) {
          throw 'Min amount must be less than max amount';
        }
      }

      // Filter patients
      final filtered =
          ReportService.applyReportFilter(widget.allPatients, filter);

      if (filtered.isEmpty) {
        throw 'No patients match the selected filter';
      }

      // Generate CSV
      final bytes = _reportType == ReportType.summary
          ? ReportService.generateSummaryCSV(filtered, widget.userRole)
          : ReportService.generateDetailCSV(filtered, widget.userRole);

      // Download
      final message = await ReportService.downloadCSV(
        bytes: bytes,
        fileName: _fileName,
      );

      setState(() {
        _resultMessage = '✅ ${filtered.length} patients exported. $message';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _resultMessage = '❌ $e';
        _isError = true;
      });
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.file_download,
                      color: Color(0xFF00695C), size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Generate Report',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Report Type ──
            const Text('Report Type',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeChip(
                    label: 'Summary',
                    subtitle: 'One row per patient',
                    icon: Icons.table_rows,
                    selected: _reportType == ReportType.summary,
                    onTap: () =>
                        setState(() => _reportType = ReportType.summary),
                  ),
                ),
                const SizedBox(width: 8),
                // Detail report only for owner and accountant
                if (widget.userRole != UserRole.secretary)
                  Expanded(
                    child: _TypeChip(
                      label: 'Detail',
                      subtitle: 'Transaction history',
                      icon: Icons.receipt_long,
                      selected: _reportType == ReportType.detail,
                      onTap: () =>
                          setState(() => _reportType = ReportType.detail),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Filter Type ──
            const Text('Filter By',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip2(
                  label: 'All Patients',
                  selected: _filterType == ReportFilterType.all,
                  onTap: () =>
                      setState(() => _filterType = ReportFilterType.all),
                ),
                _FilterChip2(
                  label: 'Single Date',
                  selected: _filterType == ReportFilterType.singleDate,
                  onTap: () => setState(
                      () => _filterType = ReportFilterType.singleDate),
                ),
                _FilterChip2(
                  label: 'Date Range',
                  selected: _filterType == ReportFilterType.dateRange,
                  onTap: () => setState(
                      () => _filterType = ReportFilterType.dateRange),
                ),
                _FilterChip2(
                  label: 'Package Amount',
                  selected: _filterType == ReportFilterType.exactPackage,
                  onTap: () => setState(
                      () => _filterType = ReportFilterType.exactPackage),
                ),
                _FilterChip2(
                  label: 'Package Range',
                  selected: _filterType == ReportFilterType.packageRange,
                  onTap: () => setState(
                      () => _filterType = ReportFilterType.packageRange),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Filter inputs ──
            _buildFilterInputs(),

            // ── Result message ──
            if (_resultMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError ? Colors.red[300]! : Colors.green[300]!,
                  ),
                ),
                child: Text(
                  _resultMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isError ? Colors.red[800] : Colors.green[800],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Generate button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download),
                label: Text(_isGenerating ? 'Generating...' : 'Download CSV'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterInputs() {
    switch (_filterType) {
      case ReportFilterType.singleDate:
        return _DatePickerRow(
          label: 'Select Date',
          date: _singleDate,
          fmt: _fmt,
          onTap: () async {
            final d = await _pickDate(context, _singleDate);
            if (d != null) setState(() => _singleDate = d);
          },
        );

      case ReportFilterType.dateRange:
        return Column(
          children: [
            _DatePickerRow(
              label: 'From Date',
              date: _fromDate,
              fmt: _fmt,
              onTap: () async {
                final d = await _pickDate(context, _fromDate);
                if (d != null) setState(() => _fromDate = d);
              },
            ),
            const SizedBox(height: 10),
            _DatePickerRow(
              label: 'To Date',
              date: _toDate,
              fmt: _fmt,
              onTap: () async {
                final d = await _pickDate(context, _toDate);
                if (d != null) setState(() => _toDate = d);
              },
            ),
          ],
        );

      case ReportFilterType.exactPackage:
        return TextField(
          controller: _exactPackageCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))
          ],
          decoration: InputDecoration(
            labelText: 'Package Amount (₹)',
            prefixIcon:
                const Icon(Icons.currency_rupee, color: Color(0xFF00695C)),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        );

      case ReportFilterType.packageRange:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minPackageCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}$'))
                ],
                decoration: InputDecoration(
                  labelText: 'Min (₹)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('to', style: TextStyle(color: Colors.grey)),
            ),
            Expanded(
              child: TextField(
                controller: _maxPackageCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}$'))
                ],
                decoration: InputDecoration(
                  labelText: 'Max (₹)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case ReportFilterType.all:
      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00695C).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.grey[500], size: 18),
              const SizedBox(width: 8),
              Text(
                'All ${widget.allPatients.length} patients will be included',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        );
    }
  }

  Future<DateTime?> _pickDate(
      BuildContext context, DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF00695C)),
        ),
        child: child!,
      ),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00695C).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF00695C) : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? const Color(0xFF00695C) : Colors.grey,
                size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? const Color(0xFF00695C)
                            : Colors.black87,
                      )),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip2({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00695C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? const Color(0xFF00695C) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateFormat fmt;
  final VoidCallback onTap;

  const _DatePickerRow({
    required this.label,
    required this.date,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: Color(0xFF00695C), size: 18),
            const SizedBox(width: 10),
            Text(
              date != null ? fmt.format(date!) : label,
              style: TextStyle(
                fontSize: 13,
                color: date != null ? Colors.black87 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Patient Card (unchanged) ─────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final UserRole userRole;

  const _PatientCard({required this.patient, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).pushNamed(
            '/patient-detail',
            arguments: patient.id,
          ) as bool?;
          if (result == true && context.mounted) {
            Provider.of<PatientProvider>(context, listen: false).refresh();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00695C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_open,
                        color: Color(0xFF00695C), size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient.patientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (patient.date != null) _infoText('Date: ${patient.date}'),
              if (patient.phone != null && userRole != UserRole.accountant)
                _infoText('Contact: ${patient.phone}'),
              if (patient.package != null)
                _infoText('Plan: ${patient.package}'),
              if (userRole != UserRole.secretary) ...[
                if (patient.cash != null)
                  _infoText('Cash: ${patient.cash}',
                      color: Colors.green[700]),
                if (patient.balance != null)
                  _infoText('Pending: ${patient.balance}',
                      color: Colors.orange[700]),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child:
                    Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoText(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color ?? Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}