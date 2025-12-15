import 'dart:async';
import 'package:flutter/foundation.dart';
import '../main.dart';

/// Service to manage user presence (online/offline status)
class PresenceService {
  Timer? _presenceTimer;
  
  /// Start updating user's online presence
  void startPresenceUpdates() {
    if (_presenceTimer != null && _presenceTimer!.isActive) {
      return; // Already running
    }

    // Update immediately
    _updatePresence();

    // Then update every minute
    _presenceTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updatePresence(),
    );

    debugPrint('✅ Presence updates started');
  }

  /// Stop updating presence
  void stopPresenceUpdates() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    debugPrint('⏹️ Presence updates stopped');
  }

  /// Update user's last_seen timestamp
  Future<void> _updatePresence() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('id', user.id);

      debugPrint('📡 Presence updated for user: ${user.id}');
    } catch (e) {
      debugPrint('❌ Error updating presence: $e');
      // Fail silently - presence is not critical
    }
  }

  /// Update presence immediately (call on user activity)
  Future<void> updateNow() async {
    await _updatePresence();
  }

  /// Dispose and cleanup
  void dispose() {
    stopPresenceUpdates();
  }
}
