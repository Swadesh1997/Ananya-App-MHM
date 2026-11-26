import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/period_history_service.dart';

/// One reading of the cycle, shared by every consumer.
///
/// Three widgets used to compute this independently, from settings they each
/// fetched separately: the home ring from Firestore, the card beneath it from
/// the device copy. Those disagree on a cold start, and with one long
/// interval in the history the disagreement is total — a 55-day gap judged
/// against a reported 28 is rejected, judged against nothing it is accepted,
/// and the same screen then showed "28 days, not yet measured" above
/// "average cycle 55, based on 2 cycles".
void main() {
  final today = DateTime(2026, 9, 24);

  List<PeriodEntry> from(List<String> isos, {int bleed = 5}) {
    final d = isos.map(DateTime.parse).toList()..sort();
    return [
      for (var i = 0; i < d.length; i++)
        PeriodEntry(
          start: d[i],
          lengthOfPeriod: bleed,
          daysSincePrevious: i == 0 ? null : d[i].difference(d[i - 1]).inDays,
        ),
    ];
  }

  Map<String, dynamic> settings({
    dynamic cycle = 28,
    dynamic bleed = 5,
    bool regular = true,
    Map<String, bool>? conditions,
  }) =>
      {
        'days_between_period': cycle,
        'length_of_period': bleed,
        'is_period_regular': regular,
        if (conditions != null) 'health_condition': conditions,
      };

  group('INVARIANT 3 — every consumer gets the same numbers', () {
    test('the same history and settings always build the same snapshot', () {
      final a = CycleSnapshot.build(
        entries: from(['2026-07-02', '2026-08-01', '2026-08-29']),
        settings: settings(),
        today: today,
      );
      final b = CycleSnapshot.build(
        entries: from(['2026-08-29', '2026-07-02', '2026-08-01']),
        settings: settings(),
        today: today,
      );

      expect(a.stats.canonicalLastStart, b.stats.canonicalLastStart);
      expect(a.prediction!.cycleDays, b.prediction!.cycleDays);
      expect(a.stats.averageCycleDays, b.stats.averageCycleDays);
      expect(a.stats.varianceDays, b.stats.varianceDays);
      expect(a.stats.isRegular, b.stats.isRegular);
      expect(a.expectedDate, b.expectedDate);
      expect(a.windowFrom, b.windowFrom);
      expect(a.windowTo, b.windowTo);
      expect(a.state, b.state);
    });

    test('the values the ring, calendar and statistics each read agree', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-07-02', '2026-08-01', '2026-08-29']),
        settings: settings(),
        today: today,
      );

      // What the ring shows.
      expect(s.expectedDate, DateTime(2026, 9, 27));
      expect(s.daysUntilExpected, 3);
      // What the calendar projects from — the same date, not the near edge.
      expect(s.windowFrom, s.expectedDate);
      // What the statistics line reports.
      expect(s.stats.averageCycleDays, 29);
      expect(s.stats.usablePeriods, 3);
      // What the reminder aims at.
      expect(s.prediction!.nextExpected(today), s.expectedDate);
    });
  });

  group('ISSUE 11 — one settings source, not two', () {
    // history with a single 55-day interval: the case where the two old
    // sources disagreed completely.
    final history = from(['2026-01-01', '2026-02-25']);

    test('Firestore reports 28 — the interval is rejected', () {
      final s = CycleSnapshot.build(
        entries: history,
        settings: settings(cycle: 28),
        today: today,
      );
      expect(s.stats.averageCycleDays, isNull);
      expect(s.prediction!.cycleDays, 28);
      expect(s.state, PredictionState.insufficientHistory);
    });

    test('local settings absent — the snapshot still resolves ONE way', () {
      // Previously the card built its own stats with reportedCycleDays null
      // and reported a measured 55-day cycle while the ring said 28. There is
      // now no second computation to disagree with.
      final s = CycleSnapshot.build(
        entries: history,
        settings: null,
        today: today,
      );
      // Without any reported cycle there is no yardstick, so the interval is
      // kept — but this is now the ONLY reading on the screen, not a second
      // one contradicting the first.
      expect(s.stats.averageCycleDays, 55);
      expect(s.prediction!.cycleDays, 55);
    });

    test('a stale reading is flagged rather than silently different', () {
      final s = CycleSnapshot.build(
        entries: history,
        settings: settings(),
        today: today,
        settingsFromDeviceCopy: true,
      );
      expect(s.settingsFromDeviceCopy, isTrue);
    });
  });

  group('ISSUE 2 — stored values that would once have crashed', () {
    test('a cycle outside the supported range is not used as one', () {
      for (final c in [0, 1, 7, 8, 14, 61, 100, -1]) {
        final s = CycleSnapshot.build(
          entries: from(['2026-09-01']),
          settings: settings(cycle: c),
          today: today,
        );
        expect(s.reportedCycleDays, isNull, reason: 'cycle $c');
        // No measured average either, so there is nothing to predict from.
        expect(s.state, PredictionState.noPrediction, reason: 'cycle $c');
        expect(s.prediction, isNull, reason: 'cycle $c');
      }
    });

    test('supported cycles are used', () {
      for (final c in [15, 28, 60]) {
        final s = CycleSnapshot.build(
          entries: from(['2026-09-01']),
          settings: settings(cycle: c),
          today: today,
        );
        expect(s.reportedCycleDays, c);
        expect(s.prediction!.cycleDays, c);
      }
    });

    test('an impossible bleed length yields no ovulation, and no crash', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-09-01'], bleed: 30),
        settings: settings(cycle: 21, bleed: 30),
        today: today,
      );
      expect(s.ovulationDayOfCycle, isNull);
      expect(s.ovulationDate, isNull);
    });

    test('a recordable but unusual bleed length still works', () {
      for (final b in [1, 7, 8, 14, 20]) {
        final s = CycleSnapshot.build(
          entries: from(['2026-09-01'], bleed: b),
          settings: settings(bleed: b),
          today: today,
        );
        expect(s.ovulationDayOfCycle, isNotNull, reason: 'bleed $b');
        expect(s.ovulationDayOfCycle!, greaterThan(b), reason: 'bleed $b');
      }
    });

    test('garbage types do not crash the builder', () {
      for (final junk in [null, 'abc', true, [], {}]) {
        expect(
          () => CycleSnapshot.build(
            entries: from(['2026-09-01']),
            settings: {'days_between_period': junk, 'length_of_period': junk},
            today: today,
          ),
          returnsNormally,
          reason: '$junk',
        );
      }
    });
  });

  group('ISSUE 9 — long absence has its own state', () {
    test('a brand new user and a long absence are distinguishable', () {
      final fresh = CycleSnapshot.build(
        entries: const [],
        settings: settings(),
        today: today,
      );
      final absent = CycleSnapshot.build(
        entries: from(['2026-01-01']),
        settings: settings(),
        today: today,
      );

      // This is the distinction the engine could not previously make: both
      // produced the same confident countdown.
      expect(fresh.daysSinceLastPeriod, isNull);
      expect(absent.daysSinceLastPeriod, 266);
      // noHistory now, distinct from noPrediction (which means there IS
      // history but no justifiable cycle length).
      expect(fresh.state, PredictionState.noHistory);
      expect(absent.cyclesRolledForward, greaterThan(8));
    });

    test('no threshold is set, so the state is never entered on its own', () {
      expect(CycleSnapshot.longAbsenceThresholdDays, isNull,
          reason: 'the number is a clinical decision, not ours');
      final s = CycleSnapshot.build(
        entries: from(['2026-01-01']),
        settings: settings(),
        today: today,
      );
      expect(s.state, isNot(PredictionState.longAbsence));
    });

    test('supplying a threshold as configuration switches the state on', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-01-01']),
        settings: settings(),
        today: today,
        longAbsenceThreshold: 90,
      );
      expect(s.state, PredictionState.longAbsence);
    });

    test('and a recent period does not trip it', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-09-01']),
        settings: settings(),
        today: today,
        longAbsenceThreshold: 90,
      );
      expect(s.state, isNot(PredictionState.longAbsence));
    });
  });

  group('INVARIANT 7 — nothing active when there is no prediction', () {
    test('noPrediction allows no reminders', () {
      final s = CycleSnapshot.build(
        entries: const [],
        settings: settings(),
        today: today,
      );
      expect(s.prediction, isNull);
      expect(s.state, PredictionState.noHistory);
      expect(s.allowsReminders, isFalse);
      expect(s.hasConfidentDate, isFalse);
      expect(s.isMeasured, isFalse);
      expect(s.expectedDate, isNull);
      expect(s.ovulationDate, isNull);
    });

    test('longAbsence allows no reminders either', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-01-01']),
        settings: settings(),
        today: today,
        longAbsenceThreshold: 90,
      );
      expect(s.allowsReminders, isFalse);
      expect(s.hasConfidentDate, isFalse);
    });

    test('a normal prediction does allow them', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-07-02', '2026-08-01', '2026-08-29']),
        settings: settings(),
        today: today,
      );
      expect(s.allowsReminders, isTrue);
    });
  });

  group('INVARIANT 6 — no confident date without evidence', () {
    test('insufficient history never claims one', () {
      final cases = <String, List<String>>{
        'one period': ['2026-08-29'],
        'one interval': ['2026-08-01', '2026-08-29'],
        'an excluded interval': ['2026-07-02', '2026-08-29'],
      };
      cases.forEach((label, isos) {
        final s = CycleSnapshot.build(
          entries: from(isos),
          settings: settings(),
          today: today,
        );
        expect(s.state, PredictionState.insufficientHistory, reason: label);
        expect(s.hasConfidentDate, isFalse, reason: label);
        expect(s.prediction!.hasWindow, isTrue, reason: label);
      });
    });

    test('two clean intervals do earn one', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-07-02', '2026-08-01', '2026-08-29']),
        settings: settings(),
        today: today,
      );
      expect(s.state, PredictionState.measuredRegular);
      expect(s.hasConfidentDate, isTrue);
    });
  });

  group('INVARIANT 4 — edits recompute deterministically', () {
    test('adding, deleting and re-adding returns the same numbers', () {
      final base = ['2026-07-02', '2026-08-01', '2026-08-29'];
      CycleSnapshot snap(List<String> isos) => CycleSnapshot.build(
            entries: from(isos),
            settings: settings(),
            today: today,
          );

      final before = snap(base);
      final deleted = snap(['2026-07-02', '2026-08-29']);
      final restored = snap(base);

      expect(deleted.expectedDate, isNot(before.expectedDate));
      expect(restored.expectedDate, before.expectedDate);
      expect(restored.stats.averageCycleDays, before.stats.averageCycleDays);
      expect(restored.state, before.state);
    });

    test('an older period added later does not drag the anchor back', () {
      final s = CycleSnapshot.build(
        entries: from(['2026-06-04', '2026-07-02', '2026-08-01', '2026-08-29']),
        settings: settings(),
        today: today,
      );
      expect(s.stats.canonicalLastStart, DateTime(2026, 8, 29));
    });
  });

  group('the legacy server path goes through the same gate', () {
    test('a usable server payload produces a prediction', () {
      final s = CycleSnapshot.fromLegacyMap({
        'period_start_from': '2026-09-26',
        'period_start_to': '2026-09-26',
        'days_between_period': 28,
        'length_of_period': 5,
        'anomalies': 'Regular',
      }, today: today);

      expect(s.prediction, isNotNull);
      expect(s.expectedDate, DateTime(2026, 9, 26));
      expect(s.ovulationDayOfCycle, 14);
      // It never claims to be measured by this engine.
      expect(s.prediction!.isMeasured, isFalse);
      expect(s.state, PredictionState.insufficientHistory);
    });

    test('a server payload that would have crashed the calendar is safe', () {
      // cycle 21 with a 25-day bleed. The DATE is still predictable — the
      // server gave a window and a supported cycle length. What is not
      // predictable is ovulation, which is where the old code threw. The
      // band simply does not appear.
      final s = CycleSnapshot.fromLegacyMap({
        'period_start_from': '2026-09-26',
        'period_start_to': '2026-09-26',
        'days_between_period': 21,
        'length_of_period': 25,
        'anomalies': 'Regular',
      }, today: today);

      expect(s.prediction, isNotNull);
      expect(s.expectedDate, DateTime(2026, 9, 26));
      expect(s.ovulationDayOfCycle, isNull);
      expect(s.ovulationDate, isNull);
    });

    test('a server cycle length outside the supported range declines', () {
      final s = CycleSnapshot.fromLegacyMap({
        'period_start_from': '2026-09-26',
        'period_start_to': '2026-09-26',
        'days_between_period': 0,
        'length_of_period': 5,
      }, today: today);

      expect(s.prediction, isNull);
      expect(s.state, PredictionState.noPrediction);
    });

    test('an unparseable payload declines rather than throwing', () {
      expect(
        () => CycleSnapshot.fromLegacyMap(
            {'period_start_from': 'not a date'}, today: today),
        returnsNormally,
      );
      expect(
        CycleSnapshot.fromLegacyMap({'period_start_from': 'not a date'},
                today: today)
            .prediction,
        isNull,
      );
    });
  });
}
