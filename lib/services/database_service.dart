import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_models.dart';
import '../models/badge_models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'triminder.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // User profiles table
    await db.execute('''
      CREATE TABLE user_profiles (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        department TEXT NOT NULL,
        totalXP INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        dailyLikes INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Screen time entries table
    await db.execute('''
      CREATE TABLE screen_time_entries (
        id INTEGER PRIMARY KEY,
        userId TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        durationMinutes INTEGER,
        breakTaken INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES user_profiles (id)
      )
    ''');

    // Badges table
    await db.execute('''
      CREATE TABLE badges (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        iconPath TEXT NOT NULL,
        type INTEGER NOT NULL,
        requiredValue INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // User badges table (earned badges)
    await db.execute('''
      CREATE TABLE user_badges (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        badgeId TEXT NOT NULL,
        earnedAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES user_profiles (id),
        FOREIGN KEY (badgeId) REFERENCES badges (id)
      )
    ''');
  }

  // CRUD Operations for User Profiles

  Future<UserProfile?> getUserProfile(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.insert(
      'user_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.update(
      'user_profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  // CRUD Operations for Screen Time Logs

  Future<List<ScreenTimeLog>> getScreenTimeLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'screen_time_logs',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'startTime DESC',
    );

    return List.generate(maps.length, (i) {
      return ScreenTimeLog.fromMap(maps[i]);
    });
  }

  Future<ScreenTimeLog?> getScreenTimeLog(int logId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'screen_time_logs',
      where: 'id = ?',
      whereArgs: [logId],
    );

    if (maps.isNotEmpty) {
      return ScreenTimeLog.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertScreenTimeLog(ScreenTimeLog entry) async {
    final db = await database;
    return await db.insert(
      'screen_time_logs',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateScreenTimeLog(ScreenTimeLog entry) async {
    final db = await database;
    return await db.update(
      'screen_time_logs',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // CRUD Operations for Badges

  Future<List<Badge>> getAllBadges() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('badges');

    return List.generate(maps.length, (i) {
      return Badge.fromMap(maps[i]);
    });
  }

  Future<int> insertBadge(Badge badge) async {
    final db = await database;
    return await db.insert(
      'badges',
      badge.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserBadge>> getUserBadges(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_badges',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'earnedAt DESC',
    );

    return List.generate(maps.length, (i) {
      return UserBadge.fromMap(maps[i]);
    });
  }

  Future<int> insertUserBadge(UserBadge userBadge) async {
    final db = await database;
    return await db.insert(
      'user_badges',
      userBadge.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Sync operations

  Future<List<ScreenTimeLog>> getUnsyncedScreenTimeLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'screen_time_entries',
      where: 'isSynced = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return ScreenTimeLog.fromMap(maps[i]);
    });
  }

  Future<int> markScreenTimeLogAsSynced(String id) async {
    final db = await database;
    return await db.update(
      'screen_time_entries',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Screen time operations
  Future<void> insertScreenTimeEntry(ScreenTimeLog entry) async {
    final db = await database;
    await db.insert('screen_time_entries', entry.toMap());
  }

  Future<List<ScreenTimeLog>> getScreenTimeEntriesForDateRange(
    String userId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    final db = await database;
    final results = await db.query(
      'screen_time_entries',
      where: 'userId = ? AND startTime >= ? AND startTime < ?',
      whereArgs: [
        userId, 
        startDate.toIso8601String(), 
        endDate.toIso8601String()
      ],
      orderBy: 'startTime DESC',
    );

    return results.map((json) => ScreenTimeLog.fromMap(json)).toList();
  }

  Future<void> markScreenTimeEntrySynced(int entryId) async {
    final db = await database;
    await db.update(
      'screen_time_entries',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('screen_time_entries');
    await db.delete('user_badges');
    await db.delete('user_profiles');
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
