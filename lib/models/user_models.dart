import '../utils/level_calculator.dart';
import '../services/database_service.dart';
// User profile model matching Supabase profiles table
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final int? departmentId;
  final int xp;
  final DateTime createdAt;
  final bool isSynced;
  final String? userTag; // Supabase: user_tag
  final String? avatarUrl; // Supabase: avatar_url
  final String? coverPhotoUrl; // Supabase: cover_photo_url
  final String? bio; // Supabase: bio (max 500 chars)

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.departmentId,
    required this.xp,
    required this.createdAt,
    this.isSynced = false,
    this.userTag,
    this.avatarUrl,
    this.coverPhotoUrl,
    this.bio,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    int? departmentId,
    int? xp,
    DateTime? createdAt,
    bool? isSynced,
    String? userTag,
    String? avatarUrl,
    String? coverPhotoUrl,
    String? bio,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      departmentId: departmentId ?? this.departmentId,
      xp: xp ?? this.xp,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      userTag: userTag ?? this.userTag,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'departmentId': departmentId,
      'xp': xp,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'userTag': userTag,
      'avatarUrl': avatarUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'bio': bio,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      fullName: map['fullName'],
      email: map['email'],
      role: map['role'],
      departmentId: map['departmentId'],
      xp: map['xp'],
      createdAt: DateTime.parse(map['createdAt']),
      isSynced: map['isSynced'] == 1,
      userTag: map['userTag'],
      avatarUrl: map['avatarUrl'],
      coverPhotoUrl: map['coverPhotoUrl'],
      bio: map['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'department_id': departmentId,
      'xp': xp,
      'created_at': createdAt.toIso8601String(),
      if (userTag != null) 'user_tag': userTag,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (coverPhotoUrl != null) 'cover_photo_url': coverPhotoUrl,
      if (bio != null) 'bio': bio,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      role: json['role'],
      departmentId: json['department_id'],
      xp: json['xp'],
      createdAt: DateTime.parse(json['created_at']),
      isSynced: true,
      userTag: json['user_tag'],
      avatarUrl: json['avatar_url'],
      coverPhotoUrl: json['cover_photo_url'],
      bio: json['bio'],
    );
  }

  // Validate bio length (max 500 characters)
  static String? validateBio(String? bio) {
    if (bio == null || bio.isEmpty) return null;
    if (bio.length > 500) {
      return 'Bio must be 500 characters or less';
    }
    return null;
  }

  // Add this method to UserProfile class
  Future<int> getTotalXPWithPending() async {
    try {
      final db = DatabaseService();
      final pendingXP = await db.getPendingXPForUser(this.id);
      return this.xp + pendingXP;
    } catch (e) {
      print('Error getting pending XP: $e');
      return this.xp; // Fallback to current XP
    }
  }

  Future<int> getLevelWithPending() async {
    final totalXP = await getTotalXPWithPending();
    return LevelCalculator.getLevel(totalXP);
  }

  Future<double> getProgressToNextLevelWithPending() async {
    final totalXP = await getTotalXPWithPending();
    return LevelCalculator.getProgressToNextLevel(totalXP);
  }

  // Convenience getters for level calculations
  int get level => LevelCalculator.getLevel(xp);
  
  double get progressToNextLevel => LevelCalculator.getProgressToNextLevel(xp);
  
  Map<String, int> get currentLevelProgress => LevelCalculator.getCurrentLevelProgress(xp);
  
  int get xpRemainingToNextLevel => LevelCalculator.getXPRemainingToNextLevel(xp);
}

// Add this at the end of lib/models/user_models.dart (after line 201)

// XP update log for offline storage
class XPUpdateLog {
  final int id;
  final String userId;
  final int xpToAdd;
  final DateTime date;
  final DateTime createdAt;
  final bool isSynced;

  XPUpdateLog({
    required this.id,
    required this.userId,
    required this.xpToAdd,
    required this.date,
    required this.createdAt,
    this.isSynced = false,
  });

  XPUpdateLog copyWith({
    int? id,
    String? userId,
    int? xpToAdd,
    DateTime? date,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return XPUpdateLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      xpToAdd: xpToAdd ?? this.xpToAdd,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'xpToAdd': xpToAdd,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory XPUpdateLog.fromMap(Map<String, dynamic> map) {
    return XPUpdateLog(
      id: map['id'],
      userId: map['userId'],
      xpToAdd: map['xpToAdd'],
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['createdAt']),
      isSynced: map['isSynced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'xp_to_add': xpToAdd,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory XPUpdateLog.fromJson(Map<String, dynamic> json) {
    return XPUpdateLog(
      id: json['id'],
      userId: json['user_id'],
      xpToAdd: json['xp_to_add'],
      date: DateTime.parse(json['date']),
      createdAt: DateTime.parse(json['created_at']),
      isSynced: json['is_synced'] ?? false,
    );
  }
}

// Screen time log model matching Supabase screen_time_logs table
class ScreenTimeLog {
  final int id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final bool breakTaken;
  final DateTime createdAt;
  final bool isSynced;

  ScreenTimeLog({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    required this.breakTaken,
    required this.createdAt,
    this.isSynced = false,
  });

  ScreenTimeLog copyWith({
    int? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    bool? breakTaken,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return ScreenTimeLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      breakTaken: breakTaken ?? this.breakTaken,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'breakTaken': breakTaken ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory ScreenTimeLog.fromMap(Map<String, dynamic> map) {
    return ScreenTimeLog(
      id: map['id'],
      userId: map['userId'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      durationMinutes: map['durationMinutes'],
      breakTaken: map['breakTaken'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      isSynced: map['isSynced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      // Note: duration_minutes is excluded - it's a generated column in Supabase
      'break_taken': breakTaken,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScreenTimeLog.fromJson(Map<String, dynamic> json) {
    return ScreenTimeLog(
      id: json['id'],
      userId: json['user_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      durationMinutes: json['duration_minutes'],
      breakTaken: json['break_taken'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      isSynced: true,
    );
  }
}

// XP Award History model matching Supabase xp_award_history table
class XPAwardHistory {
  final int id;
  final String userId;
  final DateTime awardDate; // Date only (no time component)
  final int xpAwarded;
  final int screenTimeMinutes;
  final DateTime createdAt;
  final bool isSynced;

  XPAwardHistory({
    required this.id,
    required this.userId,
    required this.awardDate,
    required this.xpAwarded,
    required this.screenTimeMinutes,
    required this.createdAt,
    this.isSynced = false,
  });

  XPAwardHistory copyWith({
    int? id,
    String? userId,
    DateTime? awardDate,
    int? xpAwarded,
    int? screenTimeMinutes,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return XPAwardHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      awardDate: awardDate ?? this.awardDate,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      screenTimeMinutes: screenTimeMinutes ?? this.screenTimeMinutes,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'awardDate': awardDate.toIso8601String().split('T')[0], // Store date only
      'xpAwarded': xpAwarded,
      'screenTimeMinutes': screenTimeMinutes,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory XPAwardHistory.fromMap(Map<String, dynamic> map) {
    // Parse date string (format: YYYY-MM-DD)
    final dateStr = map['awardDate'] as String;
    // Remove any time component if present
    final dateOnly = dateStr.split('T')[0].split(' ')[0];
    final dateParts = dateOnly.split('-');
    final awardDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    return XPAwardHistory(
      id: map['id'],
      userId: map['userId'],
      awardDate: awardDate,
      xpAwarded: map['xpAwarded'],
      screenTimeMinutes: map['screenTimeMinutes'],
      createdAt: DateTime.parse(map['createdAt']),
      isSynced: map['isSynced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    // Format date as YYYY-MM-DD for Supabase
    final dateStr = '${awardDate.year}-${awardDate.month.toString().padLeft(2, '0')}-${awardDate.day.toString().padLeft(2, '0')}';
    
    return {
      'user_id': userId,
      'award_date': dateStr,
      'xp_awarded': xpAwarded,
      'screen_time_minutes': screenTimeMinutes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory XPAwardHistory.fromJson(Map<String, dynamic> json) {
    // Parse award_date (format: YYYY-MM-DD)
    final dateStr = json['award_date'] as String;
    final dateParts = dateStr.split('-');
    final awardDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    return XPAwardHistory(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      awardDate: awardDate,
      xpAwarded: json['xp_awarded'],
      screenTimeMinutes: json['screen_time_minutes'],
      createdAt: DateTime.parse(json['created_at']),
      isSynced: true,
    );
  }
}

// Ranking entry DTO for leaderboards
class RankingEntry {
  final String userId;
  final String? userTag;
  final String? fullName;
  final int? departmentId;
  final String? departmentName;
  final String? avatarUrl; // Avatar URL from Supabase Storage
  final int valueMinutes; // daily total or averaged minutes depending on period
  final String period; // 'daily' | 'weekly' | 'monthly'

  RankingEntry({
    required this.userId,
    this.userTag,
    this.fullName,
    this.departmentId,
    this.departmentName,
    this.avatarUrl,
    required this.valueMinutes,
    required this.period,
  });

  factory RankingEntry.fromMap(Map<String, dynamic> map, {required String period}) {
    return RankingEntry(
      userId: map['user_id'] ?? map['id'] ?? map['userId'],
      userTag: map['user_tag'] ?? map['userTag'],
      fullName: map['full_name'] ?? map['fullName'],
      departmentId: map['department_id'] ?? map['departmentId'],
      departmentName: map['department_name'] ?? map['departmentName'],
      avatarUrl: map['avatar_url'] ?? map['avatarUrl'],
      valueMinutes: (map['total_minutes'] ?? map['avg_minutes'] ?? map['avg_minutes_7d'] ?? map['avg_minutes_30d'] ?? 0) as int,
      period: period,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_tag': userTag,
      'full_name': fullName,
      'department_id': departmentId,
      'department_name': departmentName,
      'avatar_url': avatarUrl,
      'value_minutes': valueMinutes,
      'period': period,
    };
  }
}