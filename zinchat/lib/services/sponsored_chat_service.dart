import 'package:flutter/foundation.dart';
import '../models/ad_story_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import 'admob_service.dart';

/// Service to manage sponsored contact in chat list
class SponsoredChatService {
  static final SponsoredChatService _instance = SponsoredChatService._internal();
  factory SponsoredChatService() => _instance;
  SponsoredChatService._internal();

  final _adMobService = AdMobService();
  SponsoredContactModel? _sponsoredContact;

  /// Get the current cached sponsored contact
  Future<SponsoredContactModel?> getSponsoredContact() async {
    return _sponsoredContact;
  }

  /// Load a sponsored ad for the chat list
  Future<SponsoredContactModel?> loadSponsoredContact() async {
    try {
      debugPrint('🔄 Loading sponsored contact...');
      
      // Trigger ad load in background (non-blocking)
      _adMobService.loadChatAd();
      
      // Return placeholder immediately
      _sponsoredContact = SponsoredContactModel();
      debugPrint('✅ Sponsored contact placeholder created');
      return _sponsoredContact;
    } catch (e) {
      debugPrint('❌ Failed to load sponsored contact: $e');
    }
    return null;
  }
  
  /// Check if ad is ready and update cached contact
  void updateIfAdReady() {
    final cachedAd = _adMobService.getCachedChatAd();
    if (cachedAd != null && _sponsoredContact?.ad == null) {
      _sponsoredContact = SponsoredContactModel(ad: cachedAd);
      debugPrint('✅ Sponsored contact updated with loaded ad');
    }
  }

  /// Convert sponsored contact to a ChatModel for display
  ChatModel? createSponsoredChatModel(SponsoredContactModel? contact) {
    if (contact == null) return null;
    
    // Show sponsored contact even without ad ready
    final sponsoredUser = UserModel(
      id: contact.id,
      displayName: contact.displayName,
      about: contact.about,
      profilePhotoUrl: contact.profilePhotoUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return ChatModel(
      id: contact.id,
      user1Id: 'system',
      user2Id: contact.id,
      createdAt: DateTime.now(),
      otherUser: sponsoredUser,
    );
  }

  /// Inject sponsored contact into chat list (always at top)
  List<ChatModel> injectSponsoredContact(
    List<ChatModel> chats,
    SponsoredContactModel? contact,
  ) {
    // ALWAYS show sponsored contact, even without ad
    final contactToUse = contact ?? SponsoredContactModel();
    
    final sponsoredChat = createSponsoredChatModel(contactToUse);
    if (sponsoredChat == null) return chats;

    // Insert at the top of the list
    return [sponsoredChat, ...chats];
  }

  /// Show the ad when user taps on sponsored contact
  Future<void> showSponsoredAd({VoidCallback? onAdDismissed}) async {
    // Check cached ad first
    final cachedAd = _adMobService.getCachedChatAd();
    if (cachedAd != null) {
      await _adMobService.showAd(cachedAd, onAdDismissed: onAdDismissed);
    } else if (_sponsoredContact?.ad != null) {
      await _adMobService.showAd(_sponsoredContact!.ad!, onAdDismissed: onAdDismissed);
    } else {
      debugPrint('❌ No ad available to show yet');
    }
  }

  /// Clean up
  void dispose() {
    _sponsoredContact?.dispose();
    _sponsoredContact = null;
  }

  /// Handle tap on sponsored contact - show ad if available
  void handleSponsoredTap(dynamic context) {
    showSponsoredAd(
      onAdDismissed: () {
        debugPrint('✅ Sponsored ad dismissed');
      },
    );
  }
}
