// lib/screens/patient_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';
import '../models/patient.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({Key? key}) : super(key: key);

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _activeFilter; // 'today', 'week', 'month', 'all'

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

    // Apply date filter
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

    // Apply name search
    if (_searchQuery.isNotEmpty) {
      patients = patients.where((p) =>
          p.patientName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return patients;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final patientProvider = Provider.of<PatientProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00695C),
        title: const Text('Records'),
        actions: [
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00695C)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Date filter chips (only)
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00695C)),
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
                        Text(
                          provider.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.refresh(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                          ),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                        Text(
                          'No records match filters',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
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
                      itemBuilder: (context, index) {
                        return _PatientCard(
                          patient: filtered[index],
                          userRole: authProvider.user?.role ?? UserRole.secretary,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (authProvider.user?.role ?? UserRole.secretary) != UserRole.accountant
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00695C),
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed('/add-patient') as bool?;
                if (result == true && mounted) {
                  patientProvider.refresh();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDateChip(String label, String filterValue) {
    final isActive = _activeFilter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = isActive ? null : filterValue;
        });
      },
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
              subtitle: Text('Role: ${authProvider.user?.role.toString().split('.').last}'),
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
                title: const Text(
                  'System Reset',
                  style: TextStyle(color: Colors.red),
                ),
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

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final UserRole userRole;

  const _PatientCard({
    required this.patient,
    required this.userRole,
  });

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
                    child: const Icon(Icons.folder_open, color: Color(0xFF00695C), size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient.patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              if (patient.package != null) _infoText('Plan: ${patient.package}'),
              if (userRole != UserRole.secretary) ...[
                if (patient.cash != null)
                  _infoText('Cash: ${patient.cash}', color: Colors.green[700]),
                if (patient.balance != null)
                  _infoText('Pending: ${patient.balance}', color: Colors.orange[700]),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
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