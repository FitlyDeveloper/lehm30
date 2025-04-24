// Web-specific implementation
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import 'dart:js' as js;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

Future<String> getWebImageBase64(String imagePath) async {
  try {
    // Handle different types of URLs
    if (imagePath.startsWith('blob:')) {
      // For blob URLs, first try the fetch API
      try {
        final blob = await _fetchBlob(imagePath);
        final bytes = await _blobToBytes(blob);
        return base64Encode(bytes);
      } catch (blobError) {
        print('Error using blob methods: $blobError');
        // Fallback to http client
        final response = await http.get(Uri.parse(imagePath));
        if (response.statusCode == 200) {
          return base64Encode(response.bodyBytes);
        } else {
          throw Exception(
              'Failed to load image from blob URL: ${response.statusCode}');
        }
      }
    } else if (imagePath.startsWith('data:')) {
      // For data URLs, extract the base64 part
      final String dataUrl = imagePath;
      final int commaIndex = dataUrl.indexOf(',');
      if (commaIndex != -1 && dataUrl.contains('base64')) {
        // Extract the base64 part after the comma
        return dataUrl.substring(commaIndex + 1);
      } else {
        throw Exception('Invalid data URL format');
      }
    } else {
      // For regular URLs
      final response = await http.get(Uri.parse(imagePath));
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      } else {
        throw Exception(
            'Failed to load image from URL: ${response.statusCode}');
      }
    }
  } catch (e) {
    print('Error in getWebImageBase64: $e');
    rethrow;
  }
}

// Fetch blob using JS interop
Future<html.Blob> _fetchBlob(String url) async {
  final completer = Completer<html.Blob>();

  final xhr = html.HttpRequest();
  xhr.open('GET', url);
  xhr.responseType = 'blob';

  xhr.onLoad.listen((event) {
    if (xhr.status == 200) {
      completer.complete(xhr.response as html.Blob);
    } else {
      completer.completeError('Failed to load blob: ${xhr.status}');
    }
  });

  xhr.onError.listen((event) {
    completer.completeError('XHR error loading blob');
  });

  xhr.send();
  return completer.future;
}

// Convert blob to bytes
Future<Uint8List> _blobToBytes(html.Blob blob) async {
  final completer = Completer<Uint8List>();
  final reader = html.FileReader();

  reader.onLoadEnd.listen((event) {
    final result = reader.result;
    if (result is Uint8List) {
      completer.complete(result);
    } else {
      completer.completeError('Failed to read blob as bytes');
    }
  });

  reader.onError.listen((event) {
    completer.completeError('Error reading blob');
  });

  reader.readAsArrayBuffer(blob);
  return completer.future;
}

// Resize an image using HTML canvas
Future<Uint8List> resizeWebImage(Uint8List sourceBytes, int targetWidth,
    {double quality = 0.85}) async {
  if (!kIsWeb) return sourceBytes;

  try {
    final completer = Completer<Uint8List>();

    // Create a blob from the bytes
    final blob = html.Blob([sourceBytes]);
    final url = html.Url.createObjectUrl(blob);

    // Create an image element
    final img = html.ImageElement();

    // Handle image load
    img.onLoad.listen((_) {
      try {
        // Calculate new dimensions preserving aspect ratio
        final aspectRatio = img.width! / img.height!;
        final targetHeight = (targetWidth / aspectRatio).round();

        // Create canvas for resizing
        final canvas = html.CanvasElement(
          width: targetWidth,
          height: targetHeight,
        );
        final ctx = canvas.context2D;

        // Enable image smoothing
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';

        // Draw resized image to canvas
        ctx.drawImageScaled(img, 0, 0, targetWidth, targetHeight);

        // Convert to JPEG with the specified quality (default 85%)
        final dataUrl = canvas.toDataUrl('image/jpeg', quality);

        // Extract base64 data
        final base64Data = dataUrl.split(',')[1];
        final resizedBytes = base64Decode(base64Data);

        // Clean up
        html.Url.revokeObjectUrl(url);

        print(
            "Image resized: ${sourceBytes.length} bytes -> ${resizedBytes.length} bytes");

        // Return the result
        completer.complete(resizedBytes);
      } catch (e) {
        print('Error in canvas operations: $e');
        completer.completeError('Canvas error: $e');
      }
    });

    // Handle load errors
    img.onError.listen((event) {
      html.Url.revokeObjectUrl(url);
      completer.completeError('Error loading image for resizing');
    });

    // Start loading the image
    img.src = url;

    // Return a fallback if the operation fails or times out
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('Resize timed out, returning original');
        return sourceBytes;
      },
    ).catchError((error) {
      print('Resize error, returning original: $error');
      return sourceBytes;
    });
  } catch (e) {
    print('Error in resizeWebImage: $e');
    return sourceBytes;
  }
}

// Create a very small JPEG
Future<Uint8List> createTinyJpeg(Uint8List originalBytes,
    {int size = 300}) async {
  try {
    if (!kIsWeb) return originalBytes;

    // Convert original bytes to blob
    final blob = html.Blob([originalBytes]);
    final url = html.Url.createObjectUrl(blob);

    final completer = Completer<Uint8List>();
    final img = html.ImageElement();

    img.onLoad.listen((_) {
      try {
        // Create a small canvas
        final canvas = html.CanvasElement(width: size, height: size);
        final ctx = canvas.context2D;

        // Calculate how to center and scale the image
        int srcX = 0, srcY = 0, srcW = img.width!, srcH = img.height!;
        final aspectRatio = srcW / srcH;

        if (aspectRatio > 1) {
          // Image is wider than tall
          srcW = (srcH * aspectRatio).toInt();
          srcX = ((img.width! - srcW) / 2).round();
        } else {
          // Image is taller than wide
          srcH = (srcW / aspectRatio).toInt();
          srcY = ((img.height! - srcH) / 2).round();
        }

        // Draw the image centered and scaled
        ctx.drawImageScaledFromSource(
            img,
            srcX,
            srcY,
            srcW,
            srcH, // Source rectangle
            0,
            0,
            size,
            size // Destination rectangle
            );

        // Get very low quality JPEG
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.1);
        final base64Data = dataUrl.split(',')[1];

        // Clean up
        html.Url.revokeObjectUrl(url);

        completer.complete(base64Decode(base64Data));
      } catch (e) {
        print('Error in tiny JPEG creation: $e');
        html.Url.revokeObjectUrl(url);
        completer.completeError(e);
      }
    });

    img.onError.listen((event) {
      html.Url.revokeObjectUrl(url);
      completer.completeError('Error loading image for tiny JPEG creation');
    });

    // Start loading
    img.src = url;

    return completer.future
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => originalBytes,
        )
        .catchError((e) => originalBytes);
  } catch (e) {
    print('createTinyJpeg error: $e');
    return originalBytes;
  }
}
