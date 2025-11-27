import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static bool get allowBypass {
    final bypass = dotenv.env['ALLOW_BYPASS'];
    if (bypass != 'false') {
      return true;
    }
    return false;
  }

  // App Information
  static String get appVersion {
    final version = dotenv.env['APP_VERSION'];
    if (version == null) {
      throw Exception('APP_VERSION not found in .env file');
    }
    return version;
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
  
  // Screen Time Milestone Configuration
  // Default session milestones (continuous screen time) - can be overridden by user preferences
  static const List<int> _defaultSessionMilestones = [30, 60]; // minutes
  
  // Default daily total milestones - can be overridden by user preferences
  static const List<int> _defaultDailyTotalMilestones = [120, 240, 360, 480]; // minutes (2hrs, 4hrs, 6hrs, 8hrs)
  
  // Keys for SharedPreferences
  static const String _sessionMilestonesKey = 'session_milestones';
  static const String _dailyMilestonesKey = 'daily_milestones';
  
  /// Get session milestones (configurable via SharedPreferences)
  static Future<List<int>> getSessionMilestones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Reload to ensure we have the latest data
      await prefs.reload();
      final saved = prefs.getStringList(_sessionMilestonesKey);
      if (saved != null && saved.isNotEmpty) {
        final milestones = saved.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList()..sort();
        print('📋 Loaded session milestones from SharedPreferences: $milestones');
        return milestones;
      } else {
        print('📋 No saved session milestones found, using defaults: $_defaultSessionMilestones');
      }
    } catch (e) {
      print('⚠️ Error loading session milestones: $e');
    }
    return List.from(_defaultSessionMilestones);
  }
  
  /// Get daily total milestones (configurable via SharedPreferences)
  static Future<List<int>> getDailyTotalMilestones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Reload to ensure we have the latest data
      await prefs.reload();
      final saved = prefs.getStringList(_dailyMilestonesKey);
      if (saved != null && saved.isNotEmpty) {
        final milestones = saved.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList()..sort();
        print('📋 Loaded daily milestones from SharedPreferences: $milestones');
        return milestones;
      } else {
        print('📋 No saved daily milestones found, using defaults: $_defaultDailyTotalMilestones');
      }
    } catch (e) {
      print('⚠️ Error loading daily milestones: $e');
    }
    return List.from(_defaultDailyTotalMilestones);
  }
  
  /// Set custom session milestones
  static Future<bool> setSessionMilestones(List<int> milestones) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Validate: must be positive integers
      final validMilestones = milestones.where((m) => m > 0).toList()..sort();
      if (validMilestones.isEmpty) {
        print('❌ Cannot save session milestones: at least one milestone required');
        return false; // At least one milestone required
      }
      final stringList = validMilestones.map((e) => e.toString()).toList();
      final success = await prefs.setStringList(_sessionMilestonesKey, stringList);
      
      // Force commit to ensure data is written immediately
      await prefs.reload();
      
      print('✅ Saved session milestones: $validMilestones (success: $success)');
      
      // Verify the save worked by reloading
      await prefs.reload();
      final saved = prefs.getStringList(_sessionMilestonesKey);
      print('🔍 Verification - Saved milestones: $saved');
      
      return success;
    } catch (e) {
      print('❌ Error saving session milestones: $e');
      return false;
    }
  }
  
  /// Set custom daily total milestones
  static Future<bool> setDailyTotalMilestones(List<int> milestones) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Validate: must be positive integers
      final validMilestones = milestones.where((m) => m > 0).toList()..sort();
      if (validMilestones.isEmpty) {
        print('❌ Cannot save daily milestones: at least one milestone required');
        return false; // At least one milestone required
      }
      final stringList = validMilestones.map((e) => e.toString()).toList();
      final success = await prefs.setStringList(_dailyMilestonesKey, stringList);
      
      // Force commit to ensure data is written immediately
      await prefs.reload();
      
      print('✅ Saved daily milestones: $validMilestones (success: $success)');
      
      // Verify the save worked
      await prefs.reload();
      final saved = prefs.getStringList(_dailyMilestonesKey);
      print('🔍 Verification - Saved daily milestones: $saved');
      
      return success;
    } catch (e) {
      print('❌ Error saving daily milestones: $e');
      return false;
    }
  }
  
  /// Reset milestones to defaults
  static Future<void> resetMilestonesToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionMilestonesKey);
      await prefs.remove(_dailyMilestonesKey);
    } catch (e) {
      print('❌ Error resetting milestones: $e');
    }
  }
  
  // Legacy getters for backward compatibility (use defaults)
  // Note: These are synchronous and return defaults. Use async getters above for user-configured values.
  static List<int> get sessionMilestones => _defaultSessionMilestones;
  static List<int> get dailyTotalMilestones => _defaultDailyTotalMilestones;
  
  // Notification Channel Configuration
  static const String reminderNotificationChannelId = 'screen_time_reminders';
  static const String reminderNotificationChannelName = 'Screen Time Reminders';
  static const String reminderNotificationChannelDescription = 'Notifications about your screen time milestones';
  
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