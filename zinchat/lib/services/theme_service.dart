import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

/// Service for managing theme selection and persistence
class ThemeService {
  static const String _themeKey = 'selected_theme';
  static const String _wallpaperKey = 'chat_wallpaper_path';
  static const String _unlockedThemesKey = 'unlocked_themes';
  
  static ThemeService? _instance;
  static ThemeService get instance {
    _instance ??= ThemeService._();
    return _instance!;
  }
  
  ThemeService._();
  
  /// Save selected theme ID
  Future<void> saveTheme(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeId);
  }
  
  /// Load saved theme ID
  Future<String> loadThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'expressive'; // Default to expressive
  }
  
  /// Load the actual theme object
  Future<AppTheme> loadTheme() async {
    final themeId = await loadThemeId();
    return AppThemes.getThemeById(themeId);
  }
  
  /// Save chat wallpaper path
  Future<void> saveWallpaperPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_wallpaperKey);
    } else {
      await prefs.setString(_wallpaperKey, path);
    }
  }
  
  /// Load chat wallpaper path
  Future<String?> loadWallpaperPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wallpaperKey);
  }
  
  /// Clear wallpaper
  Future<void> clearWallpaper() async {
    await saveWallpaperPath(null);
  }
  
  /// Mark a theme as unlocked
  /// The default 'expressive' theme is always unlocked
  Future<void> unlockTheme(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedThemes = prefs.getStringList(_unlockedThemesKey) ?? [];
    
    if (!unlockedThemes.contains(themeId)) {
      unlockedThemes.add(themeId);
      await prefs.setStringList(_unlockedThemesKey, unlockedThemes);
    }
  }
  
  /// Check if a theme is unlocked
  /// Default 'expressive' theme is always unlocked
  Future<bool> isThemeUnlocked(String themeId) async {
    // Default theme is always free
    if (themeId == 'expressive') return true;
    
    final prefs = await SharedPreferences.getInstance();
    final unlockedThemes = prefs.getStringList(_unlockedThemesKey) ?? [];
    return unlockedThemes.contains(themeId);
  }
  
  /// Get list of unlocked theme IDs
  Future<List<String>> getUnlockedThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedThemes = prefs.getStringList(_unlockedThemesKey) ?? [];
    // Always include the default theme
    if (!unlockedThemes.contains('expressive')) {
      unlockedThemes.insert(0, 'expressive');
    }
    return unlockedThemes;
  }
}
