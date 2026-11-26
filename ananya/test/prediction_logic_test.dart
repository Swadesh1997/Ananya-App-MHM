import 'package:flutter_test/flutter_test.dart';
import 'package:ananya/services/period_history_service.dart';

// Builds entries the way fetchAll does: oldest first, gaps derived.
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

void main() {
  group('statsFrom', () {
    test('empty history -> empty stats, nothing invented', () {
      final s = PeriodHistoryService.statsFrom(const []);
      expect(s.cycleCount, 0);
      expect(s.averageCycleDays, isNull);
      expect(s.varianceDays, isNull);
      expect(s.isRegular, isNull);
    });

    test('single entry -> bleed only, no cycle stats', () {
      final s = PeriodHistoryService.statsFrom(entriesFrom(['2026-08-14']));
      expect(s.cycleCount, 1);
      expect(s.averageCycleDays, isNull);
      expect(s.averageBleedDays, 5);
      expect(s.isRegular, isNull);
    });

    test('two entries -> average but no variance yet', () {
      final s = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-07-16', '2026-08-14']));
      expect(s.lastCycleDays, 29);
      expect(s.averageCycleDays, 29);
      expect(s.varianceDays, isNull, reason: 'one gap cannot show spread');
      expect(s.isRegular, isNull);
    });

    test('three regular entries -> measured regular', () {
      final s = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-06-17', '2026-07-16', '2026-08-14']));
      expect(s.averageCycleDays, 29);
      expect(s.varianceDays, 0);
      expect(s.isRegular, isTrue);
    });

    test('irregular spread -> measured irregular', () {
      // gaps 21, 35 -> variance (35-21)/2 = 7 > 4
      final s = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-06-19', '2026-07-10', '2026-08-14']));
      expect(s.varianceDays, 7);
      expect(s.isRegular, isFalse);
    });

    test('90-day gap (missed logs) is excluded from the average', () {
      // gaps: 28, 90, 28 -> only the two 28s count
      final s = PeriodHistoryService.statsFrom(entriesFrom(
          ['2026-03-01', '2026-03-29', '2026-06-27', '2026-07-25']));
      expect(s.averageCycleDays, 28);
    });

    test('sub-15-day log is collapsed into the period it belongs to', () {
      // Jun 3 is 5 days after May 29 — one period logged twice, not a cycle.
      //
      // This used to expect 26. The old code dropped the 5-day gap but then
      // measured the next gap FROM Jun 3 (23 days), anchoring the average on
      // the very entry it had just rejected as a mis-log. Collapsing Jun 3 into
      // the May 29 episode gives May 1 -> May 29 -> Jun 26, i.e. 28 and 28.
      final s = PeriodHistoryService.statsFrom(entriesFrom(
          ['2026-05-01', '2026-05-29', '2026-06-03', '2026-06-26']));
      expect(s.averageCycleDays, 28);
      expect(s.cycleCount, 3, reason: 'a duplicate is not a fourth cycle');
    });

    test('5+ gaps: single outlier month is trimmed before averaging', () {
      // gaps: 28,28,28,28,35 -> trim min & max -> avg(28,28,28) = 28
      final s = PeriodHistoryService.statsFrom(entriesFrom([
        '2026-02-01',
        '2026-02-29',
        '2026-03-28',
        '2026-04-25',
        '2026-05-23',
        '2026-06-27',
      ]));
      expect(s.averageCycleDays, 28,
          reason: 'one 35-day month must not shift the prediction');
      expect(s.lastCycleDays, 35);
    });

    test('averaging window keeps only the 6 most recent gaps', () {
      // 8 old 35-day gaps followed by 6 recent 26-day gaps: teenager whose
      // cycle settled. Prediction must follow the recent cycle.
      final dates = <String>[];
      var d = DateTime(2025, 1, 1);
      dates.add('2025-01-01');
      for (var i = 0; i < 8; i++) {
        d = d.add(const Duration(days: 35));
        dates.add(d.toIso8601String().substring(0, 10));
      }
      for (var i = 0; i < 6; i++) {
        d = d.add(const Duration(days: 26));
        dates.add(d.toIso8601String().substring(0, 10));
      }
      final s = PeriodHistoryService.statsFrom(entriesFrom(dates));
      expect(s.averageCycleDays, 26);
    });
  });

  group('predictNext', () {
    final lastStart = DateTime(2026, 8, 14);

    test('no history -> uses signup values, and does NOT name a single day',
        () {
      // This asserted from == to: a confident date from nothing but the
      // signup answer. That answer is a claim, not an observation, and it
      // defaults to "regular", so the app was promising an exact day to
      // every new user before it had measured anything at all.
      final p = PeriodHistoryService.predictNext(
        lastStart: lastStart,
        fallbackCycleDays: 29,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: CycleStats.empty,
      );
      expect(p.nextExpected(lastStart), DateTime(2026, 9, 12),
          reason: 'the centre still comes from her signup cycle');
      expect(p.hasWindow, isTrue);
      expect(p.isMeasured, isFalse);
      expect(p.basedOnCycles, 0);
    });

    test('measured average overrides the signup cycle length', () {
      final stats = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-06-17', '2026-07-16', '2026-08-14']));
      final p = PeriodHistoryService.predictNext(
        lastStart: lastStart,
        fallbackCycleDays: 40, // wrong signup guess
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: stats,
      );
      expect(p.cycleDays, 29, reason: 'measured 29 must beat signup 40');
      expect(p.from, DateTime(2026, 9, 12));
      expect(p.isMeasured, isTrue);
    });

    test('irregular (self-reported, no data) -> ±5 day window', () {
      final p = PeriodHistoryService.predictNext(
        lastStart: lastStart,
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: false,
        stats: CycleStats.empty,
      );
      expect(p.to.difference(p.from).inDays, 10);
      expect(p.hasWindow, isTrue);
    });

    test('measured-regular data overrides self-reported irregular', () {
      final stats = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-06-17', '2026-07-16', '2026-08-14']));
      final p = PeriodHistoryService.predictNext(
        lastStart: lastStart,
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: false, // she said irregular at signup
        stats: stats, // but the logs show perfectly regular
      );
      expect(p.hasWindow, isFalse,
          reason: 'measurement beats the signup answer');
    });

    test('PCOS always widens to ±7 even when cycles look regular', () {
      final stats = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-06-17', '2026-07-16', '2026-08-14']));
      final p = PeriodHistoryService.predictNext(
        lastStart: lastStart,
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: stats,
        reportsPcos: true,
      );
      expect(p.to.difference(p.from).inDays, 14);
    });

    test('zero/garbage fallback cycle does not produce a crash', () {
      final p = PeriodHistoryService.predictNext(
        lastStart: lastStart,
        fallbackCycleDays: 0,
        fallbackBleedDays: 0,
        selfReportedRegular: true,
        stats: CycleStats.empty,
      );
      // Degenerate but non-crashing: the prediction centres on lastStart
      // itself. The window around it is the usual unmeasured one.
      expect(p.nextExpected(lastStart), lastStart);
    });
  });

  group('nextExpected (reminder target date)', () {
    test('future window -> its midpoint, untouched', () {
      final p = CyclePrediction(
        from: DateTime(2026, 9, 8),
        to: DateTime(2026, 9, 18),
        cycleDays: 28,
        bleedDays: 5,
        basedOnCycles: 3,
      );
      expect(p.nextExpected(DateTime(2026, 8, 27)), DateTime(2026, 9, 13));
    });

    test('window straddling today is NOT skipped', () {
      // from Aug 25, to Sep 4, today Aug 27: the period is due right now.
      final p = CyclePrediction(
        from: DateTime(2026, 8, 25),
        to: DateTime(2026, 9, 4),
        cycleDays: 28,
        bleedDays: 5,
        basedOnCycles: 3,
      );
      expect(p.nextExpected(DateTime(2026, 8, 27)), DateTime(2026, 8, 30),
          reason: 'must stay in the current window, not jump a month');
    });

    test('fully passed window rolls whole cycles forward', () {
      // Last logged in May, never since. Expected must land on the first
      // upcoming occurrence, keeping the cycle rhythm.
      final p = CyclePrediction(
        from: DateTime(2026, 6, 7),
        to: DateTime(2026, 6, 7),
        cycleDays: 28,
        bleedDays: 5,
        basedOnCycles: 2,
      );
      expect(p.nextExpected(DateTime(2026, 8, 27)), DateTime(2026, 8, 30));
    });

    test('zero cycleDays cannot loop forever', () {
      final p = CyclePrediction(
        from: DateTime(2026, 6, 7),
        to: DateTime(2026, 6, 7),
        cycleDays: 0,
        bleedDays: 5,
        basedOnCycles: 0,
      );
      expect(p.nextExpected(DateTime(2026, 8, 27)), DateTime(2026, 6, 7));
    });
  });

  group('calendar/reminder date arithmetic', () {
    test('roll-forward lands on the first not-yet-started cycle', () {
      // Mirrors getData(): last period 2026-05-10, cycle 28, today 2026-08-27.
      var next = DateTime(2026, 5, 10);
      final today = DateTime(2026, 8, 27);
      while (next.isBefore(today)) {
        next = next.add(const Duration(days: 28));
      }
      expect(next, DateTime(2026, 8, 30));
    });

    test('reminder offsets cross month boundaries correctly', () {
      // Predicted start Sep 3 -> the 7-day reminder is Aug 27.
      final fire = DateTime(2026, 9, 3 - 7, 9);
      expect(fire, DateTime(2026, 8, 27, 9));
    });

    test('logged band day expansion crosses month boundaries', () {
      // Mirrors the loggedDays loop: start Aug 30, 5 bleed days.
      final days = [
        for (var i = 0; i < 5; i++) DateTime(2026, 8, 30 + i),
      ];
      expect(days.last, DateTime(2026, 9, 3));
    });
  });
}
