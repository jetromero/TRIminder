import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double verySmallScreenBreakpoint = 360;

  // Screen size detection
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  // Check if very small screen (< 360px)
  static bool isVerySmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < verySmallScreenBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // Get responsive padding
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isVerySmallScreen(context)) {
      return const EdgeInsets.all(12.0); // Smaller padding for very small screens
    } else if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0);
    }
  }

  // Get responsive spacing
  static double getSpacing(BuildContext context, {double mobile = 16.0, double tablet = 20.0, double desktop = 24.0}) {
    if (isVerySmallScreen(context)) {
      // Reduce spacing for very small screens
      return mobile * 0.75;
    } else if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  // Get responsive font scale
  static double getFontScale(BuildContext context) {
    if (isVerySmallScreen(context)) {
      return 0.85; // Smaller font for very small screens
    } else if (isMobile(context)) {
      return 1.0;
    } else if (isTablet(context)) {
      return 1.1;
    } else {
      return 1.2;
    }
  }

  // Get font scale specifically for very small screens
  static double getSmallScreenFontScale(BuildContext context) {
    if (isVerySmallScreen(context)) {
      return 0.85;
    } else if (MediaQuery.of(context).size.width < 400) {
      return 0.9;
    }
    return 1.0;
  }

  // Get responsive card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(20.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }

  // Get responsive grid columns
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 3;
    }
  }

  // Get responsive max width for content
  static double getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isDesktop(context)) {
      return screenWidth * 0.8; // 80% of screen width on desktop
    }
    return screenWidth;
  }

  // Check if landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Get responsive icon size
  static double getIconSize(BuildContext context, {double mobile = 24.0, double tablet = 28.0, double desktop = 32.0}) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }
}

// Extension for easy MediaQuery access
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
  bool get isLandscape => ResponsiveUtils.isLandscape(this);
}
