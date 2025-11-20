import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../models/user_models.dart';
import '../models/badge_models.dart';
import '../utils/input_validator.dart';
import '../config/app_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Rate limiting
  DateTime? _lastLoginAttempt;
  int _loginAttempts = 0;
  DateTime? _lastPasswordResetAttempt;
  int _passwordResetAttempts = 0;
  static const int _maxPasswordResetAttempts = 3;
  static const Duration _passwordResetCooldown = Duration(minutes: 2);

  // User tag rules: up to 15 letters followed by up to 4 digits
  static const int _userTagLettersMax = 15;
  static const int _userTagDigitsMax = 4;

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
    // Validate configuration
    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception('Invalid Supabase configuration');
    }
    
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    print('Using Supabase URL: ${AppConfig.supabaseUrl}');
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
    _resetRateLimiting();
    try {
      await DatabaseService().setSyncMetadata('supabase_session_json', '');
    } catch (_) {}
  }

  // Authentication methods with validation
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // Input validation
    if (!InputValidator.isValidEmail(email)) {
      throw Exception('Invalid email format');
    }
    
    final passwordError = InputValidator.validatePassword(password);
    if (passwordError != null) {
      throw Exception(passwordError);
    }
    
    // Rate limiting check
    if (_isRateLimited()) {
      throw Exception('Too many login attempts. Please wait before trying again.');
    }
    
    // Sanitize inputs
    final sanitizedEmail = InputValidator.sanitizeInput(email);
    
    try {
      _loginAttempts++;
      _lastLoginAttempt = DateTime.now();
      
      final response = await _client.auth.signInWithPassword(
        email: sanitizedEmail,
        password: password,
      );
      
      // Reset rate limiting on successful login
      _resetRateLimiting();
      
      // Persist session JSON for background recovery
      try {
        final session = response.session ?? _client.auth.currentSession;
        if (session != null) {
          final sessionJson = jsonEncode(session.toJson());
          await DatabaseService().setSyncMetadata('supabase_session_json', sessionJson);
        }
      } catch (_) {}
      
      return response;
    } catch (e) {
      print('Login attempt failed for ${InputValidator.hashForLogging(email)}: $e');
      rethrow;
    }
  }

  
  // Rate limiting methods
  bool _isRateLimited() {
    if (_lastLoginAttempt == null) return false;
    
    final timeSinceLastAttempt = DateTime.now().difference(_lastLoginAttempt!);
    return _loginAttempts >= AppConfig.maxLoginAttempts && 
           timeSinceLastAttempt < AppConfig.loginCooldown;
  }
  
  void _resetRateLimiting() {
    _loginAttempts = 0;
    _lastLoginAttempt = null;
  }

  bool _isPasswordResetRateLimited() {
    if (_lastPasswordResetAttempt == null) return false;

    final elapsed = DateTime.now().difference(_lastPasswordResetAttempt!);
    if (elapsed >= _passwordResetCooldown) {
      _passwordResetAttempts = 0;
      return false;
    }

    return _passwordResetAttempts >= _maxPasswordResetAttempts;
  }

  Future<void> sendPasswordResetEmail(String email, {String? redirectUrl}) async {
    if (!InputValidator.isValidEmail(email)) {
      throw Exception('Please enter a valid EVSU email address.');
    }

    if (_isPasswordResetRateLimited()) {
      throw Exception('Too many password reset requests. Please wait a moment before trying again.');
    }

    final sanitizedEmail = InputValidator.sanitizeInput(email.toLowerCase());

    try {
      _passwordResetAttempts++;
      _lastPasswordResetAttempt = DateTime.now();

      await _client.auth.resetPasswordForEmail(
        sanitizedEmail,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      // Roll back attempt counter so user can retry if request never reached Supabase
      if (DateTime.now().difference(_lastPasswordResetAttempt!).inSeconds < 5) {
        _passwordResetAttempts = (_passwordResetAttempts - 1).clamp(0, _maxPasswordResetAttempts);
      }
      rethrow;
    }
  }

  // ... rest of the existing methods remain the same


  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String department,
  }) async {
    // Input validation
    if (!InputValidator.isValidEmail(email)) {
      throw Exception('Invalid email format');
    }

    final passwordError = InputValidator.validatePassword(password);
    if (passwordError != null) {
      throw Exception(passwordError);
    }

    final nameError = InputValidator.validateName(fullName);
    if (nameError != null) {
      throw Exception(nameError);
    }

    // Sanitize inputs
    final sanitizedEmail = InputValidator.sanitizeInput(email);
    final sanitizedName = InputValidator.sanitizeInput(fullName);
    final sanitizedDepartment = InputValidator.sanitizeInput(department);

    try {
      print('Starting signup for: ${InputValidator.hashForLogging(email)}');
      const redirectUrl = 'triminder://auth-callback';
      print('📧 Email confirmation will redirect to: $redirectUrl');

      final response = await _client.auth.signUp(
        email: sanitizedEmail,
        password: password,
        emailRedirectTo: redirectUrl,
        data: {
          'full_name': sanitizedName,
          'department': sanitizedDepartment,
        },
      );

      print('Auth signup response: ${response.user?.id}');

      if (response.user != null) {
        print('Creating user profile...');

        final int? departmentId = await _getDepartmentId(sanitizedDepartment);

        // Generate a unique user tag for the new user
        final String userTag = await _generateUniqueUserTag(seedName: sanitizedName);

        final userProfile = UserProfile(
          id: response.user!.id,
          fullName: sanitizedName,
          email: sanitizedEmail,
          role: 'student',
          departmentId: departmentId,
          xp: 0,
          createdAt: DateTime.now(),
          isSynced: true,
        );

        await _createUserProfileWithTag(userProfile, userTag);
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

  /// Fetch department name by id from Supabase and cache locally
  Future<String?> getDepartmentNameById(int departmentId) async {
    try {
      final res = await _client
          .from('departments')
          .select('name')
          .eq('id', departmentId)
          .single();
      final name = res['name'] as String?;
      if (name != null) {
        await DatabaseService().upsertDepartment(departmentId, name);
      }
      return name;
    } catch (e) {
      // Fallback to local cache
      try {
        return await DatabaseService().getDepartmentName(departmentId);
      } catch (_) {
        return null;
      }
    }
  }

  // User profile operations

  // Note: superseded by _createUserProfileWithTag

  /// Create user profile and include a server-side `user_tag` field
  Future<UserProfile?> _createUserProfileWithTag(UserProfile profile, String userTag) async {
    try {
      final payload = {
        ...profile.toJson(),
        'user_tag': userTag.trim(),
      };
      final response = await _client
          .from('profiles')
          .insert(payload)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error creating user profile with tag: $e');
      return null;
    }
  }

  // In SupabaseService.getUserProfile()
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(Duration(seconds: 5)); // Add 5-second timeout
      
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
          .single()
          .timeout(Duration(seconds: 5)); // Add 5-second timeout

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  /// Update user profile with specific fields (avatar, cover photo, bio)
  Future<UserProfile?> updateUserProfileFields({
    String? avatarUrl,
    String? coverPhotoUrl,
    String? bio,
  }) async {
    if (!isAuthenticated) return null;

    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final updateData = <String, dynamic>{};
      // Allow setting to null by passing empty string, or update if provided
      if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl.isEmpty ? null : avatarUrl;
      }
      if (coverPhotoUrl != null) {
        updateData['cover_photo_url'] = coverPhotoUrl.isEmpty ? null : coverPhotoUrl;
      }
      if (bio != null) {
        // Validate bio length
        if (bio.length > 500) {
          throw Exception('Bio must be 500 characters or less');
        }
        updateData['bio'] = bio.isEmpty ? null : bio;
      }

      if (updateData.isEmpty) return null;

      final response = await _client
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single()
          .timeout(Duration(seconds: 5));

      final updatedProfile = UserProfile.fromJson(response);
      
      // Update local database after successful Supabase update
      try {
        final db = DatabaseService();
        await db.updateUserProfile(updatedProfile);
        print('✅ Profile updated in local database');
      } catch (e) {
        print('⚠️ Failed to update local database after profile update: $e');
        // Don't fail the entire operation if local update fails
      }
      
      return updatedProfile;
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('column') && errorMsg.contains('does not exist')) {
        throw Exception(
          'Database columns missing. Please run the migration: supabase_migrations/add_profile_fields.sql '
          'in your Supabase SQL Editor to add avatar_url, cover_photo_url, and bio columns.'
        );
      }
      print('Error updating user profile fields: $e');
      rethrow;
    }
  }

  /// Get user profile by ID (alias for getUserProfile for clarity)
  Future<UserProfile?> getUserProfileById(String userId) async {
    return getUserProfile(userId);
  }

  /// Get user badges with badge details
  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    try {
      final response = await _client
          .from('user_badges')
          .select('''
            badge_id,
            awarded_at,
            badges (
              id,
              name,
              description,
              icon_url,
              xp_reward
            )
          ''')
          .eq('user_id', userId)
          .order('awarded_at', ascending: false);

      final badges = <Map<String, dynamic>>[];
      for (final item in response) {
        final badgeData = item['badges'] as Map<String, dynamic>?;
        if (badgeData != null) {
          badges.add({
            'badgeId': item['badge_id'],
            'awardedAt': DateTime.parse(item['awarded_at']),
            'badge': {
              'id': badgeData['id'],
              'name': badgeData['name'],
              'description': badgeData['description'],
              'iconUrl': badgeData['icon_url'],
              'xpReward': badgeData['xp_reward'],
            },
          });
        }
      }

      return badges;
    } catch (e) {
      print('Error fetching user badges: $e');
      return [];
    }
  }

  /// Get friendship status between current user and target user
  /// Returns: 'none', 'friends', 'pending_in', 'pending_out', 'blocked', 'self'
  Future<String> getFriendshipStatus(String targetUserId) async {
    try {
      final me = currentUserId;
      if (me == null) return 'none';
      if (me == targetUserId) return 'self';

      final a = _leastId(me, targetUserId);
      final b = _greatestId(me, targetUserId);

      final response = await _client
          .from('friendships')
          .select('status, requester_id')
          .eq('user_a_id', a)
          .eq('user_b_id', b)
          .maybeSingle();

      if (response == null) return 'none';

      final status = response['status'] as String?;
      final requesterId = response['requester_id'] as String?;

      if (status == 'accepted') return 'friends';
      if (status == 'pending') {
        return requesterId == me ? 'pending_out' : 'pending_in';
      }
      if (status == 'blocked') return 'blocked';
      return 'none';
    } catch (e) {
      print('Error getting friendship status: $e');
      return 'none';
    }
  }

  // ---------------------------
  // XP Award History methods
  // ---------------------------

  /// Check if XP was already awarded for a specific date
  Future<bool> checkXPAwardedForDate(String userId, DateTime date) async {
    if (!isAuthenticated) return false;

    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final response = await _client
          .from('xp_award_history')
          .select('id')
          .eq('user_id', userId)
          .eq('award_date', dateStr)
          .limit(1)
          .timeout(Duration(seconds: 5));

      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking XP award for date: $e');
      return false; // Return false on error to allow retry
    }
  }

  /// Insert XP award history record into Supabase
  Future<XPAwardHistory?> insertXPAwardHistory(XPAwardHistory history) async {
    if (!isAuthenticated) return null;

    try {
      final response = await _client
          .from('xp_award_history')
          .insert(history.toJson())
          .select()
          .single()
          .timeout(Duration(seconds: 5));

      return XPAwardHistory.fromJson(response);
    } catch (e) {
      print('Error inserting XP award history: $e');
      return null;
    }
  }

  // ---------------------------
  // User Tag helpers
  // ---------------------------

  /// Validate user tag format (<=15 letters then <=4 digits)
  bool isValidUserTag(String tag) {
    final trimmed = tag.trim();
    return RegExp(r'^[A-Za-z]{1,15}\d{0,4}$').hasMatch(trimmed);
  }

  /// Check if a user tag is available (not used by any profile)
  Future<bool> isUserTagAvailable(String tag) async {
    try {
      if (!isValidUserTag(tag)) return false;
      final res = await _client
          .from('profiles')
          .select('id')
          .ilike('user_tag', tag.trim())
          .limit(1);
      return (res as List).isEmpty;
    } catch (e) {
      print('Error checking user tag availability: $e');
      return false;
    }
  }

  /// Update current user's tag if available and valid
  Future<bool> updateCurrentUserTag(String newTag) async {
    try {
      if (!isAuthenticated) return false;
      if (!isValidUserTag(newTag)) return false;
      final available = await isUserTagAvailable(newTag);
      if (!available) return false;
      final String uid = currentUserId!;
      
      // Update in Supabase
      await _client
          .from('profiles')
          .update({'user_tag': newTag.trim()})
          .eq('id', uid)
          .select('id')
          .single();
      
      // Fetch updated profile and update local database
      try {
        final updatedProfile = await getUserProfile(uid);
        if (updatedProfile != null) {
          final db = DatabaseService();
          await db.updateUserProfile(updatedProfile);
          print('✅ User tag updated in local database');
        }
      } catch (e) {
        print('⚠️ Failed to update local database after tag update: $e');
        // Still return true since Supabase update succeeded
      }
      
      return true;
    } catch (e) {
      print('Error updating user tag: $e');
      return false;
    }
  }

  /// Generate a unique user tag using the name seed and random digits
  Future<String> _generateUniqueUserTag({String? seedName}) async {
    // Derive base letters from name (letters only, max 20)
    String base = (seedName ?? 'User').replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (base.isEmpty) base = 'User';
    if (base.length > _userTagLettersMax) {
      base = base.substring(0, _userTagLettersMax);
    }

    // Try base without digits first
    String candidate = base;
    if (await isUserTagAvailable(candidate)) return candidate;

    // Then try base + 1..9999
    for (int i = 1; i <= 9999; i++) {
      final suffix = i.toString().padLeft(1, '0');
      if (suffix.length > _userTagDigitsMax) break;
      candidate = '$base$suffix';
      if (await isUserTagAvailable(candidate)) return candidate;
    }

    // Fallback to random letters+digits within limits
    for (int i = 0; i < 100; i++) {
      final digitsLen = (_userTagDigitsMax);
      final randNum = DateTime.now().microsecondsSinceEpoch % (pow10(digitsLen));
      candidate = '$base$randNum';
      if (candidate.length > (_userTagLettersMax + _userTagDigitsMax)) {
        candidate = candidate.substring(0, _userTagLettersMax + _userTagDigitsMax);
      }
      if (await isUserTagAvailable(candidate)) return candidate;
    }

    // Last resort
    return '${base}1';
  }

  int pow10(int n) {
    int v = 1;
    for (int i = 0; i < n; i++) v *= 10;
    return v;
  }

  // Screen time operations

  Future<List<ScreenTimeLog>> getScreenTimeLogs(String userId) async {
    if (!isAuthenticated) return [];

    try {
      final response = await _client
          .from('screen_time_logs')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .timeout(Duration(seconds: 5)); // Add 5-second timeout

      return (response as List)
          .map((json) => ScreenTimeLog.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching screen time entries: $e');
      return [];
    }
  }

  // ---------------------------
  // Friends / Profiles Lookup
  // ---------------------------

  /// Lookup a profile by user_tag (case-insensitive). Returns null if not found.
  Future<UserProfile?> getProfileByUserTag(String tag) async {
    try {
      if (tag.trim().isEmpty) return null;
      final res = await _client
          .from('profiles')
          .select()
          .ilike('user_tag', tag.trim())
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return UserProfile.fromJson(res);
    } catch (e) {
      print('Error looking up profile by tag: $e');
      return null;
    }
  }

  // -------------------------------------------------
  // Friendships (pending/accept/cancel) with normalized pair
  // Schema expected: friendships(user_a_id, user_b_id, requester_id, status)
  // -------------------------------------------------

  String _leastId(String a, String b) => a.compareTo(b) <= 0 ? a : b;
  String _greatestId(String a, String b) => a.compareTo(b) > 0 ? a : b;

  /// Send a friend request to [targetUserId]. Returns true if created or already pending.
  Future<bool> sendFriendRequest(String targetUserId) async {
    try {
      final me = currentUserId;
      if (me == null) throw Exception('Not authenticated');
      if (me == targetUserId) throw Exception('Cannot friend yourself');

      final a = _leastId(me, targetUserId);
      final b = _greatestId(me, targetUserId);

      // Try insert; if unique pair exists, handle gracefully
      try {
        await _client.from('friendships').insert({
          'user_a_id': a,
          'user_b_id': b,
          'requester_id': me,
          'status': 'pending',
        });
        return true;
      } catch (e) {
        // Check existing row and act based on status
        final existing = await _client
            .from('friendships')
            .select('id, requester_id, status')
            .eq('user_a_id', a)
            .eq('user_b_id', b)
            .maybeSingle();
        if (existing == null) rethrow;
        final status = existing['status'] as String?;
        if (status == 'accepted' || status == 'pending') return true;
        // If rejected/blocked, allow re-send by updating back to pending by requester
        if (existing['requester_id'] == me) {
          await _client
              .from('friendships')
              .update({'status': 'pending'})
              .eq('user_a_id', a)
              .eq('user_b_id', b);
          return true;
        }
        return false;
      }
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  /// Get incoming pending requests (someone sent me a request)
  Future<List<Map<String, dynamic>>> getIncomingPendingRequests() async {
    try {
      final me = currentUserId;
      if (me == null) return [];
      final rows = await _client
          .from('friendships')
          .select('id, user_a_id, user_b_id, requester_id, status, created_at')
          .eq('status', 'pending')
          .neq('requester_id', me)
          .or('user_a_id.eq.$me,user_b_id.eq.$me')
          .order('created_at', ascending: false);

      // Attach counterpart profile for convenience
      final counterpartIds = <String>{};
      for (final r in rows) {
        final ua = r['user_a_id'] as String;
        final ub = r['user_b_id'] as String;
        final other = ua == me ? ub : ua;
        counterpartIds.add(other);
      }
      final profiles = await _fetchProfilesByIds(counterpartIds.toList());
      final byId = {for (final p in profiles) p.id: p};
      return rows.map<Map<String, dynamic>>((r) {
        final ua = r['user_a_id'] as String;
        final ub = r['user_b_id'] as String;
        final other = ua == me ? ub : ua;
        return {
          ...r,
          'counterpart': byId[other],
        };
      }).toList();
    } catch (e) {
      print('Error fetching incoming requests: $e');
      return [];
    }
  }

  /// Get outgoing pending requests (I sent and waiting)
  Future<List<Map<String, dynamic>>> getOutgoingPendingRequests() async {
    try {
      final me = currentUserId;
      if (me == null) return [];
      final rows = await _client
          .from('friendships')
          .select('id, user_a_id, user_b_id, requester_id, status, created_at')
          .eq('status', 'pending')
          .eq('requester_id', me)
          .order('created_at', ascending: false);
      final counterpartIds = <String>{};
      for (final r in rows) {
        final ua = r['user_a_id'] as String;
        final ub = r['user_b_id'] as String;
        final other = ua == me ? ub : ua;
        counterpartIds.add(other);
      }
      final profiles = await _fetchProfilesByIds(counterpartIds.toList());
      final byId = {for (final p in profiles) p.id: p};
      return rows.map<Map<String, dynamic>>((r) {
        final ua = r['user_a_id'] as String;
        final ub = r['user_b_id'] as String;
        final other = ua == me ? ub : ua;
        return {
          ...r,
          'counterpart': byId[other],
        };
      }).toList();
    } catch (e) {
      print('Error fetching outgoing requests: $e');
      return [];
    }
  }

  /// Accept a pending request (recipient action)
  Future<bool> acceptFriendRequest(int id) async {
    try {
      await _client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', id)
          .eq('status', 'pending');
      return true;
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  /// Reject a pending request (recipient action)
  Future<bool> rejectFriendRequest(int id) async {
    try {
      await _client
          .from('friendships')
          .update({'status': 'rejected'})
          .eq('id', id)
          .eq('status', 'pending');
      return true;
    } catch (e) {
      print('Error rejecting friend request: $e');
      return false;
    }
  }

  /// Cancel my pending request (requester action)
  Future<bool> cancelMyPendingRequest(int id) async {
    try {
      await _client
          .from('friendships')
          .delete()
          .eq('id', id)
          .eq('status', 'pending');
      return true;
    } catch (e) {
      print('Error cancelling friend request: $e');
      return false;
    }
  }

  /// Unfriend a user (remove accepted friendship)
  Future<bool> unfriend(String targetUserId) async {
    try {
      final me = currentUserId;
      if (me == null) throw Exception('Not authenticated');
      if (me == targetUserId) throw Exception('Cannot unfriend yourself');

      final a = _leastId(me, targetUserId);
      final b = _greatestId(me, targetUserId);

      print('Unfriending: me=$me, target=$targetUserId, a=$a, b=$b');

      // First check if friendship exists and get the ID
      final existing = await _client
          .from('friendships')
          .select('id, status')
          .eq('user_a_id', a)
          .eq('user_b_id', b)
          .maybeSingle();

      if (existing == null) {
        print('No friendship record found');
        return false;
      }

      final friendshipId = existing['id'] as int?;
      final status = existing['status'] as String?;
      print('Found friendship with id=$friendshipId, status=$status');

      if (status != 'accepted') {
        print('Friendship status is not "accepted", it is: $status');
        return false;
      }

      if (friendshipId == null) {
        print('Friendship ID is null');
        return false;
      }

      // Delete the friendship record using the ID (more reliable than composite key)
      await _client
          .from('friendships')
          .delete()
          .eq('id', friendshipId);
      
      // Verify deletion by checking if record still exists
      final verify = await _client
          .from('friendships')
          .select('id')
          .eq('user_a_id', a)
          .eq('user_b_id', b)
          .maybeSingle();
      
      if (verify != null) {
        print('Warning: Friendship still exists after delete attempt');
        return false;
      }
      
      print('Successfully unfriended user: $targetUserId');
      return true;
    } catch (e, stackTrace) {
      print('Error unfriending user: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// List of accepted friends as UserProfile
  Future<List<UserProfile>> getFriends() async {
    try {
      final me = currentUserId;
      if (me == null) return [];
      final rows = await _client
          .from('friendships')
          .select('user_a_id, user_b_id, status')
          .eq('status', 'accepted')
          .or('user_a_id.eq.$me,user_b_id.eq.$me');
      final ids = <String>{};
      for (final r in rows) {
        final ua = r['user_a_id'] as String;
        final ub = r['user_b_id'] as String;
        ids.add(ua == me ? ub : ua);
      }
      return _fetchProfilesByIds(ids.toList());
    } catch (e) {
      print('Error fetching friends: $e');
      return [];
    }
  }

  /// Get friends count for a specific user
  /// Uses database function to bypass RLS and get accurate count for any user
  /// Only counts friendships with status = 'accepted' (same as getFriends())
  Future<int> getFriendsCountForUser(String userId) async {
    try {
      if (userId.isEmpty) return 0;
      
      // Use database function to get friends count (bypasses RLS)
      final response = await _client.rpc('get_user_friends_count', params: {
        'target_user_id': userId,
      });
      
      final count = (response as int?) ?? 0;
      print('Friends count from function for user $userId: $count');
      return count;
    } catch (e) {
      print('Error fetching friends count via function for user $userId: $e');
      print('Falling back to direct query...');
      
      // Fallback: use same logic as getFriends() to ensure consistency
      try {
        final rows = await _client
            .from('friendships')
            .select('user_a_id, user_b_id, status')
            .eq('status', 'accepted')  // Only count accepted friendships
            .or('user_a_id.eq.$userId,user_b_id.eq.$userId');
        
        final count = rows.length;
        print('Friends count from fallback query for user $userId: $count');
        return count;
      } catch (fallbackError) {
        print('Fallback query also failed: $fallbackError');
        return 0;
      }
    }
  }

  Future<List<UserProfile>> _fetchProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final res = await _client
          .from('profiles')
          .select()
          .inFilter('id', ids);
      return (res as List).map((e) => UserProfile.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching profiles by ids: $e');
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
          .order('start_time', ascending: false)
          .timeout(Duration(seconds: 5)); // Add 5-second timeout

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
          .single()
          .timeout(Duration(seconds: 5)); // Add 5-second timeout

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
          .from('screen_time_logs')
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

      await _client.from('screen_time_logs').upsert(data)
          .timeout(Duration(seconds: 10)); // Add 10-second timeout for batch upload
      return true;
    } catch (e) {
      print('Error uploading screen time entries: $e');
      return false;
    }
  }

  // Connection status
  // In SupabaseService
  Future<bool> isConnected() async {
    try {
      // Add timeout to prevent hanging
      await _client.from('profiles').select('id').limit(1)
          .timeout(Duration(seconds: 1)); // 1-second timeout
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

  // ---------------------------
  // Rankings (daily/weekly/monthly)
  // ---------------------------

  /// Get daily rankings (ascending by total minutes). Requires table: user_usage_daily
  Future<List<RankingEntry>> getDailyRankings({
    DateTime? date,
    int? departmentId,
    int limit = 100,
    int offset = 0,
    bool ascending = true,
  }) async {
    try {
      // Fix timezone bug: Use local time instead of UTC to prevent date shifting
      // For Philippines (UTC+8), this prevents showing yesterday's data until 8 AM
      final targetDate = date ?? DateTime.now();
      final dateStr = DateTime(targetDate.year, targetDate.month, targetDate.day).toIso8601String().substring(0, 10); // YYYY-MM-DD
      
      // Debug logging for timezone verification
      print('🌍 Daily rankings timezone debug:');
      print('   Local time: ${DateTime.now()}');
      print('   Target date: $targetDate');
      print('   Date string: $dateStr');

      final base = _client
          .from('user_usage_daily')
          .select('user_id, total_minutes, profiles!inner(id, full_name, user_tag, department_id, avatar_url, departments!inner(name))')
          .eq('usage_date', dateStr);

      if (departmentId != null) {
        // Apply related table filter before transform methods
        base.eq('profiles.department_id', departmentId);
      }

      final rows = await base
          .order('total_minutes', ascending: ascending)
          .range(offset, offset + limit - 1);
      return (rows as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final department = profile != null ? profile['departments'] as Map<String, dynamic>? : null;
        return RankingEntry(
          userId: row['user_id'] as String,
          userTag: profile != null ? profile['user_tag'] as String? : null,
          fullName: profile != null ? profile['full_name'] as String? : null,
          departmentId: profile != null ? profile['department_id'] as int? : null,
          departmentName: department != null ? department['name'] as String? : null,
          avatarUrl: profile != null ? profile['avatar_url'] as String? : null,
          valueMinutes: (row['total_minutes'] ?? 0) as int,
          period: 'daily',
        );
      }).toList();
    } catch (e) {
      print('Error fetching daily rankings: $e');
      return [];
    }
  }

  /// Get weekly rankings (ascending by avg minutes). Requires view: weekly_user_avg
  Future<List<RankingEntry>> getWeeklyRankings({
    int? departmentId,
    int limit = 100,
    int offset = 0,
    bool ascending = true,
  }) async {
    try {
      final base = _client
          .from('weekly_user_avg')
          .select('user_id, avg_minutes_7d, profiles!inner(id, full_name, user_tag, department_id, avatar_url, departments!inner(name))');

      if (departmentId != null) {
        base.eq('profiles.department_id', departmentId);
      }

      final rows = await base
          .order('avg_minutes_7d', ascending: ascending)
          .range(offset, offset + limit - 1);
      return (rows as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final department = profile != null ? profile['departments'] as Map<String, dynamic>? : null;
        return RankingEntry(
          userId: row['user_id'] as String,
          userTag: profile != null ? profile['user_tag'] as String? : null,
          fullName: profile != null ? profile['full_name'] as String? : null,
          departmentId: profile != null ? profile['department_id'] as int? : null,
          departmentName: department != null ? department['name'] as String? : null,
          avatarUrl: profile != null ? profile['avatar_url'] as String? : null,
          valueMinutes: (row['avg_minutes_7d'] ?? 0) as int,
          period: 'weekly',
        );
      }).toList();
    } catch (e) {
      print('Error fetching weekly rankings: $e');
      return [];
    }
  }

  /// Get monthly rankings (ascending by avg minutes). Requires view: monthly_user_avg
  Future<List<RankingEntry>> getMonthlyRankings({
    int? departmentId,
    int limit = 100,
    int offset = 0,
    bool ascending = true,
  }) async {
    try {
      final base = _client
          .from('monthly_user_avg')
          .select('user_id, avg_minutes_30d, profiles!inner(id, full_name, user_tag, department_id, avatar_url, departments!inner(name))');

      if (departmentId != null) {
        base.eq('profiles.department_id', departmentId);
      }

      final rows = await base
          .order('avg_minutes_30d', ascending: ascending)
          .range(offset, offset + limit - 1);
      return (rows as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final department = profile != null ? profile['departments'] as Map<String, dynamic>? : null;
        return RankingEntry(
          userId: row['user_id'] as String,
          userTag: profile != null ? profile['user_tag'] as String? : null,
          fullName: profile != null ? profile['full_name'] as String? : null,
          departmentId: profile != null ? profile['department_id'] as int? : null,
          departmentName: department != null ? department['name'] as String? : null,
          avatarUrl: profile != null ? profile['avatar_url'] as String? : null,
          valueMinutes: (row['avg_minutes_30d'] ?? 0) as int,
          period: 'monthly',
        );
      }).toList();
    } catch (e) {
      print('Error fetching monthly rankings: $e');
      return [];
    }
  }

  // ---------------------------
  // Friends Rankings
  // ---------------------------

  /// Get friend IDs for the current user (including self)
  Future<List<String>> _getFriendIds() async {
    try {
      final me = currentUserId;
      if (me == null) return [];

      // Get accepted friends
      final rows = await _client
          .from('friendships')
          .select('user_a_id, user_b_id, status')
          .eq('status', 'accepted')
          .or('user_a_id.eq.$me,user_b_id.eq.$me');

      final ids = <String>{me}; // Include current user
      for (final r in rows) {
        final ua = r['user_a_id'] as String;
        final ub = r['user_b_id'] as String;
        ids.add(ua == me ? ub : ua);
      }
      return ids.toList();
    } catch (e) {
      print('Error fetching friend IDs: $e');
      return [];
    }
  }

  /// Get daily rankings filtered by accepted friends
  Future<List<RankingEntry>> getFriendsDailyRankings({
    DateTime? date,
    int limit = 100,
    int offset = 0,
    bool ascending = true,
  }) async {
    try {
      final friendIds = await _getFriendIds();
      if (friendIds.isEmpty) {
        return [];
      }

      final targetDate = date ?? DateTime.now();
      final dateStr = DateTime(targetDate.year, targetDate.month, targetDate.day).toIso8601String().substring(0, 10);

      final base = _client
          .from('user_usage_daily')
          .select('user_id, total_minutes, profiles!inner(id, full_name, user_tag, department_id, avatar_url, departments!inner(name))')
          .eq('usage_date', dateStr)
          .inFilter('user_id', friendIds);

      final rows = await base
          .order('total_minutes', ascending: ascending)
          .range(offset, offset + limit - 1);

      return (rows as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final department = profile != null ? profile['departments'] as Map<String, dynamic>? : null;
        return RankingEntry(
          userId: row['user_id'] as String,
          userTag: profile != null ? profile['user_tag'] as String? : null,
          fullName: profile != null ? profile['full_name'] as String? : null,
          departmentId: profile != null ? profile['department_id'] as int? : null,
          departmentName: department != null ? department['name'] as String? : null,
          avatarUrl: profile != null ? profile['avatar_url'] as String? : null,
          valueMinutes: (row['total_minutes'] ?? 0) as int,
          period: 'daily',
        );
      }).toList();
    } catch (e) {
      print('Error fetching friends daily rankings: $e');
      return [];
    }
  }

  /// Get weekly rankings filtered by accepted friends
  Future<List<RankingEntry>> getFriendsWeeklyRankings({
    int limit = 100,
    int offset = 0,
    bool ascending = true,
  }) async {
    try {
      final friendIds = await _getFriendIds();
      if (friendIds.isEmpty) {
        return [];
      }

      final base = _client
          .from('weekly_user_avg')
          .select('user_id, avg_minutes_7d, profiles!inner(id, full_name, user_tag, department_id, avatar_url, departments!inner(name))')
          .inFilter('user_id', friendIds);

      final rows = await base
          .order('avg_minutes_7d', ascending: ascending)
          .range(offset, offset + limit - 1);

      return (rows as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final department = profile != null ? profile['departments'] as Map<String, dynamic>? : null;
        return RankingEntry(
          userId: row['user_id'] as String,
          userTag: profile != null ? profile['user_tag'] as String? : null,
          fullName: profile != null ? profile['full_name'] as String? : null,
          departmentId: profile != null ? profile['department_id'] as int? : null,
          departmentName: department != null ? department['name'] as String? : null,
          avatarUrl: profile != null ? profile['avatar_url'] as String? : null,
          valueMinutes: (row['avg_minutes_7d'] ?? 0) as int,
          period: 'weekly',
        );
      }).toList();
    } catch (e) {
      print('Error fetching friends weekly rankings: $e');
      return [];
    }
  }

  /// Get monthly rankings filtered by accepted friends
  Future<List<RankingEntry>> getFriendsMonthlyRankings({
    int limit = 100,
    int offset = 0,
    bool ascending = true,
  }) async {
    try {
      final friendIds = await _getFriendIds();
      if (friendIds.isEmpty) {
        return [];
      }

      final base = _client
          .from('monthly_user_avg')
          .select('user_id, avg_minutes_30d, profiles!inner(id, full_name, user_tag, department_id, avatar_url, departments!inner(name))')
          .inFilter('user_id', friendIds);

      final rows = await base
          .order('avg_minutes_30d', ascending: ascending)
          .range(offset, offset + limit - 1);

      return (rows as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final department = profile != null ? profile['departments'] as Map<String, dynamic>? : null;
        return RankingEntry(
          userId: row['user_id'] as String,
          userTag: profile != null ? profile['user_tag'] as String? : null,
          fullName: profile != null ? profile['full_name'] as String? : null,
          departmentId: profile != null ? profile['department_id'] as int? : null,
          departmentName: department != null ? department['name'] as String? : null,
          avatarUrl: profile != null ? profile['avatar_url'] as String? : null,
          valueMinutes: (row['avg_minutes_30d'] ?? 0) as int,
          period: 'monthly',
        );
      }).toList();
    } catch (e) {
      print('Error fetching friends monthly rankings: $e');
      return [];
    }
  }

  // ---------------------------
  // Account Deletion
  // ---------------------------

  /// Delete user account and all associated data from Supabase
  /// Returns true if successful, false otherwise
  Future<bool> deleteUserAccount(String userId) async {
    if (!isAuthenticated) {
      print('❌ Cannot delete account: User not authenticated');
      return false;
    }

    // Verify user can only delete their own account
    if (currentUserId != userId) {
      print('❌ Cannot delete account: User can only delete their own account');
      return false;
    }

    try {
      print('🗑️ Starting account deletion for user: $userId');

      // Delete user data from all tables in order (respecting foreign key constraints)
      
      // 1. Delete friendships (where user is either user_a_id or user_b_id)
      try {
        await _client
            .from('friendships')
            .delete()
            .or('user_a_id.eq.$userId,user_b_id.eq.$userId');
        print('✅ Deleted friendships');
      } catch (e) {
        print('⚠️ Error deleting friendships: $e');
        // Continue with other deletions
      }

      // 2. Delete likes (where user is either liker_id or liked_id)
      try {
        await _client
            .from('likes')
            .delete()
            .or('liker_id.eq.$userId,liked_id.eq.$userId');
        print('✅ Deleted likes');
      } catch (e) {
        print('⚠️ Error deleting likes: $e');
        // Continue with other deletions
      }

      // 3. Delete leaderboard snapshots
      try {
        await _client
            .from('leaderboard_snapshots')
            .delete()
            .eq('user_id', userId);
        print('✅ Deleted leaderboard snapshots');
      } catch (e) {
        print('⚠️ Error deleting leaderboard snapshots: $e');
        // Continue with other deletions
      }

      // 4. Delete user badges
      try {
        await _client
            .from('user_badges')
            .delete()
            .eq('user_id', userId);
        print('✅ Deleted user badges');
      } catch (e) {
        print('⚠️ Error deleting user badges: $e');
        // Continue with other deletions
      }

      // 5. Delete XP award history
      try {
        await _client
            .from('xp_award_history')
            .delete()
            .eq('user_id', userId);
        print('✅ Deleted XP award history');
      } catch (e) {
        print('⚠️ Error deleting XP award history: $e');
        // Continue with other deletions
      }

      // 6. Delete screen time logs
      try {
        await _client
            .from('screen_time_logs')
            .delete()
            .eq('user_id', userId);
        print('✅ Deleted screen time logs');
      } catch (e) {
        print('⚠️ Error deleting screen time logs: $e');
        // Continue with other deletions
      }

      // 7. Delete from usage aggregation tables (these have foreign keys to profiles)
      // These tables are used for rankings and must be deleted before profile deletion
      try {
        await _client
            .from('user_usage_daily')
            .delete()
            .eq('user_id', userId);
        print('✅ Deleted user_usage_daily records');
      } catch (e) {
        print('⚠️ Error deleting user_usage_daily: $e');
        // Continue with other deletions
      }

      // Note: weekly_user_avg and monthly_user_avg are views (not tables)
      // Views are computed from underlying tables and don't store data
      // They will automatically reflect deletions when screen_time_logs are deleted
      // No need to delete from views - they're read-only aggregations

      // 8. Delete auth account via RPC function (BEFORE deleting profile)
      // This must be done before profile deletion so auth.uid() is still valid
      // This requires a database function to be created in Supabase
      bool authDeleted = false;
      try {
        // Call the RPC function to delete the auth user
        // We do this before deleting the profile so the security check works
        final rpcResult = await _client.rpc('delete_user_account', params: {
          'user_id_to_delete': userId,
        });
        
        // Handle different return types (boolean, integer, etc.)
        if (rpcResult == true || rpcResult == 1 || rpcResult == 'true') {
          print('✅ Auth account deleted via RPC');
          authDeleted = true;
        } else if (rpcResult == false || rpcResult == 0 || rpcResult == 'false') {
          print('⚠️ RPC function returned false - auth account deletion failed');
          print('   This might be due to the user not existing or permission issues');
          print('   Continuing with profile deletion anyway...');
        } else {
          print('⚠️ RPC returned unexpected result: $rpcResult (type: ${rpcResult.runtimeType})');
        }
      } catch (e) {
        print('⚠️ Error deleting auth account via RPC: $e');
        
        // If RPC function doesn't exist, provide helpful error message
        if (e.toString().contains('function') || e.toString().contains('does not exist')) {
          print('⚠️ RPC function "delete_user_account" not found in Supabase.');
          print('   Please create the function in your Supabase database.');
          print('   See ACCOUNT_DELETION_SETUP.md or supabase_migrations/delete_user_account_function.sql');
          print('   Continuing with data deletion...');
        }
      }

      // 9. Delete user profile (must be after usage tables due to foreign key constraints)
      try {
        await _client
            .from('profiles')
            .delete()
            .eq('id', userId);
        print('✅ Deleted user profile');
      } catch (e) {
        print('⚠️ Error deleting user profile: $e');
        // Continue even if profile deletion fails
      }
      
      // Sign out regardless of RPC result
      try {
        await _client.auth.signOut();
        if (authDeleted) {
          print('✅ Signed out after successful auth deletion');
        } else {
          print('⚠️ Signed out but auth account may still exist in Supabase');
          print('   Please check Supabase dashboard and manually delete if needed');
        }
      } catch (signOutError) {
        print('❌ Error signing out: $signOutError');
      }

      print('✅ Account deletion completed successfully');
      return true;
    } catch (e) {
      print('❌ Error during account deletion: $e');
      return false;
    }
  }
}
