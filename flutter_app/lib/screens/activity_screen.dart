// lib/screens/activity_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

// ─── IST converter ───────────────────────────────────────────────────────────
String toIST(String utcTimestamp) {
  final utc = DateTime.parse(utcTimestamp).toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  return DateFormat('dd MMM yyyy, hh:mm a').format(ist);
}

// ─── Human-readable description builder ──────────────────────────────────────
String describeActivity(Map<String, dynamic> log, bool isOwnerView) {
  final action = log['action'] ?? '';
  final details = log['details'] as Map<String, dynamic>? ?? {};

  // For owner's all-logs view: username comes from joined user object
  // For self-activity view: no user join needed
  final username = log['user']?['username'] as String?;
  final role = log['user']?['role'] as String?;
  final who = (username != null)
      ? '$username${role != null ? " ($role)" : ""}'
      : 'You';

  switch (action) {
    case 'LOGIN':
      return '$who logged in';

    case 'CREATE':
      final name = details['patientName'] as String?;
      return name != null
          ? '$who added patient: $name'
          : '$who added a new patient';

    case 'UPDATE':
      final name = details['patientName'] as String?;
      final fields = details['fieldsChanged'];
      String fieldStr = '';
      if (fields is List && fields.isNotEmpty) {
        fieldStr = ' (${fields.join(", ")})';
      }
      return name != null
          ? '$who updated patient: $name$fieldStr'
          : '$who updated patient record$fieldStr';

    case 'DELETE':
      final name = details['patientName'] as String?;
      return name != null
          ? '$who deleted patient: $name'
          : '$who deleted a patient record';

    case 'PANIC_WIPE':
      final count = details['recordCount'];
      return count != null
          ? '🚨 $who executed PANIC WIPE — $count records permanently deleted'
          : '🚨 $who executed PANIC WIPE — all records permanently deleted';

    case 'BACKUP':
      return '$who triggered an encrypted backup';

    case 'LOGOUT':
      return '$who logged out';

    default:
      return '$who performed: $action';
  }
}

// ─── Widget ──────────────────────────────────────────────────────────────────
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late Future<List<dynamic>> _activityFuture;
  final _apiService = ApiService();
  late bool _isOwner;

  @override
  void initState() {
    super.initState();
    // We read role once in initState; safe because auth won't change mid-session
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _isOwner = authProvider.user?.role.toString().toUpperCase().contains('OWNER') ?? false;

    // ✅ KEY FIX: Owner calls getAuditLogs() → GET /audit/logs  (sees everyone)
    //            Others call getMyActivity() → GET /audit/my-activity (sees self)
    _activityFuture = _isOwner
        ? _apiService.getAllAuditLogs()
        : _apiService.getMyActivity();
  }

  void _reload() {
    setState(() {
      _activityFuture = _isOwner
          ? _apiService.getAllAuditLogs()
          : _apiService.getMyActivity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isOwner ? 'All Activities' : 'My Activity',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _activityFuture,
        builder: (context, snapshot) {
          // ── Loading ──
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Error ──
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load activity',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Empty ──
          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, color: Colors.grey[400], size: 52),
                  const SizedBox(height: 16),
                  Text('No activity recorded yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          // ── List ──
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final log = activities[index] as Map<String, dynamic>;
              return _ActivityCard(log: log, isOwnerView: _isOwner);
            },
          );
        },
      ),
    );
  }
}

// ─── Activity Card ────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isOwnerView;

  const _ActivityCard({required this.log, required this.isOwnerView});

  @override
  Widget build(BuildContext context) {
    final action = log['action'] as String? ?? 'UNKNOWN';
    final timestamp = log['timestamp'] as String?;
    final ipAddress = log['ipAddress'] as String?;
    final resourceId = log['resourceId'] as String?;

    final _ActionStyle style = _actionStyle(action);
    final String description = describeActivity(log, isOwnerView);
    final String timeStr = timestamp != null ? toIST(timestamp) : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.borderColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon badge ──
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: style.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, color: style.iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // ── Content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action badge + description
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: style.badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: style.iconColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Human-readable description ← THE MAIN FIX
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Metadata row
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      // Time in IST
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),

                      // IP address (only for owner)
                      if (isOwnerView && ipAddress != null && ipAddress.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi, size: 13, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              ipAddress,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),

                      // Resource ID (truncated) — helpful for debugging
                      if (resourceId != null && resourceId.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fingerprint, size: 13, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              'ID: ${resourceId.length > 8 ? resourceId.substring(0, 8) : resourceId}…',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action style config ──────────────────────────────────────────────────────
class _ActionStyle {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color badgeBg;
  final Color borderColor;

  const _ActionStyle({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.badgeBg,
    required this.borderColor,
  });
}

_ActionStyle _actionStyle(String action) {
  switch (action) {
    case 'LOGIN':
      return _ActionStyle(
        icon: Icons.login_rounded,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFDCFCE7),
        badgeBg: const Color(0xFFD1FAE5),
        borderColor: const Color(0xFF16A34A),
      );
    case 'CREATE':
      return _ActionStyle(
        icon: Icons.person_add_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDBEAFE),
        badgeBg: const Color(0xFFDEEBFF),
        borderColor: const Color(0xFF2563EB),
      );
    case 'UPDATE':
      return _ActionStyle(
        icon: Icons.edit_rounded,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFEF3C7),
        badgeBg: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFD97706),
      );
    case 'DELETE':
      return _ActionStyle(
        icon: Icons.delete_rounded,
        iconColor: const Color(0xFFDC2626),
        iconBg: const Color(0xFFFEE2E2),
        badgeBg: const Color(0xFFFFF1F1),
        borderColor: const Color(0xFFDC2626),
      );
    case 'PANIC_WIPE':
      return _ActionStyle(
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFF991B1B),
        iconBg: const Color(0xFFFECACA),
        badgeBg: const Color(0xFFFECACA),
        borderColor: const Color(0xFF991B1B),
      );
    case 'BACKUP':
      return _ActionStyle(
        icon: Icons.cloud_upload_rounded,
        iconColor: const Color(0xFF7C3AED),
        iconBg: const Color(0xFFEDE9FE),
        badgeBg: const Color(0xFFF3EEFF),
        borderColor: const Color(0xFF7C3AED),
      );
    case 'LOGOUT':
      return _ActionStyle(
        icon: Icons.logout_rounded,
        iconColor: const Color(0xFF64748B),
        iconBg: const Color(0xFFF1F5F9),
        badgeBg: const Color(0xFFF8FAFC),
        borderColor: const Color(0xFF94A3B8),
      );
    default:
      return _ActionStyle(
        icon: Icons.info_rounded,
        iconColor: const Color(0xFF64748B),
        iconBg: const Color(0xFFF1F5F9),
        badgeBg: const Color(0xFFF8FAFC),
        borderColor: const Color(0xFF94A3B8),
      );
  }
}