// lib/screens/panic_wipe_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class PanicWipeScreen extends StatefulWidget {
  const PanicWipeScreen({Key? key}) : super(key: key);

  @override
  State<PanicWipeScreen> createState() => _PanicWipeScreenState();
}

class _PanicWipeScreenState extends State<PanicWipeScreen> {
  final _pinControllers = List<TextEditingController>.generate(6, (_) => TextEditingController());
  bool _isExecuting = false;
  bool _confirmUnderstanding = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Set the API token
    final token = Provider.of<AuthProvider>(context, listen: false).user;
    if (token != null) {
      // In a real app, get the token from secure storage
    }
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _enteredPin => _pinControllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        backgroundColor: Colors.red[600],
        title: const Text('Alarm Erase - Panic Wipe'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Warning icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                size: 64,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 24),

            // Warning text
            Text(
              'ALARM ERASE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Permanent Data Deletion',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 32),

            // Warning message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'WARNING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This action will:\n'
                    '• Create a final encrypted backup\n'
                    '• Email the backup to your configured address\n'
                    '• PERMANENTLY DELETE all patient records\n'
                    '• This cannot be undone!',
                    style: TextStyle(
                      color: Colors.red[700],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // PIN entry
            Text(
              'Enter 6-Digit Panic PIN',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 16),
            _buildPinEntry(),
            const SizedBox(height: 32),

            // Confirm checkbox
            CheckboxListTile(
              value: _confirmUnderstanding,
              onChanged: (value) {
                setState(() {
                  _confirmUnderstanding = value ?? false;
                });
              },
              title: Text(
                'I understand this will permanently delete all data',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Execute button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _enteredPin.length == 6 && _confirmUnderstanding
                    ? _executePanicWipe
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isExecuting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'EXECUTE PANIC WIPE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red[600]!),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        6,
        (index) => SizedBox(
          width: 50,
          child: TextField(
            controller: _pinControllers[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                FocusScope.of(context).nextFocus();
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).previousFocus();
              }
              setState(() {});
            },
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[600]!, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executePanicWipe() async {
    if (_enteredPin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit PIN'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show final confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: const Text('FINAL CONFIRMATION'),
        content: const Text(
          'This will IMMEDIATELY:\n\n'
          '1. Backup all patient data\n'
          '2. Send backup to email\n'
          '3. PERMANENTLY DELETE all records\n\n'
          'This cannot be undone!',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CONTINUE WITH PANIC WIPE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isExecuting = true;
    });

    try {
      final result = await _apiService.executePanicWipe(_enteredPin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Panic wipe completed'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Redirect to login after a delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await Provider.of<AuthProvider>(context, listen: false).logout();
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }
}
