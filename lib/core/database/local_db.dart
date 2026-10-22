import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();

  static Database? _database;

  /// Tests set this to [inMemoryDatabasePath] so test files don't share rows
  /// through a single on-disk database.
  @visibleForTesting
  static String? pathOverride;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('stride.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final path = pathOverride ?? join(await getDatabasesPath(), filePath);

    return await openDatabase(path, version: 6, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE activities ADD COLUMN steps INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN age INTEGER');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE activities ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE activities ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
      await db.execute('UPDATE activities SET updated_at = end_time');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE user_profile ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE activities ADD COLUMN splits TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE activities (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  start_time INTEGER NOT NULL,
  end_time INTEGER NOT NULL,
  distance_meters REAL NOT NULL,
  duration_seconds INTEGER NOT NULL,
  avg_pace REAL NOT NULL,
  calories_estimate REAL NOT NULL,
  route_polyline TEXT,
  synced INTEGER NOT NULL DEFAULT 0,
  steps INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL DEFAULT 0,
  deleted INTEGER NOT NULL DEFAULT 0,
  splits TEXT
)
''');

    await db.execute('''
CREATE TABLE splits (
  activity_id TEXT NOT NULL,
  split_index INTEGER NOT NULL,
  distance_meters REAL NOT NULL,
  duration_seconds INTEGER NOT NULL,
  FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE user_profile (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  goal TEXT,
  experience_level TEXT,
  gender TEXT,
  age INTEGER,
  height REAL,
  weight REAL,
  activity_level TEXT,
  units_preference TEXT,
  updated_at INTEGER NOT NULL DEFAULT 0,
  synced INTEGER NOT NULL DEFAULT 0
)
''');
  }

  Future<void> insertActivity(Map<String, dynamic> activity) async {
    final db = await instance.database;
    await db.insert(
      'activities',
      {'updated_at': DateTime.now().millisecondsSinceEpoch, ...activity},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Soft-deletes: the row becomes an unsynced tombstone so the delete
  /// reaches the cloud (as a bare tombstone, without the route). The sync
  /// engine purges it once pushed. Until then [restoreActivity] can undo it.
  Future<void> deleteActivity(String id) async {
    final db = await instance.database;
    await db.update(
      'activities',
      {
        'deleted': 1,
        'synced': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Undoes [deleteActivity]. Returns false if the tombstone was already
  /// pushed and purged.
  Future<bool> restoreActivity(String id) async {
    final db = await instance.database;
    final count = await db.update(
      'activities',
      {
        'deleted': 0,
        'synced': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted = 1',
      whereArgs: [id],
    );
    return count > 0;
  }

  /// Without an account there's nowhere to propagate deletes, so tombstones
  /// (and the routes they still hold) can go immediately.
  Future<void> purgeTombstones() async {
    final db = await instance.database;
    await db.delete('activities', where: 'deleted = 1');
  }

  Future<List<Map<String, dynamic>>> getActivities() async {
    final db = await instance.database;
    return await db.query('activities', where: 'deleted = 0', orderBy: 'start_time DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedActivities() async {
    final db = await instance.database;
    return await db.query('activities', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> updateActivitySyncStatus(String id, bool synced) async {
    final db = await instance.database;
    await db.update(
      'activities',
      {'synced': synced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await instance.database;
    final result = await db.query('user_profile', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  /// Upserts the single profile row. Local edits are stamped and marked
  /// unsynced; the sync engine passes its own `updated_at`/`synced`.
  Future<void> updateUserProfile(Map<String, dynamic> fields) async {
    final db = await instance.database;
    final profile = {
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
      ...fields,
    };
    final result = await db.query('user_profile', limit: 1);
    if (result.isNotEmpty) {
      await db.update('user_profile', profile, where: 'id = ?', whereArgs: [result.first['id']]);
    } else {
      await db.insert('user_profile', profile);
    }
  }

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('splits');
    await db.delete('activities');
    await db.delete('user_profile');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
