import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDatabase.pathOverride = inMemoryDatabasePath;
  });

  setUp(() async {
    final dbHelper = LocalDatabase.instance;
    final db = await dbHelper.database;
    await db.delete('activities');
    await db.delete('user_profile');
  });

  test('SyncEngine pushes local data to Firestore and updates synced flag', () async {
    // 1. Setup mocks
    final fakeFirestore = FakeFirebaseFirestore();
    final mockUser = MockUser(uid: 'test_user_123');
    final mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    
    final engine = SyncEngine(auth: mockAuth, firestore: fakeFirestore);

    // 2. Insert unsynced data to local DB
    final activity = ActivityModel(
      id: 'activity_1',
      type: 'run',
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      distanceMeters: 1000,
      durationSeconds: 300,
      avgPace: 5.0,
      caloriesEstimate: 60,
      routePoints: [],
      synced: false,
    );
    await LocalDatabase.instance.insertActivity(activity.toMap());

    // 3. Trigger sync
    await engine.syncUnsyncedActivities();

    // 4. Verify Firestore
    final docSnapshot = await fakeFirestore
        .collection('users')
        .doc('test_user_123')
        .collection('activities')
        .doc('activity_1')
        .get();
        
    expect(docSnapshot.exists, true);
    expect(docSnapshot.data()!.containsKey('synced'), false);
    expect(docSnapshot.data()?['distance_meters'], 1000);

    // 5. Verify local DB flag is updated
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('activities', where: 'id = ?', whereArgs: ['activity_1']);
    expect(rows.first['synced'], 1);
  });

  test('SyncEngine splits uploads larger than one Firestore batch', () async {
    final fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth(mockUser: MockUser(uid: 'u'), signedIn: true);
    final engine = SyncEngine(auth: mockAuth, firestore: fakeFirestore);

    final count = SyncEngine.batchLimit + 50;
    for (var i = 0; i < count; i++) {
      await LocalDatabase.instance.insertActivity(ActivityModel(
        id: 'a$i',
        type: 'run',
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1),
        distanceMeters: 100,
        durationSeconds: 60,
        avgPace: 5.0,
        caloriesEstimate: 10,
        routePoints: [],
      ).toMap());
    }

    expect(await engine.syncUnsyncedActivities(), true);

    final cloud = await fakeFirestore.collection('users').doc('u').collection('activities').get();
    expect(cloud.docs.length, count);
    expect(await LocalDatabase.instance.getUnsyncedActivities(), isEmpty);
  });

  test('Deleting a synced run tombstones it in the cloud and purges it locally', () async {
    final fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth(mockUser: MockUser(uid: 'u'), signedIn: true);
    final engine = SyncEngine(auth: mockAuth, firestore: fakeFirestore);

    await LocalDatabase.instance.insertActivity(ActivityModel(
      id: 'gone',
      type: 'run',
      startTime: DateTime(2026, 1, 1),
      endTime: DateTime(2026, 1, 1),
      distanceMeters: 100,
      durationSeconds: 60,
      avgPace: 5.0,
      caloriesEstimate: 10,
      routePoints: [],
    ).toMap());
    await engine.syncUnsyncedActivities();

    await LocalDatabase.instance.deleteActivity('gone');
    expect(await LocalDatabase.instance.getActivities(), isEmpty);
    expect(await engine.syncUnsyncedActivities(), true);

    final doc = await fakeFirestore
        .collection('users').doc('u').collection('activities').doc('gone').get();
    expect(doc.data()?['deleted'], 1);
    expect(doc.data()!.containsKey('route_polyline'), false);

    final db = await LocalDatabase.instance.database;
    expect(await db.query('activities'), isEmpty);
  });

  group('pullFromCloud', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SyncEngine engine;

    Map<String, dynamic> cloudRun(String id, {Object distance = 1000}) => {
          'id': id,
          'type': 'run',
          'start_time': 1700000000000,
          'end_time': 1700000600000,
          'distance_meters': distance,
          'duration_seconds': 600,
          'avg_pace': 6, // int on purpose: Firestore can return whole doubles as ints
          'calories_estimate': 50,
          'route_polyline': '[]',
          'updated_at': 1700000600000,
        };

    Future<void> putCloud(String id, Map<String, dynamic> data) => fakeFirestore
        .collection('users').doc('u').collection('activities').doc(id).set(data);

    Future<List<String>> localIds() async {
      final db = await LocalDatabase.instance.database;
      return (await db.query('activities', orderBy: 'id')).map((r) => r['id'] as String).toList();
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      engine = SyncEngine(
        auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u'), signedIn: true),
        firestore: fakeFirestore,
      );
    });

    test('downloads cloud runs, coercing numbers and dropping unknown fields', () async {
      await putCloud('r1', {...cloudRun('r1'), 'synced': 1, 'some_future_field': true});

      await engine.pullFromCloud('u');

      final rows = await LocalDatabase.instance.getActivities();
      expect(rows.single['id'], 'r1');
      expect(rows.single['avg_pace'], 6.0);
      expect(rows.single['synced'], 1);
      expect(ActivityModel.fromMap(rows.single).distanceMeters, 1000.0);
    });

    test('skips malformed docs without failing the rest', () async {
      await putCloud('good', cloudRun('good'));
      await putCloud('bad', {'id': 'bad', 'type': 'run'});

      await engine.pullFromCloud('u');

      expect(await localIds(), ['good']);
    });

    test('local pending changes win; tombstones and remotely wiped runs are removed', () async {
      // Locally pending edit of a run that also exists in the cloud.
      await LocalDatabase.instance.insertActivity({...cloudRun('pending'), 'distance_meters': 42.0, 'avg_pace': 6.0, 'calories_estimate': 50.0, 'synced': 0});
      await putCloud('pending', cloudRun('pending'));
      // Synced locally, tombstoned in the cloud.
      await LocalDatabase.instance.insertActivity({...cloudRun('tomb'), 'distance_meters': 1.0, 'avg_pace': 6.0, 'calories_estimate': 50.0, 'synced': 1});
      await putCloud('tomb', {'id': 'tomb', 'deleted': 1, 'updated_at': 1});
      // Synced locally, gone from the cloud (wiped from another device).
      await LocalDatabase.instance.insertActivity({...cloudRun('wiped'), 'distance_meters': 1.0, 'avg_pace': 6.0, 'calories_estimate': 50.0, 'synced': 1});

      await engine.pullFromCloud('u');

      final rows = await LocalDatabase.instance.getActivities();
      expect(rows.map((r) => r['id']), ['pending']);
      expect(rows.single['distance_meters'], 42.0);
    });

    test('fullSync pushes guest runs and merges existing cloud history', () async {
      await putCloud('cloud_run', cloudRun('cloud_run'));
      await LocalDatabase.instance.insertActivity({...cloudRun('guest_run'), 'distance_meters': 5.0, 'avg_pace': 6.0, 'calories_estimate': 50.0, 'synced': 0});

      expect(await engine.fullSync(), true);

      expect(await localIds(), ['cloud_run', 'guest_run']);
      final cloud = await fakeFirestore.collection('users').doc('u').collection('activities').get();
      expect(cloud.docs.map((d) => d.id).toSet(), {'cloud_run', 'guest_run'});
    });
  });

  group('profile sync', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SyncEngine engine;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      engine = SyncEngine(
        auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u'), signedIn: true),
        firestore: fakeFirestore,
      );
    });

    test('pushes a local profile edit to users/{uid}', () async {
      await LocalDatabase.instance.updateUserProfile({'goal': 'Marathon', 'weight': 61.5});

      expect(await engine.syncUnsyncedActivities(), true);

      final doc = await fakeFirestore.collection('users').doc('u').get();
      expect(doc.data()?['profile']['goal'], 'Marathon');
      expect(doc.data()?['profile']['weight'], 61.5);
      expect((await LocalDatabase.instance.getUserProfile())?['synced'], 1);
    });

    test('a fresh device gets the cloud profile and the account counts as existing', () async {
      await fakeFirestore.collection('users').doc('u').set({
        'profile': {'goal': '5K', 'weight': 80, 'age': 40, 'updated_at': 5},
      });

      expect(await engine.checkCloudData('u'), CloudDataStatus.exists);
      await engine.pullFromCloud('u');

      final local = await LocalDatabase.instance.getUserProfile();
      expect(local?['goal'], '5K');
      expect(local?['weight'], 80.0);
      expect(local?['synced'], 1);
    });

    test('a newer unsynced local edit is not overwritten by an older cloud copy', () async {
      await fakeFirestore.collection('users').doc('u').set({
        'profile': {'goal': 'old', 'updated_at': 1},
      });
      await LocalDatabase.instance.updateUserProfile({'goal': 'new'});

      await engine.pullFromCloud('u');

      expect((await LocalDatabase.instance.getUserProfile())?['goal'], 'new');
    });

    test('an empty account reports empty', () async {
      expect(await engine.checkCloudData('u'), CloudDataStatus.empty);
    });
  });
}
