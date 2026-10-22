import 'package:flutter_test/flutter_test.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/tracking/models/split.dart';

void main() {
  test('SplitRecorder emits one split per unit crossed, plus a remainder', () {
    final r = SplitRecorder(1000);
    expect(r.update(500, 150), false);
    expect(r.update(1010, 300), true);
    // A jump across two boundaries records both.
    expect(r.update(3005, 900), true);

    final splits = r.finish(3400, 1020);
    expect(splits.map((s) => s.durationSeconds), [300, 600, 0, 120]);
    expect(splits.last.distanceMeters, closeTo(400, 0.01));
  });

  test('a remainder under 50 m is dropped', () {
    final r = SplitRecorder(1000)..update(1000, 300);
    expect(r.finish(1030, 310).length, 1);
  });

  test('partial split pace is scaled to a full unit', () {
    expect(const Split(500, 150).paceSecondsPer(1000), 300);
  });

  test('splits survive a toMap/fromMap round trip with their unit', () {
    final a = ActivityModel(
      id: 'a',
      type: 'run',
      startTime: DateTime(2026),
      endTime: DateTime(2026),
      distanceMeters: 2000,
      durationSeconds: 700,
      avgPace: 6,
      caloriesEstimate: 1,
      routePoints: const [],
      splits: const [Split(1609.344, 400), Split(390.656, 300)],
      splitUnitMeters: 1609.344,
    );
    final back = ActivityModel.fromMap(a.toMap());
    expect(back.splitUnitMeters, 1609.344);
    expect(back.splits.map((s) => s.durationSeconds), [400, 300]);
  });
}
