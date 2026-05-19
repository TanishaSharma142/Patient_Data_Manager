// lib/services/secure_storage_stub.dart
// This file is compiled on non-web builds (dart.library.io is available)
// All functions are no-ops because mobile uses flutter_secure_storage directly

void webStorageWrite(String key, String value) {}

String? webStorageRead(String key) => null;

void webStorageDelete(String key) {}

void webStorageClear() {}