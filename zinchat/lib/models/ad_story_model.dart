import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Model representing an ad displayed as a story/status
class AdStoryModel {
  final String id;
  final String title;
  final String subtitle;
  final InterstitialAd? ad;
  final DateTime createdAt;
  
  AdStoryModel({
    required this.id,
    this.title = 'Sponsored',
    this.subtitle = 'Tap to view',
    this.ad,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if this ad story should be shown
  bool get isAvailable => true; // Always show, ad loads in background

  /// Dispose the ad
  void dispose() {
    ad?.dispose();
  }
}

/// Model representing a sponsored contact in the chat list
class SponsoredContactModel {
  final String id;
  final String displayName;
  final String about;
  final String? profilePhotoUrl;
  final InterstitialAd? ad;
  
  SponsoredContactModel({
    this.id = 'sponsored-ads',
    this.displayName = '📢 Sponsored',
    this.about = 'Tap to view offers',
    this.profilePhotoUrl,
    this.ad,
  });

  /// Check if this sponsored contact should be shown
  bool get isAvailable => true; // Always show, ad loads in background

  /// Dispose the ad
  void dispose() {
    ad?.dispose();
  }

  /// Convert to a format similar to UserModel for display
  Map<String, dynamic> toDisplayJson() {
    return {
      'id': id,
      'display_name': displayName,
      'about': about,
      'profile_photo_url': profilePhotoUrl,
      'is_sponsored': true,
    };
  }
}
