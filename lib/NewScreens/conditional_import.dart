// This file contains helper code for conditional imports
// that prevent errors when compiling for different platforms

// Used to make conditional imports work properly
class WebUtils {
  static bool get isWeb => identical(0, 0.0);
}
