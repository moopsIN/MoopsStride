import 'package:flutter_test/flutter_test.dart';
import 'package:stride/features/rewards/domain/streaks.dart';

void main() {
  final now = DateTime(2026, 10, 23, 18, 0);
  DateTime daysAgo(int n, [int hour = 8]) => DateTime(now.year, now.month, now.day - n, hour);

  group('currentStreak', () {
    test('is zero with no runs', () {
      expect(currentStreak([], now), 0);
    });

    test('counts consecutive days ending today', () {
      expect(currentStreak([daysAgo(0), daysAgo(1), daysAgo(2), daysAgo(4)], now), 3);
    });

    test('is still alive if the last run was yesterday', () {
      expect(currentStreak([daysAgo(1), daysAgo(2)], now), 2);
    });

    test('is broken by a missed day', () {
      expect(currentStreak([daysAgo(2), daysAgo(3)], now), 0);
    });

    test('several runs on one day count once', () {
      expect(currentStreak([daysAgo(0, 6), daysAgo(0, 20), daysAgo(1)], now), 2);
    });

    test('uses local calendar days, not 24-hour windows', () {
      // 23:50 yesterday and 00:10 today are different days.
      final lateYesterday = DateTime(now.year, now.month, now.day - 1, 23, 50);
      final earlyToday = DateTime(now.year, now.month, now.day, 0, 10);
      expect(currentStreak([lateYesterday, earlyToday], DateTime(now.year, now.month, now.day, 0, 20)), 2);
    });
  });

  group('longestStreak', () {
    test('finds the longest block anywhere in history', () {
      final runs = [
        DateTime(2026, 1, 1), DateTime(2026, 1, 2),
        DateTime(2026, 2, 10), DateTime(2026, 2, 11), DateTime(2026, 2, 12), DateTime(2026, 2, 13),
        DateTime(2026, 3, 1),
      ];
      expect(longestStreak(runs), 4);
    });

    test('spans month and year boundaries', () {
      expect(longestStreak([DateTime(2025, 12, 30), DateTime(2025, 12, 31), DateTime(2026, 1, 1)]), 3);
    });

    test('is zero with no runs', () {
      expect(longestStreak([]), 0);
    });
  });

  group('daylight saving', () {
    // US DST starts 2026-03-08 and ends 2026-11-01. Run with
    // TZ=America/New_York to exercise the 23- and 25-hour days; in zones
    // without DST these still pass, as calendar stepping is exact.
    test('streak survives the spring-forward day', () {
      final runs = [DateTime(2026, 3, 7, 9), DateTime(2026, 3, 8, 9), DateTime(2026, 3, 9, 9)];
      expect(currentStreak(runs, DateTime(2026, 3, 9, 20)), 3);
      expect(longestStreak(runs), 3);
    });

    test('streak survives the fall-back day', () {
      final runs = [DateTime(2026, 10, 31, 9), DateTime(2026, 11, 1, 9), DateTime(2026, 11, 2, 9)];
      expect(currentStreak(runs, DateTime(2026, 11, 2, 20)), 3);
      expect(longestStreak(runs), 3);
    });

    test('addDays lands on midnight of the right day across DST', () {
      expect(addDays(DateTime(2026, 3, 9), -1), DateTime(2026, 3, 8));
      expect(addDays(DateTime(2026, 11, 2), -1), DateTime(2026, 11, 1));
    });
  });
}
