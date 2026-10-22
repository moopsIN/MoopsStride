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
  });

  setUp(() async {
    final dbHelper = LocalDatabase.instance;
    final db = await dbHelper.database;
    await db.delete('activities');
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
}
