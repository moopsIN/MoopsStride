import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:sqflite/sqflite.dart';

enum _PushResult { ok, failed, timedOut }

/// Whether an account already has data in the cloud. [unknown] means the
/// server couldn't be reached; callers must not treat it as [empty].
enum CloudDataStatus { exists, empty, unknown }

/// Thrown when the cloud can't be read, so callers can tell the user instead
/// of silently carrying on with partial data.
class SyncException implements Exception {
  final String message;
  SyncException(this.message);
  @override
  String toString() => message;
}

class SyncEngine {
  /// Firestore rejects batches over 500 operations; stay well under it.
  static const int batchLimit = 400;

  /// On mobile, a Firestore commit only completes once the server acknowledges
  /// it, so offline it would wait forever. The write stays queued in
  /// Firestore's local cache either way; we just stop waiting for it.
  static const Duration commitTimeout = Duration(seconds: 20);

  /// Local columns a cloud activity doc may populate.
  static const _activityColumns = {
    'id', 'type', 'start_time', 'end_time', 'distance_meters', 'duration_seconds',
    'avg_pace', 'calories_estimate', 'route_polyline', 'steps', 'updated_at',
  };

  /// Reads that must reflect the server; Firestore's offline cache would
  /// otherwise answer "no data" on a fresh device.
  static const _fromServer = GetOptions(source: Source.server);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Called after a pull changes local data, so UI can reload.
  void Function()? onLocalDataChanged;

  /// Push and pull run one at a time; interleaving them could let a pull drop
  /// a row a concurrent push had just marked synced.
  Future<void> _tail = Future.value();

  SyncEngine({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _activitiesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('activities');

  Future<T> _exclusive<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Pushes local changes, then pulls the cloud's. Returns true if both
  /// completed fully.
  Future<bool> fullSync() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final pushed = await syncUnsyncedActivities();
    try {
      await pullFromCloud(user.uid);
      return pushed;
    } catch (e) {
      debugPrint('Pull failed: $e');
      return false;
    }
  }

  /// Pushes every locally unsynced activity. Returns true only if all of them
  /// reached the server.
  Future<bool> syncUnsyncedActivities() => _exclusive(_push);

  Future<bool> _push() async {
    final user = _auth.currentUser;
    if (user == null) return false; // Must be logged in to sync

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
    }
  }

  Future<_PushResult> _pushRows(
    CollectionReference<Map<String, dynamic>> ref,
    List<Map<String, dynamic>> rows,
  ) async {
    final batch = _firestore.batch();
    for (final row in rows) {
      final doc = ref.doc(row['id'] as String);
      if (row['deleted'] == 1) {
        // Overwrite (no merge) so the route and stats are erased from the cloud,
        // leaving only the tombstone other devices need to drop their copy.
        batch.set(doc, {'id': row['id'], 'deleted': 1, 'updated_at': row['updated_at']});
      } else {
        batch.set(doc, _toCloud(row), SetOptions(merge: true));
      }
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

  /// Matches on `updated_at` so a row changed locally while its push was in
  /// flight stays unsynced. Pushed tombstones have done their job and are purged.
  Future<void> _markSynced(Database db, List<Map<String, dynamic>> rows) async {
    final batch = db.batch();
    for (final row in rows) {
      const where = 'id = ? AND updated_at = ?';
      final args = [row['id'], row['updated_at']];
      if (row['deleted'] == 1) {
        batch.delete('activities', where: where, whereArgs: args);
      } else {
        batch.update('activities', {'synced': 1}, where: where, whereArgs: args);
      }
    }
    await batch.commit(noResult: true);
  }

  /// The local `synced` flag is device bookkeeping and doesn't belong in the cloud.
  Map<String, dynamic> _toCloud(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(row)..remove('synced');

  Future<CloudDataStatus> checkCloudData(String uid) async {
    try {
      final snapshot = await _activitiesRef(uid).limit(1).get(_fromServer).timeout(commitTimeout);
      return snapshot.docs.isEmpty ? CloudDataStatus.empty : CloudDataStatus.exists;
    } catch (e) {
      debugPrint('Cloud check failed: $e');
      return CloudDataStatus.unknown;
    }
  }

  /// Merges the cloud's activities into the local DB. Locally pending rows win
  /// until they're pushed; cloud tombstones remove local copies; synced local
  /// rows missing from the cloud were wiped elsewhere and are dropped.
  /// Throws [SyncException] if the cloud can't be read.
  Future<void> pullFromCloud(String uid) => _exclusive(() => _pull(uid));

  Future<void> _pull(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _activitiesRef(uid).get(_fromServer).timeout(commitTimeout);
    } catch (e) {
      throw SyncException("Couldn't reach the cloud. Check your connection and try again.");
    }

    final db = await LocalDatabase.instance.database;
    final pending = (await db.query('activities', columns: ['id'], where: 'synced = 0'))
        .map((r) => r['id'])
        .toSet();

    final batch = db.batch();
    final remoteIds = <String>{};
    for (final doc in snapshot.docs) {
      remoteIds.add(doc.id);
      if (pending.contains(doc.id)) continue;

      final data = doc.data();
      if (data['deleted'] == 1) {
        batch.delete('activities', where: 'id = ?', whereArgs: [doc.id]);
        continue;
      }
      final row = _rowFromCloud(doc.id, data);
      if (row == null) {
        debugPrint('Skipping malformed cloud activity ${doc.id}');
        continue;
      }
      batch.insert('activities', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final syncedLocal = await db.query('activities', columns: ['id'], where: 'synced = 1');
    for (final r in syncedLocal) {
      if (!remoteIds.contains(r['id'])) {
        batch.delete('activities', where: 'id = ? AND synced = 1', whereArgs: [r['id']]);
      }
    }

    await batch.commit(noResult: true);
    onLocalDataChanged?.call();
  }

  /// Keeps only known columns and coerces numbers, since Firestore may hand
  /// back an int where SQLite and the model expect a double. Returns null if a
  /// required field is missing.
  Map<String, dynamic>? _rowFromCloud(String id, Map<String, dynamic> data) {
    num? n(String k) => data[k] is num ? data[k] as num : null;
    final start = n('start_time'), end = n('end_time'), distance = n('distance_meters'),
        duration = n('duration_seconds'), pace = n('avg_pace'), calories = n('calories_estimate');
    if (start == null || end == null || distance == null || duration == null ||
        pace == null || calories == null) {
      return null;
    }
    final row = {
      for (final k in _activityColumns)
        if (data.containsKey(k)) k: data[k],
    };
    return row
      ..['id'] = id
      ..['type'] = data['type'] is String ? data['type'] : 'run'
      ..['start_time'] = start.toInt()
      ..['end_time'] = end.toInt()
      ..['distance_meters'] = distance.toDouble()
      ..['duration_seconds'] = duration.toInt()
      ..['avg_pace'] = pace.toDouble()
      ..['calories_estimate'] = calories.toDouble()
      ..['steps'] = n('steps')?.toInt() ?? 0
      ..['updated_at'] = n('updated_at')?.toInt() ?? end.toInt()
      ..['synced'] = 1
      ..['deleted'] = 0;
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
  final engine = SyncEngine()
    ..onLocalDataChanged = () => ref.read(progressProvider.notifier).refresh();

  // When a user logs in, push any local "guest" runs and merge in their cloud
  // history.
  ref.listen<User?>(authProvider, (previous, next) {
    if (next != null && previous == null) {
      engine.fullSync();
    }
  });

  return engine;
});
