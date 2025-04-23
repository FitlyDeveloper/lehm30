import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FoodAnalyzerApi {
  // Base URL of our Render.com API server
  static const String baseUrl = 'https://snap-food.onrender.com';

  // Endpoint for food analysis
  static const String analyzeEndpoint = '/api/analyze-food';

  // Method to analyze a food image
  static Future<Map<String, dynamic>> analyzeFoodImage(
      Uint8List imageBytes) async {
    try {
      // Convert image bytes to base64
      final String base64Image = base64Encode(imageBytes);
      final String dataUri = 'data:image/jpeg;base64,$base64Image';

      // Call our secure API endpoint
      final response = await http
          .post(
            Uri.parse('$baseUrl$analyzeEndpoint'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'image': dataUri}),
          )
          .timeout(const Duration(seconds: 30));

      // Check for HTTP errors
      if (response.statusCode != 200) {
        print('API error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to analyze image: ${response.statusCode}');
      }

      // Parse the response
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      // Check for API-level errors
      if (responseData['success'] != true) {
        throw Exception('API error: ${responseData['error']}');
      }

      // Return the data
      return responseData['data'];
    } catch (e) {
      print('Error analyzing food image: $e');
      rethrow;
    }
  }

  // Check if the API is available
  static Future<bool> checkApiAvailability() async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('API unavailable: $e');
      return false;
    }
  }
}
