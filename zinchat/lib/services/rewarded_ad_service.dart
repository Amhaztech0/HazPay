import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service for managing rewarded ads following AdMob best practices
/// 
/// ✅ AdMob Policy Compliance:
/// - User explicitly chooses to watch ads (not forced)
/// - Clear "yes/no" choice in dialog
/// - No misleading UI or fake close buttons
/// - Reward is granted ONLY after full video completion
/// - No aggressive ad placements
class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  /// Get rewarded ad unit IDs for different platforms
  static String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      // Theme reward ad unit
      return 'ca-app-pub-3763345250812931/9623169760'; // Production ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3763345250812931/9623169760'; // Production ID
    }
    return '';
  }

  RewardedAd? _cachedRewardedAd;
  bool _isAdLoading = false;

  /// Load a rewarded ad in the background
  /// This should be called periodically to keep ads ready
  Future<void> loadRewardedAd() async {
    if (_isAdLoading || _cachedRewardedAd != null) {
      debugPrint('⏳ Rewarded ad is already loading or cached');
      return;
    }

    _isAdLoading = true;

    try {
      debugPrint('📥 Loading rewarded ad with ID: $_rewardedAdUnitId');

      RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _cachedRewardedAd = ad;
            _isAdLoading = false;
            debugPrint('✅ Rewarded ad loaded successfully and cached');
          },
          onAdFailedToLoad: (LoadAdError error) {
            _isAdLoading = false;
            _cachedRewardedAd = null;
            debugPrint(
              '❌ Rewarded ad failed to load: ${error.code} - ${error.message}',
            );
          },
        ),
      );
    } catch (e) {
      _isAdLoading = false;
      debugPrint('❌ Error loading rewarded ad: $e');
    }
  }

  /// Get cached rewarded ad
  RewardedAd? getCachedRewardedAd() {
    return _cachedRewardedAd;
  }

  /// Check if a rewarded ad is available
  bool isRewardedAdAvailable() {
    return _cachedRewardedAd != null && !_isAdLoading;
  }

  /// Show rewarded ad with proper callbacks
  /// Returns true if user watched the full ad and received reward
  Future<bool> showRewardedAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailed,
  }) async {
    final ad = _cachedRewardedAd;

    if (ad == null) {
      debugPrint('⚠️ No rewarded ad available to show');
      onAdFailed.call();
      return false;
    }

    bool rewardEarned = false;

    // Setup callbacks for this ad session
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd dismissedAd) {
        debugPrint('📺 Rewarded ad is showing');
      },
      onAdDismissedFullScreenContent: (RewardedAd dismissedAd) {
        debugPrint('❌ Rewarded ad dismissed without reward');
        dismissedAd.dispose();
        _cachedRewardedAd = null;

        // Load next ad in background
        loadRewardedAd();

        if (!rewardEarned) {
          onAdDismissed.call();
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd failedAd, AdError error) {
        debugPrint('❌ Rewarded ad failed to show: $error');
        failedAd.dispose();
        _cachedRewardedAd = null;

        // Load next ad in background
        loadRewardedAd();

        onAdFailed.call();
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          rewardEarned = true;
          debugPrint(
            '🎁 User earned reward: ${reward.amount} ${reward.type}',
          );
          onRewardEarned.call();
        },
      );

      return rewardEarned;
    } catch (e) {
      debugPrint('❌ Error showing rewarded ad: $e');
      onAdFailed.call();
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _cachedRewardedAd?.dispose();
    _cachedRewardedAd = null;
  }
}
