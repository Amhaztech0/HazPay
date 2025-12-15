/// String sanitization utilities to prevent UTF-16 and rendering issues
class StringSanitizer {
  /// Sanitize a string to remove invalid UTF-16 characters and control characters
  /// This prevents "string is not well-formed UTF-16" errors
  static String sanitize(String? input) {
    if (input == null || input.isEmpty) return '';
    
    try {
      // Remove control characters (invalid UTF-16)
      var result = input.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '');
      // Remove most problematic special characters, keep alphanumeric and common punctuation
      result = result.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-._()@#$%&+=/|<>?~:;,!]'), '');
      return result.trim();
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Safe substring that doesn't throw on invalid indices
  static String safeSubstring(String input, int start, {int? end}) {
    try {
      if (input.isEmpty) return '';
      if (start >= input.length) return '';
      return input.substring(
        start,
        end != null && end <= input.length ? end : input.length,
      );
    } catch (e) {
      return '';
    }
  }

  /// Get first character safely
  static String getFirstCharacter(String input) {
    try {
      final sanitized = sanitize(input);
      if (sanitized.isEmpty) return 'U';
      return sanitized[0].toUpperCase();
    } catch (e) {
      return 'U';
    }
  }
}
