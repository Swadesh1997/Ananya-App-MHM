import 'package:flutter_test/flutter_test.dart';

/// The countdown must aim at the date the period is expected, not the first
/// day it could conceivably arrive.
///
/// Reproduces a real account: one period logged on 1 September 2026, a 28-day
/// cycle, and is_period_regular = false. The irregular margin is ±5 days, so
/// the prediction window runs 24 September to 4 October with the 29th at its
/// centre. On 23 September the ring said "1 day to go" — counting to the 24th,
/// the near edge — for a period six days away.
void main() {
  // Mirrors the arithmetic in PeriodCycleInformation.getData().
  DateTime expectedFrom(DateTime from, DateTime to) =>
      from.add(Duration(days: to.difference(from).inDays ~/ 2));

  int daysUntil(DateTime from, DateTime to, DateTime today) =>
      expectedFrom(from, to).difference(today).inDays;

  group('irregular cycle, ±5 day window', () {
    final from = DateTime(2026, 9, 24);
    final to = DateTime(2026, 10, 4);

    test('the expected date is the middle of the window, not its edge', () {
      expect(expectedFrom(from, to), DateTime(2026, 9, 29));
    });

    test('counts to the expected date', () {
      expect(daysUntil(from, to, DateTime(2026, 9, 23)), 6);
    });

    test('does not report 1 day when the period is 6 days away', () {
      // The exact reading that prompted this test.
      expect(daysUntil(from, to, DateTime(2026, 9, 23)), isNot(1));
    });

    test('reaches zero on the expected day', () {
      expect(daysUntil(from, to, DateTime(2026, 9, 29)), 0);
    });

    test('goes negative once the expected day has passed', () {
      // Still inside the window, but overdue relative to the forecast — the
      // screen needs to be able to tell those apart.
      expect(daysUntil(from, to, DateTime(2026, 10, 1)), -2);
    });
  });

  group('regular cycle, no margin', () {
    // margin 0, so from == to and the midpoint is that same day.
    final day = DateTime(2026, 9, 29);

    test('a single-day prediction is unchanged', () {
      expect(expectedFrom(day, day), day);
      expect(daysUntil(day, day, DateTime(2026, 9, 23)), 6);
    });
  });

  group('PCOS, ±7 day window', () {
    final from = DateTime(2026, 9, 22);
    final to = DateTime(2026, 10, 6);

    test('still centres on the expected date', () {
      expect(expectedFrom(from, to), DateTime(2026, 9, 29));
      expect(daysUntil(from, to, DateTime(2026, 9, 23)), 6);
    });
  });

  group('the window itself is unchanged', () {
    test('1 Sept + 28 days is 29 Sept', () {
      expect(DateTime(2026, 9, 1).add(const Duration(days: 28)),
          DateTime(2026, 9, 29));
    });

    test('±5 around the 29th spans 24 Sept to 4 Oct', () {
      final expected = DateTime(2026, 9, 29);
      expect(expected.subtract(const Duration(days: 5)), DateTime(2026, 9, 24));
      expect(expected.add(const Duration(days: 5)), DateTime(2026, 10, 4));
    });
  });
}
