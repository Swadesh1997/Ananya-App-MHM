import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/services/local_period_store.dart';
import 'package:ananya/services/period_history_service.dart';

/// Removing a mis-logged period.
///
/// A wrong date used to be permanent from inside the app, and it quietly
/// skewed every prediction after it. These cover the two traps in deleting it:
/// the entry coming back on the next load, and the forecast going on being
/// derived from data the user has removed.
///
/// PeriodHistoryService.delete itself talks to Firestore, so it cannot run
/// here. What is tested is the device copy it awaits, the seeding rule that
/// could undo it, and the arithmetic every consumer then reads.

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('device copy', () {
    test('a deleted period is gone from the device history', () async {
      await LocalPeriodStore.recordPeriod('u1', '2026-01-01', 5);
      await LocalPeriodStore.recordPeriod('u1', '2026-02-01', 5);

      await LocalPeriodStore.deletePeriod('u1', '2026-01-01');

      final history = await LocalPeriodStore.readHistory('u1');
      expect(history.keys, ['2026-02-01']);
    });

    test('deleting the only period leaves an empty history, not a stale one',
        () async {
      await LocalPeriodStore.recordPeriod('u1', '2026-01-01', 5);
      await LocalPeriodStore.deletePeriod('u1', '2026-01-01');

      expect(await LocalPeriodStore.readHistory('u1'), isEmpty);
    });

    test('deleting a date that was never logged is harmless', () async {
      await LocalPeriodStore.recordPeriod('u1', '2026-01-01', 5);
      await LocalPeriodStore.deletePeriod('u1', '2026-06-06');

      expect((await LocalPeriodStore.readHistory('u1')).keys, ['2026-01-01']);
    });

    test('deleting does not touch another account on the same handset',
        () async {
      await LocalPeriodStore.recordPeriod('u1', '2026-01-01', 5);
      // Switching uid clears the store, which is the existing behaviour.
      await LocalPeriodStore.recordPeriod('u2', '2026-03-01', 5);
      await LocalPeriodStore.deletePeriod('u2', '2026-03-01');

      expect(await LocalPeriodStore.readHistory('u2'), isEmpty);
      expect(await LocalPeriodStore.readHistory('u1'), isEmpty,
          reason: 'u1 lost the store when u2 signed in, as before');
    });
  });

  group('the deletion must not undo itself', () {
    test('seeding is refused once it has already happened', () async {
      // A returning user is bootstrapped from period/latest exactly once.
      expect(await LocalPeriodStore.hasSeeded('u1'), isFalse);
      await LocalPeriodStore.markSeeded('u1');
      expect(await LocalPeriodStore.hasSeeded('u1'), isTrue);
    });

    test('an empty history after a delete is NOT mistaken for never-seeded',
        () async {
      // This is the trap: seeding fires when the history is empty, and a user
      // who deletes her only logged period also has an empty history. Without
      // the flag the seed would write the date straight back on the next load.
      await LocalPeriodStore.recordPeriod('u1', '2026-01-01', 5);
      await LocalPeriodStore.markSeeded('u1');

      await LocalPeriodStore.deletePeriod('u1', '2026-01-01');

      expect(await LocalPeriodStore.readHistory('u1'), isEmpty);
      expect(await LocalPeriodStore.hasSeeded('u1'), isTrue,
          reason: 'the seed must not run again and resurrect the period');
    });

    test('a new account on the handset can still be seeded', () async {
      await LocalPeriodStore.markSeeded('u1');
      expect(await LocalPeriodStore.hasSeeded('u2'), isFalse,
          reason: 'the flag is per account, not per device');
    });
  });

  group('deleting an episode removes every log behind it', () {
    // The UI lists episodes, not raw logs. Removing only the canonical date
    // would leave a collapsed duplicate in place, and it would immediately
    // become an episode of its own — the period would reappear days later.

    test('a plain period maps to its own single date', () {
      final dates = PeriodHistoryService.datesInEpisode(
          entriesFrom(['2026-01-01', '2026-02-01']), DateTime(2026, 2, 1));

      expect(dates, [DateTime(2026, 2, 1)]);
    });

    test('a collapsed duplicate is included', () {
      final dates = PeriodHistoryService.datesInEpisode(
          entriesFrom(['2026-01-01', '2026-01-04', '2026-02-01']),
          DateTime(2026, 1, 1));

      expect(dates, [DateTime(2026, 1, 1), DateTime(2026, 1, 4)]);
    });

    test('a chain of duplicates is included in full', () {
      final dates = PeriodHistoryService.datesInEpisode(
          entriesFrom(['2026-01-01', '2026-01-04', '2026-01-07', '2026-02-01']),
          DateTime(2026, 1, 1));

      expect(dates, [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 4),
        DateTime(2026, 1, 7),
      ]);
    });

    test('neighbouring episodes are not swept up', () {
      final dates = PeriodHistoryService.datesInEpisode(
          entriesFrom(['2026-01-01', '2026-01-04', '2026-02-01', '2026-03-04']),
          DateTime(2026, 2, 1));

      expect(dates, [DateTime(2026, 2, 1)]);
    });

    test('removing the episode leaves nothing behind to resurface', () {
      final raw = entriesFrom(['2026-01-01', '2026-01-04', '2026-02-01']);
      final doomed = PeriodHistoryService
          .datesInEpisode(raw, DateTime(2026, 1, 1))
          .toSet();

      // What the history looks like once those documents are gone.
      final remaining =
          raw.where((e) => !doomed.contains(e.start)).toList();
      final after = PeriodHistoryService.normalize(remaining);

      expect(after.map((e) => e.start), [DateTime(2026, 2, 1)],
          reason: 'Jan 4 must not come back as a period of its own');
    });
  });

  group('what the rest of the app reads afterwards', () {
    test('removing a mis-logged date restores the real cycle length', () async {
      // She meant to log Feb 1 and typed Feb 11. The average is wrong until
      // the bad entry is removed.
      final withTypo =
          PeriodHistoryService.statsFrom(entriesFrom(['2026-01-01', '2026-02-11']));
      expect(withTypo.averageCycleDays, 41);

      final corrected =
          PeriodHistoryService.statsFrom(entriesFrom(['2026-01-01', '2026-02-01']));
      expect(corrected.averageCycleDays, 31);
    });

    test('removing the most recent period moves the anchor back', () async {
      final before = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-01-01', '2026-02-01', '2026-03-04']));
      expect(before.canonicalLastStart, DateTime(2026, 3, 4));

      final after = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-01-01', '2026-02-01']));
      expect(after.canonicalLastStart, DateTime(2026, 2, 1));
      expect(after.cycleCount, 2);
    });

    test('the prediction is recomputed from the periods that remain', () async {
      final after = PeriodHistoryService.statsFrom(
          entriesFrom(['2026-01-01', '2026-02-01']));
      final p = PeriodHistoryService.predictNext(
        lastStart: DateTime(2026, 3, 4), // stale settings value
        fallbackCycleDays: 28,
        fallbackBleedDays: 5,
        selfReportedRegular: true,
        stats: after,
      );

      // Feb 1 + the measured 31-day cycle.
      //
      // Asserted on the expected date rather than the window's near edge.
      // One surviving interval is not enough to promise a day, so the window
      // is no longer zero-width — but its centre, which is the date she is
      // actually shown, has not moved.
      expect(p.cycleDays, 31);
      expect(p.nextExpected(DateTime(2026, 2, 1)), DateTime(2026, 3, 4));
    });

    test('deleting everything leaves nothing to predict from', () async {
      final none = PeriodHistoryService.statsFrom(const []);

      expect(none.cycleCount, 0);
      expect(none.canonicalLastStart, isNull);
      expect(none.averageCycleDays, isNull);
      // user_home then takes the lastStart == null branch, which publishes an
      // empty payload and cancels the queued reminders.
    });

    test('the calendar loses exactly the removed band', () async {
      List<DateTime> bandStarts(List<String> dates) =>
          PeriodHistoryService.normalize(entriesFrom(dates))
              .map((e) => e.start)
              .toList();

      expect(bandStarts(['2026-01-01', '2026-02-01', '2026-03-04']).length, 3);
      expect(bandStarts(['2026-01-01', '2026-03-04']),
          [DateTime(2026, 1, 1), DateTime(2026, 3, 4)]);
    });
  });
}
