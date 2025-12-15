import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/constants.dart';
import '../../utils/string_sanitizer.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';
import '../../models/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../dialogs/theme_unlock_dialog.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _storageService = StorageService();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();

  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _authService.getCurrentUserProfile();
      if (mounted) {
        if (user != null) {
          setState(() {
            _currentUser = user;
            _nameController.text = user.displayName;
            _aboutController.text = user.about;
            _isLoading = false;
          });
        } else {
          // User profile doesn't exist, create a basic one
          final currentUserId = _authService.getCurrentUserId();
          if (currentUserId == null) {
            throw Exception('No user is logged in');
          }

          setState(() {
            _currentUser = UserModel(
              id: currentUserId,
              displayName: 'ZinChat User',
              about: 'Hey there! I am using ZinChat.',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            _nameController.text = _currentUser!.displayName;
            _aboutController.text = _currentUser!.about;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // Show error and allow manual retry
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadProfile,
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    final about = _aboutController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _authService.updateProfile(
        displayName: name,
        about: about,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    final file = await _storageService.pickImage(fromCamera: false);

    if (file == null) return;

    setState(() => _isSaving = true);

    try {
      // Show uploading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading profile photo...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Upload to storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('Uploading profile photo to profile-photos bucket...');
      
      final url = await _storageService.uploadFile(
        file: file,
        bucket: 'profile-photos',
        path: 'profile_${_currentUser!.id}_$timestamp',
      );

      if (url != null) {
        debugPrint('Upload successful, URL: $url');
        await _authService.updateProfile(profilePhotoUrl: url);
        await _loadProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Upload returned null URL. Ensure "profile-photos" bucket exists in Supabase Storage and is set as public.');
      }
    } catch (e) {
      debugPrint('Failed to update profile photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo. ${e.toString().contains('Bucket') ? 'Create "profile-photos" bucket in Supabase Storage.' : 'Error: $e'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;
        return _buildProfileContent(context, theme);
      },
    );
  }
  
  Widget _buildProfileContent(BuildContext context, AppTheme theme) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _updateProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'SAVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Profile photo
            Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: theme.primaryColor,
                  backgroundImage: _currentUser?.profilePhotoUrl != null
                      ? CachedNetworkImageProvider(
                          _currentUser!.profilePhotoUrl!,
                        )
                      : null,
                  child: _currentUser?.profilePhotoUrl == null
                      ? Text(
                          StringSanitizer.getFirstCharacter(_currentUser?.displayName ?? ''),
                          style: const TextStyle(
                            fontSize: 50,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: theme.primaryColor,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _changeProfilePhoto,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // About field
            TextField(
              controller: _aboutController,
              decoration: InputDecoration(
                labelText: 'About',
                prefixIcon: const Icon(Icons.info_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Phone number (read-only)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.greyLight,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: theme.grey),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                      Text(
                        _currentUser?.phoneNumber ?? 'Not set',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Account created date
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.greyLight,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: theme.grey),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Member since',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                      Text(
                        _currentUser != null
                            ? '${_currentUser!.createdAt.day}/${_currentUser!.createdAt.month}/${_currentUser!.createdAt.year}'
                            : 'Unknown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Theme Selection Section
            _buildThemeSelector(theme),

            const SizedBox(height: AppSpacing.lg),

            // Chat Wallpaper Section
            _buildWallpaperSelector(theme),

            const SizedBox(height: AppSpacing.xl),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Logout',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(dynamic theme) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final currentTheme = themeProvider.currentTheme;
        
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: currentTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: currentTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette_rounded,
                    color: currentTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Theme',
                    style: AppTextStyles.heading3.copyWith(
                      color: currentTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Choose your preferred color scheme',
                style: AppTextStyles.bodySmall.copyWith(
                  color: currentTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...AppThemes.allThemes.map((selectedTheme) => _buildThemeOption(
                selectedTheme,
                isSelected: selectedTheme.id == currentTheme.id,
                onTap: () => _handleThemeSelection(selectedTheme),
                currentTheme: currentTheme,
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(AppTheme theme, {required bool isSelected, required VoidCallback onTap, required dynamic currentTheme}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primaryColor.withOpacity(0.15)
                  : currentTheme.greyLight,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Color swatches
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.secondaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                // Theme info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        theme.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.primaryColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWallpaperSelector(dynamic theme) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final hasWallpaper = themeProvider.wallpaperPath != null;
        final currentTheme = themeProvider.currentTheme;
        
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: currentTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: currentTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wallpaper_rounded,
                    color: currentTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Chat Wallpaper',
                    style: AppTextStyles.heading3.copyWith(
                      color: currentTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Set a custom background for all your chats',
                style: AppTextStyles.bodySmall.copyWith(
                  color: currentTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickWallpaper,
                      icon: const Icon(Icons.image_rounded, size: 20),
                      label: Text(hasWallpaper ? 'Change Wallpaper' : 'Select Wallpaper'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentTheme.primaryColor,
                        foregroundColor: currentTheme.background,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                  if (hasWallpaper) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await themeProvider.clearWallpaper();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Wallpaper removed'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_rounded),
                      color: currentTheme.secondaryColor,
                      style: IconButton.styleFrom(
                        backgroundColor: currentTheme.greyLight,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickWallpaper() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      if (mounted) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        await themeProvider.setWallpaper(image.path);
        
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallpaper set successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set wallpaper: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: Text(
          'Logout',
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.saturatedMagenta,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Handle theme selection with rewarded ad gating
  /// If theme is not unlocked, show dialog to watch rewarded ad
  Future<void> _handleThemeSelection(AppTheme selectedTheme) async {
    HapticFeedback.mediumImpact();
    
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isUnlocked = themeProvider.isThemeUnlocked(selectedTheme.id);

    // If already the current theme, just show feedback
    if (selectedTheme.id == themeProvider.currentTheme.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already using ${selectedTheme.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // If theme is unlocked, apply it immediately
    if (isUnlocked) {
      await themeProvider.setTheme(selectedTheme);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme changed to ${selectedTheme.name}'),
            backgroundColor: selectedTheme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // If theme is locked, show unlock dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => ThemeUnlockDialog(
          themeName: selectedTheme.name,
          onThemeUnlocked: () async {
            // Unlock the theme
            await themeProvider.unlockTheme(selectedTheme.id);
            // Apply the theme
            await themeProvider.setTheme(selectedTheme);
          },
        ),
      );
    }
  }
}
