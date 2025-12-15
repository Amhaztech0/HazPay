import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';
import '../../main.dart';

/// Debug screen to test and troubleshoot push notifications
class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  String? _fcmToken;
  bool _isInitialized = false;
  String _status = 'Checking...';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkNotificationSetup();
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toLocal()}: $message');
    });
  }

  Future<void> _checkNotificationSetup() async {
    _addLog('Starting notification check...');

    try {
      // Check if user is logged in
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _status = '❌ Not logged in');
        _addLog('ERROR: User not logged in');
        return;
      }
      _addLog('✅ User logged in: ${user.email}');

      // Check FCM token
      final token = NotificationService().fcmToken;
      setState(() => _fcmToken = token);
      
      if (token == null) {
        setState(() => _status = '❌ No FCM token');
        _addLog('ERROR: FCM token not generated');
        return;
      }
      _addLog('✅ FCM Token: ${token.substring(0, 20)}...');

      // Check if token is saved in Supabase
      final response = await supabase
          .from('user_tokens')
          .select()
          .eq('user_id', user.id)
          .eq('fcm_token', token)
          .maybeSingle();

      if (response == null) {
        setState(() => _status = '⚠️ Token not in database');
        _addLog('WARNING: FCM token not found in Supabase user_tokens table');
        _addLog('Attempting to save token...');
        
        // Try to save it manually
        await _saveTokenManually(user.id, token);
      } else {
        setState(() => _status = '✅ All setup complete');
        _addLog('✅ FCM token found in database');
      }

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
      _addLog('ERROR: $e');
    }
  }

  Future<void> _saveTokenManually(String userId, String token) async {
    try {
      await supabase.from('user_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      });
      _addLog('✅ Token saved successfully');
      setState(() => _status = '✅ All setup complete');
    } catch (e) {
      _addLog('ERROR saving token: $e');
      setState(() => _status = '❌ Failed to save token');
    }
  }

  Future<void> _sendTestNotification() async {
    _addLog('Sending test notification...');
    
    try {
      final user = supabase.auth.currentUser;
      if (user == null || _fcmToken == null) {
        _addLog('ERROR: Not ready to send notification');
        return;
      }

      // Insert a test message to trigger notification
      // This assumes you have a cloud function or trigger set up
      _addLog('NOTE: You need to trigger this from Supabase or a backend service');
      _addLog('Test notification payload would be:');
      _addLog('  type: direct_message');
      _addLog('  sender_name: Test User');
      _addLog('  content: Test notification');
      _addLog('  fcm_token: $_fcmToken');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('See logs. You need to send notification from Supabase/backend'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _addLog('ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _logs.clear();
                _status = 'Checking...';
              });
              _checkNotificationSetup();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 16,
                      color: _status.startsWith('✅') 
                          ? Colors.green 
                          : _status.startsWith('❌')
                              ? Colors.red
                              : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // FCM Token Card
          if (_fcmToken != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FCM Token',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _fcmToken!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Token copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fcmToken!,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Action Buttons
          ElevatedButton.icon(
            onPressed: _isInitialized ? _sendTestNotification : null,
            icon: const Icon(Icons.send),
            label: const Text('Test Notification (see logs)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              await _checkNotificationSetup();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Recheck Setup'),
          ),
          const SizedBox(height: 24),

          // Logs Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Debug Logs',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _logs.clear());
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No logs yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  _logs[index],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: _logs[index].contains('ERROR')
                                        ? Colors.red
                                        : _logs[index].contains('WARNING')
                                            ? Colors.orange
                                            : _logs[index].contains('✅')
                                                ? Colors.green
                                                : Colors.white70,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Troubleshooting Steps
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Troubleshooting Checklist',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildCheckItem('Run SQL migration in Supabase SQL Editor'),
                  _buildCheckItem('google-services.json in android/app/'),
                  _buildCheckItem('Build.gradle has Google Services plugin'),
                  _buildCheckItem('AndroidManifest has POST_NOTIFICATIONS permission'),
                  _buildCheckItem('Notification permission granted on device'),
                  _buildCheckItem('Test on real device (not emulator)'),
                  _buildCheckItem('Create Supabase Edge Function to send FCM'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_box_outline_blank, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
