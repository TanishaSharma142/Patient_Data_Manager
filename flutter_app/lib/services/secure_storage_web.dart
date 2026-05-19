// lib/services/secure_storage_web.dart
// This file is only compiled on web builds (dart.library.html is available)
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void webStorageWrite(String key, String value) {
  html.window.sessionStorage[key] = value;
}

String? webStorageRead(String key) {
  return html.window.sessionStorage[key];
}

void webStorageDelete(String key) {
  html.window.sessionStorage.remove(key);
}

void webStorageClear() {
  html.window.sessionStorage.clear();
}