import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  // Store the API key securely - in production this should come from secure storage
  // This is just for temporary development testing
  static const String _apiKey = ""; // Empty, will be set by user

  // Set the API key at runtime
  static String _runtimeApiKey = "";
  static void setApiKey(String apiKey) {
    _runtimeApiKey = apiKey;
  }

  // Check if API key has been configured
  static bool get isApiKeyConfigured => _runtimeApiKey.isNotEmpty;

  // Analyze food image using OpenAI API directly (no Firebase)
  static Future<Map<String, dynamic>> analyzeFoodImage(
      Uint8List imageBytes) async {
    // Convert image bytes to base64
    final String base64Image = base64Encode(imageBytes);
    final String dataUri = 'data:image/jpeg;base64,$base64Image';

    if (_runtimeApiKey.isEmpty) {
      throw Exception("API key not configured. Please set an API key first.");
    }

    // Make the OpenAI API request directly
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_runtimeApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a nutrition expert analyzing food images. Return detailed nutritional information in JSON format with this structure: { "meal": [{ "dish": "Name of dish", "calories": "Total calories (number only)", "macronutrients": { "protein": "grams (number only)", "carbohydrates": "grams (number only)", "fat": "grams (number only)" }, "ingredients": ["ingredient1", "ingredient2", ...] }] }'
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                      "What's in this meal? Please analyze the nutritional content and ingredients, providing calories and macronutrient breakdown."
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUri}
                }
              ]
            }
          ],
          'max_tokens': 1000
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed with status ${response.statusCode}: ${response.body}');
      }

      // Parse the response JSON
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['choices'] == null ||
          responseData['choices'].isEmpty ||
          responseData['choices'][0]['message'] == null ||
          responseData['choices'][0]['message']['content'] == null) {
        throw Exception('Invalid response format from OpenAI');
      }

      final String content = responseData['choices'][0]['message']['content'];

      // Parse the JSON response
      return _parseResult(content);
    } catch (e) {
      debugPrint('Error in OpenAI request: $e');
      throw Exception('Failed to analyze food image: $e');
    }
  }

  // Parse the JSON from the text response
  static Map<String, dynamic> _parseResult(String content) {
    try {
      // First try direct parsing
      return jsonDecode(content);
    } catch (error1) {
      // Look for JSON in markdown blocks
      final jsonMatch =
          RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(content) ??
              RegExp(r'\{[\s\S]*\}').firstMatch(content);

      if (jsonMatch != null) {
        final jsonText =
            jsonMatch.group(0)!.replaceAll(RegExp(r'```json\n|```'), '').trim();
        try {
          return jsonDecode(jsonText);
        } catch (error2) {
          // Fallback to text
          return {'text': content};
        }
      } else {
        // No JSON found
        return {'text': content};
      }
    }
  }
}
