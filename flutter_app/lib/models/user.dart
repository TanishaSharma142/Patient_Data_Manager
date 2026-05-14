// lib/models/user.dart

enum UserRole { owner, accountant, secretary }

class User {
  final String id;
  final String username;
  final String email;
  final UserRole role;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: _parseRole(json['role'] ?? 'OWNER'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'role': role.toString().split('.').last.toUpperCase(),
  };

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
