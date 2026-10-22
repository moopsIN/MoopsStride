import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:sqflite/sqflite.dart';

enum _PushResult { ok, failed, timedOut }

class SyncEngine {
  /// Firestore rejects batches over 500 operations; stay well under it.
  static const int batchLimit = 400;

  /// On mobile, a Firestore commit only completes once the server acknowledges
  /// it, so offline it would wait forever. The write stays queued in
  /// Firestore's local cache either way; we just stop waiting for it.
  static const Duration commitTimeout = Duration(seconds: 20);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _isSyncing = false;

  SyncEngine({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _activitiesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('activities');

  /// Pushes every locally unsynced activity. Returns true only if all of them
  /// reached the server.
  Future<bool> syncUnsyncedActivities() async {
    if (_isSyncing) return false;
    final user = _auth.currentUser;
    if (user == null) return false; // Must be logged in to sync

    _isSyncing = true;
    try {
      final db = await LocalDatabase.instance.database;
      final unsynced = await db.query(
        'activities',
        where: 'synced = ?',
        whereArgs: [0],
      );

      final ref = _activitiesRef(user.uid);
      var allPushed = true;

      for (var i = 0; i < unsynced.length; i += batchLimit) {
        final chunk = unsynced.sublist(i, min(i + batchLimit, unsynced.length));

        final result = await _pushRows(ref, chunk);
        if (result == _PushResult.ok) {
          await _markSynced(db, chunk);
          continue;
        }
        if (result == _PushResult.timedOut) return false; // Offline; retry later.

        // The batch was rejected. Push rows one by one so a single bad record
        // (e.g. a route over Firestore's 1 MiB doc limit) can't block the rest.
        for (final row in chunk) {
          final single = await _pushRows(ref, [row]);
          if (single == _PushResult.ok) {
            await _markSynced(db, [row]);
          } else {
            allPushed = false;
            if (single == _PushResult.timedOut) return false;
            debugPrint('Sync skipped activity ${row['id']}');
          }
        }
      }

      return allPushed;
    } catch (e) {
      // Sync failed (offline, permission denied, etc). Will retry later.
      debugPrint('Sync failed: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<_PushResult> _pushRows(
    CollectionReference<Map<String, dynamic>> ref,
    List<Map<String, dynamic>> rows,
  ) async {
    final batch = _firestore.batch();
    for (final row in rows) {
      batch.set(ref.doc(row['id'] as String), _toCloud(row), SetOptions(merge: true));
    }
    try {
      await batch.commit().timeout(commitTimeout);
      return _PushResult.ok;
    } on TimeoutException {
      return _PushResult.timedOut;
    } catch (e) {
      debugPrint('Sync push failed: $e');
      return _PushResult.failed;
    }
  }

  Future<void> _markSynced(Database db, List<Map<String, dynamic>> rows) async {
    final batch = db.batch();
    for (final row in rows) {
      batch.update('activities', {'synced': 1}, where: 'id = ?', whereArgs: [row['id']]);
    }
    await batch.commit(noResult: true);
  }

  /// The local `synced` flag is device bookkeeping and doesn't belong in the cloud.
  Map<String, dynamic> _toCloud(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(row)..remove('synced');

  Future<bool> checkCloudDataExists(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).collection('activities').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Cloud check failed: $e');
      return false;
    }
  }

  Future<void> downSync(String uid) async {
    try {
      final db = await LocalDatabase.instance.database;
      
      // Ensure we have a local profile so splash screen doesn't think we need onboarding
      final profiles = await db.query('user_profile', limit: 1);
      if (profiles.isEmpty) {
        await db.insert('user_profile', {
          'goal': '',
          'experience_level': '',
          'gender': '',
          'age': 25,
          'height': 170.0,
          'weight': 70.0,
          'activity_level': '',
          'units_preference': 'km',
        });
      }

      final snapshot = await _firestore.collection('users').doc(uid).collection('activities').get();
      if (snapshot.docs.isEmpty) return;

      final batch = db.batch();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['synced'] = 1; // It's coming from cloud, so it's already synced
        batch.insert(
          'activities',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Down-sync failed: $e');
    }
  }

  Future<void> wipeCloudData(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).collection('activities').get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Wipe cloud data failed: $e');
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
