import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UploadFunctionClient {
  final Uri endpoint;

  UploadFunctionClient(this.endpoint);

  /// Uploads [file] to the configured Edge Function which will write to
  /// Supabase Storage using the service_role key and return a public URL.
  ///
  /// Returns the public URL on success or throws an Exception on failure.
  Future<String> uploadFile(File file, {String bucket = 'chat-media', String? path}) async {
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    // Safely derive filename from path
    final fileName = file.path.split(Platform.pathSeparator).last;
    final body = jsonEncode({
      'fileBase64': base64Str,
      'fileName': fileName,
      'bucket': bucket,
      'path': path ?? fileName,
    });
    // Retry logic for transient failures
    const int maxAttempts = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final res = await http.post(endpoint, headers: {'Content-Type': 'application/json'}, body: body);
        if (res.statusCode != 200) {
          throw Exception('Upload function failed: ${res.statusCode} ${res.body}');
        }

        final data = jsonDecode(res.body);
        final publicUrl = data['publicUrl'];
        if (publicUrl == null) {
          throw Exception('Upload function returned no publicUrl: ${res.body}');
        }
        return publicUrl as String;
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        // small backoff
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }
}
