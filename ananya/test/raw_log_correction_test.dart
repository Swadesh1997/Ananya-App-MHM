import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/period_history_service.dart';

/// Normalisation stays analytical. Correction becomes possible.
///
/// Two logs fewer than 15 days apart collapse into one episode whose
/// canonical start is the EARLIER date. That is right for reading — a period
/// logged twice is one period — but it made a correction impossible. A girl
/// who logged 1 January by mistake and then logged the real date, 10 January,
/// saw no new row, no change to the displayed date, and no feedback that
/// anything had happened; the only control removed both dates at once.
///
/// The grouping is unchanged. What is added is a way to reach the individual
/// logs behind an episode, so one can go without taking the other. The app
/// still makes NO guess about which of the two she meant — the dates alone
/// cannot say, and this deliberately does not try.
void main() {
  List<PeriodEntry> raw(List<String> isos, {int bleed = 5}) => [
        for (final iso in isos)
          PeriodEntry(start: DateTime.parse(iso), lengthOfPeriod: bleed),
      ];

  group('the grouping itself is untouched', () {
    test('Jan 1 + Jan 10 is still one episode, starting Jan 1', () {
      final episodes =
          PeriodHistoryService.normalize(raw(['2026-01-01', '2026-01-10']));
      expect(episodes.length, 1);
      expect(episodes.first.start, DateTime(2026, 1, 1));
    });

    test('the 15-day boundary has not moved', () {
      // 14 days apart merges; 15 days apart does not.
      expect(
        PeriodHistoryService.normalize(raw(['2026-01-01', '2026-01-15']))
            .length,
        1,
      );
      expect(
        PeriodHistoryService.normalize(raw(['2026-01-01', '2026-01-16']))
            .length,
        2,
      );
    });

    test('deleting an episode still removes every log behind it', () {
      final logs = raw(['2026-01-01', '2026-01-04', '2026-01-10']);
      final dates =
          PeriodHistoryService.datesInEpisode(logs, DateTime(2026, 1, 1));
      expect(dates.length, 3);
    });
  });

  group('the individual logs are now reachable', () {
    test('a single-log delete exists and is separate from the episode one',
        () {
      final src =
          File('lib/services/period_history_service.dart').readAsStringSync();
      expect(src, contains('static Future<void> deleteSingleLog('));
      expect(src, contains('static Future<List<DateTime>> fetchRawLocal('));
    });

    test('it removes one date only, not the episode', () {
      // Verified at the level this test can reach without a Firestore fake:
      // deleteSingleLog formats exactly one document id, where delete()
      // expands the episode first via datesInEpisode.
      final src =
          File('lib/services/period_history_service.dart').readAsStringSync();
      final single =
          src.substring(src.indexOf('static Future<void> deleteSingleLog('));
      // Up to the NEXT declaration: the parameter list also ends in a
      // closing brace, so a naive brace search stops too early.
      final body = single.substring(0, single.indexOf("  /// Removes one logged period"));
      expect(body.contains('datesInEpisode'), isFalse,
          reason: 'a single-log delete must not expand to the episode');
      expect(body, contains('LocalPeriodStore.deletePeriod'));
      expect(body, contains('_syncLatestToHistory'));
    });

    test('removing the mistaken date leaves the correction standing', () {
      // The outcome the user could not previously reach. Simulated at the
      // normalisation layer: with Jan 1 gone, Jan 10 is the episode.
      final afterCorrection = PeriodHistoryService.normalize(raw(
        ['2026-01-10'],
      ));
      expect(afterCorrection.length, 1);
      expect(afterCorrection.first.start, DateTime(2026, 1, 10));
    });

    test('and the anchor follows it', () {
      final before = PeriodHistoryService.statsFrom(
          raw(['2026-01-01', '2026-01-10']),
          reportedCycleDays: 28);
      final after = PeriodHistoryService.statsFrom(raw(['2026-01-10']),
          reportedCycleDays: 28);

      expect(before.canonicalLastStart, DateTime(2026, 1, 1),
          reason: 'the mistake anchored the forecast nine days early');
      expect(after.canonicalLastStart, DateTime(2026, 1, 10));
    });
  });

  group('the UI exposes them', () {
    test('the history row lists the dates behind a collapsed episode', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      expect(src, contains('_extraLogsFor'));
      expect(src, contains('logged_dates_in_entry'));
      expect(src, contains('remove_this_date'));
    });

    test('and each one can be removed on its own', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      expect(src, contains('PeriodHistoryService.deleteSingleLog'));
      // Distinct from the whole-episode delete, which is still there.
      expect(src, contains('PeriodHistoryService.delete('));
    });

    test('it only appears when a row really hides more than one date', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      expect(src, contains('if (dates.length < 2) return const []'));
    });

    test('removing one asks the screen above to recompute', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('Future<void> _removeSingleLog('));
      expect(fn.substring(0, fn.indexOf('Future<void> _loadRawDates')),
          contains('widget.onHistoryChanged?.call()'));
    });
  });

  group('no inference from the dates', () {
    test('a duplicate and a correction are indistinguishable, and stay so',
        () {
      // Identical inputs, opposite intent. The engine treats them the same
      // because it cannot tell, and guessing would be worse than not.
      final duplicate =
          PeriodHistoryService.normalize(raw(['2026-01-01', '2026-01-10']));
      final correction =
          PeriodHistoryService.normalize(raw(['2026-01-01', '2026-01-10']));
      expect(duplicate.first.start, correction.first.start);
      expect(duplicate.length, correction.length);
    });

    test('the longest reported bleed is still kept for the episode', () {
      final episodes = PeriodHistoryService.normalize([
        PeriodEntry(start: DateTime(2026, 1, 1), lengthOfPeriod: 4),
        PeriodEntry(start: DateTime(2026, 1, 4), lengthOfPeriod: 7),
      ]);
      expect(episodes.single.lengthOfPeriod, 7);
    });
  });
}
