import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_models.dart';
import '../models/badge_models.dart';
import '../utils/app_logger.dart';

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
      onOpen: (db) async {
        await _applyMigrations(db);
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // User profiles table
    await db.execute('''
    CREATE TABLE user_profiles (
      id TEXT PRIMARY KEY,
      fullName TEXT NOT NULL,
      email TEXT NOT NULL,
      role TEXT NOT NULL,
      departmentId INTEGER,
      xp INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL,
      isSynced INTEGER NOT NULL DEFAULT 0,
      userTag TEXT
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

    // Departments table (cache for offline display)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS departments (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
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

    // Sync metadata table (for improved sync service)
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE xp_update_logs (
        id INTEGER PRIMARY KEY,
        userId TEXT NOT NULL,
        xpToAdd INTEGER NOT NULL,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES user_profiles (id)
      )
    ''');

    // XP Award History table
    await db.execute('''
      CREATE TABLE xp_award_history (
        id INTEGER PRIMARY KEY,
        userId TEXT NOT NULL,
        awardDate TEXT NOT NULL,
        xpAwarded INTEGER NOT NULL,
        screenTimeMinutes INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES user_profiles (id)
      )
    ''');

    // Add performance indexes
    await db.execute('CREATE INDEX idx_screen_time_user_date ON screen_time_entries(userId, startTime)');
    await db.execute('CREATE INDEX idx_screen_time_synced ON screen_time_entries(isSynced)');
    await db.execute('CREATE INDEX idx_screen_time_user_synced ON screen_time_entries(userId, isSynced)');
    await db.execute('CREATE INDEX idx_xp_award_history_user_date ON xp_award_history(userId, awardDate)');
    await db.execute('CREATE INDEX idx_xp_award_history_synced ON xp_award_history(isSynced)');
  }

  /// Apply lightweight migrations on open
  Future<void> _applyMigrations(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(user_profiles)');
      final hasUserTag = columns.any((c) => (c['name'] as String?) == 'userTag');
      if (!hasUserTag) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN userTag TEXT');
      }

      // Ensure departments table exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS departments (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      
      // Add unique constraint to prevent duplicate screen time entries
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_screen_time_user_start_unique '
        'ON screen_time_entries(userId, startTime)'
      );
      
      // Migrate xp_award_history table if it doesn't exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='xp_award_history'"
      );
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE xp_award_history (
            id INTEGER PRIMARY KEY,
            userId TEXT NOT NULL,
            awardDate TEXT NOT NULL,
            xpAwarded INTEGER NOT NULL,
            screenTimeMinutes INTEGER NOT NULL,
            createdAt TEXT NOT NULL,
            isSynced INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (userId) REFERENCES user_profiles (id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_xp_award_history_user_date ON xp_award_history(userId, awardDate)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_xp_award_history_synced ON xp_award_history(isSynced)');
      }
    } catch (e) {
      AppLogger.warning('Migration check failed', 'migrate', e);
    }
  }

  // Departments cache CRUD
  Future<void> upsertDepartment(int id, String name) async {
    final db = await database;
    await db.insert(
      'departments',
      {'id': id, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getDepartmentName(int id) async {
    final db = await database;
    final res = await db.query('departments', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isNotEmpty) return res.first['name'] as String?;
    return null;
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

  // XP Update Log operations
  Future<int> insertXPUpdateLog(XPUpdateLog xpUpdate) async {
    final db = await database;
    return await db.insert('xp_update_logs', xpUpdate.toMap());
  }

  Future<int> getPendingXPForUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'xp_update_logs',
      columns: ['xpToAdd'],
      where: 'userId = ? AND isSynced = ?',
      whereArgs: [userId, 0],
    );
    
    return maps.fold<int>(0, (sum, map) => sum + (map['xpToAdd'] as int));
  }
  Future<List<XPUpdateLog>> getUnsyncedXPUpdates(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'xp_update_logs',
      where: 'userId = ? AND isSynced = ?',
      whereArgs: [userId, 0],
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => XPUpdateLog.fromMap(map)).toList();
    
  }

  Future<void> markXPUpdateAsSynced(int xpUpdateId) async {
    final db = await database;
    await db.update(
      'xp_update_logs',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [xpUpdateId],
    );
  }

  // XP Award History operations
  Future<int> insertXPAwardHistory(XPAwardHistory history) async {
    final db = await database;
    return await db.insert('xp_award_history', history.toMap());
  }

  Future<XPAwardHistory?> getXPAwardHistoryForDate(String userId, DateTime date) async {
    final db = await database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    final List<Map<String, dynamic>> maps = await db.query(
      'xp_award_history',
      where: 'userId = ? AND awardDate = ?',
      whereArgs: [userId, dateStr],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return XPAwardHistory.fromMap(maps.first);
    }
    return null;
  }

  Future<List<XPAwardHistory>> getUnsyncedXPAwardHistory(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'xp_award_history',
      where: 'userId = ? AND isSynced = ?',
      whereArgs: [userId, 0],
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => XPAwardHistory.fromMap(map)).toList();
  }

  Future<void> markXPAwardHistoryAsSynced(int historyId) async {
    final db = await database;
    await db.update(
      'xp_award_history',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [historyId],
    );
  }

  // CRUD Operations for Screen Time Logs

  Future<List<ScreenTimeLog>> getScreenTimeLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'screen_time_entries',
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
      'screen_time_entries',
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
      'screen_time_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateScreenTimeLog(ScreenTimeLog entry) async {
    final db = await database;
    return await db.update(
      'screen_time_entries',
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
      'screen_time_entries', // Note: Keep as screen_time_entries (local table name)
      where: 'isSynced = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return ScreenTimeLog.fromMap(maps[i]);
    });
  }



  // Screen time operations
  Future<void> insertScreenTimeEntry(ScreenTimeLog entry) async {
    try {
      final db = await database;
      final result = await db.insert('screen_time_entries', entry.toMap());
      AppLogger.database('Inserted screen time entry with ID: $result for user: ${entry.userId}', 'insert');
    } catch (e) {
      AppLogger.error('Failed to insert screen time entry', 'insert', e);
      AppLogger.debug('Entry data: ${entry.toMap()}', 'insert');
      
      // Try to insert with a different ID if duplicate
      if (e.toString().contains('UNIQUE constraint failed')) {
        try {
          final newEntry = entry.copyWith(id: DateTime.now().microsecondsSinceEpoch);
          final db = await database;
          final result = await db.insert('screen_time_entries', newEntry.toMap());
          print('✅ Retry successful with new ID: $result');
        } catch (retryError) {
          print('❌ Retry also failed: $retryError');
        }
      }
    }
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

  // Also create the method that was referenced in sync_service
  Future<int> markScreenTimeLogAsSynced(int id) async {
    final db = await database;
    return await db.update(
      'screen_time_entries',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('screen_time_entries');
    await db.delete('user_badges');
    await db.delete('user_profiles');
    await db.delete('sync_metadata');
  }

  // Sync Metadata Operations (for improved sync service)

  /// Get sync metadata value by key
  Future<String?> getSyncMetadata(String key) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'sync_metadata',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (maps.isNotEmpty) {
        return maps.first['value'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting sync metadata: $e');
      return null;
    }
  }

  /// Set sync metadata value
  Future<void> setSyncMetadata(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'sync_metadata',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error setting sync metadata: $e');
    }
  }

  /// Get last successful sync timestamp
  Future<DateTime?> getLastSyncTimestamp() async {
    final value = await getSyncMetadata('last_successful_sync');
    if (value != null) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Invalid sync timestamp format: $value');
      }
    }
    return null;
  }

  /// Save last successful sync timestamp
  Future<void> saveLastSyncTimestamp(DateTime timestamp) async {
    await setSyncMetadata('last_successful_sync', timestamp.toIso8601String());
  }

  /// Get last cloud sync timestamp
  Future<DateTime?> getLastCloudSyncTimestamp() async {
    final value = await getSyncMetadata('last_cloud_sync');
    if (value != null) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Invalid cloud sync timestamp format: $value');
      }
    }
    return null;
  }

  /// Save last cloud sync timestamp
  Future<void> saveLastCloudSyncTimestamp(DateTime timestamp) async {
    await setSyncMetadata('last_cloud_sync', timestamp.toIso8601String());
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  /// Get screen time log by user and start time for deduplication
  Future<ScreenTimeLog?> getScreenTimeLogByUserAndTime(
    String userId, 
    DateTime startTime
  ) async {
    final db = await database;
    final maps = await db.query(
      'screen_time_entries',
      where: 'userId = ? AND startTime = ?',
      whereArgs: [userId, startTime.toIso8601String()],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ScreenTimeLog.fromMap(maps.first);
  }
}
