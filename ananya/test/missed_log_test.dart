import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/period_history_service.dart';

/// A month that was never logged must not be read as one very long cycle.
///
/// Deleting a period from the history, or simply forgetting to log one, leaves
/// a gap of roughly two cycles. It sits well inside the 15-60 day plausible
/// range, so nothing rejected it and it was averaged in as though real: two
/// 28-day cycles with the middle one missing became a measured 58-day cycle,
/// and the forecast moved a month out. She would be told her period was weeks
/// away on the day before it arrived.
///
/// The two cases are the same observation and cannot be told apart by
/// arithmetic, so the rule below picks the safer error deliberately — see
/// PeriodHistoryService.missedLogMultiple.
void main() {
  List<PeriodEntry> from(List<String> isoDates, {int bleed = 5}) {
    final sorted = isoDates.map(DateTime.parse).toList()..sort();
    return [
      for (var i = 0; i < sorted.length; i++)
        PeriodEntry(
          start: sorted[i],
          lengthOfPeriod: bleed,
          daysSincePrevious:
              i == 0 ? null : sorted[i].difference(sorted[i - 1]).inDays,
        ),
    ];
  }

  group('deleting the middle of three periods', () {
    // July 2, August 1, August 29 — 30 and 28 day cycles.
    const all = ['2026-07-02', '2026-08-01', '2026-08-29'];

    test('with all three, the average is 29', () {
      final s = PeriodHistoryService.statsFrom(from(all),
          reportedCycleDays: 28);
      expect(s.averageCycleDays, 29);
      expect(s.usableGaps, 2);
    });

    test('with the middle one deleted, the 58-day gap is not a cycle', () {
      final s = PeriodHistoryService.statsFrom(
          from(['2026-07-02', '2026-08-29']),
          reportedCycleDays: 28);

      expect(s.averageCycleDays, isNull,
          reason: '58 days is two cycles, not one');
      expect(s.usableGaps, 0);
    });

    test('so the forecast falls back rather than moving a month out', () {
      final s = PeriodHistoryService.statsFrom(
          from(['2026-07-02', '2026-08-29']),
          reportedCycleDays: 28);
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 8, 29),
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: s,
      );

      expect(p.cycleDays, 28);
      // The CENTRE is what she is shown, and it is unchanged. The window
      // around it is new: with the 58-day interval rejected there is not one
      // usable interval left, so the app no longer offers an exact day.
      expect(p.nextExpected(DateTime(2026, 9, 23)), DateTime(2026, 9, 26));
      expect(p.hasWindow, isTrue,
          reason: 'nothing measured means no promise of a day');
      expect(p.basedOnCycles, 0,
          reason: 'it must not claim to be measured from her cycles');
    });

    test('the two remaining periods are still counted and still anchor it', () {
      // The gap is unusable; the periods themselves are not in doubt.
      final s = PeriodHistoryService.statsFrom(
          from(['2026-07-02', '2026-08-29']),
          reportedCycleDays: 28);

      expect(s.cycleCount, 2);
      expect(s.canonicalLastStart, DateTime(2026, 8, 29));
      expect(s.averageBleedDays, 5);
    });
  });

  group('with enough history it needs no help from signup', () {
    test('one missing month among four cycles is dropped', () {
      // Gaps 28, 55, 30, 28. The 55 is April-to-July with a month missing.
      final s = PeriodHistoryService.statsFrom(from([
        '2026-04-10',
        '2026-05-08',
        '2026-07-02',
        '2026-08-01',
        '2026-08-29',
      ]));

      expect(s.averageCycleDays, 29, reason: 'was 35 with the 55 averaged in');
      expect(s.usableGaps, 3);
      // This expected isRegular == true. It no longer holds, deliberately.
      // The 55-day interval was discarded, and discarding an observation
      // must not make the app more sure of itself — both filters remove LONG
      // gaps, so what survives is the short half of the history, which has
      // no spread by construction. That is how a 25/50 pattern was reported
      // as a flawless 25-day cycle. The centre still uses the surviving
      // 28-day intervals; only the confidence is withheld.
      expect(s.excludedObservations, 1);
      expect(s.isRegular, isNull,
          reason: 'an excluded interval cannot buy confidence');
    });
  });

  group('what it must not throw away', () {
    test('a genuinely long cycle, once her own history shows that pattern', () {
      // PCOS-length cycles: 50, 48, 52. Nothing here is a missed log.
      final s = PeriodHistoryService.statsFrom(
        from(['2026-04-01', '2026-05-21', '2026-07-08', '2026-08-29']),
      );

      expect(s.usableGaps, 3);
      expect(s.averageCycleDays, 50);
    });

    test('erratic adolescent cycles keep their long half', () {
      // 20 then 40 days is a real adolescent pattern, and 40 is under the
      // floor. Discarding it would flatten the spread and report her regular.
      final s = PeriodHistoryService.statsFrom(
          from(['2026-07-01', '2026-07-21', '2026-08-30']),
          reportedCycleDays: 28);

      expect(s.usableGaps, 2);
      expect(s.averageCycleDays, 30);
      expect(s.isRegular, isFalse);
    });

    test('a long cycle that is only a little long survives', () {
      final s = PeriodHistoryService.statsFrom(
          from(['2026-07-01', '2026-08-14']), // 44 days
          reportedCycleDays: 28);

      expect(s.averageCycleDays, 44, reason: '44 is under the 45-day floor');
    });
  });

  group('it corrects itself', () {
    test('a real long cycle is restored once it repeats', () {
      // First 55-day gap against a reported 28 is read as a missed log...
      final first = PeriodHistoryService.statsFrom(
          from(['2026-05-05', '2026-06-29']),
          reportedCycleDays: 28);
      expect(first.averageCycleDays, isNull);

      // ...but once it happens twice her own logs are the yardstick, and the
      // signup answer stops mattering.
      final then = PeriodHistoryService.statsFrom(
          from(['2026-05-05', '2026-06-29', '2026-08-23']),
          reportedCycleDays: 28);
      expect(then.averageCycleDays, 55);
    });
  });

  group('the rule itself', () {
    test('needs both the multiple and the floor', () {
      // 40 days is 2x a 20-day cycle but under the floor.
      expect(PeriodHistoryService.looksLikeMissedLog(40, 20), isFalse);
      // 46 clears the floor but is only 1.2x a 38-day cycle.
      expect(PeriodHistoryService.looksLikeMissedLog(46, 38), isFalse);
      // 58 clears both against a 28-day cycle.
      expect(PeriodHistoryService.looksLikeMissedLog(58, 28), isTrue);
    });

    test('the reference prefers her logs, then her signup answer', () {
      expect(PeriodHistoryService.referenceCycle([30, 28], 40), 28);
      expect(PeriodHistoryService.referenceCycle([58], 28), 28);
      expect(PeriodHistoryService.referenceCycle([], 28), 28);
    });

    test('on an even split it takes the shorter middle', () {
      // A missed log lengthens a gap and never shortens one, so the shorter
      // reading is the safer thing to measure against.
      expect(PeriodHistoryService.referenceCycle([28, 50], null), 28);
    });

    test('an implausible signup answer is no yardstick at all', () {
      // Nothing to judge against means the gap is kept: excluding it would be
      // a guess, and guessing is what this exists to avoid.
      expect(PeriodHistoryService.referenceCycle([58], 0), isNull);
      expect(PeriodHistoryService.referenceCycle([58], 400), isNull);
      expect(PeriodHistoryService.referenceCycle([58], null), isNull);

      final s = PeriodHistoryService.statsFrom(
          from(['2026-07-02', '2026-08-29'])); // no reported cycle
      expect(s.averageCycleDays, 58);
    });
  });
}
