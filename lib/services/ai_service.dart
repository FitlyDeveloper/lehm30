// Simple AIService implementation without Firebase dependencies
// Uses the FoodAnalyzerApi for image analysis

import 'dart:typed_data';
import 'package:fitness_app/services/food_analyzer_api.dart';

class AIService {
  /// Function to analyze a food image using our Render.com API
  Future<Map<String, dynamic>> analyzeFoodImage(Uint8List imageBytes) async {
    try {
      // We use the FoodAnalyzerApi class directly
      return await FoodAnalyzerApi.analyzeFoodImage(imageBytes);
    } catch (e) {
      print('AI Service: Error analyzing food: $e');

      // Fallback to simple response in case of error
      return {
        'text':
            'Sorry, I couldn\'t analyze this image. Please try again with a clearer photo of your food.'
      };
    }
  }
}
