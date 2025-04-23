// Stub implementation for non-web platforms
import 'dart:typed_data';

Future<String> getWebImageBase64(String path) async {
  throw UnsupportedError('Web image handling not supported on this platform');
}

// Stub implementation of web image resize for non-web platforms
Future<Uint8List> resizeWebImage(Uint8List sourceBytes, int targetWidth) async {
  // Just return the original bytes on non-web platforms
  return sourceBytes;
}
