/// Calendar-day helpers and streak maths, shared by progress and rewards.
///
/// Days are local calendar days. Stepping is done with the DateTime
/// constructor (day ± n), never by subtracting 24 hours, which lands on the
/// wrong day across a daylight-saving change.
library;

/// Local midnight of the day containing [t].
DateTime localDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// [day] moved by [n] calendar days.
DateTime addDays(DateTime day, int n) => DateTime(day.year, day.month, day.day + n);

/// Consecutive days with a run, ending today, or ending yesterday if there's
/// no run yet today (the streak is still alive until today ends).
int currentStreak(Iterable<DateTime> runStarts, DateTime now) {
  final days = runStarts.map(localDay).toSet();
  final today = localDay(now);
  var cursor = days.contains(today) ? today : addDays(today, -1);
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

/// The longest run of consecutive days in the whole history.
int longestStreak(Iterable<DateTime> runStarts) {
  final days = runStarts.map(localDay).toSet();
  var best = 0;
  for (final day in days) {
    if (days.contains(addDays(day, -1))) continue; // not the start of a run
    var length = 1;
    while (days.contains(addDays(day, length))) {
      length++;
    }
    if (length > best) best = length;
  }
  return best;
}
