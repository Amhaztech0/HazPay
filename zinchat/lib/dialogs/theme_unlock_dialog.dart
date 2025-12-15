import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/rewarded_ad_service.dart';

/// Dialog for theme unlock with rewarded ad option
/// 
/// ✅ AdMob Compliance Features:
/// - Clear choice: "Yes, watch ad" / "Maybe Later"
/// - No misleading UI or fake close buttons
/// - User explicitly chooses to watch (not forced)
/// - Reward only granted after full video completion
/// - Professional, honest messaging
class ThemeUnlockDialog extends StatefulWidget {
  final String themeName;
  final VoidCallback onThemeUnlocked;

  const ThemeUnlockDialog({
    super.key,
    required this.themeName,
    required this.onThemeUnlocked,
  });

  @override
  State<ThemeUnlockDialog> createState() => _ThemeUnlockDialogState();
}

class _ThemeUnlockDialogState extends State<ThemeUnlockDialog> {
  final _adService = RewardedAdService();
  bool _isLoadingAd = false;
  bool _isWatchingAd = false;

  @override
  void initState() {
    super.initState();
    _preloadAd();
  }

  /// Pre-load the ad in the background
  void _preloadAd() {
    if (!_adService.isRewardedAdAvailable()) {
      _adService.loadRewardedAd();
    }
  }

  /// Handle ad watching
  Future<void> _watchRewardedAd() async {
    setState(() => _isWatchingAd = true);

    // If ad not available, try loading it
    if (!_adService.isRewardedAdAvailable()) {
      setState(() => _isLoadingAd = true);
      await _adService.loadRewardedAd();
      
      // Wait a moment for ad to load
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;

    if (!_adService.isRewardedAdAvailable()) {
      setState(() {
        _isLoadingAd = false;
        _isWatchingAd = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not available. Please try again later.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Show the rewarded ad
    await _adService.showRewardedAd(
      onRewardEarned: () {
        debugPrint('✅ User earned theme unlock reward!');
        if (mounted) {
          Navigator.pop(context);
          widget.onThemeUnlocked.call();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Theme unlocked! Enjoy your new theme!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onAdDismissed: () {
        debugPrint('⚠️ User dismissed ad without watching');
        if (mounted) {
          setState(() {
            _isWatchingAd = false;
            _isLoadingAd = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You need to watch the full ad to unlock the theme.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      onAdFailed: () {
        debugPrint('❌ Ad failed to show');
        if (mounted) {
          setState(() {
            _isWatchingAd = false;
            _isLoadingAd = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ad failed to load. Please try again.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );

    if (mounted) {
      setState(() {
        _isWatchingAd = false;
        _isLoadingAd = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      title: Row(
        children: [
          Icon(
            Icons.star_rounded,
            color: AppColors.primaryGreen,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Unlock ${widget.themeName}?',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Descriptive text
            Text(
              'Watch a quick rewarded ad to unlock this amazing theme!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Benefits list
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBenefitRow(
                    icon: Icons.check_circle_rounded,
                    text: 'One-time unlock',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildBenefitRow(
                    icon: Icons.check_circle_rounded,
                    text: 'Use forever',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildBenefitRow(
                    icon: Icons.check_circle_rounded,
                    text: 'No extra costs',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Info text
            Text(
              '⏱️ Ad is typically 15-30 seconds. You must watch the complete video to unlock the theme.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // "Maybe Later" button
        TextButton(
          onPressed: _isWatchingAd || _isLoadingAd
              ? null
              : () => Navigator.pop(context),
          child: Text(
            'Maybe Later',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),

        // "Watch Ad" button
        ElevatedButton.icon(
          onPressed: _isWatchingAd || _isLoadingAd ? null : _watchRewardedAd,
          icon: _isLoadingAd
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textPrimary,
                    ),
                  ),
                )
              : Icon(
                  _isWatchingAd ? Icons.play_circle_rounded : Icons.movie_rounded,
                  size: 18,
                ),
          label: Text(
            _isLoadingAd
                ? 'Loading...'
                : _isWatchingAd
                    ? 'Watching...'
                    : 'Watch Ad',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primaryGreen,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
