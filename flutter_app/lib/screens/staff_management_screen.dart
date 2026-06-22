import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({Key? key}) : super(key: key);

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _usernameController = TextEditingController();
  final _backupEmailController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  String _role = 'ACCOUNTANT';
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _lastCreatedUser;
  String? _lastTempPassword;
  bool _showVerificationForm = false;
  String? _deliveryHintCode;

  ApiService get _apiService => ApiService();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _backupEmailController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _apiService.getUsers();
      setState(() {
        _users = users;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createUser() async {
    final username = _usernameController.text.trim();
    final email = '$username@example.com';
    final role = _role;

    if (username.isEmpty) {
      setState(() {
        _error = 'Username is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _lastCreatedUser = null;
      _lastTempPassword = null;
    });

    try {
      final result = await _apiService.createUser(username, email, role);
      final tempPassword = result['tempPassword'] ?? 'N/A';
      setState(() {
        _lastCreatedUser = result['data'];
        _lastTempPassword = tempPassword;
      });
      _usernameController.clear();
      _role = 'ACCOUNTANT';
      await _loadUsers();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword(String userId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _lastCreatedUser = null;
      _lastTempPassword = null;
    });

    try {
      final result = await _apiService.resetUserPassword(userId);
      final tempPassword = result['tempPassword'] ?? 'N/A';
      setState(() {
        _lastCreatedUser = result['data'];
        _lastTempPassword = tempPassword;
      });
      await _loadUsers();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(String userId, String username, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete $username ($role)?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _apiService.deleteUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$username deleted successfully')),
      );
      await _loadUsers();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _setBackupEmail() async {
    final email = _backupEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Backup email is required');
      return;
    }

    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}");
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Invalid email format');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.setBackupEmail(email);
      setState(() {
        _showVerificationForm = true;
        _backupEmailController.clear();
        _deliveryHintCode = result['emailSent'] == false ? result['verificationCode'] as String? : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Verification code sent')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyBackupEmail() async {
    final code = _verificationCodeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() => _error = 'Enter the 6-digit verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.verifyBackupEmail(code);
      setState(() {
        _showVerificationForm = false;
        _verificationCodeController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup email verified: ${result['backupEmail']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = authProvider.user?.isOwner == true;

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Staff Management'),
          backgroundColor: const Color(0xFF00695C),
        ),
        body: const Center(
          child: Text('Access denied'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: const Color(0xFF00695C),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_lastCreatedUser != null && _lastTempPassword != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300]!, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User: ${_lastCreatedUser!['username']}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _lastTempPassword!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () => _copyToClipboard(_lastTempPassword!, 'Password'),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '⚠️  Share this password securely. User must change it on first login.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                          ),
                          onPressed: () => setState(() {
                            _lastCreatedUser = null;
                            _lastTempPassword = null;
                          }),
                          child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'Create staff account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'OWNER', child: Text('Owner')),
                  DropdownMenuItem(value: 'ACCOUNTANT', child: Text('Accountant')),
                  DropdownMenuItem(value: 'SECRETARY', child: Text('Secretary')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _createUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Backup email',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Set a backup email for account recovery',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (!_showVerificationForm) ...[
                TextField(
                  controller: _backupEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Backup email address',
                    hintText: 'backup@example.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _setBackupEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Send verification code'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verification code sent!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check your email for a 6-digit verification code.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (_deliveryHintCode != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Email delivery failed. Your code is: $_deliveryHintCode',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _verificationCodeController,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Verification code',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyBackupEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Verify'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _showVerificationForm = false;
                                  _verificationCodeController.clear();
                                  _deliveryHintCode = null;
                                  _error = null;
                                }),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Existing staff',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_isLoading && _users.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (_users.isEmpty)
                const Center(child: Text('No staff accounts found.'))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isCurrentUser = user['id'] == authProvider.user?.id;
                    final isOwner = user['role'] == 'OWNER';
                    
                    return Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['username'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${user['email'] ?? ''} • ${user['role'] ?? ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (isCurrentUser)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                            '(Your account)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _resetPassword(user['id'] as String),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Reset password'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!isCurrentUser && !isOwner)
                                  TextButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _deleteUser(
                                              user['id'] as String,
                                              user['username'] as String,
                                              user['role'] as String,
                                            ),
                                    icon: const Icon(Icons.delete, size: 18),
                                    label: const Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
