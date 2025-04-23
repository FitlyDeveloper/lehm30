import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
// Remove permission_handler temporarily
// import 'package:permission_handler/permission_handler.dart';

// Conditionally import dart:io only on non-web
import 'dart:io' if (dart.library.html) 'package:fitness_app/web_io_stub.dart';

// Import our web handling code
import 'web_impl.dart' if (dart.library.io) 'web_impl_stub.dart';

// Additional imports for mobile platforms
import 'package:flutter_image_compress/flutter_image_compress.dart'
    if (dart.library.html) 'web_image_compress_stub.dart';

// Conditionally import the image compress library
// We need to use a different approach to avoid conflicts
import 'image_compress.dart';

// Add import for our secure API service
import '../services/food_analyzer_api.dart';

class SnapFood extends StatefulWidget {
  const SnapFood({super.key});

  @override
  State<StatefulWidget> createState() => _SnapFoodState();
}

class _SnapFoodState extends State<SnapFood> {
  // Track the active button
  String _activeButton = 'Scan Food'; // Default active button
  bool _permissionsRequested = false;
  bool _isAnalyzing = false; // Track if analysis is in progress

  // Food analysis result
  Map<String, dynamic>? _analysisResult;
  String? _formattedAnalysisResult;

  // Image related variables
  File? _imageFile;
  String? _webImagePath;
  Uint8List? _webImageBytes; // Add storage for web image bytes
  final ImagePicker _picker = ImagePicker();
  XFile? imageFile;
  XFile? _mostRecentImage;
  bool _pendingAnalysis = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Simplified permission check - no permission_handler
      _checkPermissionsSimple();
    }
    print("SnapFood screen initialized");
  }

  // Simplified permission check method that doesn't use permission_handler
  Future<void> _checkPermissionsSimple() async {
    if (kIsWeb) return; // Skip permission checks on web

    // For simplicity, we'll just try to use the image picker which will trigger permission prompts
    try {
      await _picker.pickImage(source: ImageSource.camera).then((_) => null);
    } catch (e) {
      print("Camera permission might be needed: $e");
      if (mounted) {
        _showPermissionsDialog();
      }
    }
  }

  void _showPermissionsDialog() {
    _showCustomDialog("Permission Required",
        "Camera permission is needed to take pictures. Please grant permission in your device settings.");
  }

  Future<void> _requestCameraPermission() async {
    // This will trigger the actual iOS system permission dialog for camera
    try {
      // Just check availability, don't actually pick
      await _picker
          .pickImage(source: ImageSource.camera)
          .then((_) => _requestPhotoLibraryPermission());
    } catch (e) {
      print("Camera permission denied or error occurred: $e");
      _requestPhotoLibraryPermission();
    }
  }

  Future<void> _requestPhotoLibraryPermission() async {
    // This will trigger the actual iOS system permission dialog for photo library
    try {
      // Just check availability, don't actually pick
      await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      print("Photo library permission denied or error occurred: $e");
    }
  }

  // Local fallback for image analysis when Firebase isn't working
  Future<Map<String, dynamic>> _analyzeImageLocally(
      Uint8List imageBytes) async {
    // This is a local fallback that doesn't require any Firebase connection
    // It returns mock data similar to what the real function would return

    print("Using local fallback for image analysis");

    // Simulate a processing delay
    await Future.delayed(Duration(seconds: 1));

    // Return mock food analysis data
    return {
      "success": true,
      "meal": [
        {
          "dish": "Local Analysis Result",
          "calories": 450,
          "macronutrients": {"protein": 25, "carbohydrates": 45, "fat": 18},
          "ingredients": [
            "This is a local analysis",
            "Firebase functions deployment had issues",
            "This is a fallback implementation",
            "Image size: ${imageBytes.length} bytes"
          ]
        }
      ]
    };
  }

  // Modify the _analyzeImage method to use our secure API
  Future<void> _analyzeImage(XFile? image) async {
    if (_isAnalyzing || image == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      print("Processing image ${image.path}");
      Uint8List imageBytes;

      // Get bytes from the image
      if (kIsWeb && _webImageBytes != null) {
        // For web, use the bytes we already have
        imageBytes = _webImageBytes!;
        print("Using web image bytes (${imageBytes.length} bytes)");
      } else {
        // Read as bytes from the file
        imageBytes = await image.readAsBytes();
        print("Read image bytes (${imageBytes.length} bytes)");
      }

      // Process image if needed (e.g., compress large images)
      Uint8List processedBytes = imageBytes;
      if (imageBytes.length > 500 * 1024) {
        // More than 500KB, try to compress
        print(
            "Image is large (${(imageBytes.length / 1024).toStringAsFixed(1)}KB), compressing...");
        try {
          if (kIsWeb) {
            // Resize image using web-specific implementation
            processedBytes = await resizeWebImage(imageBytes, 800);
          } else {
            // For mobile, we'll use a simpler approach to avoid path_provider
            // Use FlutterImageCompress.compressWithList for direct byte processing
            final compressedBytes = await FlutterImageCompress.compressWithList(
              imageBytes,
              minWidth: 800,
              minHeight: 800,
              quality: 85,
            );

            if (compressedBytes.isNotEmpty) {
              processedBytes = Uint8List.fromList(compressedBytes);
            }
          }
          print(
              "Compressed to ${(processedBytes.length / 1024).toStringAsFixed(1)}KB");
        } catch (e) {
          print("Error compressing image: $e");
          // Fall back to original bytes if compression fails
          processedBytes = imageBytes;
        }
      }

      print("Calling secure API service");

      // Use our secure API service via Firebase
      final response = await FoodAnalyzerApi.analyzeFoodImage(processedBytes);

      print("API call successful!");
      print('Response: $response');

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisResult = response;
        });

        // Display the formatted results in the terminal
        _displayAnalysisResults(_analysisResult!);
      }
    } catch (e) {
      print("Error analyzing image: $e");
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        _showCustomDialog("Analysis Failed",
            "Failed to analyze the image. Please try again.");
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      print("Opening image picker gallery...");
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        print("Image file selected: ${pickedFile.path}");

        if (mounted) {
          if (kIsWeb) {
            // For web platform, read the bytes first
            print("Web platform: reading image bytes first");
            final bytes = await pickedFile.readAsBytes();
            print("Web image bytes read successfully: ${bytes.length} bytes");

            // Update state with both path and bytes
            setState(() {
              _webImagePath = pickedFile.path;
              _webImageBytes = bytes;
              _imageFile = null;
              _mostRecentImage = pickedFile;
            });

            // Only analyze after we have the bytes
            print("Web image loaded, starting analysis...");
            _analyzeImage(pickedFile);
          } else {
            // For mobile platforms
            setState(() {
              _imageFile = File(pickedFile.path);
              _webImagePath = null;
              _webImageBytes = null;
              _mostRecentImage = pickedFile;
            });

            _analyzeImage(pickedFile);
          }

          print(
              "Image set to state: ${kIsWeb ? _webImagePath : _imageFile?.path}");
        } else {
          print("Widget not mounted, can't update state");
        }
      } else {
        print("No image selected from gallery");
      }
    } catch (e) {
      print("Error picking image: $e");

      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        // For desktop or web
        _showUnsupportedPlatformDialog();
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      print("Opening camera...");

      // Check if camera is available using _cameraOnly method
      bool isCameraAvailable = await _cameraOnly();

      if (!isCameraAvailable) {
        print("Camera not available or permission denied");
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      // Show loading state
      setState(() {
        _isAnalyzing = true;
      });

      // Try to access camera directly, with no gallery fallback
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        print("Photo taken: ${pickedFile.path}");

        if (mounted) {
          if (kIsWeb) {
            // For web platform, read the bytes first
            print("Web platform: reading image bytes first");
            final bytes = await pickedFile.readAsBytes();
            print(
                "Web camera image bytes read successfully: ${bytes.length} bytes");

            // Update state with both path and bytes
            setState(() {
              _webImagePath = pickedFile.path;
              _webImageBytes = bytes;
              _imageFile = null;
              _mostRecentImage = pickedFile;
            });

            // Analyze the image
            _analyzeImage(pickedFile);
          } else {
            // For mobile platforms
            setState(() {
              _imageFile = File(pickedFile.path);
              _webImagePath = null;
              _webImageBytes = null;
              _mostRecentImage = pickedFile;
            });

            // Analyze the image
            _analyzeImage(pickedFile);
          }

          print(
              "Photo set to state: ${kIsWeb ? _webImagePath : _imageFile?.path}");
        } else {
          print("Widget not mounted, can't update state");
        }
      } else {
        print("No photo taken");
        setState(() {
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      print("Error taking picture: $e");
      setState(() {
        _isAnalyzing = false;
      });

      if (mounted) {
        _showCameraErrorDialog();
      }
    }
  }

  Future<bool> _cameraOnly() async {
    try {
      await _checkPermissionsSimple();

      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxHeight: 1000,
        maxWidth: 1000,
        imageQuality: 85, // Improved compression to ensure smaller file sizes
      );

      if (photo != null) {
        setState(() {
          _mostRecentImage = photo;
        });

        // Analyze the image directly here
        _analyzeImage(photo);
        return true;
      }
      return false;
    } catch (e) {
      print("Error picking image: $e");
      // Show error dialog instead of snackbar
      if (mounted) {
        _showCustomDialog("Error", "Failed to access camera: ${e.toString()}");
      }
      return false;
    }
  }

  // Simplified version that doesn't use missing libraries
  Future<String?> _getBase64FromPath(String path) async {
    try {
      // For web platform
      if (kIsWeb) {
        if (_webImageBytes != null) {
          return base64Encode(_webImageBytes!);
        } else {
          // Try to load from path for web
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            return base64Encode(response.bodyBytes);
          } else {
            throw Exception('Failed to load image from URL');
          }
        }
      }
      // For mobile platforms
      else {
        final file = File(path);
        final bytes = await file.readAsBytes();

        // Simple size check
        if (bytes.length > 700000) {
          // Use our image compression helper
          final Uint8List result = await _compressBytesConsistently(
            bytes,
            quality: 80,
            targetWidth: 800,
          );
          return base64Encode(result);
        }

        return base64Encode(bytes);
      }
    } catch (e) {
      print("Error converting image to base64: $e");
      return null;
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes) async {
    // Target quality levels for successive compression attempts
    final qualityLevels = [80, 60, 40, 30];

    // Target size in KB
    final targetSize = 300 * 1024; // 300 KB

    // Try each quality level until we get below target size
    for (int quality in qualityLevels) {
      try {
        Uint8List result = await _compressBytesConsistently(
          imageBytes,
          quality: quality,
          targetWidth: 800,
        );

        print(
            'Compressed to quality $quality: ${(result.length / 1024).toStringAsFixed(2)} KB');

        // If we're below target size or on last attempt, return this result
        if (result.length < targetSize || quality == qualityLevels.last) {
          return result;
        }
      } catch (e) {
        print('Error compressing at quality $quality: $e');
        // If compression fails, try next lower quality or return original
      }
    }

    // If all compression attempts fail, return original
    return imageBytes;
  }

  void _displayAnalysisResults(Map<String, dynamic> analysisData) {
    try {
      // Format the data for console output
      String foodName = "";
      String ingredients = "";
      String calories = "0";
      String protein = "0";
      String fat = "0";
      String carbs = "0";
      String vitaminC = "0";
      List<Map<String, dynamic>> ingredientsList = [];

      // Check for meal format (new API response format)
      if (analysisData.containsKey('meal') &&
          analysisData['meal'] is List &&
          analysisData['meal'].isNotEmpty) {
        var meal = analysisData['meal'][0];

        // Extract food name
        if (meal.containsKey('dish')) {
          foodName = meal['dish']?.toString() ?? "";
        }

        // Extract ingredients with estimated amounts
        if (meal.containsKey('ingredients') && meal['ingredients'] is List) {
          final List<dynamic> rawIngredients = meal['ingredients'];
          for (var ing in rawIngredients) {
            String name = ing.toString();
            String amount = ""; // Default empty amount
            int estCalories = 0;

            // Try to estimate amount and calories for common ingredients
            if (name.toLowerCase().contains("pasta") ||
                name.toLowerCase().contains("rigatoni")) {
              amount = "90g";
              estCalories = 320;
            } else if (name.toLowerCase().contains("cheese") ||
                name.toLowerCase().contains("parmesan")) {
              amount = "20g";
              estCalories = 80;
            } else if (name.toLowerCase().contains("cream") ||
                name.toLowerCase().contains("sauce")) {
              amount = "60ml";
              estCalories = 150;
            } else if (name.toLowerCase().contains("oil") ||
                name.toLowerCase().contains("olive")) {
              amount = "15ml";
              estCalories = 120;
            } else if (name.toLowerCase().contains("herb") ||
                name.toLowerCase().contains("basil")) {
              amount = "5g";
              estCalories = 5;
            }

            ingredientsList
                .add({'name': name, 'amount': amount, 'calories': estCalories});
          }

          // Join ingredients with estimated amounts
          ingredients = ingredientsList.map((ing) {
            if (ing['amount'].toString().isNotEmpty) {
              return "${ing['name']} (${ing['amount']}; ${ing['calories']}kcal)";
            } else {
              return ing['name'];
            }
          }).join(", ");
        }

        // Extract calories
        if (meal.containsKey('calories')) {
          calories = meal['calories']?.toString() ?? "0";
        }

        // Extract macronutrients
        if (meal.containsKey('macronutrients') &&
            meal['macronutrients'] is Map) {
          var macros = meal['macronutrients'];
          protein = macros['protein']?.toString() ?? "0";
          fat = macros['fat']?.toString() ?? "0";
          carbs = macros['carbohydrates']?.toString() ?? "0";
        }

        // Look for vitamin C in any available field
        if (meal.containsKey('vitamins') && meal['vitamins'] is Map) {
          vitaminC = meal['vitamins']['C']?.toString() ?? "0";
        }
      } else {
        // Try alternative formats

        // Food name
        if (analysisData.containsKey('dish')) {
          foodName = analysisData['dish']?.toString() ?? "";
        } else if (analysisData.containsKey('dishName')) {
          foodName = analysisData['dishName']?.toString() ?? "";
        } else if (analysisData.containsKey('description')) {
          foodName = analysisData['description']?.toString() ?? "";
        }

        // Ingredients
        if (analysisData.containsKey('ingredients') &&
            analysisData['ingredients'] is List) {
          final List<dynamic> rawIngredients = analysisData['ingredients'];
          for (var ing in rawIngredients) {
            String name = ing.toString();
            String amount = ""; // Default empty amount
            int estCalories = 0;

            // Try to estimate amount and calories for common ingredients
            if (name.toLowerCase().contains("pasta") ||
                name.toLowerCase().contains("rigatoni")) {
              amount = "90g";
              estCalories = 320;
            } else if (name.toLowerCase().contains("cheese") ||
                name.toLowerCase().contains("parmesan")) {
              amount = "20g";
              estCalories = 80;
            } else if (name.toLowerCase().contains("cream") ||
                name.toLowerCase().contains("sauce")) {
              amount = "60ml";
              estCalories = 150;
            } else if (name.toLowerCase().contains("oil") ||
                name.toLowerCase().contains("olive")) {
              amount = "15ml";
              estCalories = 120;
            } else if (name.toLowerCase().contains("herb") ||
                name.toLowerCase().contains("basil")) {
              amount = "5g";
              estCalories = 5;
            }

            ingredientsList
                .add({'name': name, 'amount': amount, 'calories': estCalories});
          }

          // Join ingredients with estimated amounts
          ingredients = ingredientsList.map((ing) {
            if (ing['amount'].toString().isNotEmpty) {
              return "${ing['name']} (${ing['amount']}; ${ing['calories']}kcal)";
            } else {
              return ing['name'];
            }
          }).join(", ");
        }

        // Calories
        if (analysisData.containsKey('calories')) {
          calories = analysisData['calories']?.toString() ?? "0";
        }

        // Macronutrients
        if (analysisData.containsKey('macros') &&
            analysisData['macros'] is Map) {
          var macros = analysisData['macros'];
          protein = macros['protein']?.toString() ?? "0";
          fat = macros['fat']?.toString() ?? "0";
          carbs = macros['carbs']?.toString() ?? "0";
        } else if (analysisData.containsKey('macronutrients') &&
            analysisData['macronutrients'] is Map) {
          var macros = analysisData['macronutrients'];
          protein = macros['protein']?.toString() ?? "0";
          fat = macros['fat']?.toString() ?? "0";
          carbs = macros['carbohydrates']?.toString() ?? "0";
        }

        // Vitamin C
        if (analysisData.containsKey('vitamins') &&
            analysisData['vitamins'] is Map) {
          vitaminC = analysisData['vitamins']['C']?.toString() ?? "0";
        }
      }

      // Print results to terminal in specified format with units
      print("\n----- FOOD ANALYSIS RESULTS -----");
      print("Food name: $foodName");
      print("Ingredients: $ingredients");
      print("Calories: ${calories}kcal");
      print("Protein: ${protein}g");
      print("Fat: ${fat}g");
      print("Carbs: ${carbs}g");
      print("Vitamin C: ${vitaminC}mg");
      print("---------------------------------\n");

      // We don't need to store or display the formatted text anymore
      setState(() {
        // Set the analysis result but don't display it visually
        _analysisResult = analysisData;
        _formattedAnalysisResult = null;
      });
    } catch (e) {
      print("Error formatting analysis results: $e");

      setState(() {
        _analysisResult = analysisData;
        _formattedAnalysisResult = null;
      });
    }
  }

  // Test the echo function to verify callable functions work
  Future<void> _testEchoFunction() async {
    // Function logic removed
  }

  // Test the simple image analyzer function
  Future<void> _testSimpleImageAnalyzer() async {
    // Function logic removed
  }

  @override
  Widget build(BuildContext context) {
    print("Building SnapFood widget, has image: $_hasImage");
    if (_imageFile != null) {
      print("Image file path: ${_imageFile!.path}");
      // Only check file existence on non-web platforms
      if (!kIsWeb) {
        print("Image file exists: ${_imageFile!.existsSync()}");
      }
    }
    if (_webImagePath != null) {
      print("Web image path: $_webImagePath");
    }

    // Call analyzeImage with the most recent image if there is a pending request
    if (_pendingAnalysis && _mostRecentImage != null) {
      _pendingAnalysis = false;
      _analyzeImage(_mostRecentImage);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background - either selected image or black background
            if (_hasImage)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: _getImageProvider(),
                    fit: BoxFit.contain, // Show original size, not zoomed in
                  ),
                  color: Colors.black, // Black background for letterboxing
                ),
              )
            else
              Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
              ),

            // Top corner frames as a group
            Positioned(
              top: 102, // Distance from gray circle (21+36+45=102)
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 29),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCornerFrame(topLeft: true),
                    _buildCornerFrame(topRight: true),
                  ],
                ),
              ),
            ),

            // Bottom corner frames as a group
            Positioned(
              bottom: 223, // Adjusted for 45px gap (109+69+45=223)
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 29),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCornerFrame(bottomLeft: true),
                    _buildCornerFrame(bottomRight: true),
                  ],
                ),
              ),
            ),

            // Gray circle behind back button
            Positioned(
              top: 21,
              left: 29,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Back button
            Positioned(
              top: 21,
              left: 29,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.black, size: 24),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ),
            ),

            // Loading indicator while analyzing
            if (_isAnalyzing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Analyzing meal...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom action buttons (Scan Food, Scan Code, Add Photo)
            Positioned(
              bottom:
                  109, // Adjusted to create 24px gap with shutter button (15 + 70 + 24 = 109)
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 29),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Scan Food button
                    GestureDetector(
                      onTap: () {
                        _setActiveButton('Scan Food');
                      },
                      child: Container(
                        width: 99,
                        height: 69, // Increased to 69px as requested
                        decoration: BoxDecoration(
                          color: _activeButton == 'Scan Food'
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Image.asset(
                                'assets/images/foodscan.png',
                                width: 31,
                                height: 31,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Scan Food',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Scan Code button
                    GestureDetector(
                      onTap: () {
                        _setActiveButton('Scan Code');
                      },
                      child: Container(
                        width: 99,
                        height: 69, // Increased to 69px as requested
                        decoration: BoxDecoration(
                          color: _activeButton == 'Scan Code'
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Image.asset(
                                'assets/images/qrcodescan.png',
                                width: 31,
                                height: 31,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Scan Code',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Add Photo button
                    GestureDetector(
                      onTap: () {
                        _setActiveButton('Add Photo');
                      },
                      child: Container(
                        width: 99,
                        height: 69, // Increased to 69px as requested
                        decoration: BoxDecoration(
                          color: _activeButton == 'Add Photo'
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8.0,
                                  left:
                                      2.0), // Added 2px padding to the left to shift image right
                              child: Image.asset(
                                'assets/images/addphoto.png',
                                width: 31,
                                height: 31,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Add Photo',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Shutter button - camera only, no gallery fallback
            Positioned(
              bottom: 15,
              left: 29, // Adjusted to match 29px padding
              right: 29, // Adjusted to match 29px padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Flash button
                  Padding(
                    padding: const EdgeInsets.only(right: 40),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/flashwhite.png',
                        width: 37,
                        height: 37,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Shutter button - camera only, no gallery fallback
                  GestureDetector(
                    onTap:
                        _cameraOnly, // New dedicated camera function with no gallery fallback
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Empty space to balance the layout
                  const SizedBox(width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get the appropriate image provider based on platform
  ImageProvider _getImageProvider() {
    if (kIsWeb && _webImagePath != null) {
      // Web platform with path
      return NetworkImage(_webImagePath!);
    } else if (kIsWeb && _webImageBytes != null) {
      // Web platform with bytes
      return MemoryImage(_webImageBytes!);
    } else if (!kIsWeb && _imageFile != null) {
      try {
        // Use different approaches based on platform
        if (kIsWeb) {
          return const AssetImage('assets/images/placeholder.png');
        } else {
          return MemoryImage(Uint8List.fromList(_imageFile!.readAsBytesSync()));
        }
      } catch (e) {
        print("Error loading image: $e");
        return const AssetImage('assets/images/placeholder.png');
      }
    } else {
      // Fallback to a placeholder
      return const AssetImage('assets/images/placeholder.png');
    }
  }

  // Helper method to build corner frames
  Widget _buildCornerFrame({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: 50,
      height: 50,
      child: CustomPaint(
        painter: CornerPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }

  // Helper widget to build macros row
  Widget _buildMacrosRow(Map<String, dynamic> macros) {
    // Handle different formats of macros data
    int? protein, carbs, fat;

    // Case 1: Format as in {"protein": 10, "carbs": 20, "fat": 15}
    if (macros.containsKey('protein')) {
      protein = macros['protein'] as int?;
    }
    if (macros.containsKey('carbs')) {
      carbs = macros['carbs'] as int?;
    } else if (macros.containsKey('carbohydrates')) {
      carbs = macros['carbohydrates'] as int?;
    }
    if (macros.containsKey('fat')) {
      fat = macros['fat'] as int?;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (protein != null)
          _buildMacroItem('Protein', protein, Colors.blue.shade300),
        if (carbs != null)
          _buildMacroItem('Carbs', carbs, Colors.green.shade300),
        if (fat != null) _buildMacroItem('Fat', fat, Colors.red.shade300),
      ],
    );
  }

  // Helper widget to build a single macro nutrient item
  Widget _buildMacroItem(String name, num value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          Text(
            "$value g",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build ingredients list
  List<Widget> _buildIngredientsList(List<dynamic> ingredients) {
    return ingredients.map<Widget>((ingredient) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "• ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            Expanded(
              child: Text(
                ingredient,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Helper method to build meal analysis widgets
  List<Widget> _buildMealAnalysis(Map<String, dynamic> meal) {
    final widgets = <Widget>[];

    // Show dish name
    if (meal.containsKey('dish')) {
      widgets.add(
        Text(
          "${meal['dish']}",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      widgets.add(SizedBox(height: 8));
    }

    // Show calories
    if (meal.containsKey('calories')) {
      widgets.add(
        Text(
          "Calories: ${meal['calories']} kcal",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
      widgets.add(SizedBox(height: 5));
    }

    // Show macros
    if (meal.containsKey('macronutrients')) {
      widgets.add(_buildMacrosRow(meal['macronutrients']));
      widgets.add(SizedBox(height: 10));
    }

    // Show ingredients
    if (meal.containsKey('ingredients') && meal['ingredients'] is List) {
      widgets.add(
        Text(
          "Ingredients:",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      widgets.add(SizedBox(height: 5));
      widgets.addAll(_buildIngredientsList(meal['ingredients']));
    }

    return widgets;
  }

  // Function to get web image bytes by handling different URL formats
  Future<Uint8List> getWebImageBytes(String path) async {
    try {
      if (path.startsWith('data:')) {
        // Handle data URLs
        final int startIndex = path.indexOf(',') + 1;
        final String base64Data = path.substring(startIndex);
        return base64Decode(base64Data);
      } else if (path.startsWith('blob:') || path.startsWith('http')) {
        // Use HTTP GET for blob and http URLs
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          throw Exception('Failed to load image: ${response.statusCode}');
        }
      } else {
        // For other paths
        throw Exception('Unsupported image path format');
      }
    } catch (e) {
      print('Error in getWebImageBytes: $e');
      rethrow; // Rethrow to be handled by caller
    }
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }

  // Helper method to get optimized image bytes for local analysis
  Future<Uint8List> _optimizeImageBytes(Uint8List imageBytes) async {
    if (imageBytes.length < 300 * 1024) {
      // Small enough, no need to optimize
      return imageBytes;
    }

    try {
      // Use our unified image compression function
      return await compressImage(imageBytes, quality: 85, targetWidth: 800);
    } catch (e) {
      print("Error optimizing image bytes: $e");
      return imageBytes;
    }
  }

  // Compress image and convert to base64
  Future<String> _compressAndConvertToBase64(Uint8List imageBytes) async {
    try {
      // Compress the image first
      Uint8List compressedBytes = await compressImage(
        imageBytes,
        quality: 85,
        targetWidth: 1024,
      );

      // Convert to base64
      return base64Encode(compressedBytes);
    } catch (e) {
      print("Error in compress and convert: $e");
      return base64Encode(imageBytes); // Fallback to original
    }
  }

  // Helper method for optimizing single image bytes
  Future<Uint8List> _optimizeSingleImage(
    Uint8List bytes, {
    int targetWidth = 800,
    int quality = 85,
  }) async {
    try {
      if (bytes.length < 100 * 1024) return bytes; // Skip small files

      return await compressImage(
        bytes,
        targetWidth: targetWidth,
        quality: quality,
      );
    } catch (e) {
      print("Error optimizing single image: $e");
      return bytes;
    }
  }

  // Handle Uint8List compression consistently
  Future<Uint8List> _compressBytesConsistently(
    Uint8List bytes, {
    int quality = 85,
    int targetWidth = 800,
  }) async {
    try {
      return await compressImage(
        bytes,
        quality: quality,
        targetWidth: targetWidth,
      );
    } catch (e) {
      print("Compression error: $e");
      return bytes;
    }
  }

  // Web-specific function to compress images using canvas
  Future<Uint8List> _compressWebImageWithCanvas(
      Uint8List imageData, int maxDimension) async {
    try {
      return await compressImage(imageData, targetWidth: maxDimension);
    } catch (e) {
      print("Error compressing web image: $e");
      return imageData; // Return original if compression fails
    }
  }

  // Helper method to prepare an image for analysis when only file/bytes are available
  void _prepareImageForAnalysis() async {
    // Create an XFile from the available image source
    XFile? fileToAnalyze;

    try {
      if (_imageFile != null) {
        // Mobile platform with File
        fileToAnalyze = XFile(_imageFile!.path);
      } else if (_webImageBytes != null && kIsWeb) {
        // For web, we need to handle this differently
        // Create a data URL and set it as webImagePath
        final base64Image = base64Encode(_webImageBytes!);
        final dataUrl = 'data:image/jpeg;base64,$base64Image';
        fileToAnalyze = XFile(dataUrl);
      } else if (_webImagePath != null) {
        // Web platform with path
        fileToAnalyze = XFile(_webImagePath!);
      }

      if (fileToAnalyze != null) {
        setState(() {
          _isAnalyzing = true;
          _mostRecentImage = fileToAnalyze;
        });
        await _analyzeImage(fileToAnalyze);
      } else {
        print("No valid image source found for analysis");
        _showCustomDialog('Error', 'No image available to analyze');
      }
    } catch (e) {
      print("Error preparing image for analysis: $e");
      _showCustomDialog('Error', 'Error preparing image: ${e.toString()}');
    }
  }

  // Helper method to reduce image size on web platforms
  Future<Uint8List> _reduceImageSizeForWeb(
      Uint8List originalBytes, int targetWidth) async {
    if (!kIsWeb) {
      return originalBytes; // Only for web
    }

    // This function will be implemented by using the html package
    // and is only used on web platforms
    try {
      // Use our unified compressImage function
      return await compressImage(originalBytes, targetWidth: targetWidth);
    } catch (e) {
      print("Web resize error: $e");
      return originalBytes;
    }
  }

  // Custom styled dialog to show messages - replaces all SnackBars
  void _showCustomDialog(String title, String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.0),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.0),
                TextButton(
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show any error alerts with proper styling
  void _showErrorAlert(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Analysis Error",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.0),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.0),
                TextButton(
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUnsupportedPlatformDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Camera Unavailable",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.0),
                Text(
                  "Camera access is not available on this platform. Please use the 'Add Photo' button to select an image from your gallery.",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.0),
                TextButton(
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCameraErrorDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Camera Error",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.0),
                Text(
                  "There was an error accessing the camera. Please check your camera permissions and try again.",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.0),
                TextButton(
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to check if we have an image
  bool get _hasImage =>
      _imageFile != null || _webImagePath != null || _webImageBytes != null;

  void _scanFood() {
    print("Scanning food...");
    // If we have an image, analyze it
    if (_hasImage && !_isAnalyzing && _mostRecentImage != null) {
      _analyzeImage(_mostRecentImage);
    } else if (_hasImage && !_isAnalyzing) {
      // Show dialog to take a new picture instead of using the broken _prepareImageForAnalysis
      _showCustomDialog(
          "Analysis needed", "Please take a new picture to analyze food.");
    }
  }

  void _scanCode() {
    print("Scanning QR/Barcode...");
    // Placeholder for code scanning functionality
  }

  void _setActiveButton(String buttonName) {
    setState(() {
      _activeButton = buttonName;
    });
    print("Active button changed to: $_activeButton");

    // Perform action based on the selected button
    switch (buttonName) {
      case 'Scan Food':
        _scanFood();
        break;
      case 'Scan Code':
        _scanCode();
        break;
      case 'Add Photo':
        _pickImage();
        break;
    }
  }

  // Format the analysis results for display
  String _formatAnalysisResult(Map<String, dynamic> analysis) {
    // This is no longer used for displaying UI, but we keep it for compatibility
    return "";
  }
}

// Custom painter for the corner frames
class CornerPainter extends CustomPainter {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  CornerPainter({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final width = size.width;
    final height = size.height;
    final lineLength = size.width * 0.7;

    if (topLeft) {
      // Top line
      canvas.drawLine(
        Offset(0, 0),
        Offset(lineLength, 0),
        paint,
      );
      // Left line
      canvas.drawLine(
        Offset(0, 0),
        Offset(0, lineLength),
        paint,
      );
    } else if (topRight) {
      // Top line
      canvas.drawLine(
        Offset(width, 0),
        Offset(width - lineLength, 0),
        paint,
      );
      // Right line
      canvas.drawLine(
        Offset(width, 0),
        Offset(width, lineLength),
        paint,
      );
    } else if (bottomLeft) {
      // Bottom line
      canvas.drawLine(
        Offset(0, height),
        Offset(lineLength, height),
        paint,
      );
      // Left line
      canvas.drawLine(
        Offset(0, height),
        Offset(0, height - lineLength),
        paint,
      );
    } else if (bottomRight) {
      // Bottom line
      canvas.drawLine(
        Offset(width, height),
        Offset(width - lineLength, height),
        paint,
      );
      // Right line
      canvas.drawLine(
        Offset(width, height),
        Offset(width, height - lineLength),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CornerPainter oldDelegate) => false;
}
