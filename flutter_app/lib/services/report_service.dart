// lib/services/report_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/patient.dart';
import '../models/user.dart';

// Web-only import handled via conditional
import 'report_download_web.dart'
    if (dart.library.io) 'report_download_stub.dart';

class ReportService {
  // ─── Generate CSV bytes based on report type and role ───────────────────

  static List<int> generateSummaryCSV(
      List<Patient> patients, UserRole role) {
    final rows = <List<String>>[];

    // Headers based on role
    final headers = _summaryHeaders(role);
    rows.add(headers);

    for (final p in patients) {
      rows.add(_summaryRow(p, role));
    }

    return _encodeCSV(rows);
  }

  static List<int> generateDetailCSV(
      List<Patient> patients, UserRole role) {
    final rows = <List<String>>[];

    // Detail report headers
    if (role == UserRole.secretary) {
      rows.add(['Patient Name', 'Registration Date', 'Phone', 'Address', 'Package']);
      for (final p in patients) {
        rows.add([
          p.patientName,
          p.date ?? '',
          p.phone ?? '',
          p.address ?? '',
          p.package ?? '',
        ]);
      }
    } else {
      // Owner and Accountant see transaction detail
      rows.add([
        'Patient Name',
        'Registration Date',
        'Transaction Type',
        'Transaction Date',
        'Amount (₹)',
        'Running Balance (₹)',
      ]);

      for (final p in patients) {
        final packageAmt = double.tryParse(p.package ?? '0') ?? 0;
        double running = packageAmt;

        // Collect all entries and sort by date
        final allEntries = <Map<String, String>>[];

        for (final e in (p.cashEntries ?? [])) {
          allEntries.add({
            'type': 'Cash',
            'date': e.entryDate,
            'amount': e.amount,
          });
        }
        for (final e in (p.bankEntries ?? [])) {
          allEntries.add({
            'type': 'Bank',
            'date': e.entryDate,
            'amount': e.amount,
          });
        }

        // Sort by date ascending
        allEntries.sort((a, b) {
          final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
          return da.compareTo(db);
        });

        if (allEntries.isEmpty) {
          // Patient with no entries — show one row
          rows.add([
            p.patientName,
            p.date ?? '',
            '-',
            '-',
            '-',
            running.toStringAsFixed(2),
          ]);
        } else {
          for (final entry in allEntries) {
            final amt = double.tryParse(entry['amount'] ?? '0') ?? 0;
            running -= amt;
            rows.add([
              p.patientName,
              p.date ?? '',
              entry['type'] ?? '',
              entry['date'] ?? '',
              amt.toStringAsFixed(2),
              running.toStringAsFixed(2),
            ]);
          }
        }
      }
    }

    return _encodeCSV(rows);
  }

  // ─── Download the CSV file ────────────────────────────────────────────────

  static Future<String> downloadCSV({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      downloadCSVWeb(bytes, fileName);
      return 'Downloaded as $fileName';
    } else {
      return await downloadCSVMobile(bytes, fileName);
    }
  }

  // ─── Filter patients ──────────────────────────────────────────────────────

  static List<Patient> applyReportFilter(
    List<Patient> patients,
    ReportFilter filter,
  ) {
    return patients.where((p) {
      // Date filters
      if (filter.filterType == ReportFilterType.singleDate &&
          filter.singleDate != null) {
        if (p.date == null) return false;
        final pd = DateTime.tryParse(p.date!);
        if (pd == null) return false;
        final fd = filter.singleDate!;
        return pd.year == fd.year &&
            pd.month == fd.month &&
            pd.day == fd.day;
      }

      if (filter.filterType == ReportFilterType.dateRange &&
          filter.fromDate != null &&
          filter.toDate != null) {
        if (p.date == null) return false;
        final pd = DateTime.tryParse(p.date!);
        if (pd == null) return false;
        return !pd.isBefore(filter.fromDate!) &&
            !pd.isAfter(filter.toDate!);
      }

      // Package filters
      if (filter.filterType == ReportFilterType.exactPackage &&
          filter.exactPackage != null) {
        final pkg = double.tryParse(p.package ?? '');
        return pkg != null &&
            pkg == filter.exactPackage;
      }

      if (filter.filterType == ReportFilterType.packageRange &&
          filter.minPackage != null &&
          filter.maxPackage != null) {
        final pkg = double.tryParse(p.package ?? '');
        return pkg != null &&
            pkg >= filter.minPackage! &&
            pkg <= filter.maxPackage!;
      }

      return true; // all patients
    }).toList();
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static List<String> _summaryHeaders(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return [
          'ID', 'Registration Date', 'Patient Name',
          'Phone', 'Address', 'Package (₹)',
          'Total Cash (₹)', 'Total Bank (₹)', 'Balance (₹)',
        ];
      case UserRole.accountant:
        return [
          'ID', 'Registration Date', 'Patient Name',
          'Package (₹)', 'Total Cash (₹)', 'Total Bank (₹)', 'Balance (₹)',
        ];
      case UserRole.secretary:
        return [
          'ID', 'Registration Date', 'Patient Name',
          'Phone', 'Address', 'Package',
        ];
    }
  }

  static List<String> _summaryRow(Patient p, UserRole role) {
    final cashTotal = (p.cashEntries ?? [])
        .fold<double>(0, (s, e) => s + (double.tryParse(e.amount) ?? 0));
    final bankTotal = (p.bankEntries ?? [])
        .fold<double>(0, (s, e) => s + (double.tryParse(e.amount) ?? 0));
    final pkg = double.tryParse(p.package ?? '0') ?? 0;
    final balance = pkg - cashTotal - bankTotal;

    switch (role) {
      case UserRole.owner:
        return [
          p.id,
          p.date ?? '',
          p.patientName,
          p.phone ?? '',
          p.address ?? '',
          pkg.toStringAsFixed(2),
          cashTotal.toStringAsFixed(2),
          bankTotal.toStringAsFixed(2),
          balance.toStringAsFixed(2),
        ];
      case UserRole.accountant:
        return [
          p.id,
          p.date ?? '',
          p.patientName,
          pkg.toStringAsFixed(2),
          cashTotal.toStringAsFixed(2),
          bankTotal.toStringAsFixed(2),
          balance.toStringAsFixed(2),
        ];
      case UserRole.secretary:
        return [
          p.id,
          p.date ?? '',
          p.patientName,
          p.phone ?? '',
          p.address ?? '',
          p.package ?? '',
        ];
    }
  }

  static List<int> _encodeCSV(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCSV).join(','));
    }
    return utf8.encode(buffer.toString());
  }

  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

// ─── Filter model ─────────────────────────────────────────────────────────────

enum ReportFilterType {
  all,
  singleDate,
  dateRange,
  exactPackage,
  packageRange,
}

enum ReportType {
  summary,
  detail,
}

class ReportFilter {
  final ReportFilterType filterType;
  final DateTime? singleDate;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double? exactPackage;
  final double? minPackage;
  final double? maxPackage;

  const ReportFilter({
    this.filterType = ReportFilterType.all,
    this.singleDate,
    this.fromDate,
    this.toDate,
    this.exactPackage,
    this.minPackage,
    this.maxPackage,
  });
}