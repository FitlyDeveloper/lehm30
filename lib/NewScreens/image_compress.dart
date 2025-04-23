import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// For web, we'll use our custom methods
import 'web_impl.dart' if (dart.library.io) 'web_impl_stub.dart';

// Only import the package on mobile platforms
import 'package:flutter_image_compress/flutter_image_compress.dart'
    if (dart.library.html) 'web_image_compress_stub.dart';

// Common interface for both platforms
Future<Uint8List> compressImage(
  Uint8List imageBytes, {
  int quality = 80,
  int targetWidth = 800,
}) async {
  if (kIsWeb) {
    // Use web-specific compression
    try {
      return await resizeWebImage(imageBytes, targetWidth);
    } catch (e) {
      print("Web compression error: $e");
      return imageBytes;
    }
  } else {
    // Use mobile-specific compression
    try {
      return await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: quality,
        minWidth: targetWidth,
        minHeight: targetWidth,
      );
    } catch (e) {
      print("Mobile compression error: $e");
      return imageBytes;
    }
  }
}
