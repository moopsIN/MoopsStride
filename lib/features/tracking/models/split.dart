/// One leg of a run: a full km/mi, or the shorter remainder at the end.
class Split {
  final double distanceMeters;
  final int durationSeconds;

  const Split(this.distanceMeters, this.durationSeconds);

  /// Seconds per [unitMeters], comparable across full and partial splits.
  double paceSecondsPer(double unitMeters) =>
      distanceMeters <= 0 ? 0 : durationSeconds * unitMeters / distanceMeters;
}

/// Turns a growing distance/elapsed-time stream into splits of [unitMeters].
class SplitRecorder {
  /// A trailing remainder shorter than this isn't worth showing.
  static const double minPartialMeters = 50;

  final double unitMeters;
  final List<Split> _splits = [];
  int _lastSplitElapsed = 0;

  SplitRecorder(this.unitMeters);

  List<Split> get splits => List.unmodifiable(_splits);

  /// Returns true if this update completed at least one split.
  bool update(double distanceMeters, int elapsedSeconds) {
    var completed = false;
    while (distanceMeters >= (_splits.length + 1) * unitMeters) {
      _splits.add(Split(unitMeters, elapsedSeconds - _lastSplitElapsed));
      _lastSplitElapsed = elapsedSeconds;
      completed = true;
    }
    return completed;
  }

  /// Full splits plus the remainder, if it's long enough to matter.
  List<Split> finish(double distanceMeters, int elapsedSeconds) {
    final rest = distanceMeters - _splits.length * unitMeters;
    return [
      ..._splits,
      if (rest >= minPartialMeters) Split(rest, elapsedSeconds - _lastSplitElapsed),
    ];
  }
}
