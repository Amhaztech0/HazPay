import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Debug screen to test Supabase Storage connectivity
/// Navigate to this screen to verify your storage bucket is set up correctly
class StorageTestScreen extends StatefulWidget {
  const StorageTestScreen({super.key});

  @override
  State<StorageTestScreen> createState() => _StorageTestScreenState();
}

class _StorageTestScreenState extends State<StorageTestScreen> {
  String _status = 'Ready to test';
  bool _isTesting = false;

  Future<void> _testStorageConnection() async {
    setState(() {
      _isTesting = true;
      _status = 'Testing storage connection...';
    });

    try {
      // Test 1: Check if we can access storage
      setState(() => _status = 'Test 1: Checking storage access...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Test 2: List buckets
      setState(() => _status = 'Test 2: Listing storage buckets...');
      final supabase = Supabase.instance.client;
      final buckets = await supabase.storage.listBuckets();
      
      final bucketNames = buckets.map((b) => b.name).toList();
      final hasServerMedia = bucketNames.contains('server-media');
      
      if (!hasServerMedia) {
        setState(() {
          _status = '❌ FAILED: "server-media" bucket not found!\n\n'
              'Found buckets: ${bucketNames.join(", ")}\n\n'
              'ACTION NEEDED:\n'
              '1. Go to Supabase Dashboard\n'
              '2. Click Storage\n'
              '3. Create bucket: "server-media"\n'
              '4. Set as Public\n'
              '5. Try again';
          _isTesting = false;
        });
        return;
      }

      // Test 3: Check bucket properties
      setState(() => _status = 'Test 3: Checking bucket configuration...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      final bucket = buckets.firstWhere((b) => b.name == 'server-media');
      final isPublic = bucket.public;

      if (!isPublic) {
        setState(() {
          _status = '⚠️ WARNING: "server-media" bucket exists but is NOT public!\n\n'
              'This means images may not be accessible via public URLs.\n\n'
              'RECOMMENDATION:\n'
              '1. Go to Supabase Dashboard → Storage\n'
              '2. Click on "server-media" bucket\n'
              '3. Settings → Make bucket public\n'
              'OR use signed URLs in your code';
          _isTesting = false;
        });
        return;
      }

      // Test 4: Try to list files (will be empty if no uploads yet)
      setState(() => _status = 'Test 4: Testing bucket access...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        await supabase.storage.from('server-media').list();
      } catch (e) {
        setState(() {
          _status = '❌ FAILED: Cannot access bucket files!\n\n'
              'Error: $e\n\n'
              'Possible causes:\n'
              '- Storage policies not configured\n'
              '- User not authenticated\n'
              '- Permission issues';
          _isTesting = false;
        });
        return;
      }

      // All tests passed!
      setState(() {
        _status = '✅ SUCCESS! Storage is configured correctly!\n\n'
            'Bucket: server-media\n'
            'Public: Yes\n'
            'Access: Working\n\n'
            'You should now be able to upload images in server chats.\n\n'
            'If uploads still fail:\n'
            '1. Check your internet connection\n'
            '2. Verify you are logged in\n'
            '3. Check console logs for detailed errors';
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ ERROR: $e\n\n'
            'Failed to connect to Supabase Storage.\n\n'
            'Check:\n'
            '1. Internet connection\n'
            '2. Supabase project is active\n'
            '3. API keys in config.dart are correct';
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Supabase Storage Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This test verifies that your "server-media" storage bucket is properly configured.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isTesting ? null : _testStorageConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isTesting ? 'Testing...' : 'Run Storage Test',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
