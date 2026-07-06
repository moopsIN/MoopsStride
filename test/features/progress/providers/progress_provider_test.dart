import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
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

  test('Calculates streak correctly', () async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    final fourDaysAgo = today.subtract(const Duration(days: 4)); // Gap

    // 3 day streak (today, yesterday, 2 days ago)
    await LocalDatabase.instance.insertActivity(ActivityModel(
      id: '1', type: 'run', startTime: today, endTime: today, distanceMeters: 100, durationSeconds: 60, avgPace: 5.0, caloriesEstimate: 50, routePoints: [], synced: false
    ).toMap());

    await LocalDatabase.instance.insertActivity(ActivityModel(
      id: '2', type: 'run', startTime: yesterday, endTime: yesterday, distanceMeters: 100, durationSeconds: 60, avgPace: 5.0, caloriesEstimate: 50, routePoints: [], synced: false
    ).toMap());

    await LocalDatabase.instance.insertActivity(ActivityModel(
      id: '3', type: 'run', startTime: twoDaysAgo, endTime: twoDaysAgo, distanceMeters: 100, durationSeconds: 60, avgPace: 5.0, caloriesEstimate: 50, routePoints: [], synced: false
    ).toMap());

    await LocalDatabase.instance.insertActivity(ActivityModel(
      id: '4', type: 'run', startTime: fourDaysAgo, endTime: fourDaysAgo, distanceMeters: 100, durationSeconds: 60, avgPace: 5.0, caloriesEstimate: 50, routePoints: [], synced: false
    ).toMap());

    final container = ProviderContainer();
    final notifier = container.read(progressProvider.notifier);
    
    // In tests, the initial build() might run before we can await it, so let's call refresh and wait
    notifier.refresh();
    await Future.delayed(const Duration(milliseconds: 100));

    final state = container.read(progressProvider);
    expect(state.currentStreak, 3); // Four days ago shouldn't be counted due to the gap
    expect(state.activities.length, 4);
    
    container.dispose();
  });
}
