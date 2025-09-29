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
    );
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
