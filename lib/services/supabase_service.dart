import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_models.dart';
import '../models/badge_models.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw Exception('Supabase not initialized. Call SupabaseService.initialize() first.');
    }
  }

  // Public getter for client access
  SupabaseClient get client => _client;

  // Initialize Supabase (call this in main.dart)
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  // Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  // Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  // Get current user email
  String? get currentUserEmail => _client.auth.currentUser?.email;

  // Sign out current user
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Authentication methods
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String department,
  }) async {
    try {
      print('Starting signup for: $email');
      
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'department': department,
        },
      );

      print('Auth signup response: ${response.user?.id}');

      // Create user profile in database
      if (response.user != null) {
        print('Creating user profile...');
        
        // First, get the department ID
        int? departmentId = await _getDepartmentId(department);
        
        final userProfile = UserProfile(
          id: response.user!.id,
          fullName: fullName,
          email: email,
          role: 'student',
          departmentId: departmentId,
          xp: 0,
          createdAt: DateTime.now(),
          isSynced: true,
        );

        await _createUserProfile(userProfile);
        print('User profile created successfully');
      }

      return response;
    } catch (e) {
      print('Error in signUpWithEmailPassword: $e');
      rethrow;
    }
  }

  // Helper method to get department ID
  Future<int?> _getDepartmentId(String departmentName) async {
    try {
      print('Looking up department: $departmentName');
      final response = await _client
          .from('departments')
          .select('id')
          .eq('name', departmentName)
          .single();
      
      print('Found department ID: ${response['id']}');
      return response['id'] as int?;
    } catch (e) {
      print('Error fetching department ID for "$departmentName": $e');
      // For now, return null and let the profile be created without department
      return null;
    }
  }

  // User profile operations

  Future<UserProfile?> _createUserProfile(UserProfile profile) async {
    try {
      final response = await _client
          .from('profiles')
          .insert(profile.toJson())
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error creating user profile: $e');
      return null;
    }
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<UserProfile?> updateUserProfile(UserProfile profile) async {
    if (!isAuthenticated) return null;

    try {
      final response = await _client
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  // Screen time operations

  Future<List<ScreenTimeLog>> getScreenTimeLogs(String userId) async {
    if (!isAuthenticated) return [];

    try {
      final response = await _client
          .from('screen_time_logs')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false);

      return (response as List)
          .map((json) => ScreenTimeLog.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching screen time entries: $e');
      return [];
    }
  }

  /// Get screen time logs since a specific timestamp (for incremental sync)
  Future<List<ScreenTimeLog>> getScreenTimeLogsSince(String userId, DateTime since) async {
    if (!isAuthenticated) return [];

    try {
      final response = await _client
          .from('screen_time_logs')
          .select()
          .eq('user_id', userId)
          .gte('created_at', since.toIso8601String())
          .order('start_time', ascending: false);

      print('📥 Queried Supabase for logs since ${since.toIso8601String()}');
      print('   - Found ${(response as List).length} entries');

      return (response as List)
          .map((json) => ScreenTimeLog.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching incremental screen time logs: $e');
      return [];
    }
  }

  Future<ScreenTimeLog?> insertScreenTimeLog(ScreenTimeLog entry) async {
    if (!isAuthenticated) return null;

    try {
      final data = entry.toJson();
      data['user_id'] = currentUserId;

      final response = await _client
          .from('screen_time_logs')
          .insert(data)
          .select()
          .single();

      return ScreenTimeLog.fromJson(response);
    } catch (e) {
      print('Error inserting screen time entry: $e');
      return null;
    }
  }

  Future<ScreenTimeLog?> updateScreenTimeLog(ScreenTimeLog entry) async {
    if (!isAuthenticated) return null;

    try {
      final data = entry.toJson();
      data['user_id'] = currentUserId;

      final response = await _client
          .from('screen_time_entries')
          .update(data)
          .eq('id', entry.id)
          .eq('user_id', currentUserId!)
          .select()
          .single();

      return ScreenTimeLog.fromJson(response);
    } catch (e) {
      print('Error updating screen time entry: $e');
      return null;
    }
  }

  // Badge operations

  Future<List<Badge>> getAllBadges() async {
    try {
      final response = await _client
          .from('badges')
          .select()
          .order('created_at');

      return (response as List)
          .map((json) => Badge.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching badges: $e');
      return [];
    }
  }

  Future<List<UserBadge>> getUserBadges(String userId) async {
    if (!isAuthenticated) return [];

    try {
      final response = await _client
          .from('user_badges')
          .select()
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      return (response as List)
          .map((json) => UserBadge.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user badges: $e');
      return [];
    }
  }

  Future<UserBadge?> insertUserBadge(UserBadge userBadge) async {
    if (!isAuthenticated) return null;

    try {
      final data = userBadge.toJson();
      data['user_id'] = currentUserId;

      final response = await _client
          .from('user_badges')
          .insert(data)
          .select()
          .single();

      return UserBadge.fromJson(response);
    } catch (e) {
      print('Error inserting user badge: $e');
      return null;
    }
  }

  // Rankings and social features

  Future<List<UserProfile>> getDepartmentRankings(int departmentId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('department_id', departmentId)
          .order('xp', ascending: false)
          .limit(50);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching department rankings: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getGlobalRankings() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .order('xp', ascending: false)
          .limit(100);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching global rankings: $e');
      return [];
    }
  }

  // Sync operations

  Future<bool> uploadScreenTimeLogs(List<ScreenTimeLog> entries) async {
    if (!isAuthenticated || entries.isEmpty) return false;

    try {
      final data = entries.map((entry) {
        final json = entry.toJson();
        json['user_id'] = currentUserId;
        return json;
      }).toList();

      await _client.from('screen_time_logs').upsert(data);
      return true;
    } catch (e) {
      print('Error uploading screen time entries: $e');
      return false;
    }
  }

  // Connection status
  Future<bool> isConnected() async {
    try {
      // Simple connectivity test - just check if we can reach Supabase
      await _client.from('profiles').select('id').limit(1);
      print('🔍 Supabase connection: ✅ Success');
      return true;
    } catch (e) {
      print('🔍 Supabase connection: ❌ Failed - $e');
      
      // Check if it's a table permissions issue vs connectivity
      if (e.toString().contains('relation "profiles" does not exist') ||
          e.toString().contains('permission denied')) {
        print('   → This might be a database permissions or table name issue');
        return false;
      } else if (e.toString().contains('network') ||
                e.toString().contains('timeout') ||
                e.toString().contains('connection')) {
        print('   → This appears to be a network connectivity issue');
        return false;
      } else {
        print('   → Unknown connectivity issue: $e');
        return false;
      }
    }
  }
}
