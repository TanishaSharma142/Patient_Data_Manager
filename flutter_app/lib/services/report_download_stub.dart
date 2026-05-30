// lib/services/report_download_stub.dart
// Only compiled on mobile/desktop (dart.library.io is available)
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void downloadCSVWeb(List<int> bytes, String fileName) {
  // Stub — not called on mobile
}

Future<String> downloadCSVMobile(List<int> bytes, String fileName) async {
  try {
    // On Android, save to Downloads directory
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        // Fallback to app documents directory
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return 'Saved to ${file.path}';
  } catch (e) {
    throw 'Failed to save file: $e';
  }
}