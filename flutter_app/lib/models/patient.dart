// lib/models/patient.dart

class Patient {
  final String id;
  final String? date;
  final String patientName;
  final String? phone;
  final String? address;
  final String? package;
  final String? cash;
  final String? bank;
  final String? balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    required this.id,
    this.date,
    required this.patientName,
    this.phone,
    this.address,
    this.package,
    this.cash,
    this.bank,
    this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? '',
      date: json['date'],
      patientName: json['patientName'],
      phone: json['phone'],
      address: json['address'],
      package: json['package'],
      cash: json['cash'],
      bank: json['bank'],
      balance: json['balance'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'patientName': patientName,
    'phone': phone,
    'address': address,
    'package': package,
    'cash': cash,
    'bank': bank,
    'balance': balance,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Patient copyWith({
    String? id,
    String? date,
    String? patientName,
    String? phone,
    String? address,
    String? package,
    String? cash,
    String? bank,
    String? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      date: date ?? this.date,
      patientName: patientName ?? this.patientName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      package: package ?? this.package,
      cash: cash ?? this.cash,
      bank: bank ?? this.bank,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
