import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:device_preview/device_preview.dart';
import 'Features/onboarding_screen.dart';
import 'firebase_options.dart';
import 'core/utils/device_size_adapter.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitness_app/Features/codia/codia_page.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

// Custom binding to disable overflow errors
class NoOverflowErrorsFlutterBinding extends WidgetsFlutterBinding {
  @override
  void initInstances() {
    super.initInstances();
    // Disable overflow warning service extension
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflowed') ||
          details.toString().contains('overflow') ||
          details.toString().contains('exceeded')) {
        // Do nothing for overflow errors
        return;
      }
      // Forward other errors
      FlutterError.presentError(details);
    };
  }

  static WidgetsBinding ensureInitialized() {
    if (WidgetsBinding.instance is NoOverflowErrorsFlutterBinding) {
      return WidgetsBinding.instance;
    }
    NoOverflowErrorsFlutterBinding();
    return WidgetsBinding.instance;
  }
}

// Class to hide overflow messages in debug UI
class HideOverflowErrorsApp extends StatelessWidget {
  final Widget child;

  const HideOverflowErrorsApp({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      // Hide any existing overflow errors
      final overlay = WidgetsBinding.instance.renderViewElement;
      final renderObject = overlay?.renderObject;
      if (renderObject is RenderBox) {
        // Force layout to avoid overflow
        renderObject.markNeedsPaint();
      }

      return child;
    });
  }
}

void main() async {
  // Initialize the Flutter binding first
  WidgetsFlutterBinding.ensureInitialized();

  // Configure web for hash-less URLs
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

  // Disable ALL debug rendering features
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;

  // Initialize Firebase on all platforms
  try {
    await FirebaseService.initialize();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Failed to initialize Firebase: $e');
    // Continue without Firebase - the app will use mock services
  }

  // Debug option: Uncomment the line below to clear all saved data during testing
  // await SharedPreferences.getInstance().then((prefs) => prefs.clear());

  // Update hot restart timestamp for detection in Coach screen
  if (kDebugMode) {
    _updateHotRestartTimestamp();
  }

  // Initialize background cleanup for expired chat messages (every 6 hours)
  _initializeMessageCleanupService();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const MyApp(),
    ),
  );
}

// Update timestamp when app is hot restarted
Future<void> _updateHotRestartTimestamp() async {
  try {
    const String hotRestartKey = 'coach_hot_restart_timestamp';
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(hotRestartKey, now);
    print('Set hot restart timestamp: $now');
  } catch (e) {
    print('Error setting hot restart timestamp: $e');
  }
}

// Setup a background timer to clean up expired chat messages
void _initializeMessageCleanupService() {
  // Run initial cleanup immediately
  _cleanupExpiredMessages();

  // Setup periodic cleanup every 6 hours
  Timer.periodic(Duration(hours: 6), (timer) {
    _cleanupExpiredMessages();
  });
}

// Clean up messages older than 12 hours from SharedPreferences
Future<void> _cleanupExpiredMessages() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    const String chatHistoryKey = 'coach_chat_history';
    const Duration messageExpiry = Duration(hours: 12);

    // Check if we have any chat history
    final String? chatHistoryJson = prefs.getString(chatHistoryKey);
    if (chatHistoryJson == null) return;

    // Parse the JSON string
    final List<dynamic> allMessages = jsonDecode(chatHistoryJson);
    final now = DateTime.now();

    // Filter out messages older than 12 hours
    final validMessages = allMessages.where((msgMap) {
      try {
        final timestamp = DateTime.parse(msgMap['timestamp']);
        return now.difference(timestamp) < messageExpiry;
      } catch (e) {
        print('Error parsing message timestamp: $e');
        // Remove messages with invalid timestamps
        return false;
      }
    }).toList();

    // Only update if we removed some messages
    if (validMessages.length < allMessages.length) {
      await prefs.setString(chatHistoryKey, jsonEncode(validMessages));
      print(
          'Background cleanup: Removed ${allMessages.length - validMessages.length} expired messages');
    } else {
      print('Background cleanup: No expired messages found');
    }
  } catch (e) {
    print('Error in background message cleanup: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      title: 'Gym App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        textTheme: TextTheme(
          bodyLarge:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          bodyMedium:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          bodySmall:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          titleLarge:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          titleMedium:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          titleSmall:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          displayLarge:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          displayMedium:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          displaySmall:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          headlineLarge:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          headlineMedium:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          headlineSmall:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          labelLarge:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          labelMedium:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
          labelSmall:
              TextStyle(color: Colors.black, decoration: TextDecoration.none),
        ),
        // Add global text style to ensure all text has no decoration
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.black,
        ),
        // Ensure all text has no decoration by default
        typography: Typography.material2021().copyWith(
          black: Typography.material2021().black.apply(
                decoration: TextDecoration.none,
              ),
          white: Typography.material2021().white.apply(
                decoration: TextDecoration.none,
              ),
        ),
      ),
      home: const OnboardingScreen(),
    );
  }
}

// Simple widget to ignore overflow errors
class IgnoreOverflowErrors extends StatelessWidget {
  final Widget child;

  const IgnoreOverflowErrors({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Using LayoutBuilder provides a boundary for overflow errors
        return child;
      },
    );
  }
}
