// This file is used in non-web platforms
// It contains the real platform imports for mobile/desktop

import 'dart:io';
import 'dart:typed_data';

export 'dart:io';

class PlatformHandler {
  static bool fileExists(String path) {
    return File(path).existsSync();
  }

  static Future<Uint8List> readFileAsBytes(String path) async {
    return await File(path).readAsBytes();
  }

  static Future<String> readFileAsString(String path) async {
    return await File(path).readAsString();
  }
}
