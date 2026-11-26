import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/period_history_service.dart';

/// End-to-end arithmetic for the prediction, walked through the exact sequence
/// a user follows: one logged period, then two, then three.
///
/// This is the app's central feature. Every number it puts on screen comes
/// from here, so each step below asserts the figure a person would actually
/// read — the expected date, the window, the average, and whether the app
/// claims to have measured her cycle or is still leaning on what she typed at
/// signup.
void main() {
  PeriodEntry e(int y, int m, int d, int bleed) =>
      PeriodEntry(start: DateTime(y, m, d), lengthOfPeriod: bleed);

  group('ovulation is counted back from the next period', () {
    // The luteal phase is the fixed part of the cycle. Taking the midpoint
    // instead is right only at 28 days, and the error grows either side.
    test('28-day cycle: day 14, where the midpoint also lands', () {
      expect(PeriodHistoryService.ovulationDayOfCycle(28), 14);
    });

    test('35-day cycle: day 21, not the midpoint 17', () {
      expect(PeriodHistoryService.ovulationDayOfCycle(35), 21);
      expect(PeriodHistoryService.ovulationDayOfCycle(35), isNot(35 ~/ 2));
    });

    test('21-day cycle: day 7, not the midpoint 10', () {
      expect(PeriodHistoryService.ovulationDayOfCycle(21), 7);
      expect(PeriodHistoryService.ovulationDayOfCycle(21), isNot(21 ~/ 2));
    });

    test('never lands during bleeding', () {
      // A 16-day cycle counted back 14 gives day 2, mid-period.
      final day = PeriodHistoryService.ovulationDayOfCycle(16, bleedDays: 5);
      expect(day, greaterThan(5));
    });

    test('never lands on or after the next period', () {
      // Only for cycles the app supports. Below 15 days there is no cycle
      // length this engine will estimate from, and the function now declines
      // rather than returning day 14 — which, at cycle 8, sat outside the
      // cycle it was supposed to be inside.
      for (final c in [15, 21, 28, 35, 45, 60]) {
        expect(PeriodHistoryService.ovulationDayOfCycle(c),
            lessThan(c), reason: 'cycle $c');
      }
      for (final c in [0, 1, 7, 8, 12, 14, 61]) {
        expect(PeriodHistoryService.ovulationDayOfCycle(c), isNull,
            reason: 'cycle $c is outside the supported range');
      }
    });
  });

  group('step 1 — one period logged', () {
    final entries = [e(2026, 9, 1, 4)];
    final stats = PeriodHistoryService.statsFrom(entries);

    test('nothing is measured yet', () {
      expect(stats.cycleCount, 1);
      expect(stats.averageCycleDays, isNull);
      expect(stats.varianceDays, isNull);
      expect(stats.isRegular, isNull);
      expect(stats.usableGaps, 0);
      expect(stats.usablePeriods, 1);
    });

    test('bleed length is known from the one entry', () {
      expect(stats.averageBleedDays, 4);
    });

    test('the anchor is that period', () {
      expect(stats.canonicalLastStart, DateTime(2026, 9, 1));
    });

    test('prediction falls back to signup values, with the irregular window',
        () {
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 9, 1),
        fallbackCycleDays: 28,
        fallbackBleedDays: 4,
        selfReportedRegular: false,
        stats: stats,
      );

      expect(p.cycleDays, 28, reason: 'from signup, not measured');
      expect(p.basedOnCycles, 0, reason: 'nothing measured yet');
      expect(p.isMeasured, isFalse);

      // 1 Sept + 28 = 29 Sept, +/- 5 because she said irregular.
      expect(p.from, DateTime(2026, 9, 24));
      expect(p.to, DateTime(2026, 10, 4));
      expect(p.nextExpected(DateTime(2026, 9, 23)), DateTime(2026, 9, 29));
    });

    test('a self-reported regular cycle no longer buys a single date', () {
      // This expected hasWindow == false. It no longer holds, deliberately:
      // with one logged period there is not a single measured interval, so
      // "regular" is a claim she typed at signup, not an observation — and
      // the field defaults to regular. Honouring it turned an unknown into a
      // promise of an exact day. The centre of the forecast is unchanged;
      // only the certainty around it is now honest.
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 9, 1),
        fallbackCycleDays: 28,
        fallbackBleedDays: 4,
        selfReportedRegular: true,
        stats: stats,
      );
      expect(p.hasWindow, isTrue);
      expect(p.nextExpected(DateTime(2026, 9, 1)), DateTime(2026, 9, 29),
          reason: 'the expected date itself must not move');
      expect(p.from, DateTime(2026, 9, 24));
      expect(p.to, DateTime(2026, 10, 4));
    });
  });

  group('step 2 — a second, earlier period added', () {
    // She remembers August: 4 August, 30 days before 3 September.
    final entries = [e(2026, 8, 4, 5), e(2026, 9, 3, 4)];
    final stats = PeriodHistoryService.statsFrom(entries);

    test('one usable interval now exists', () {
      expect(stats.cycleCount, 2);
      expect(stats.usableGaps, 1);
      expect(stats.usablePeriods, 2);
      expect(stats.lastCycleDays, 30);
    });

    test('the average is measured, from her own data', () {
      expect(stats.averageCycleDays, 30);
    });

    test('regularity still cannot be judged from one interval', () {
      // A spread needs at least two gaps; one interval has no spread.
      expect(stats.varianceDays, isNull);
      expect(stats.isRegular, isNull);
      expect(stats.hasMeasuredRegularity, isFalse);
    });

    test('the measured average overrides the signup figure', () {
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 9, 3),
        fallbackCycleDays: 28, // she typed this; it must now be ignored
        fallbackBleedDays: 4,
        selfReportedRegular: false,
        stats: stats,
      );
      expect(p.cycleDays, 30, reason: 'measured 30, not the typed 28');
      expect(p.isMeasured, isTrue);
      expect(p.basedOnCycles, 2);

      // 3 Sept + 30 = 3 Oct, still +/-5 while regularity is unmeasured.
      expect(p.nextExpected(DateTime(2026, 9, 23)), DateTime(2026, 10, 3));
    });

    test('bleed length averages across both', () {
      expect(stats.averageBleedDays, 5, reason: '(5 + 4) / 2 rounds to 5');
    });
  });

  group('step 3 — a third period, regularity becomes measurable', () {
    // 5 July, 4 Aug (30), 3 Sept (30) — steady.
    final regular = PeriodHistoryService.statsFrom(
      [e(2026, 7, 5, 5), e(2026, 8, 4, 5), e(2026, 9, 3, 4)],
    );

    test('two intervals, so a spread can be measured', () {
      expect(regular.usableGaps, 2);
      expect(regular.usablePeriods, 3);
      expect(regular.hasMeasuredRegularity, isTrue);
    });

    test('steady cycles read as regular', () {
      expect(regular.averageCycleDays, 30);
      expect(regular.varianceDays, 0);
      expect(regular.isRegular, isTrue);
    });

    test('a regular measured cycle drops the window entirely', () {
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 9, 3),
        fallbackCycleDays: 28,
        fallbackBleedDays: 4,
        // She said irregular at signup; three logs say otherwise and the
        // measurement must win.
        selfReportedRegular: false,
        stats: regular,
      );
      expect(p.hasWindow, isFalse);
      expect(p.from, DateTime(2026, 10, 3));
      expect(p.nextExpected(DateTime(2026, 9, 23)), DateTime(2026, 10, 3));
    });

    test('scattered cycles read as irregular and keep the window', () {
      // 1 July, 20 Aug (50), 3 Sept (14 -> collapsed, see below), so use
      // clearly separated but uneven dates instead.
      final uneven = PeriodHistoryService.statsFrom(
        [e(2026, 6, 20, 5), e(2026, 7, 26, 5), e(2026, 9, 3, 4)],
      );
      expect(uneven.usableGaps, 2);
      expect(uneven.averageCycleDays, 38, reason: '(36 + 39) / 2 = 37.5 -> 38');
      expect(uneven.isRegular, isFalse,
          reason: 'average above 35 is outside the normal range');

      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 9, 3),
        fallbackCycleDays: 28,
        fallbackBleedDays: 4,
        selfReportedRegular: true, // said regular; measurement disagrees
        stats: uneven,
      );
      expect(p.hasWindow, isTrue);
      expect(p.to.difference(p.from).inDays,
          PeriodHistoryService.irregularMarginDays * 2);
    });
  });

  group('things that must never break the maths', () {
    test('a duplicate log does not become a 3-day cycle', () {
      // She logs 1 Sept, then re-logs on the 4th mid-flow.
      final stats =
          PeriodHistoryService.statsFrom([e(2026, 9, 1, 4), e(2026, 9, 4, 3)]);
      expect(stats.cycleCount, 1, reason: 'one episode, not two');
      expect(stats.averageCycleDays, isNull);
      expect(stats.canonicalLastStart, DateTime(2026, 9, 1),
          reason: 'the anchor must stay on the real start');
    });

    test('the anchor is never a duplicate, even with real cycles around it',
        () {
      final stats = PeriodHistoryService.statsFrom(
        [e(2026, 8, 1, 5), e(2026, 8, 4, 3), e(2026, 9, 1, 5)],
      );
      expect(stats.cycleCount, 2);
      expect(stats.lastCycleDays, 31, reason: '1 Aug -> 1 Sept, not 4 Aug');
      expect(stats.canonicalLastStart, DateTime(2026, 9, 1));
    });

    test('a missed log is excluded rather than averaged in', () {
      // A 90-day hole is a period she never recorded, not a 90-day cycle.
      final stats = PeriodHistoryService.statsFrom(
        [e(2026, 3, 1, 5), e(2026, 5, 30, 5), e(2026, 6, 29, 5)],
      );
      expect(stats.cycleCount, 3);
      expect(stats.usableGaps, 1, reason: 'the 90-day gap is not usable');
      expect(stats.averageCycleDays, 30);
    });

    test('usablePeriods never overstates what the app can measure', () {
      final stats = PeriodHistoryService.statsFrom(
        [e(2026, 3, 1, 5), e(2026, 5, 30, 5), e(2026, 6, 29, 5)],
      );
      // Three logged, but only two form a usable chain.
      expect(stats.cycleCount, 3);
      expect(stats.usablePeriods, 2);
    });

    test('out-of-order input gives the same answer as sorted input', () {
      final sorted = PeriodHistoryService.statsFrom(
        [e(2026, 7, 5, 5), e(2026, 8, 4, 5), e(2026, 9, 3, 4)],
      );
      final shuffled = PeriodHistoryService.statsFrom(
        [e(2026, 9, 3, 4), e(2026, 7, 5, 5), e(2026, 8, 4, 5)],
      );
      expect(shuffled.averageCycleDays, sorted.averageCycleDays);
      expect(shuffled.canonicalLastStart, sorted.canonicalLastStart);
      expect(shuffled.usableGaps, sorted.usableGaps);
    });

    test('normalising twice changes nothing', () {
      final once = PeriodHistoryService.normalize(
          [e(2026, 9, 1, 4), e(2026, 9, 4, 3), e(2026, 10, 2, 5)]);
      final twice = PeriodHistoryService.normalize(once);
      expect(twice.length, once.length);
      for (var i = 0; i < once.length; i++) {
        expect(twice[i].start, once[i].start);
        expect(twice[i].daysSincePrevious, once[i].daysSincePrevious);
      }
    });

    test('an old prediction rolls forward instead of sitting in the past', () {
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 1, 1),
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: CycleStats.empty,
      );
      final next = p.nextExpected(DateTime(2026, 9, 23));
      expect(next.isAfter(DateTime(2026, 9, 22)), isTrue);
      // Whole cycles from 29 Jan.
      expect(next.difference(DateTime(2026, 1, 29)).inDays % 28, 0);
    });

    test('PCOS always gets a window, even when the cycles look regular', () {
      final steady = PeriodHistoryService.statsFrom(
          [e(2026, 7, 5, 5), e(2026, 8, 4, 5), e(2026, 9, 3, 4)]);
      expect(steady.isRegular, isTrue);

      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 9, 3),
        fallbackCycleDays: 28,
        fallbackBleedDays: 4,
        selfReportedRegular: true,
        stats: steady,
        reportsPcos: true,
      );
      expect(p.hasWindow, isTrue);
      expect(p.to.difference(p.from).inDays,
          PeriodHistoryService.pcosMarginDays * 2);
    });
  });
}
