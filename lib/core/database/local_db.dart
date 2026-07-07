import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();

  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('stride.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE activities ADD COLUMN steps INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN age INTEGER');
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
  steps INTEGER NOT NULL DEFAULT 0
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
  units_preference TEXT
)
''');
  }

  Future<void> insertActivity(Map<String, dynamic> activity) async {
    final db = await instance.database;
    await db.insert(
      'activities',
      activity,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getActivities() async {
    final db = await instance.database;
    return await db.query('activities', orderBy: 'start_time DESC');
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

  Future<void> updateUserProfile(Map<String, dynamic> profile) async {
    final db = await instance.database;
    final result = await db.query('user_profile', limit: 1);
    if (result.isNotEmpty) {
      await db.update('user_profile', profile, where: 'id = ?', whereArgs: [result.first['id']]);
    } else {
      await db.insert('user_profile', profile);
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
