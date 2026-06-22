// lib/models/user.dart

enum UserRole { owner, accountant, secretary }

class User {
  final String id;
  final String username;
  final String email;
  final UserRole role;
  final bool mustChangePassword;
  final String? backupEmail;
  final bool backupEmailVerified;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.mustChangePassword = false,
    this.backupEmail,
    this.backupEmailVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Safely extract each field with type checking
    final id = (json['id'] as String?)?.trim() ?? '';
    final username = (json['username'] as String?)?.trim() ?? '';
    final email = (json['email'] as String?)?.trim() ?? '';
    final roleString = (json['role'] as String?)?.trim().toUpperCase() ?? 'OWNER';
    
    // Validate required fields
    if (id.isEmpty || username.isEmpty) {
      throw FormatException('User.fromJson: missing required fields (id, username)');
    }
    
    return User(
      id: id,
      username: username,
      email: email,
      role: _parseRole(roleString),
      mustChangePassword: json['mustChangePassword'] == true,
      backupEmail: json['backupEmail'] as String?,
      backupEmailVerified: json['backupEmailVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'role': role.toString().split('.').last.toUpperCase(),
    'mustChangePassword': mustChangePassword,
    'backupEmail': backupEmail,
    'backupEmailVerified': backupEmailVerified,
  };

  User copyWith({
    String? id,
    String? username,
    String? email,
    UserRole? role,
    bool? mustChangePassword,
    String? backupEmail,
    bool? backupEmailVerified,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      backupEmail: backupEmail ?? this.backupEmail,
      backupEmailVerified: backupEmailVerified ?? this.backupEmailVerified,
    );
  }

  static UserRole _parseRole(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return UserRole.owner;
      case 'ACCOUNTANT':
        return UserRole.accountant;
      case 'SECRETARY':
        return UserRole.secretary;
      default:
        return UserRole.secretary;
    }
  }

  bool get isOwner => role == UserRole.owner;
  bool get isAccountant => role == UserRole.accountant;
  bool get isSecretary => role == UserRole.secretary;
}
