import 'package:flutter/material.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/next_intro_screen_2.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/next_intro_screen_4.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NextIntroScreen extends StatefulWidget {
  const NextIntroScreen({super.key});

  @override
  State<NextIntroScreen> createState() => _NextIntroScreenState();
}

class _NextIntroScreenState extends State<NextIntroScreen> {
  double _sliderValue = 0; // Start at beginning

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Box 4 (background with gradient)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey[100]!.withOpacity(0.9),
                ],
              ),
            ),
          ),

          // Header content (back arrow and progress bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.07),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.black, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: const LinearProgressIndicator(
                            value: 3 / 13,
                            minHeight: 2,
                            backgroundColor: Color(0xFFE5E5EA),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 21.2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How often can you go to the gym?',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1.21,
                          fontFamily: '.SF Pro Display',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This helps us create the best gym workout plan for you.',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          fontFamily: '.SF Pro Display',
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Slider content
          Positioned(
            left: 24,
            right: 24,
            top: MediaQuery.of(context).size.height * 0.52, // 2% down
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: Colors.black,
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: Colors.white,
                    overlayColor: Colors.black.withOpacity(0.05),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 17,
                    ),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                      elevation: 4,
                    ),
                  ),
                  child: Slider(
                    value: _sliderValue,
                    min: 0,
                    max: 7,
                    divisions: 7,
                    onChanged: (value) {
                      setState(() {
                        _sliderValue = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_sliderValue.round()} ${_sliderValue.round() == 1 ? 'time' : 'times'} a week',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: '.SF Pro Display',
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Box 5 (white box at bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.148887,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),

          // Box 6 (black button)
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).size.height * 0.06,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.0689,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextButton(
                onPressed: () {
                  // Load height from SharedPreferences before navigating
                  _loadHeightAndNavigate();
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    fontFamily: '.SF Pro Display',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to load height from SharedPreferences and then navigate
  Future<void> _loadHeightAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get height from SharedPreferences (if available)
      int heightInCm = 170; // Default height if not found

      // Try to get height from SharedPreferences in priority order
      if (prefs.containsKey('user_height_cm')) {
        heightInCm = prefs.getInt('user_height_cm') ?? heightInCm;
      } else if (prefs.containsKey('heightInCm')) {
        heightInCm = prefs.getDouble('heightInCm')?.toInt() ?? heightInCm;
      }

      print('Loaded height from SharedPreferences: $heightInCm cm');

      // Get weight from SharedPreferences (if available)
      int initialWeight = 150; // Default weight in lbs
      bool isMetric = prefs.getBool('is_metric') ?? false;

      if (prefs.containsKey('user_weight_kg')) {
        double weightKg = prefs.getDouble('user_weight_kg') ?? 70.0;
        if (!isMetric) {
          // Convert kg to lbs for imperial
          initialWeight = (weightKg / 0.453592).round();
        } else {
          initialWeight = weightKg.round();
        }
      } else if (prefs.containsKey('original_weight_lbs') && !isMetric) {
        initialWeight = prefs.getInt('original_weight_lbs') ?? initialWeight;
      }

      // Navigate based on gym frequency
      if (_sliderValue == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NextIntroScreen4(
              isMetric: isMetric,
              initialWeight: initialWeight,
              gymGoal: null, // No gym goal since they selected 0 times per week
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NextIntroScreen2(
              isMetric: isMetric,
              initialWeight: initialWeight,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error loading height from SharedPreferences: $e');
      // Continue with navigation using defaults
      if (_sliderValue == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NextIntroScreen4(
              isMetric: false,
              initialWeight: 150,
              gymGoal: null,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NextIntroScreen2(
              isMetric: false,
              initialWeight: 150,
            ),
          ),
        );
      }
    }
  }
}
