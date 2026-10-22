import 'package:flutter_test/flutter_test.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialize sqflite for desktop/unit test environments
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDatabase.pathOverride = inMemoryDatabasePath;
  });

  group('LocalDatabase CRUD Tests', () {
    late LocalDatabase dbHelper;

    setUp(() async {
      dbHelper = LocalDatabase.instance;
      // In-memory database for tests
      await dbHelper.database;
      // We cannot easily override the singleton's internal path in the current design
      // But sqflite_common_ffi handles 'stride.db' by writing it to the project root during tests.
      // For a more robust setup we might dependency inject the path, but this suffices for the test.
    });

    tearDown(() async {
      final db = await dbHelper.database;
      await db.delete('activities');
    });

    test('Insert and get activities', () async {
      final activity = {
        'id': 'test_id_1',
        'type': 'run',
        'start_time': 1600000000,
        'end_time': 1600001800,
        'distance_meters': 5000.0,
        'duration_seconds': 1800,
        'avg_pace': 6.0,
        'calories_estimate': 400.0,
        'route_polyline': 'test_polyline',
        'synced': 0,
      };

      await dbHelper.insertActivity(activity);

      final activities = await dbHelper.getActivities();
      expect(activities.length, 1);
      expect(activities.first['id'], 'test_id_1');
      expect(activities.first['type'], 'run');
    });

    test('Get unsynced activities', () async {
      final syncedActivity = {
        'id': 'test_id_sync',
        'type': 'walk',
        'start_time': 1600000000,
        'end_time': 1600001800,
        'distance_meters': 5000.0,
        'duration_seconds': 1800,
        'avg_pace': 6.0,
        'calories_estimate': 400.0,
        'route_polyline': '',
        'synced': 1,
      };

      final unsyncedActivity = {
        'id': 'test_id_unsync',
        'type': 'walk',
        'start_time': 1600000000,
        'end_time': 1600001800,
        'distance_meters': 5000.0,
        'duration_seconds': 1800,
        'avg_pace': 6.0,
        'calories_estimate': 400.0,
        'route_polyline': '',
        'synced': 0,
      };

      await dbHelper.insertActivity(syncedActivity);
      await dbHelper.insertActivity(unsyncedActivity);

      final unsynced = await dbHelper.getUnsyncedActivities();
      expect(unsynced.length, 1);
      expect(unsynced.first['id'], 'test_id_unsync');
    });

    test('Update sync status', () async {
      final activity = {
        'id': 'test_update',
        'type': 'run',
        'start_time': 1600000000,
        'end_time': 1600001800,
        'distance_meters': 5000.0,
        'duration_seconds': 1800,
        'avg_pace': 6.0,
        'calories_estimate': 400.0,
        'route_polyline': '',
        'synced': 0,
      };

      await dbHelper.insertActivity(activity);
      
      var unsynced = await dbHelper.getUnsyncedActivities();
      expect(unsynced.length, 1);

      await dbHelper.updateActivitySyncStatus('test_update', true);

      unsynced = await dbHelper.getUnsyncedActivities();
      expect(unsynced.length, 0);
    });

    test('Delete hides a run; restore brings it back intact', () async {
      await dbHelper.insertActivity({
        'id': 'undo_me',
        'type': 'run',
        'start_time': 1600000000,
        'end_time': 1600001800,
        'distance_meters': 5000.0,
        'duration_seconds': 1800,
        'avg_pace': 6.0,
        'calories_estimate': 400.0,
        'route_polyline': '[[1.0,2.0]]',
        'synced': 1,
      });

      await dbHelper.deleteActivity('undo_me');
      expect(await dbHelper.getActivities(), isEmpty);

      expect(await dbHelper.restoreActivity('undo_me'), true);
      final rows = await dbHelper.getActivities();
      expect(rows.single['route_polyline'], '[[1.0,2.0]]');
      expect(rows.single['synced'], 0); // re-sync so the cloud matches

      await dbHelper.deleteActivity('undo_me');
      await dbHelper.purgeTombstones();
      expect(await dbHelper.restoreActivity('undo_me'), false);
    });
  });
}
