// lib/services/report_download_web.dart
// Only compiled on web builds
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadCSVWeb(List<int> bytes, String fileName) {
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<String> downloadCSVMobile(List<int> bytes, String fileName) async {
  // Stub — not called on web
  return '';
}