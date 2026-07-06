import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';

class SyncEngine {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _isSyncing = false;

  SyncEngine({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> syncUnsyncedActivities() async {
    if (_isSyncing) return;
    final user = _auth.currentUser;
    if (user == null) return; // Must be logged in to sync

    _isSyncing = true;
    try {
      final db = await LocalDatabase.instance.database;
      final unsynced = await db.query(
        'activities',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (unsynced.isEmpty) {
        _isSyncing = false;
        return;
      }

      final batch = _firestore.batch();
      final userActivitiesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activities');

      for (final row in unsynced) {
        final id = row['id'] as String;
        final docRef = userActivitiesRef.doc(id);
        
        // Convert to mutable map and prepare for Firestore
        final data = Map<String, dynamic>.from(row);
        data['synced'] = 1; // Mark as synced in cloud payload (optional, but good practice)
        
        // We could store route_polyline as a string, or parse it back to array if needed.
        // Keeping it as string is fine for now as it's just raw JSON.
        
        batch.set(docRef, data, SetOptions(merge: true));
      }

      await batch.commit();

      // If successful, update local db
      final batchUpdate = db.batch();
      for (final row in unsynced) {
        final id = row['id'] as String;
        batchUpdate.update(
          'activities',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batchUpdate.commit();

    } catch (e) {
      // Sync failed (offline, permission denied, etc). Will retry later.
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine();
  
  // Listen to auth state. When user logs in, trigger a sync for any local "guest" runs.
  ref.listen<User?>(authProvider, (previous, next) {
    if (next != null && previous == null) {
      engine.syncUnsyncedActivities();
    }
  });
  
  return engine;
});
