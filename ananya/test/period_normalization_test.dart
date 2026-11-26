import 'package:flutter_test/flutter_test.dart';
import 'package:ananya/services/period_history_service.dart';

/// Regression tests for the one canonical reading of a period history.
///
/// The bug these cover: an implausible log (less than 15 days after the
/// previous period) was ignored by the statistics but still drawn on the
/// calendar, still reset the cycle-day counter, still became "your last
/// period", and still moved the prediction. Six parts of the app held six
/// different opinions about the same data.
///
/// Everything here therefore checks the SAME normalised history feeding each
/// consumer, not just that normalize() works in isolation.

/// Builds raw entries exactly the way fetchAll does before normalising:
/// oldest first, gaps derived from consecutive raw starts.
List<PeriodEntry> rawEntries(List<String> dates, {List<int>? bleeds}) {
  final parsed = dates.map(DateTime.parse).toList()..sort();
  return [
    for (var i = 0; i < parsed.length; i++)
      PeriodEntry(
        start: parsed[i],
        lengthOfPeriod: bleeds == null ? 5 : bleeds[i],
        daysSincePrevious:
            i == 0 ? null : parsed[i].difference(parsed[i - 1]).inDays,
      )
  ];
}

List<DateTime> startsOf(List<PeriodEntry> e) => e.map((x) => x.start).toList();

/// Mirrors the loggedDays loop in period_cycle_information.dart getData().
List<DateTime> loggedDays(List<PeriodEntry> entries) => [
      for (final e in entries)
        for (var i = 0; i < e.lengthOfPeriod; i++)
          DateTime(e.start.year, e.start.month, e.start.day + i)
    ];

/// Mirrors the cycle_day expression in period_cycle_information.dart getData().
int? cycleDay(List<PeriodEntry> entries, DateTime today) => entries.isEmpty
    ? null
    : DateTime(today.year, today.month, today.day)
            .difference(entries.last.start)
            .inDays +
        1;

void main() {
  group('normalize', () {
    test('1. normal cycles are left completely alone', () {
      final raw = rawEntries(['2026-01-01', '2026-02-01', '2026-03-02']);
      final n = PeriodHistoryService.normalize(raw);

      expect(startsOf(n), [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 2),
      ]);
      expect(n.map((e) => e.daysSincePrevious), [null, 31, 29]);
    });

    test('2. a duplicate log does not become a separate cycle', () {
      final n = PeriodHistoryService.normalize(
          rawEntries(['2026-01-01', '2026-01-04', '2026-02-01']));

      expect(startsOf(n), [DateTime(2026, 1, 1), DateTime(2026, 2, 1)],
          reason: 'Jan 4 belongs to the Jan 1 period');
      expect(n.last.daysSincePrevious, 31,
          reason: 'effective cycle is Jan 1 -> Feb 1, not Jan 4 -> Feb 1 (28)');
    });

    test('3. chained duplicates all collapse into one episode', () {
      final n = PeriodHistoryService.normalize(rawEntries(
          ['2026-01-01', '2026-01-04', '2026-01-07', '2026-02-01']));

      expect(startsOf(n), [DateTime(2026, 1, 1), DateTime(2026, 2, 1)]);
      expect(n.last.daysSincePrevious, 31);
    });

    test('3b. a chain cannot swallow a genuine cycle', () {
      // Each log is 13 days after the previous RAW one, but Jan 27 is 26 days
      // after the episode start and is a plausible cycle. Measuring from the
      // previous raw log would have merged everything into one episode.
      final n = PeriodHistoryService.normalize(
          rawEntries(['2026-01-01', '2026-01-14', '2026-01-27']));

      expect(startsOf(n), [DateTime(2026, 1, 1), DateTime(2026, 1, 27)]);
      expect(n.last.daysSincePrevious, 26);
    });

    test('4. one duplicate in the middle of several valid cycles', () {
      final n = PeriodHistoryService.normalize(rawEntries([
        '2026-01-01',
        '2026-02-01',
        '2026-02-04', // duplicate of the February period
        '2026-03-02',
        '2026-04-01',
      ]));

      expect(startsOf(n), [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 2),
        DateTime(2026, 4, 1),
      ]);
      expect(n.map((e) => e.daysSincePrevious), [null, 31, 29, 30]);
    });

    test('bleed length is the longest reported, never the merged span', () {
      // Jan 1 for 3 days and Jan 4 for 6 days. The span Jan 1 -> Jan 9 is 9
      // days, which she never reported; 6 is the most she actually claimed.
      final n = PeriodHistoryService.normalize(
          rawEntries(['2026-01-01', '2026-01-04'], bleeds: [3, 6]));

      expect(n.single.lengthOfPeriod, 6);
    });

    test('normalising twice changes nothing (idempotent)', () {
      final once = PeriodHistoryService.normalize(
          rawEntries(['2026-01-01', '2026-01-04', '2026-02-01']));
      final twice = PeriodHistoryService.normalize(once);

      expect(startsOf(twice), startsOf(once));
      expect(twice.map((e) => e.daysSincePrevious),
          once.map((e) => e.daysSincePrevious));
    });

    test('empty and single histories are safe', () {
      expect(PeriodHistoryService.normalize(const []), isEmpty);
      final one = PeriodHistoryService.normalize(rawEntries(['2026-01-01']));
      expect(one.single.start, DateTime(2026, 1, 1));
      expect(one.single.daysSincePrevious, isNull);
    });
  });

  group('statistics', () {
    test('5. 5+ cycle shortest/longest trimming is unchanged', () {
      // gaps 28,28,28,28,35 -> trim min and max -> avg(28,28,28) = 28
      final s = PeriodHistoryService.statsFrom(rawEntries([
        '2026-02-01',
        '2026-02-29',
        '2026-03-28',
        '2026-04-25',
        '2026-05-23',
        '2026-06-27',
      ]));

      expect(s.averageCycleDays, 28);
      expect(s.lastCycleDays, 35);
      expect(s.cycleCount, 6);
    });

    test('5b. trimming still applies once duplicates are collapsed', () {
      // The same six real periods, but February was logged twice. The
      // duplicate must not become a 7th cycle or a 0-length gap in the trim.
      final s = PeriodHistoryService.statsFrom(rawEntries([
        '2026-02-01',
        '2026-02-05', // duplicate
        '2026-02-29',
        '2026-03-28',
        '2026-04-25',
        '2026-05-23',
        '2026-06-27',
      ]));

      expect(s.cycleCount, 6, reason: 'the duplicate is not a 7th cycle');
      expect(s.averageCycleDays, 28, reason: 'identical to the clean history');
      expect(s.lastCycleDays, 35);
    });

    test('a 90-day gap is still treated as a missed log, not collapsed', () {
      final s = PeriodHistoryService.statsFrom(rawEntries(
          ['2026-03-01', '2026-03-29', '2026-06-27', '2026-07-25']));

      expect(s.averageCycleDays, 28);
      expect(s.cycleCount, 4, reason: 'all four are real, distinct periods');
    });

    test('8. last period displayed comes from the canonical history', () {
      final s = PeriodHistoryService.statsFrom(
          rawEntries(['2026-01-01', '2026-02-01', '2026-02-04']));

      expect(s.canonicalLastStart, DateTime(2026, 2, 1),
          reason: 'Feb 4 was a duplicate, so the last period began Feb 1');
    });
  });

  group('9. prediction anchor', () {
    test('a duplicate log cannot shift the predicted date', () {
      final raw = rawEntries(['2026-01-01', '2026-01-04', '2026-02-01']);
      final stats = PeriodHistoryService.statsFrom(raw);

      // period/latest holds Jan 4: the logging flow overwrote it with the
      // duplicate. It must be ignored in favour of the canonical history.
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 1, 4),
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: stats,
      );

      expect(stats.averageCycleDays, 31, reason: 'Jan 1 -> Feb 1');
      // The centre, not the near edge: one interval no longer earns a
      // zero-width window, but the anchor question this test exists to ask
      // is unchanged.
      expect(p.nextExpected(DateTime(2026, 2, 1)), DateTime(2026, 3, 4),
          reason: 'Feb 1 + 31 days; anchoring on Jan 4 would give Feb 4 + n');
      expect(p.nextExpected(DateTime(2026, 2, 1)), isNot(DateTime(2026, 2, 4)));
    });

    test('with no history at all the signup date is still used', () {
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 8, 14),
        fallbackCycleDays: 29,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: CycleStats.empty,
      );

      // Centre, not edge: with no history the app will not name an exact
      // day, but the date it centres on is still the signup figure.
      expect(p.nextExpected(DateTime(2026, 8, 14)), DateTime(2026, 9, 12));
      expect(p.isMeasured, isFalse);
    });

    test('10. PCOS still widens the window rather than moving it', () {
      final stats = PeriodHistoryService.statsFrom(
          rawEntries(['2026-01-01', '2026-01-04', '2026-02-01', '2026-03-04']));
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 1, 4),
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: stats,
        reportsPcos: true,
      );

      expect(p.to.difference(p.from).inDays, 14, reason: '+/- 7 days');
      // Centre of the window is the anchor + cycle length, unmoved by Jan 4.
      final centre = p.from.add(Duration(days: p.to.difference(p.from).inDays ~/ 2));
      expect(centre, DateTime(2026, 4, 4));
    });

    test('10b. irregular history keeps its +/-5 day window', () {
      // gaps 21 and 35 -> variance 7 -> measured irregular.
      final stats = PeriodHistoryService.statsFrom(
          rawEntries(['2026-06-19', '2026-07-10', '2026-08-14']));
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 8, 14),
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: stats,
      );

      expect(stats.isRegular, isFalse);
      expect(p.to.difference(p.from).inDays, 10);
    });
  });

  group('calendar and cycle-day consumers', () {
    test('6. a duplicate does not draw a second period band', () {
      final raw = rawEntries(['2026-01-01', '2026-01-04']);

      // What the calendar used to draw from raw entries: two overlapping
      // bands covering Jan 1 to Jan 8.
      expect(loggedDays(raw).toSet().length, 8);

      final n = PeriodHistoryService.normalize(raw);
      final days = loggedDays(n);
      expect(n.length, 1, reason: 'one episode, so one band');
      expect(days.first, DateTime(2026, 1, 1));
      expect(days.last, DateTime(2026, 1, 5));
      expect(days.length, 5);
    });

    test('6b. genuinely separate periods still draw separate bands', () {
      final n = PeriodHistoryService.normalize(
          rawEntries(['2026-01-01', '2026-02-01']));

      expect(n.length, 2);
      expect(loggedDays(n).length, 10);
    });

    test('7. a duplicate does not reset the cycle-day counter', () {
      final today = DateTime(2026, 1, 10);
      final raw = rawEntries(['2026-01-01', '2026-01-04']);

      expect(cycleDay(raw, today), 7,
          reason: 'the old behaviour: counted from the duplicate');
      expect(cycleDay(PeriodHistoryService.normalize(raw), today), 10,
          reason: 'she is on day 10 of the period that began Jan 1');
    });

    test('7b. cycle day still restarts on a genuinely new period', () {
      final n = PeriodHistoryService.normalize(
          rawEntries(['2026-01-01', '2026-02-01']));

      expect(cycleDay(n, DateTime(2026, 2, 3)), 3);
    });
  });

  group('offline and sync consistency', () {
    // fetchAll needs Firebase, so these check the property that makes it safe:
    // normalize is a pure function of the SET of logged dates. Whatever order
    // or duplication the local and remote copies arrive in, both devices
    // derive the same episodes.

    test('11. a history logged offline normalises the same as a synced one', () {
      // Offline: only the device copy exists, in log order.
      final offline = PeriodHistoryService.normalize(
          rawEntries(['2026-01-01', '2026-01-04', '2026-02-01']));

      // Later, the same three dates come back from the server too. fetchAll
      // unions them by date, so the set is identical.
      final synced = PeriodHistoryService.normalize(
          rawEntries(['2026-02-01', '2026-01-01', '2026-01-04']));

      expect(startsOf(synced), startsOf(offline));
      expect(synced.map((e) => e.lengthOfPeriod),
          offline.map((e) => e.lengthOfPeriod));
    });

    test('12. two devices with the same dates predict identically', () {
      // Handset A logged Feb 1 offline; handset B logged the Feb 4 duplicate.
      // After sync both hold all three dates and must agree.
      final deviceA = rawEntries(['2026-01-01', '2026-02-01', '2026-02-04']);
      final deviceB = rawEntries(['2026-02-04', '2026-02-01', '2026-01-01']);

      final statsA = PeriodHistoryService.statsFrom(deviceA);
      final statsB = PeriodHistoryService.statsFrom(deviceB);

      expect(statsA.canonicalLastStart, statsB.canonicalLastStart);
      expect(statsA.averageCycleDays, statsB.averageCycleDays);
      expect(statsA.cycleCount, statsB.cycleCount);

      DateTime predict(CycleStats s) => PeriodHistoryService.predictNext(
            lastStart: DateTime(2026, 2, 4),
            fallbackCycleDays: 28,
            fallbackBleedDays: 5,
            selfReportedRegular: true,
            stats: s,
          ).nextExpected(DateTime(2026, 2, 1));

      expect(predict(statsA), predict(statsB));
      expect(predict(statsA), DateTime(2026, 3, 4),
          reason: 'Feb 1 + 31, never Feb 4 + anything');
    });

    test('END TO END: every consumer reads the same history', () {
      // The whole chain user_home runs, with a duplicate logged on Mar 7 and
      // period/latest poisoned by it. Calendar, cycle day, last period,
      // statistics and prediction must all describe the same three periods.
      final raw = rawEntries(
          ['2026-01-01', '2026-02-01', '2026-03-04', '2026-03-07']);
      final poisonedSettingsDate = DateTime(2026, 3, 7);

      final stats = PeriodHistoryService.statsFrom(raw);
      final prediction = PeriodHistoryService.predictNext(
        lastStart: poisonedSettingsDate,
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: stats,
      );
      // What period_cycle_information holds: fetchAll's normalised output.
      final entries = PeriodHistoryService.normalize(raw);

      // Statistics
      expect(stats.cycleCount, 3);
      expect(stats.averageCycleDays, 31);
      expect(stats.lastCycleDays, 31);

      // Last period displayed
      expect(entries.last.start, DateTime(2026, 3, 4));
      expect(stats.canonicalLastStart, entries.last.start,
          reason: 'the statistics and the display must not disagree');

      // Prediction, driven by the same anchor rather than by period/latest
      expect(prediction.cycleDays, 31);
      expect(prediction.from, DateTime(2026, 4, 4));

      // Calendar: three bands, and Mar 7 sits inside the March one instead of
      // starting a fourth.
      expect(entries.length, 3);
      final days = loggedDays(entries);
      expect(days.contains(DateTime(2026, 3, 7)), isTrue);
      expect(startsOf(entries).contains(DateTime(2026, 3, 7)), isFalse);
      expect(days.length, 15, reason: '3 periods x 5 bleed days');

      // Cycle day, counted from the same March period the calendar draws.
      expect(cycleDay(entries, DateTime(2026, 3, 10)), 7);

      // The prediction the calendar is handed is a whole number of canonical
      // cycles after the period the calendar itself draws as most recent.
      expect(
        prediction.from.difference(entries.last.start).inDays %
            prediction.cycleDays,
        0,
        reason: 'the forecast must line up with the drawn history',
      );
    });

    test('a duplicate arriving out of order is still collapsed', () {
      // The server can return the duplicate before the real start.
      final n = PeriodHistoryService.normalize(
          rawEntries(['2026-01-04', '2026-01-01', '2026-02-01']));

      expect(startsOf(n), [DateTime(2026, 1, 1), DateTime(2026, 2, 1)],
          reason: 'the EARLIEST start is canonical, whatever the arrival order');
    });
  });
}
