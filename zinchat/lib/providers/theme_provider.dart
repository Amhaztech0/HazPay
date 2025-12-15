import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../services/theme_service.dart';

/// Provider for managing app theme state
class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppThemes.expressive;
  String? _wallpaperPath;
  bool _isLoading = true;
  List<String> _unlockedThemes = ['expressive']; // Default theme always unlocked
  
  AppTheme get currentTheme => _currentTheme;
  String? get wallpaperPath => _wallpaperPath;
  bool get isLoading => _isLoading;
  List<String> get unlockedThemes => _unlockedThemes;
  
  final ThemeService _themeService = ThemeService.instance;
  
  ThemeProvider() {
    _loadSavedTheme();
  }
  
  /// Load saved theme and wallpaper on startup
  Future<void> _loadSavedTheme() async {
    try {
      _currentTheme = await _themeService.loadTheme();
      _wallpaperPath = await _themeService.loadWallpaperPath();
      _unlockedThemes = await _themeService.getUnlockedThemes();
    } catch (e) {
      // If loading fails, use default theme
      _currentTheme = AppThemes.expressive;
      _wallpaperPath = null;
      _unlockedThemes = ['expressive'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Change the current theme
  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    await _themeService.saveTheme(theme.id);
  }
  
  /// Set chat wallpaper
  Future<void> setWallpaper(String? path) async {
    _wallpaperPath = path;
    notifyListeners();
    await _themeService.saveWallpaperPath(path);
  }
  
  /// Clear wallpaper
  Future<void> clearWallpaper() async {
    _wallpaperPath = null;
    notifyListeners();
    await _themeService.clearWallpaper();
  }
  
  /// Check if a theme is unlocked
  bool isThemeUnlocked(String themeId) {
    return _unlockedThemes.contains(themeId);
  }
  
  /// Unlock a theme after watching rewarded ad
  Future<void> unlockTheme(String themeId) async {
    if (!_unlockedThemes.contains(themeId)) {
      _unlockedThemes.add(themeId);
      notifyListeners();
      await _themeService.unlockTheme(themeId);
    }
  }
}
