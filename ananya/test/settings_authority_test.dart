import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/local_period_store.dart';
import 'package:ananya/services/period_history_service.dart';

/// Which settings document the prediction rests on, and what happens when two
/// devices hold different ones.
///
/// Audit 3 demonstrated the same account predicting 7 October on one handset
/// and 3 October on another, from an identical history, because one had the
/// signup cycle length and the other did not. No new conflict-resolution rule
/// is introduced here: the authority model is written down, the cache is made
/// to behave like a cache, and the part that remains genuinely unsolvable
/// offline is pinned so it cannot be mistaken for a bug later.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 9, 24);

  List<PeriodEntry> history() => [
        PeriodEntry(start: DateTime(2026, 1, 1), lengthOfPeriod: 5),
        PeriodEntry(
            start: DateTime(2026, 2, 25),
            lengthOfPeriod: 5,
            daysSincePrevious: 55),
      ];

  CycleSnapshot withCycle(int? cycle) => CycleSnapshot.build(
        entries: history(),
        settings: cycle == null
            ? const {'length_of_period': 5}
            : {'days_between_period': cycle, 'length_of_period': 5},
        today: today,
      );

  group('the authority model, as implemented', () {
    test('the server document wins whenever it can be read', () {
      final src =
          File('lib/screens/landing/user_home.dart').readAsStringSync();
      final load = src.substring(src.indexOf('Future<void> _loadPeriodData()'));
      final body = load.substring(0, load.indexOf('// ================= MAP'));

      // Local first so the screen can render offline...
      expect(body.indexOf('LocalPeriodStore.readSettings'),
          lessThan(body.indexOf('doc.exists')));
      // ...then overwritten wholesale by the server when it answers.
      expect(body, contains('firebaseData = doc.data()!'));
      expect(body, contains('settingsFromDeviceCopy = false'));
    });

    test('the cache is replaced by the server copy, never merged into it', () {
      final src =
          File('lib/screens/landing/user_home.dart').readAsStringSync();
      expect(src, contains('LocalPeriodStore.replaceSettings'));
      expect(src.contains('LocalPeriodStore.saveSettings'), isFalse,
          reason: 'merging the server answer leaves removed fields behind');
    });

    test('replaceSettings drops a field the server no longer holds',
        () async {
      SharedPreferences.setMockInitialValues({});
      await LocalPeriodStore.saveSettings('u1', {
        'days_between_period': 28,
        'length_of_period': 5,
        'retired_field': 'x',
      });
      await LocalPeriodStore.replaceSettings('u1', {
        'days_between_period': 30,
        'length_of_period': 5,
      });

      final read = await LocalPeriodStore.readSettings('u1');
      expect(read!['days_between_period'], 30);
      expect(read.containsKey('retired_field'), isFalse);
    });

    test('saveSettings still merges, because the logging flow needs it',
        () async {
      SharedPreferences.setMockInitialValues({});
      await LocalPeriodStore.saveSettings('u2', {
        'days_between_period': 28,
        'length_of_period': 5,
      });
      // The short flow writes only these.
      await LocalPeriodStore.saveSettings('u2', {
        'last_period_start': '2026-09-01',
      });

      final read = await LocalPeriodStore.readSettings('u2');
      expect(read!['days_between_period'], 28,
          reason: 'a partial write must not erase the rest');
      expect(read['last_period_start'], '2026-09-01');
    });
  });

  group('the divergence that remains, pinned', () {
    // Both devices are online and synced: they agree, because both read the
    // same server document.
    test('same settings, same history -> identical prediction', () {
      final a = withCycle(28);
      final b = withCycle(28);
      expect(a.expectedDate, b.expectedDate);
      expect(a.prediction!.cycleDays, b.prediction!.cycleDays);
      expect(a.state, b.state);
    });

    test('DIFFERENT settings, same history -> DIFFERENT prediction', () {
      // This is the audit-3 scenario and it is NOT fixed, deliberately. It
      // arises only when one device cannot reach Firestore and is reading a
      // device copy that predates the other's. Resolving it would need a
      // conflict policy — whose write wins, and on what evidence — and that
      // is a product decision, not an engineering one.
      final a = withCycle(28);
      final b = withCycle(null);

      expect(a.prediction!.cycleDays, 28,
          reason: '55 is rejected as a probable missed log against 28');
      expect(b.prediction!.cycleDays, 55,
          reason: 'with no yardstick the interval is kept');
      expect(a.expectedDate, isNot(b.expectedDate));
    });

    test('but each device says which copy it is using', () {
      final stale = CycleSnapshot.build(
        entries: history(),
        settings: const {'days_between_period': 28, 'length_of_period': 5},
        today: today,
        settingsFromDeviceCopy: true,
      );
      final fresh = CycleSnapshot.build(
        entries: history(),
        settings: const {'days_between_period': 28, 'length_of_period': 5},
        today: today,
      );
      expect(stale.settingsFromDeviceCopy, isTrue);
      expect(fresh.settingsFromDeviceCopy, isFalse);
    });

    test('and they converge the moment either one reaches the server', () {
      // Once the server answers, both replace their cache with the same
      // document, so the next snapshot on each is identical.
      const server = {'days_between_period': 28, 'length_of_period': 5};
      final a = CycleSnapshot.build(
          entries: history(), settings: server, today: today);
      final b = CycleSnapshot.build(
          entries: history(), settings: server, today: today);
      expect(a.expectedDate, b.expectedDate);
      expect(a.stats.averageCycleDays, b.stats.averageCycleDays);
    });
  });

  group('section 8 — a collapsed episode still shows its dates', () {
    test('two devices logging 4 days apart keep BOTH raw dates', () {
      // Normalisation groups them for the maths; the raw logs are untouched.
      final raw = [
        PeriodEntry(start: DateTime(2026, 8, 1), lengthOfPeriod: 5),
        PeriodEntry(start: DateTime(2026, 8, 5), lengthOfPeriod: 5),
      ];
      final episodes = PeriodHistoryService.normalize(raw);

      expect(episodes.length, 1, reason: 'the rule is unchanged');
      expect(episodes.single.start, DateTime(2026, 8, 1));

      // Both are still reachable, which is what stops 5 August looking lost.
      final behind = PeriodHistoryService.datesInEpisode(
          raw, DateTime(2026, 8, 1));
      expect(behind, [DateTime(2026, 8, 1), DateTime(2026, 8, 5)]);
    });

    test('removing one leaves the other', () {
      final remaining = PeriodHistoryService.normalize([
        PeriodEntry(start: DateTime(2026, 8, 5), lengthOfPeriod: 5),
      ]);
      expect(remaining.single.start, DateTime(2026, 8, 5));
    });

    test('normalisation affects the prediction, never the stored logs', () {
      final src =
          File('lib/services/period_history_service.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('static List<PeriodEntry> normalize('));
      final body = fn.substring(0, fn.indexOf('\n  }\n'));
      expect(body.contains('delete'), isFalse,
          reason: 'normalisation must never remove anything from storage');
    });
  });
}
