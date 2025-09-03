import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String _envFile = '.env';
  
  // Supabase Configuration
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? 
           'https://mgfnwykwlrbxisiltmqe.supabase.co';
  }
  
  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? 
           'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZm53eWt3bHJieGlzaWx0bXFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MTEzNzYsImV4cCI6MjA3MDk4NzM3Nn0.dM6kl0SfNF8Jw9i0NrLlO8KcsjHbLUVgFEOTYsVL_zM';
  }
  
  // App Configuration
  static const int maxLoginAttempts = 5;
  static const Duration loginCooldown = Duration(minutes: 15);
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxSyncRetries = 3;
  
  // Database Configuration
  static const int databaseVersion = 1;
  static const String databaseName = 'triminder.db';
  
  // Validation Rules
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 100;
  
  // Initialize configuration
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: _envFile);
      print('✅ Environment configuration loaded');
    } catch (e) {
      print('⚠️ Could not load .env file, using defaults: $e');
    }
  }
}