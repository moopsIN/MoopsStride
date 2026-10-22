import 'package:flutter_test/flutter_test.dart';
import 'package:stride/core/utils/formatters.dart';

void main() {
  test('formatPace converts speed to min/km and min/mi', () {
    expect(formatPace(12, isKm: true), '5\'00"');
    expect(formatPace(10, isKm: true), '6\'00"');
    expect(formatPace(10 * kmPerMile, isKm: false), '6\'00"');
  });

  test('formatPace hides meaningless pace when barely moving', () {
    expect(formatPace(0, isKm: true), '--\'--"');
    expect(formatPace(0.5, isKm: true), '--\'--"');
  });

  test('formatDuration', () {
    expect(formatDuration(65), '01:05');
    expect(formatDuration(3725), '1:02:05');
  });
}
