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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final patientProvider = Provider.of<PatientProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        title: const Text('Patients'),
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
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
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
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          
          // Patients list
          Expanded(
            child: Consumer<PatientProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red[300], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final patients = _searchQuery.isEmpty
                    ? provider.patients
                    : provider.searchByQuery(_searchQuery);

                if (patients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info, color: Colors.grey[400], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No patients found'
                              : 'No results for "$_searchQuery"',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    return _PatientCard(
                      patient: patients[index],
                      userRole: authProvider.user?.role ?? UserRole.secretary,
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
              backgroundColor: Colors.blue[600],
              onPressed: () async {
                final result = await Navigator.of(context)
                    .pushNamed('/add-patient') as bool?;
                if (result == true && mounted) {
                  patientProvider.refresh();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
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
              leading: const Icon(Icons.person),
              title: Text('User: ${authProvider.user?.username}'),
              subtitle: Text('Role: ${authProvider.user?.role.toString().split('.').last}'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
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
                  'Panic Wipe',
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: () async {
          final result = await Navigator.of(context).pushNamed(
            '/patient-detail',
            arguments: patient.id,
          ) as bool?;
          
          if (result == true && context.mounted) {
            Provider.of<PatientProvider>(context, listen: false).refresh();
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.person, color: Colors.blue[600]),
        ),
        title: Text(
          patient.patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (patient.date != null)
              Text('Date: ${patient.date}', style: const TextStyle(fontSize: 12)),
            if (patient.phone != null && userRole != UserRole.accountant)
              Text('Phone: ${patient.phone}', style: const TextStyle(fontSize: 12)),
            if (patient.package != null)
              Text('Package: ${patient.package}', style: const TextStyle(fontSize: 12)),
            if (patient.cash != null && userRole != UserRole.secretary)
              Text(
                'Cash: ${patient.cash}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            if (patient.balance != null && userRole != UserRole.secretary)
              Text(
                'Balance: ${patient.balance}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
