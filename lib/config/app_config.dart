import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String _envFile = '.env';
  
  // Supabase Configuration
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null) {
      throw Exception('SUPABASE_URL not found in .env file');
    }
    return url;
  }
  
  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null) {
      throw Exception('SUPABASE_ANON_KEY not found in .env file');
    }
    return key;
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