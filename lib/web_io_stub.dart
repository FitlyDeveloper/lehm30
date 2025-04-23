// This file provides stub implementations of dart:io classes for web

import 'dart:typed_data';

// A minimal stub implementation of the File class for web
class File {
  final String path;

  File(this.path);

  bool existsSync() {
    // On web, we can't check file existence synchronously
    return true;
  }

  Future<Uint8List> readAsBytes() async {
    // This will never be called on web, we use different logic
    throw UnsupportedError('File operations are not supported on web');
  }

  Uint8List readAsBytesSync() {
    // This will never be called on web, we use different logic
    throw UnsupportedError('File operations are not supported on web');
  }

  Future<String> readAsString() async {
    // This will never be called on web, we use different logic
    throw UnsupportedError('File operations are not supported on web');
  }
}

// Stub implementation of Platform for web
class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
}
