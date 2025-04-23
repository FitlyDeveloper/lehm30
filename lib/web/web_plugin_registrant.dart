// This file is used to register all the Flutter web plugins
import 'package:connectivity_plus_web/connectivity_plus_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';

// Register all the web plugins used in the app
void registerPlugins(Registrar registrar) {
  ConnectivityPlusWebPlugin.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  ImagePickerPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
