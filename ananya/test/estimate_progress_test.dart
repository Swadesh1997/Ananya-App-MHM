import 'package:flutter_test/flutter_test.dart';
import 'package:ananya/services/period_history_service.dart';

/// What the status box counts.
///
/// The box used to say "needs N more logs" from `3 - cycleCount`, which is not
/// the condition the algorithm actually uses. Regularity becomes measurable
/// when there are two USABLE intervals between periods — gaps inside the
/// 15-60 day range. Three logged periods with a ninety-day hole between two of
/// them give one usable interval, not two, so counting rows would have claimed
/// the app could measure her cycle when it could not. The old expression was
/// also floored at 1, so it could never reach 0 and could sit at "1 more"
/// forever.

List<PeriodEntry> entriesFrom(List<String> dates, {int bleed = 5}) {
  final parsed = dates.map(DateTime.parse).toList()..sort();
  return [
    for (var i = 0; i < parsed.length; i++)
      PeriodEntry(
        start: parsed[i],
        lengthOfPeriod: bleed,
        daysSincePrevious:
            i == 0 ? null : parsed[i].difference(parsed[i - 1]).inDays,
      )
  ];
}

CycleStats stats(List<String> dates) =>
    PeriodHistoryService.statsFrom(entriesFrom(dates));

void main() {
  group('how many periods the app can actually use', () {
    test('0 logged periods', () {
      final s = PeriodHistoryService.statsFrom(const []);
      expect(s.cycleCount, 0);
      expect(s.usablePeriods, 0);
      expect(s.hasMeasuredRegularity, isFalse);
    });

    test('1 logged period', () {
      final s = stats(['2026-06-01']);
      expect(s.usablePeriods, 1);
      expect(s.hasMeasuredRegularity, isFalse);
    });

    test('2 logged periods with a valid gap', () {
      final s = stats(['2026-06-01', '2026-06-29']);
      expect(s.usableGaps, 1);
      expect(s.usablePeriods, 2);
      expect(s.hasMeasuredRegularity, isFalse);
    });

    test('3 logged periods with valid gaps -> measurable', () {
      final s = stats(['2026-06-01', '2026-06-29', '2026-07-27']);
      expect(s.usableGaps, 2);
      expect(s.usablePeriods, 3);
      expect(s.hasMeasuredRegularity, isTrue);
    });

    test('more than 3 logged periods', () {
      final s = stats([
        '2026-04-06',
        '2026-05-04',
        '2026-06-01',
        '2026-06-29',
        '2026-07-27',
      ]);
      expect(s.cycleCount, 5);
      expect(s.usableGaps, 4);
      expect(s.usablePeriods, 5);
      expect(s.hasMeasuredRegularity, isTrue);
    });
  });

  group('data quality decides the count, not the row count', () {
    test('an implausibly long gap is not usable', () {
      // Jun 1 -> Sep 1 is 92 days: a period is missing from the middle.
      final s = stats(['2026-06-01', '2026-09-01', '2026-09-29']);
      expect(s.cycleCount, 3, reason: 'three rows exist');
      expect(s.usableGaps, 1, reason: 'but only one interval is usable');
      expect(s.usablePeriods, 2);
      expect(s.hasMeasuredRegularity, isFalse,
          reason: 'the algorithm cannot measure this, so the box must not '
              'claim it can');
    });

    test('enough rows but not enough usable gaps still reads as incomplete',
        () {
      // Four rows, three intervals, two of them too long to use.
      final s = stats(
          ['2026-01-01', '2026-05-01', '2026-09-01', '2026-09-29']);
      expect(s.cycleCount, 4);
      expect(s.usableGaps, 1);
      expect(s.usablePeriods, 2);
      expect(s.hasMeasuredRegularity, isFalse);
    });

    test('the displayed count never exceeds what is measurable', () {
      // Whatever the history, usablePeriods must never overstate the chain.
      for (final dates in [
        ['2026-06-01'],
        ['2026-06-01', '2026-06-29'],
        ['2026-06-01', '2026-09-01', '2026-09-29'],
        ['2026-01-01', '2026-05-01', '2026-09-01', '2026-09-29'],
        ['2026-04-06', '2026-05-04', '2026-06-01'],
      ]) {
        final s = stats(dates);
        expect(s.usablePeriods, lessThanOrEqualTo(s.cycleCount),
            reason: '$dates');
        expect(s.usablePeriods, s.usableGaps + 1, reason: '$dates');
      }
    });

    test('measured state and the progress count agree on the threshold', () {
      for (final dates in [
        <String>[],
        ['2026-06-01'],
        ['2026-06-01', '2026-06-29'],
        ['2026-06-01', '2026-06-29', '2026-07-27'],
        ['2026-06-01', '2026-09-01', '2026-09-29'],
        ['2026-01-01', '2026-05-01', '2026-09-01', '2026-09-29'],
      ]) {
        final s = dates.isEmpty
            ? PeriodHistoryService.statsFrom(const [])
            : stats(dates);
        expect(
          s.hasMeasuredRegularity,
          s.usablePeriods >= CycleStats.periodsForMeasurement,
          reason: 'the dots and the measured message must flip together: '
              '$dates',
        );
      }
    });
  });

  group('the counter can never get stuck or go negative', () {
    test('remaining never floors at 1 the way the old expression did', () {
      // The old code was `3 - cycleCount` clamped up to 1, so a user who had
      // reached the threshold could still be told "1 more".
      for (final dates in [
        ['2026-06-01', '2026-06-29', '2026-07-27'],
        ['2026-04-06', '2026-05-04', '2026-06-01', '2026-06-29'],
      ]) {
        final s = stats(dates);
        final remaining =
            CycleStats.periodsForMeasurement - s.usablePeriods;
        expect(remaining, lessThanOrEqualTo(0),
            reason: 'nothing more is needed once measurable: $dates');
        expect(s.hasMeasuredRegularity, isTrue);
      }
    });

    test('remaining is never negative in the incomplete state', () {
      for (final dates in [
        <String>[],
        ['2026-06-01'],
        ['2026-06-01', '2026-06-29'],
      ]) {
        final s = dates.isEmpty
            ? PeriodHistoryService.statsFrom(const [])
            : stats(dates);
        final remaining =
            CycleStats.periodsForMeasurement - s.usablePeriods;
        expect(remaining, greaterThan(0), reason: '$dates');
        expect(remaining, lessThanOrEqualTo(3), reason: '$dates');
      }
    });

    test('the threshold constants stay in step with each other', () {
      expect(CycleStats.periodsForMeasurement,
          CycleStats.gapsForMeasurement + 1);
      expect(CycleStats.gapsForMeasurement, 2,
          reason: 'varianceDays requires two gaps');
    });
  });
}
