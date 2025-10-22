import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../services/database_service.dart';

/// Helper to ensure Supabase is initialized in background isolate and
/// recover the user's session so background sync can proceed.
class BackgroundSupabaseClient {
  static bool _initialized = false;

  /// Ensure Supabase is initialized and session is recovered.
  /// Returns true if an authenticated user is available afterwards.
  static Future<bool> ensureInitializedAndRecovered() async {
    try {
      // Initialize if needed
      if (!_initialized) {
        // Load environment for background isolate
        try {
          await AppConfig.initialize();
        } catch (_) {}

        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
        _initialized = true;
      }

      final client = Supabase.instance.client;

      // If already authenticated, nothing else to do
      if (client.auth.currentUser != null) {
        return true;
      }

      // Try to recover persisted session
      final sessionJson = await DatabaseService().getSyncMetadata('supabase_session_json');
      if (sessionJson == null || sessionJson.isEmpty) {
        return false;
      }

      // Recover session from persisted JSON string
      try {
        await client.auth.recoverSession(sessionJson);
      } catch (_) {
        // If recover fails, consider not authenticated
        return false;
      }

      return client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }
}


