import 'package:flutter/material.dart';

/// Represents a complete app theme with all color and style configurations
class AppTheme {
  final String id;
  final String name;
  final String description;
  
  // Primary Brand Colors
  final Color primaryColor;
  final Color secondaryColor;
  final Color primaryLight;
  
  // Background colors
  final Color background;
  final Color chatBackground;
  final Color cardBackground;
  
  // Message bubble colors
  final Color myMessageBubble;
  final Color otherMessageBubble;
  
  // Text colors
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  
  // Grey shades
  final Color grey;
  final Color greyLight;
  final Color divider;
  
  // Status colors
  final Color online;
  final Color offline;
  
  // Other colors
  final Color error;
  final Color success;
  final Color warning;
  final Color info;
  
  const AppTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.primaryLight,
    required this.background,
    required this.chatBackground,
    required this.cardBackground,
    required this.myMessageBubble,
    required this.otherMessageBubble,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.grey,
    required this.greyLight,
    required this.divider,
    required this.online,
    required this.offline,
    required this.error,
    required this.success,
    this.warning = const Color(0xFFFF9800),
    this.info = const Color(0xFF2196F3),
  });
  
  // Computed gradients
  LinearGradient get primaryGradient => LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  LinearGradient get statusRingGradient => LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadow colors
  Color get primaryShadow => primaryColor.withOpacity(0.3);
  Color get secondaryShadow => secondaryColor.withOpacity(0.3);
  
  // Shadow definitions
  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primaryColor.withOpacity(0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: primaryColor.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 0),
      spreadRadius: 2,
    ),
  ];
  
  List<BoxShadow> get secondaryGlow => [
    BoxShadow(
      color: secondaryColor.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 0),
      spreadRadius: 2,
    ),
  ];
  
  /// Build Material 3 ThemeData from AppTheme
  /// This ensures Material 3 compatibility across all components
  ThemeData toMaterial3ThemeData() {
    final colorScheme = ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: background,
      outline: divider,
      error: error,
      onError: Colors.white,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onSurface: textPrimary,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      
      // Primary colors
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      canvasColor: cardBackground,
      
      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Text theme - Material 3 typography
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textLight,
        ),
      ),
      
      // Icon theme
      iconTheme: IconThemeData(
        color: textPrimary,
        size: 24,
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: greyLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: textLight, fontSize: 14),
        helperStyle: TextStyle(color: textSecondary, fontSize: 12),
        errorStyle: TextStyle(color: error, fontSize: 12),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: textPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: greyLight,
        labelStyle: TextStyle(color: textPrimary, fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Pre-defined theme configurations
class AppThemes {
  // Theme 1: Expressive (Default) - Teal/Magenta/Charcoal
  static const AppTheme expressive = AppTheme(
    id: 'expressive',
    name: 'Expressive',
    description: 'Bold teal and magenta with deep charcoal',
    primaryColor: Color(0xFF00CED1), // Electric Teal
    secondaryColor: Color(0xFFFF0066), // Saturated Magenta
    primaryLight: Color(0xFF00E5E8), // Lighter Teal
    background: Color(0xFF1C1C1C), // Deep Charcoal
    chatBackground: Color(0xFF121212),
    cardBackground: Color(0xFF2A2A2A),
    myMessageBubble: Color(0xFF00CED1),
    otherMessageBubble: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textLight: Color(0xFF808080),
    grey: Color(0xFF666666),
    greyLight: Color(0xFF3A3A3A),
    divider: Color(0xFF2A2A2A),
    online: Color(0xFF00CED1),
    offline: Color(0xFF666666),
    error: Color(0xFFFF0066),
    success: Color(0xFF00CED1),
  );
  
  // Theme 2: Vibrant - Orange/Blue/Dark Gray
  static const AppTheme vibrant = AppTheme(
    id: 'vibrant',
    name: 'Vibrant',
    description: 'Energetic orange and electric blue',
    primaryColor: Color(0xFFFF7043), // Bright Orange
    secondaryColor: Color(0xFF00BCD4), // Electric Blue
    primaryLight: Color(0xFFFF8A65), // Lighter Orange
    background: Color(0xFF263238), // Dark Gray
    chatBackground: Color(0xFF1C2228),
    cardBackground: Color(0xFF37474F),
    myMessageBubble: Color(0xFFFF7043),
    otherMessageBubble: Color(0xFF37474F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0BEC5),
    textLight: Color(0xFF78909C),
    grey: Color(0xFF607D8B),
    greyLight: Color(0xFF455A64),
    divider: Color(0xFF37474F),
    online: Color(0xFF00BCD4),
    offline: Color(0xFF607D8B),
    error: Color(0xFFFF7043),
    success: Color(0xFF00BCD4),
  );
  
  // Theme 3: Muted - Gold/Violet/Off-Black
  static const AppTheme muted = AppTheme(
    id: 'muted',
    name: 'Muted',
    description: 'Sophisticated gold and deep violet',
    primaryColor: Color(0xFFB8860B), // Muted Gold
    secondaryColor: Color(0xFF8A2BE2), // Deep Violet
    primaryLight: Color(0xFFDAA520), // Lighter Gold
    background: Color(0xFF101010), // Off-Black
    chatBackground: Color(0xFF0A0A0A),
    cardBackground: Color(0xFF1E1E1E),
    myMessageBubble: Color(0xFFB8860B),
    otherMessageBubble: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA0A0A0),
    textLight: Color(0xFF707070),
    grey: Color(0xFF5A5A5A),
    greyLight: Color(0xFF2A2A2A),
    divider: Color(0xFF1E1E1E),
    online: Color(0xFFB8860B),
    offline: Color(0xFF5A5A5A),
    error: Color(0xFF8A2BE2),
    success: Color(0xFFB8860B),
  );
  
  // Theme 4: Solid Minimal - Pure Black/White with Blue
  static const AppTheme solidMinimal = AppTheme(
    id: 'solid_minimal',
    name: 'Solid Minimal',
    description: 'Pure black and white with simple blue',
    primaryColor: Color(0xFF2196F3), // Simple Blue
    secondaryColor: Color(0xFF2196F3), // Same blue (no gradient)
    primaryLight: Color(0xFF64B5F6), // Lighter Blue
    background: Color(0xFF000000), // Pure Black
    chatBackground: Color(0xFF000000),
    cardBackground: Color(0xFF1A1A1A),
    myMessageBubble: Color(0xFF2196F3),
    otherMessageBubble: Color(0xFF1A1A1A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textLight: Color(0xFF808080),
    grey: Color(0xFF616161),
    greyLight: Color(0xFF2A2A2A),
    divider: Color(0xFF1A1A1A),
    online: Color(0xFF2196F3),
    offline: Color(0xFF616161),
    error: Color(0xFFF44336),
    success: Color(0xFF2196F3),
  );
  
  // Theme 5: Light Blue - White/Blue Light Theme
  static const AppTheme lightBlue = AppTheme(
    id: 'light_blue',
    name: 'Light Blue',
    description: 'Clean white background with blue accents',
    primaryColor: Color(0xFF0D47A1), // Deep Blue
    secondaryColor: Color(0xFF1976D2), // Medium Blue
    primaryLight: Color(0xFF42A5F5), // Light Blue
    background: Color(0xFFFFFFFF), // Pure White - all pages
    chatBackground: Color(0xFFFFFFFF), // Pure White - chat area
    cardBackground: Color(0xFFFFFFFF), // Pure White - cards
    myMessageBubble: Color(0xFF1976D2), // Blue bubble for my messages
    otherMessageBubble: Color(0xFFE8E8E8), // Light gray for others
    textPrimary: Color(0xFF000000), // Pure Black - strong visibility
    textSecondary: Color(0xFF424242), // Dark Gray - good readability
    textLight: Color(0xFF757575), // Medium Gray - secondary info
    grey: Color(0xFFBDBDBD), // Light Gray
    greyLight: Color(0xFFEEEEEE), // Very Light Gray
    divider: Color(0xFFE0E0E0), // Divider lines
    online: Color(0xFF1976D2), // Blue for online status
    offline: Color(0xFF9E9E9E), // Gray for offline
    error: Color(0xFFD32F2F), // Red
    success: Color(0xFF388E3C), // Green
  );
  
  // Theme 6: Light Pink - White background with pink accents
  static const AppTheme lightPink = AppTheme(
    id: 'light_pink',
    name: 'Light Pink',
    description: 'Clean white background with pink accents',
    primaryColor: Color(0xFFD81B60), // Deep Pink
    secondaryColor: Color(0xFFEC407A), // Medium Pink
    primaryLight: Color(0xFFF48FB1), // Light Pink
    background: Color(0xFFFFFFFF), // Pure White
    chatBackground: Color(0xFFFFFFFF), // Pure White
    cardBackground: Color(0xFFFFFFFF), // Pure White
    myMessageBubble: Color(0xFFEC407A), // Pink bubble for my messages
    otherMessageBubble: Color(0xFFE8E8E8), // Light gray for others
    textPrimary: Color(0xFF000000), // Pure Black
    textSecondary: Color(0xFF424242), // Dark Gray
    textLight: Color(0xFF757575), // Medium Gray
    grey: Color(0xFFBDBDBD), // Light Gray
    greyLight: Color(0xFFEEEEEE), // Very Light Gray
    divider: Color(0xFFE0E0E0), // Divider lines
    online: Color(0xFFEC407A), // Pink for online status
    offline: Color(0xFF9E9E9E), // Gray for offline
    error: Color(0xFFD32F2F), // Red
    success: Color(0xFF388E3C), // Green
  );
  
  // Theme 7: Light Green - White background with green accents
  static const AppTheme lightGreen = AppTheme(
    id: 'light_green',
    name: 'Light Green',
    description: 'Clean white background with green accents',
    primaryColor: Color(0xFF00796B), // Deep Teal/Green
    secondaryColor: Color(0xFF009688), // Medium Teal
    primaryLight: Color(0xFF4DB6AC), // Light Teal
    background: Color(0xFFFFFFFF), // Pure White
    chatBackground: Color(0xFFFFFFFF), // Pure White
    cardBackground: Color(0xFFFFFFFF), // Pure White
    myMessageBubble: Color(0xFF009688), // Green bubble for my messages
    otherMessageBubble: Color(0xFFE8E8E8), // Light gray for others
    textPrimary: Color(0xFF000000), // Pure Black
    textSecondary: Color(0xFF424242), // Dark Gray
    textLight: Color(0xFF757575), // Medium Gray
    grey: Color(0xFFBDBDBD), // Light Gray
    greyLight: Color(0xFFEEEEEE), // Very Light Gray
    divider: Color(0xFFE0E0E0), // Divider lines
    online: Color(0xFF009688), // Green for online status
    offline: Color(0xFF9E9E9E), // Gray for offline
    error: Color(0xFFD32F2F), // Red
    success: Color(0xFF388E3C), // Green
  );
  
  // Theme 8: Blush Pink - Modern, minimal, feminine aesthetic
  static const AppTheme blushPink = AppTheme(
    id: 'blush_pink',
    name: 'Blush Pink',
    description: 'Modern, minimal, and feminine with soft blush and rose accents',
    primaryColor: Color(0xFFF0C5D1), // Soft blush pink
    secondaryColor: Color(0xFFE8A3B3), // Slightly darker rose pink
    primaryLight: Color(0xFFFADEE4), // Very soft pink tint
    background: Color(0xFFFFFFFF), // Pure white
    chatBackground: Color(0xFFFFFBFC), // Nearly white with subtle pink hint
    cardBackground: Color(0xFFFFFFFF), // Pure white
    myMessageBubble: Color(0xFFF0A8C0), // Deeper pink for sender
    otherMessageBubble: Color(0xFFFCE4EC), // Very light pink for receiver
    textPrimary: Color(0xFF2C2C2C), // Very dark brown-black for readability
    textSecondary: Color(0xFF8D8D8D), // Light grey for hints/secondary UI
    textLight: Color(0xFFB0B0B0), // Lighter grey
    grey: Color(0xFFD4D4D4), // Light grey
    greyLight: Color(0xFFF5F5F5), // Very light grey
    divider: Color(0xFFE8D4DB), // Soft pink divider
    online: Color(0xFFE8A3B3), // Rose pink for online status
    offline: Color(0xFFB0B0B0), // Grey for offline
    error: Color(0xFFC2185B), // Rose red for errors
    success: Color(0xFF80CBC4), // Soft teal for success
  );
  
  /// Get all available themes
  static List<AppTheme> get allThemes => [expressive, vibrant, muted, solidMinimal, lightBlue, lightPink, lightGreen, blushPink];
  
  /// Get theme by ID
  static AppTheme getThemeById(String id) {
    return allThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => expressive,
    );
  }
}
