import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_models.dart';
import '../models/badge_models.dart';
import '../models/app_usage_models.dart';
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
      version: 2, // Incremented to ensure migrations run
      onCreate: _createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Run migrations on upgrade
        await _applyMigrations(db);
      },
      onOpen: (db) async {
        // Also run migrations on open (for existing databases)
        await _applyMigrations(db);
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // User profiles table
    await db.execute('''
    CREATE TABLE user_profiles (
      id TEXT PRIMARY KEY,
      firstName TEXT NOT NULL,
      lastName TEXT NOT NULL,
      email TEXT NOT NULL,
      role TEXT NOT NULL,
      departmentId INTEGER,
      xp INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL,
      isSynced INTEGER NOT NULL DEFAULT 0,
      userTag TEXT,
      studentId TEXT,
      gender TEXT,
      yearLevel TEXT,
      dateOfBirth TEXT
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

    // App usage logs table (local-only, no cloud sync)
    await db.execute('''
      CREATE TABLE app_usage_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        packageName TEXT NOT NULL,
        appName TEXT,
        usageMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES user_profiles (id),
        UNIQUE(userId, packageName, date)
      )
    ''');

    // Add performance indexes
    await db.execute('CREATE INDEX idx_screen_time_user_date ON screen_time_entries(userId, startTime)');
    await db.execute('CREATE INDEX idx_screen_time_synced ON screen_time_entries(isSynced)');
    await db.execute('CREATE INDEX idx_screen_time_user_synced ON screen_time_entries(userId, isSynced)');
    await db.execute('CREATE INDEX idx_xp_award_history_user_date ON xp_award_history(userId, awardDate)');
    await db.execute('CREATE INDEX idx_xp_award_history_synced ON xp_award_history(isSynced)');
    await db.execute('CREATE INDEX idx_app_usage_user_date ON app_usage_logs(userId, date)');
    
    // Add unique constraint to prevent duplicate XP awards per user per day
    try {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_award_history_user_date_unique '
        'ON xp_award_history(userId, awardDate)'
      );
      print('✅ Unique constraint added to xp_award_history (userId, awardDate)');
    } catch (e) {
      print('⚠️ Error creating unique constraint (may already exist): $e');
    }
  }

  /// Apply lightweight migrations on open
  Future<void> _applyMigrations(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(user_profiles)');
      final columnNames = columns.map((c) => (c['name'] as String?)).toSet();
      
      // Migration: Split fullName into firstName and lastName
      // SQLite doesn't support DROP COLUMN, so we need to recreate the table
      if (columnNames.contains('fullName') && !columnNames.contains('firstName')) {
        print('🔄 Migrating fullName to firstName/lastName (recreating table)...');
        
        // Step 1: Create new table with correct schema
        await db.execute('''
          CREATE TABLE user_profiles_new (
            id TEXT PRIMARY KEY,
            firstName TEXT NOT NULL,
            lastName TEXT NOT NULL,
            email TEXT NOT NULL,
            role TEXT NOT NULL,
            departmentId INTEGER,
            xp INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            isSynced INTEGER NOT NULL DEFAULT 0,
            userTag TEXT,
            avatarUrl TEXT,
            coverPhotoUrl TEXT,
            bio TEXT,
            studentId TEXT,
            gender TEXT,
            yearLevel TEXT,
            dateOfBirth TEXT
          )
        ''');
        
        // Step 2: Migrate existing data
        final profiles = await db.query('user_profiles');
        for (final profile in profiles) {
          final fullName = profile['fullName'] as String? ?? '';
          final parts = fullName.trim().split(' ');
          final firstName = parts.isNotEmpty ? parts.first : 'User';
          final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          
          await db.insert('user_profiles_new', {
            'id': profile['id'],
            'firstName': firstName,
            'lastName': lastName,
            'email': profile['email'],
            'role': profile['role'],
            'departmentId': profile['departmentId'],
            'xp': profile['xp'],
            'createdAt': profile['createdAt'],
            'isSynced': profile['isSynced'],
            'userTag': profile['userTag'],
            'avatarUrl': profile['avatarUrl'],
            'coverPhotoUrl': profile['coverPhotoUrl'],
            'bio': profile['bio'],
            'studentId': profile['studentId'],
            'gender': profile['gender'],
            'yearLevel': profile['yearLevel'],
            'dateOfBirth': profile['dateOfBirth'],
          });
        }
        
        // Step 3: Drop old table
        await db.execute('DROP TABLE user_profiles');
        
        // Step 4: Rename new table
        await db.execute('ALTER TABLE user_profiles_new RENAME TO user_profiles');
        
        // Step 5: Recreate indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_screen_time_user_date ON screen_time_entries(userId, startTime)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_screen_time_synced ON screen_time_entries(isSynced)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_screen_time_user_synced ON screen_time_entries(userId, isSynced)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_xp_award_history_user_date ON xp_award_history(userId, awardDate)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_xp_award_history_synced ON xp_award_history(isSynced)');
        
        // Add unique constraint to prevent duplicate XP awards per user per day
        try {
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_award_history_user_date_unique '
            'ON xp_award_history(userId, awardDate)'
          );
          print('✅ Unique constraint added to xp_award_history (userId, awardDate)');
        } catch (e) {
          print('⚠️ Error creating unique constraint (may already exist): $e');
        }
        
        print('✅ Migration complete: fullName split into firstName/lastName');
      }
      
      if (!columnNames.contains('userTag')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN userTag TEXT');
      }
      
      if (!columnNames.contains('avatarUrl')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN avatarUrl TEXT');
      }
      
      if (!columnNames.contains('coverPhotoUrl')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN coverPhotoUrl TEXT');
      }
      
      if (!columnNames.contains('bio')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN bio TEXT');
      }

      // Cleanup: Remove fullName column if it still exists (after migration)
      if (columnNames.contains('fullName') && columnNames.contains('firstName') && columnNames.contains('lastName')) {
        print('🔄 Removing deprecated fullName column...');
        try {
          // Recreate table without fullName column
          await db.execute('''
            CREATE TABLE user_profiles_temp (
              id TEXT PRIMARY KEY,
              firstName TEXT NOT NULL,
              lastName TEXT NOT NULL,
              email TEXT NOT NULL,
              role TEXT NOT NULL,
              departmentId INTEGER,
              xp INTEGER NOT NULL DEFAULT 0,
              createdAt TEXT NOT NULL,
              isSynced INTEGER NOT NULL DEFAULT 0,
              userTag TEXT,
              avatarUrl TEXT,
              coverPhotoUrl TEXT,
              bio TEXT,
              studentId TEXT,
              gender TEXT,
              yearLevel TEXT,
              dateOfBirth TEXT
            )
          ''');
          
          // Copy data (excluding fullName)
          final profiles = await db.query('user_profiles');
          for (final profile in profiles) {
            await db.insert('user_profiles_temp', {
              'id': profile['id'],
              'firstName': profile['firstName'],
              'lastName': profile['lastName'],
              'email': profile['email'],
              'role': profile['role'],
              'departmentId': profile['departmentId'],
              'xp': profile['xp'],
              'createdAt': profile['createdAt'],
              'isSynced': profile['isSynced'],
              'userTag': profile['userTag'],
              'avatarUrl': profile['avatarUrl'],
              'coverPhotoUrl': profile['coverPhotoUrl'],
              'bio': profile['bio'],
              'studentId': profile['studentId'],
              'gender': profile['gender'],
              'yearLevel': profile['yearLevel'],
              'dateOfBirth': profile['dateOfBirth'],
            });
          }
          
          // Drop old table and rename new one
          await db.execute('DROP TABLE user_profiles');
          await db.execute('ALTER TABLE user_profiles_temp RENAME TO user_profiles');
          
          print('✅ Removed deprecated fullName column');
        } catch (e) {
          print('⚠️ Error removing fullName column: $e');
          // Continue - this is not critical
        }
      }

      // Add new signup fields
      if (!columnNames.contains('studentId')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN studentId TEXT');
      }
      
      if (!columnNames.contains('gender')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN gender TEXT');
      }
      
      if (!columnNames.contains('yearLevel')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN yearLevel TEXT');
      }
      
      if (!columnNames.contains('dateOfBirth')) {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN dateOfBirth TEXT');
      }

      // Ensure departments table exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS departments (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      
      // Ensure app_usage_logs table exists (migration for existing databases)
      try {
        final appUsageTableInfo = await db.rawQuery('PRAGMA table_info(app_usage_logs)');
        if (appUsageTableInfo.isEmpty) {
          print('🔄 Creating app_usage_logs table...');
          await db.execute('''
            CREATE TABLE app_usage_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              userId TEXT NOT NULL,
              packageName TEXT NOT NULL,
              appName TEXT,
              usageMinutes INTEGER NOT NULL,
              date TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              FOREIGN KEY (userId) REFERENCES user_profiles (id),
              UNIQUE(userId, packageName, date)
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_app_usage_user_date ON app_usage_logs(userId, date)');
          print('✅ app_usage_logs table created');
        }
      } catch (e) {
        print('⚠️ Error creating app_usage_logs table: $e');
      }
      
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
        
        // Add unique constraint to prevent duplicate XP awards per user per day
        try {
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_award_history_user_date_unique '
            'ON xp_award_history(userId, awardDate)'
          );
          print('✅ Unique constraint added to xp_award_history (userId, awardDate)');
        } catch (e) {
          print('⚠️ Error creating unique constraint (may already exist): $e');
        }
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
    
    // Check if XP was already awarded for this date (duplicate prevention)
    final existing = await getXPAwardHistoryForDate(history.userId, history.awardDate);
    if (existing != null) {
      print('⚠️ XP already awarded locally for ${history.awardDate}, skipping duplicate insert');
      return existing.id; // Return existing ID
    }
    
    // Use INSERT OR IGNORE to handle race conditions gracefully
    // The unique constraint will prevent duplicates even if check passes
    try {
      return await db.insert(
        'xp_award_history', 
        history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore duplicates
      );
    } catch (e) {
      // If insert fails due to unique constraint, try to fetch existing record
      final existingRecord = await getXPAwardHistoryForDate(history.userId, history.awardDate);
      if (existingRecord != null) {
        print('⚠️ Duplicate XP award prevented (unique constraint): ${history.awardDate}');
        return existingRecord.id;
      }
      rethrow; // Re-throw if it's a different error
    }
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
      final map = maps[i];
      // Convert badgeId from TEXT to int
      final badgeId = int.tryParse(map['badgeId']?.toString() ?? '0') ?? 0;
      return UserBadge(
        userId: map['userId']?.toString() ?? '',
        badgeId: badgeId,
        awardedAt: DateTime.parse(map['earnedAt']?.toString() ?? DateTime.now().toIso8601String()),
        isSynced: (map['isSynced'] as int? ?? 0) == 1,
      );
    });
  }

  /// Get badge details by badgeId from local database
  Future<Badge?> getBadgeById(String badgeId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'badges',
        where: 'id = ?',
        whereArgs: [badgeId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final map = maps.first;
        // Map local database fields to Badge model
        // Local DB has: id, name, description, iconPath, type, requiredValue, createdAt
        // Badge model expects: id, name, description, iconUrl, xpReward
        return Badge(
          id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
          name: map['name']?.toString() ?? 'Unknown Badge',
          description: map['description']?.toString(),
          iconUrl: map['iconPath']?.toString(), // Map iconPath to iconUrl
          xpReward: map['requiredValue'] as int? ?? 0, // Use requiredValue as xpReward
        );
      }
      return null;
    } catch (e) {
      print('Error fetching badge by ID: $e');
      return null;
    }
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

  /// Delete all user-specific data from local database
  /// Uses transactions for atomicity
  /// Does NOT delete shared data (departments, badges definitions)
  Future<void> deleteUserData(String userId) async {
    final db = await database;
    
    try {
      // Use transaction to ensure atomicity
      await db.transaction((txn) async {
        // Delete user-specific data in order (respecting foreign key constraints)
        
        // 1. Delete screen time entries
        await txn.delete(
          'screen_time_entries',
          where: 'userId = ?',
          whereArgs: [userId],
        );
        
        // 2. Delete XP update logs
        await txn.delete(
          'xp_update_logs',
          where: 'userId = ?',
          whereArgs: [userId],
        );
        
        // 3. Delete XP award history
        await txn.delete(
          'xp_award_history',
          where: 'userId = ?',
          whereArgs: [userId],
        );
        
        // 4. Delete user badges
        await txn.delete(
          'user_badges',
          where: 'userId = ?',
          whereArgs: [userId],
        );
        
        // 5. Delete user profile
        await txn.delete(
          'user_profiles',
          where: 'id = ?',
          whereArgs: [userId],
        );
        
        // 6. Clear user-specific sync metadata
        // Keep app-level metadata but remove user-specific entries
        await txn.delete(
          'sync_metadata',
          where: 'key IN (?, ?, ?)',
          whereArgs: [
            'current_user_id',
            'supabase_session_json',
            'last_successful_sync',
          ],
        );
      });
      
      print('✅ Deleted all local data for user: $userId');
    } catch (e) {
      print('❌ Error deleting user data: $e');
      rethrow;
    }
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

  // ============================================
  // App Usage Logs Methods (Local-only storage)
  // ============================================

  /// Insert or update app usage entry
  /// Uses INSERT OR REPLACE to handle unique constraint (userId, packageName, date)
  Future<int> insertAppUsageEntry(AppUsageEntry entry) async {
    try {
      final db = await database;
      final result = await db.insert(
        'app_usage_logs',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return result;
    } catch (e) {
      print('❌ Error inserting app usage entry: $e');
      rethrow;
    }
  }

  /// Insert or update multiple app usage entries in a batch
  Future<void> insertAppUsageEntries(List<AppUsageEntry> entries) async {
    if (entries.isEmpty) return;
    
    try {
      final db = await database;
      final batch = db.batch();
      
      for (final entry in entries) {
        batch.insert(
          'app_usage_logs',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    } catch (e) {
      print('❌ Error inserting app usage entries: $e');
      rethrow;
    }
  }

  /// Get app usage entries for a specific date
  Future<List<AppUsageEntry>> getAppUsageForDate(String userId, DateTime date) async {
    try {
      final db = await database;
      final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      final maps = await db.query(
        'app_usage_logs',
        where: 'userId = ? AND date = ?',
        whereArgs: [userId, dateStr],
        orderBy: 'usageMinutes DESC',
      );
      
      return maps.map((map) => AppUsageEntry.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting app usage for date: $e');
      return [];
    }
  }

  /// Get top N apps by usage for a specific date
  Future<List<AppUsageEntry>> getTopAppsForDate(
    String userId,
    DateTime date,
    int limit,
  ) async {
    try {
      final db = await database;
      final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      final maps = await db.query(
        'app_usage_logs',
        where: 'userId = ? AND date = ?',
        whereArgs: [userId, dateStr],
        orderBy: 'usageMinutes DESC',
        limit: limit,
      );
      
      return maps.map((map) => AppUsageEntry.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting top apps for date: $e');
      return [];
    }
  }

  /// Get app usage entries for a date range
  Future<List<AppUsageEntry>> getAppUsageForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await database;
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      
      final maps = await db.query(
        'app_usage_logs',
        where: 'userId = ? AND date >= ? AND date <= ?',
        whereArgs: [userId, startStr, endStr],
        orderBy: 'date DESC, usageMinutes DESC',
      );
      
      return maps.map((map) => AppUsageEntry.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting app usage for date range: $e');
      return [];
    }
  }

  /// Get app usage entry by package name and date
  Future<AppUsageEntry?> getAppUsageEntry(
    String userId,
    String packageName,
    DateTime date,
  ) async {
    try {
      final db = await database;
      final dateStr = date.toIso8601String().split('T')[0];
      
      final maps = await db.query(
        'app_usage_logs',
        where: 'userId = ? AND packageName = ? AND date = ?',
        whereArgs: [userId, packageName, dateStr],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return AppUsageEntry.fromMap(maps.first);
    } catch (e) {
      print('❌ Error getting app usage entry: $e');
      return null;
    }
  }

  /// Delete app usage entries for a user (for cleanup)
  Future<void> deleteAppUsageEntries(String userId) async {
    try {
      final db = await database;
      await db.delete(
        'app_usage_logs',
        where: 'userId = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('❌ Error deleting app usage entries: $e');
    }
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
