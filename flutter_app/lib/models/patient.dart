// lib/models/patient.dart

class CashEntry {
  final String id;
  final String entryDate;
  final String amount;

  CashEntry({
    required this.id,
    required this.entryDate,
    required this.amount,
  });

  factory CashEntry.fromJson(Map<String, dynamic> json) {
    return CashEntry(
      id: json['id'] ?? '',
      entryDate: json['entryDate'] ?? '',
      amount: json['amount']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entryDate': entryDate,
    'amount': amount,
  };
}

class BankEntry {
  final String id;
  final String entryDate;
  final String amount;

  BankEntry({
    required this.id,
    required this.entryDate,
    required this.amount,
  });

  factory BankEntry.fromJson(Map<String, dynamic> json) {
    return BankEntry(
      id: json['id'] ?? '',
      entryDate: json['entryDate'] ?? '',
      amount: json['amount']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entryDate': entryDate,
    'amount': amount,
  };
}

class Patient {
  final String id;
  final String? date;
  final String patientName;
  final String? countryCode;
  final String? phone;
  final String? address;
  final String? package;
  final String? cash;
  final String? bank;
  final String? balance;
  final List<CashEntry>? cashEntries;
  final List<BankEntry>? bankEntries;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    required this.id,
    this.date,
    required this.patientName,
    this.countryCode,
    this.phone,
    this.address,
    this.package,
    this.cash,
    this.bank,
    this.balance,
    this.cashEntries,
    this.bankEntries,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? '',
      date: json['date'] != null
          ? (DateTime.tryParse(json['date'])?.toIso8601String().split('T')[0] ?? json['date'])
          : null,
      patientName: json['patientName'] ?? '',
      countryCode: json['countryCode'],
      phone: json['phone'],
      address: json['address'],
      package: json['package']?.toString(),
      cash: json['cash']?.toString(),
      bank: json['bank']?.toString(),
      balance: json['balance']?.toString(),
      cashEntries: json['cashEntries'] != null
          ? (json['cashEntries'] as List)
              .map((entry) => CashEntry.fromJson(entry as Map<String, dynamic>))
              .toList()
          : null,
      bankEntries: json['bankEntries'] != null
          ? (json['bankEntries'] as List)
              .map((entry) => BankEntry.fromJson(entry as Map<String, dynamic>))
              .toList()
          : null,
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
    'countryCode': countryCode,
    'phone': phone,
    'address': address,
    'package': package,
    'cash': cash,
    'bank': bank,
    'balance': balance,
    'cashEntries': cashEntries?.map((entry) => entry.toJson()).toList(),
    'bankEntries': bankEntries?.map((entry) => entry.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Patient copyWith({
    String? id,
    String? date,
    String? patientName,
    String? countryCode,
    String? phone,
    String? address,
    String? package,
    String? cash,
    String? bank,
    String? balance,
    List<CashEntry>? cashEntries,
    List<BankEntry>? bankEntries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      date: date ?? this.date,
      patientName: patientName ?? this.patientName,
      countryCode: countryCode ?? this.countryCode,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      package: package ?? this.package,
      cash: cash ?? this.cash,
      bank: bank ?? this.bank,
      balance: balance ?? this.balance,
      cashEntries: cashEntries ?? this.cashEntries,
      bankEntries: bankEntries ?? this.bankEntries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
