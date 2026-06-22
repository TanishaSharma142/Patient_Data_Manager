// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/patient_provider.dart';
import 'screens/login_screen.dart';
import 'screens/patient_list_screen.dart';
import 'screens/patient_detail_screen.dart';
import 'screens/add_patient_screen.dart';
import 'screens/panic_wipe_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/staff_management_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'IVF Patient Manager',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const PatientListScreen(),
          '/add-patient': (context) => const AddPatientScreen(),
          '/patient-detail': (context) => PatientDetailScreen(
            patientId: ModalRoute.of(context)!.settings.arguments as String,
          ),
          '/panic-wipe': (context) => const PanicWipeScreen(),
          '/activity': (context) => const ActivityScreen(),
          '/change-password': (context) => const ChangePasswordScreen(),
          '/staff-management': (context) => const StaffManagementScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading && !authProvider.isAuthenticated) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          if (authProvider.mustChangePassword) {
            return const ChangePasswordScreen();
          }
          return const PatientListScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
