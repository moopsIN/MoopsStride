/// The badge catalogue. Order here is display and celebration order.
enum BadgeId {
  firstStride,
  run5k,
  run10k,
  runHalf,
  total10,
  total50,
  total100,
  total250,
  streak3,
  streak7,
  streak30,
  earlyBird,
  nightOwl,
  weekendWarrior,
}

enum BadgeKind { firstRun, singleRun, lifetime, streak, timeOfDay, weekend }

class BadgeDef {
  final BadgeId id;
  final String title;
  final String description;
  final BadgeKind kind;
  /// Metres for distance badges, days for streaks; unused otherwise.
  final double target;

  const BadgeDef(this.id, this.title, this.description, this.kind, [this.target = 0]);
}

/// Runs shorter than this don't count for time-of-day and weekend badges,
/// so an accidental tap at 6am can't earn Early Bird.
const double qualifyingRunMeters = 1000;

const double halfMarathonMeters = 21097.5;

const List<BadgeDef> badgeCatalogue = [
  BadgeDef(BadgeId.firstStride, 'First stride', 'Finish your first run.', BadgeKind.firstRun),
  BadgeDef(BadgeId.run5k, '5K', 'Run 5 km in one go.', BadgeKind.singleRun, 5000),
  BadgeDef(BadgeId.run10k, '10K', 'Run 10 km in one go.', BadgeKind.singleRun, 10000),
  BadgeDef(BadgeId.runHalf, 'Half marathon', 'Run 21.1 km in one go.', BadgeKind.singleRun, halfMarathonMeters),
  BadgeDef(BadgeId.total10, '10 km club', 'Run 10 km in total.', BadgeKind.lifetime, 10000),
  BadgeDef(BadgeId.total50, '50 km club', 'Run 50 km in total.', BadgeKind.lifetime, 50000),
  BadgeDef(BadgeId.total100, 'Century', 'Run 100 km in total.', BadgeKind.lifetime, 100000),
  BadgeDef(BadgeId.total250, '250 km club', 'Run 250 km in total.', BadgeKind.lifetime, 250000),
  BadgeDef(BadgeId.streak3, 'Hat trick', 'Run 3 days in a row.', BadgeKind.streak, 3),
  BadgeDef(BadgeId.streak7, 'On a roll', 'Run 7 days in a row.', BadgeKind.streak, 7),
  BadgeDef(BadgeId.streak30, 'Unstoppable', 'Run 30 days in a row.', BadgeKind.streak, 30),
  BadgeDef(BadgeId.earlyBird, 'Early bird', 'Start a run of 1 km+ before 7 am.', BadgeKind.timeOfDay),
  BadgeDef(BadgeId.nightOwl, 'Night owl', 'Start a run of 1 km+ after 9 pm.', BadgeKind.timeOfDay),
  BadgeDef(BadgeId.weekendWarrior, 'Weekend warrior', 'Run 1 km+ on both Saturday and Sunday of one weekend.',
      BadgeKind.weekend),
];

BadgeDef badgeDef(BadgeId id) => badgeCatalogue[id.index];
