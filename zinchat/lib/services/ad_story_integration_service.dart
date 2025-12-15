import 'package:flutter/foundation.dart';
import '../models/ad_story_model.dart';
import '../models/status_model.dart';
import '../models/user_model.dart';
import 'admob_service.dart';

/// Service to manage ad integration with status/stories
class AdStoryIntegrationService {
  static final AdStoryIntegrationService _instance = AdStoryIntegrationService._internal();
  factory AdStoryIntegrationService() => _instance;
  AdStoryIntegrationService._internal();

  final _adMobService = AdMobService();
  AdStoryModel? _currentAdStory;
  
  /// Initialize ad story (call this when opening status screen)
  Future<AdStoryModel?> loadAdStory() async {
    try {
      // Trigger load in background (non-blocking)
      _adMobService.loadStoryAd();
      
      // Return placeholder immediately with 'sponsored' ID to avoid UUID errors
      _currentAdStory = AdStoryModel(
        id: 'sponsored',
      );
      return _currentAdStory;
    } catch (e) {
      debugPrint('❌ Failed to load ad story: $e');
    }
    return null;
  }

  /// Convert ad story to a UserStatusGroup for display
  UserStatusGroup? createAdStatusGroup(AdStoryModel? adStory) {
    if (adStory == null) return null;
    
    // Always show sponsored story, even without ad ready
    // Create a fake user for the sponsored content
    final sponsoredUser = UserModel(
      id: 'sponsored',
      displayName: '📢 Sponsored',
      about: 'Tap to view',
      profilePhotoUrl: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create a fake status update
    final fakeStatus = StatusUpdate(
      id: adStory.id,
      userId: 'sponsored',
      content: adStory.subtitle,
      mediaType: 'ad',
      createdAt: adStory.createdAt,
      expiresAt: adStory.createdAt.add(const Duration(hours: 24)),
      user: sponsoredUser,
    );

    return UserStatusGroup(
      user: sponsoredUser,
      statuses: [fakeStatus],
      hasViewed: false,
    );
  }

  /// Show the ad when user taps on the ad story
  Future<void> showAdStory({VoidCallback? onAdDismissed}) async {
    try {
      // Check cached ad first
      final cachedAd = _adMobService.getCachedStoryAd();
      if (cachedAd != null) {
        await _adMobService.showAd(
          cachedAd,
          onAdDismissed: () {
            debugPrint('✅ Ad dismissed - calling callback');
            onAdDismissed?.call();
          },
        );
      } else if (_currentAdStory?.ad != null) {
        await _adMobService.showAd(
          _currentAdStory!.ad!,
          onAdDismissed: () {
            debugPrint('✅ Ad dismissed - calling callback');
            onAdDismissed?.call();
          },
        );
      } else {
        debugPrint('❌ Story ad not loaded yet - calling callback anyway');
        // If no ad available, still advance
        onAdDismissed?.call();
      }
    } catch (e) {
      debugPrint('❌ Error in showAdStory: $e');
      // On error, still advance to next status
      onAdDismissed?.call();
    }
  }

  /// Inject ad story into status groups list
  /// Typically adds it at position 2 or 3 (after user's own status)
  List<UserStatusGroup> injectAdIntoStatusGroups(
    List<UserStatusGroup>? groups,
    AdStoryModel? adStory,
  ) {
    try {
      // Handle null input gracefully
      if (groups == null) {
        groups = [];
      }
      
      // Always show ad story, create placeholder if needed
      final storyToUse = adStory ?? AdStoryModel(id: 'ad_placeholder');
      
      final adGroup = createAdStatusGroup(storyToUse);
      if (adGroup == null) return groups;

      final newGroups = List<UserStatusGroup>.from(groups);
      
      // Insert ad at position 1 (right after user's own status at position 0)
      final insertPosition = newGroups.length > 1 ? 1 : newGroups.length;
      newGroups.insert(insertPosition, adGroup);
      
      return newGroups;
    } catch (e, st) {
      debugPrint('❌ Error injecting ad into status groups: $e');
      debugPrint('Stack trace: $st');
      // Return original groups on error
      return groups ?? [];
    }
  }

  /// Clean up
  void dispose() {
    _currentAdStory?.dispose();
    _currentAdStory = null;
  }
}
