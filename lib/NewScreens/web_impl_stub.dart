// This is a stub implementation for non-web platforms
import 'dart:typed_data';

// Stub implementation that just returns the original bytes
Future<String> getWebImageBase64(String imagePath) async {
  throw UnsupportedError(
      'getWebImageBase64 is only supported on web platforms');
}

// Stub implementation that just returns the original bytes
Future<Uint8List> resizeWebImage(Uint8List sourceBytes, int targetWidth,
    {double quality = 0.85}) async {
  return sourceBytes;
}

// Stub implementation that just returns the original bytes
Future<Uint8List> createTinyJpeg(Uint8List originalBytes,
    {int size = 300}) async {
  return originalBytes;
}
