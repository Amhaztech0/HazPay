import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Replace these with your actual AdMob Ad Unit IDs
  // Get them from https://apps.admob.com/
  static String get storyAdUnitId {
    if (Platform.isAndroid) {
      // Contact interstitial ad unit
      return 'ca-app-pub-3763345250812931/4839840271'; // Production ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3763345250812931/4839840271'; // Production ID
    }
    return '';
  }

  static String get chatAdUnitId {
    if (Platform.isAndroid) {
      // Status interstitial ad unit
      return 'ca-app-pub-3763345250812931/4549030387'; // Production ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3763345250812931/4549030387'; // Production ID
    }
    return '';
  }

  // Initialize AdMob
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      debugPrint('✅ AdMob initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize AdMob: $e');
    }
  }

  // Cached ads
  InterstitialAd? _cachedChatAd;
  InterstitialAd? _cachedStoryAd;

  // Load an interstitial ad for story view (non-blocking)
  Future<InterstitialAd?> loadStoryAd() async {
    try {
      debugPrint('📥 Attempting to load story ad with ID: $storyAdUnitId');
      
      // Load ad without blocking main thread
      unawaited(
        Future(() {
          InterstitialAd.load(
            adUnitId: storyAdUnitId,
            request: const AdRequest(),
            adLoadCallback: InterstitialAdLoadCallback(
              onAdLoaded: (InterstitialAd loadedAd) {
                _cachedStoryAd = loadedAd;
                debugPrint('✅ Story ad loaded successfully and cached');
              },
              onAdFailedToLoad: (LoadAdError error) {
                debugPrint('❌ Story ad failed to load: ${error.code} - ${error.message}');
                _cachedStoryAd = null;
              },
            ),
          );
        }),
      );

      // Return cached ad immediately (may be null initially)
      debugPrint('📤 Returning cached story ad: ${_cachedStoryAd != null ? "LOADED" : "NULL"}');
      return _cachedStoryAd;
    } catch (e) {
      debugPrint('❌ Error loading story ad: $e');
      return null;
    }
  }
  
  // Get the cached story ad
  InterstitialAd? getCachedStoryAd() {
    return _cachedStoryAd;
  }
  
  // Load an interstitial ad for chat view (non-blocking)
  Future<InterstitialAd?> loadChatAd() async {
    try {
      debugPrint('📥 Attempting to load chat ad with ID: $chatAdUnitId');
      
      // Load ad without blocking main thread
      unawaited(
        Future(() {
          InterstitialAd.load(
            adUnitId: chatAdUnitId,
            request: const AdRequest(),
            adLoadCallback: InterstitialAdLoadCallback(
              onAdLoaded: (InterstitialAd loadedAd) {
                _cachedChatAd = loadedAd;
                debugPrint('✅ Chat ad loaded successfully and cached');
              },
              onAdFailedToLoad: (LoadAdError error) {
                debugPrint('❌ Chat ad failed to load: ${error.code} - ${error.message}');
                _cachedChatAd = null;
              },
            ),
          );
        }),
      );

      // Return cached ad immediately (may be null initially)
      debugPrint('📤 Returning cached chat ad: ${_cachedChatAd != null ? "LOADED" : "NULL"}');
      return _cachedChatAd;
    } catch (e) {
      debugPrint('❌ Error loading chat ad: $e');
      return null;
    }
  }
  
  // Get the cached chat ad
  InterstitialAd? getCachedChatAd() {
    return _cachedChatAd;
  }

  // Show an interstitial ad
  Future<void> showAd(InterstitialAd ad, {VoidCallback? onAdDismissed}) async {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd dismissedAd) {
        debugPrint('Ad dismissed');
        dismissedAd.dispose();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd failedAd, AdError error) {
        debugPrint('Ad failed to show: $error');
        failedAd.dispose();
        onAdDismissed?.call();
      },
    );

    await ad.show();
  }

  // Create a banner ad for inline placement
  BannerAd createBannerAd({
    required String adUnitId,
    required AdSize adSize,
    required BannerAdListener listener,
  }) {
    return BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: listener,
    );
  }

  // Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}
