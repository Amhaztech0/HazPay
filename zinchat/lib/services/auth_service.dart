import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../main.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

// Authentication service - handles all auth operations
class AuthService {
  /// Sign in with email (OTP code - no password needed!)
  /// Sends an OTP to the provided email address.
  /// If useMagicLink is true, sends a link instead of a code
  Future<void> signInWithEmail(String email, {bool useMagicLink = false}) async {
    int attempts = 0;
    const int maxAttempts = 2; // 1 retry

    while (true) {
      attempts++;
      try {
        debugPrint('Sending OTP to: $email (useMagicLink: $useMagicLink) - attempt $attempts');

        if (useMagicLink) {
          // Send magic link that opens the app
          await supabase.auth.signInWithOtp(
            email: email,
            emailRedirectTo: 'zinchat://auth-callback',
            shouldCreateUser: true,
          );
          debugPrint('signInWithOtp completed (magic link)');
        } else {
          // Send a simple OTP code (no redirect)
          await supabase.auth.signInWithOtp(
            email: email,
            shouldCreateUser: true,
          );
          debugPrint('signInWithOtp completed');
        }

        debugPrint('OTP sent successfully to: $email');
        return;
      } catch (e, st) {
        debugPrint('Failed to send OTP to $email (attempt $attempts): $e');
        debugPrint('Stacktrace: $st');

        if (attempts >= maxAttempts) {
          debugPrint('Max attempts reached sending OTP to $email');
          throw Exception('Failed to send verification code: $e');
        }

        // Small backoff before retrying; helps transient network errors
        await Future.delayed(const Duration(seconds: 1));
        // Retry loop
      }
    }
  }

  /// Verify the OTP code sent to email
  Future<void> verifyEmailOTP(String email, String token) async {
    try {
      debugPrint('Verifying OTP for email: $email with token: "$token"');
      
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token.trim(), // Ensure token is trimmed
        type: OtpType.email,
      );

      debugPrint('OTP verification successful for user: ${response.user?.id}');

      // If this is a new user, create their profile
      if (response.user != null) {
        await _createUserProfile(response.user!);
      }

      // Save FCM token after successful login
      debugPrint('🔔 Saving FCM token after login...');
      await NotificationService().saveTokenAfterLogin();
    } on AuthException catch (e) {
      debugPrint('OTP verification AuthException: ${e.message} (code: ${e.statusCode})');
      // Provide more specific error messages
      if (e.message.contains('expired')) {
        throw Exception('Code has expired. Please request a new one.');
      } else if (e.message.contains('invalid')) {
        throw Exception('Invalid code. Please check and try again.');
      } else {
        throw Exception('Verification failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('OTP verification failed: $e');
      // capture stacktrace when available for easier debugging
      try {
        throw e;
      } catch (re, st) {
        debugPrint('OTP verification stacktrace: $st');
      }
      throw Exception('Invalid code: $e');
    }
  }

  /// Sign in with phone number (requires Twilio setup)
  /// Sends an OTP to the provided phone number.
  Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await supabase.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true,
      );
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// Verify phone OTP
  Future<void> verifyPhoneOTP(String phone, String token) async {
    try {
      final response = await supabase.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      // If this is a new user, create their profile
      if (response.user != null) {
        await _createUserProfile(response.user!);
      }

      // Save FCM token after successful login
      debugPrint('🔔 Saving FCM token after login...');
      await NotificationService().saveTokenAfterLogin();
    } catch (e) {
      throw Exception('Invalid code: $e');
    }
  }

  /// Create user profile in database after signup
  Future<void> _createUserProfile(User user) async {
    try {
      final existingProfile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        debugPrint('Creating profile for user: ${user.id}');
        
        // Build profile data - only include phone_number if not null
        final profileData = <String, dynamic>{
          'id': user.id,
          'display_name': user.phone ?? user.email?.split('@')[0] ?? 'ZinChat User',
          'about': 'Hey there! I am using ZinChat.',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        // Only add phone_number if it exists (avoid NULL constraint violation)
        if (user.phone != null && user.phone!.isNotEmpty) {
          profileData['phone_number'] = user.phone;
        }
        debugPrint('Inserting profile data for ${user.id}: $profileData');
        final insertRes = await supabase.from('profiles').insert(profileData);
        debugPrint('Insert response: $insertRes');
        
        debugPrint('Profile created successfully for user: ${user.id}');
      } else {
        debugPrint('Profile already exists for user: ${user.id}');
      }
    } catch (e) {
      debugPrint('Error creating profile: $e');
      // capture stacktrace for debugging
      try {
        throw e;
      } catch (re, st) {
        debugPrint('Profile create stacktrace: $st');
      }
      // Re-throw to make profile creation failures visible
      rethrow;
    }
  }

  /// Get current user profile
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? about,
    String? profilePhotoUrl,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) updates['display_name'] = displayName;
      if (about != null) updates['about'] = about;
      if (profilePhotoUrl != null) {
        updates['profile_photo_url'] = profilePhotoUrl;
      }

      await supabase.from('profiles').update(updates).eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return supabase.auth.currentUser != null;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return supabase.auth.currentUser?.id;
  }

  /// Update user's last seen timestamp (for online status)
  Future<void> updatePresence() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating presence: $e');
      // Don't throw - presence updates should fail silently
    }
  }

  /// Start updating presence periodically (call when app starts)
  Stream<void> startPresenceUpdates() async* {
    while (isLoggedIn()) {
      await updatePresence();
      await Future.delayed(const Duration(minutes: 1));
      yield null;
    }
  }
}
