// Configuration file for app constants
class AppConfig {
  // Supabase configuration
  // TODO: Replace these with your actual Supabase project values
  static const String supabaseUrl = 'https://avaewzkgsilitcrncqhe.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2YWV3emtnc2lsaXRjcm5jcWhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI0NTI2NzcsImV4cCI6MjA3ODAyODY3N30.wVrlS6WYTI5IpL23B5LtpD3czW-HwzSbzFC2sS9sLLg';
  
  // Example:
  // static const String supabaseUrl = 'https://abcdefgh.supabase.co';
  // static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
  
  // Edge Function endpoint for secure media uploads
  // TODO: Update this URL after deploying the upload_media function
  static const String uploadFunctionUrl = 'https://avaewzkgsilitcrncqhe.functions.supabase.co/upload_media';
  
  // App info
  static const String appName = 'ZinChat';
  static const String appTagline = 'Zance da abokai';

  // Development helper: allow sending messages to non-contacts when true
  // WARNING: For testing only — do NOT enable in production
  static const bool allowSendToNonContactsForDev = true;
}