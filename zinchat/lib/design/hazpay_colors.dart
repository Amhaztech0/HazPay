import 'package:flutter/material.dart';

/// HazPay Color System - Centralized color management
/// All colors are defined here. NO hardcoded colors in screens!
class HazPayColors {
  // ==================== PRIMARY COLORS ====================
  static const Color primary = Color(0xFF0057B8); // HazPay Blue
  static const Color primaryDark = Color(0xFF0045A0); // Darker blue for gradients
  
  // ==================== SECONDARY COLORS ====================
  static const Color accent = Color(0xFF00C49A); // HazPay Green
  
  // ==================== BACKGROUND & SURFACES ====================
  static const Color background = Color(0xFFF5F5F5); // Light gray background
  static const Color card = Color(0xFFFFFFFF); // White cards
  static const Color surfaceLight = Color(0xFFF9F9F9);
  
  // ==================== TEXT COLORS ====================
  static const Color textPrimary = Color(0xFF222B45); // Dark text
  static const Color textSecondary = Color(0xFF8F9BB3); // Gray text
  static const Color textMuted = Color(0xFF999999); // More muted text
  
  // ==================== BORDERS & DIVIDERS ====================
  static const Color border = Color(0xFFE0E0E0); // Light border
  static const Color borderLight = Color(0xFFF0F0F0); // Lighter border
  static const Color divider = Color(0xFFE4E9F2);
  
  // ==================== SHADOW ====================
  static const Color shadow = Color(0x1A222B45);
  static const Color shadowLight = Color(0x0D222B45);
  
  // ==================== SEMANTIC COLORS ====================
  static const Color error = Color(0xFFD32F2F); // Red for errors
  static const Color errorDark = Color(0xFFC62828);
  static const Color success = Color(0xFF4CAF50); // Green for success
  static const Color successDark = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFF9800); // Orange for warnings
  static const Color warningDark = Color(0xFFF57C00);
  static const Color info = Color(0xFF2196F3); // Blue for info
  
  // ==================== SERVICE CATEGORY COLORS ====================
  static const Color buyDataColor = Color(0xFF00BCD4); // Cyan
  static const Color payBillsColor = Color(0xFFFF6B6B); // Red
  static const Color loanColor = Color(0xFF26A69A); // Teal
  static const Color rewardsColor = Color(0xFFFFB74D); // Gold/Orange
  static const Color savingsColor = Color(0xFF81C784); // Light Green
  static const Color receiveColor = Color(0xFF4CAF50); // Green
  static const Color sendColor = Color(0xFF2196F3); // Light Blue
  static const Color scanColor = Color(0xFF9C27B0); // Purple
  static const Color moreColor = Color(0xFFBDBDBD); // Gray
  
  // ==================== NETWORK COLORS ====================
  static const Color mtnColor = Color(0xFFFFD700); // Gold
  static const Color gloColor = Color(0xFF009A44); // Dark Green
  static const Color airtelColor = Color(0xFFFF0000); // Bright Red
  static const Color nineNobileColor = Color(0xFF00A651); // Medium Green
  static const Color smileColor = Color(0xFF0099FF); // Bright Blue
  
  // ==================== ON PRIMARY (Text on Primary Background) ====================
  static const Color onPrimary = Color(0xFFFFFFFF); // White text on primary
  static const Color onPrimaryMuted = Color(0xB3FFFFFF); // ~70% white
  static const Color onPrimaryFaint = Color(0x3DFFFFFF); // ~24% white
  
  // ==================== TRANSPARENT ====================
  static const Color transparent = Color(0x00000000);
  
  // ==================== UTILITY METHODS ====================
  
  /// Create a color with custom opacity (uses withValues for compatibility)
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
  
  /// Alias for withOpacity for backwards compatibility
  static Color alpha(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
  
  /// Lighten a color by reducing darkness
  static Color lighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
  
  /// Darken a color by increasing darkness
  static Color darken(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

/// Extension to make using withValues cleaner
extension ColorExtension on Color {
  Color withOpacity(double opacity) => withValues(alpha: opacity);
}
