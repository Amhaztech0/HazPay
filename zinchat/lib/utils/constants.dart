import 'package:flutter/material.dart';
import '../models/app_theme.dart';
export 'color_extensions.dart';

// App Colors - Uses current theme from ThemeProvider
// For backward compatibility, default to Expressive theme colors
class AppColors {
  // Primary Brand Colors (from default theme)
  static const Color primaryGreen = Color(0xFF00CED1); // Electric Teal (renamed for compatibility)
  static const Color electricTeal = Color(0xFF00CED1); // Electric Teal (Primary Accent)
  static const Color saturatedMagenta = Color(0xFFFF0066); // Saturated Magenta (Contrast/Gradient)
  static const Color primaryLight = Color(0xFF00E5E8); // Lighter Teal
  static const Color accent = Color(0xFF00CED1); // Electric Teal
  
  // Background colors (Dark Mode First)
  static const Color background = Color(0xFF1C1C1C); // Deep Charcoal
  static const Color chatBackground = Color(0xFF121212); // Slightly darker for chat
  static const Color cardBackground = Color(0xFF2A2A2A); // Card surfaces
  static const Color white = Color(0xFFFFFFFF);
  
  // Message bubble colors
  static const Color myMessageBubble = Color(0xFF005C5E); // Darker Teal
  static const Color otherMessageBubble = Color(0xFF2A2A2A); // Dark grey
  
  // Text colors (Dark Mode Optimized)
  static const Color textPrimary = Color(0xFFEAEAEA); // Off-white for dark bg
  static const Color textSecondary = Color(0xFFB0B0B0); // Light grey
  static const Color textLight = Color(0xFF808080); // Mid grey
  
  // Grey shades
  static const Color grey = Color(0xFF666666);
  static const Color greyLight = Color(0xFF3A3A3A);
  static const Color divider = Color(0xFF2A2A2A);
  
  // Status colors
  static const Color online = Color(0xFF00CED1);
  static const Color offline = Color(0xFF666666);
  
  // Gradient colors
  static const LinearGradient tealMagentaGradient = LinearGradient(
    colors: [electricTeal, saturatedMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient statusRingGradient = LinearGradient(
    colors: [electricTeal, saturatedMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Other colors
  static const Color error = Color(0xFFFF0066); // Using magenta for errors
  static const Color success = Color(0xFF00CED1); // Using teal for success
  
  // Shadow colors
  static Color tealShadow = electricTeal.withOpacity(0.3);
  static Color magentaShadow = saturatedMagenta.withOpacity(0.3);
  
  /// Get themed colors from AppTheme instance
  static Color primary(AppTheme theme) => theme.primaryColor;
  static Color secondary(AppTheme theme) => theme.secondaryColor;
  static LinearGradient gradient(AppTheme theme) => theme.primaryGradient;
}

// Text Styles (Poppins/Inter - Colors now come from ThemeData)
class AppTextStyles {
  static const String fontFamily = 'Inter'; // Or 'Poppins' if you prefer
  
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600, // Semi-bold
    fontFamily: fontFamily,
    height: 1.4,
    letterSpacing: -0.5,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600, // Semi-bold
    fontFamily: fontFamily,
    height: 1.4,
    letterSpacing: -0.3,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500, // Medium
    fontFamily: fontFamily,
    height: 1.4,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    fontFamily: fontFamily,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    fontFamily: fontFamily,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400, // Regular
    fontFamily: fontFamily,
    height: 1.5,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400, // Regular
    fontFamily: fontFamily,
    height: 1.4,
  );
  
  // Button text style
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600, // Semi-bold
    fontFamily: fontFamily,
    letterSpacing: 0.5,
  );
}

// Spacing constants
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

// Border Radius (Increased for modern, softer feel)
class AppRadius {
  static const double small = 12.0;
  static const double medium = 16.0;
  static const double large = 20.0; // Increased for expressive feel
  static const double xl = 28.0;
  static const double pill = 999.0; // For fully rounded pill shapes
  
  // Asymmetric bubble radii for expressive chat
  static const BorderRadius messageBubble = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(20),
    bottomRight: Radius.circular(4), // Asymmetric tail
  );
  static const BorderRadius messageBubbleOther = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(4), // Asymmetric tail
    bottomRight: Radius.circular(20),
  );
  
  // Squircle shape (approximated with higher radius)
  static const double squircle = 18.0;
}

// App Dimensions
class AppDimensions {
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 60.0;
  static const double dockHeight = 72.0; // Bottom dock
  static const double statusHeight = 110.0; // Instagram-style stories
  static const double cardElevation = 4.0;
}

// Animation Durations (Consistent 200-250ms)
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  
  // Easing curves
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve elasticOut = Curves.elasticOut;
  
  // Custom page route with fade + scale animation
  static PageRouteBuilder<T> fadeScaleRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: standard,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;

        var fadeTween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        
        var scaleTween = Tween(begin: 0.95, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
    );
  }
}

// Shadow definitions
class AppShadows {
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: AppColors.tealShadow,
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> tealGlow = [
    BoxShadow(
      color: AppColors.electricTeal.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 0),
      spreadRadius: 2,
    ),
  ];
  
  static List<BoxShadow> magentaGlow = [
    BoxShadow(
      color: AppColors.saturatedMagenta.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 0),
      spreadRadius: 2,
    ),
  ];
}

// Helper extension to get theme colors from BuildContext
extension ThemeColorExtension on BuildContext {
  AppTheme get appTheme {
    // ignore: deprecated_member_use
    return Theme.of(this).brightness == Brightness.light
        ? AppThemes.lightBlue // Use lightBlue for light themes, but prefer provider
        : AppThemes.expressive;
  }
}