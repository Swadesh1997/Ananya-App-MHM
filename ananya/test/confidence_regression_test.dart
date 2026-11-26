import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/period_history_service.dart';

/// Discarding an observation must never make the app more sure of itself.
///
/// Both filters remove LONG intervals, so what survives an alternating
/// history is its short half — which by construction has no spread at all.
/// A 25/50 pattern was therefore reported as a flawless 25-day cycle with a
/// single confident date and no window, and the same happened to 30/55,
/// 28/56 and every N/2N pattern from N=23 upward. The population this app is
/// built for — adolescents, and anyone with PCOS — is exactly the population
/// whose histories look like that.
///
/// The centre of the prediction is unchanged by all of this. What changed is
/// that the app no longer claims certainty it filtered its way into.
void main() {
  final today = DateTime(2026, 9, 24);

  List<PeriodEntry> fromGaps(List<int> gaps, {int bleed = 5}) {
    final dates = <DateTime>[DateTime(2026, 8, 29)];
    for (final g in gaps.reversed) {
      dates.insert(0, dates.first.subtract(Duration(days: g)));
    }
    return [
      for (var i = 0; i < dates.length; i++)
        PeriodEntry(
          start: dates[i],
          lengthOfPeriod: bleed,
          daysSincePrevious:
              i == 0 ? null : dates[i].difference(dates[i - 1]).inDays,
        ),
    ];
  }

  CycleStats stats(List<int> gaps, {int? reported = 28}) =>
      PeriodHistoryService.statsFrom(fromGaps(gaps),
          reportedCycleDays: reported);

  CycleSnapshot snap(List<int> gaps) => CycleSnapshot.build(
        entries: fromGaps(gaps),
        settings: const {
          'days_between_period': 28,
          'length_of_period': 5,
          'is_period_regular': true,
        },
        today: today,
      );

  group('ISSUE 1 — alternating short/long histories', () {
    // Every N from 20 to 35, paired with its double. Audit 2 found the cliff
    // at N=23, where 2N first reaches the 45-day floor; from N=31 upward the
    // plausible-range filter removes the long half instead. Both routes ended
    // in the same place: a flawless short cycle.
    for (var n = 20; n <= 35; n++) {
      test('$n / ${n * 2} alternating is never reported as regular', () {
        final s = stats([n, n * 2, n, n * 2]);
        expect(s.isRegular, isNot(isTrue),
            reason: 'gaps $n/${n * 2} claimed regular');
      });
    }

    test('the specific cases audit 2 found', () {
      for (final gaps in [
        [25, 50, 25, 50],
        [30, 55, 30, 55],
        [28, 55, 55, 28],
        [23, 46, 23, 46],
        [28, 56, 28, 56],
        [31, 62, 31, 62],
        [35, 70, 35, 70],
      ]) {
        final s = snap(gaps);
        expect(s.stats.isRegular, isNot(isTrue), reason: '$gaps');
        expect(s.hasConfidentDate, isFalse, reason: '$gaps');
        expect(s.prediction!.hasWindow, isTrue, reason: '$gaps');
        expect(s.state, PredictionState.insufficientHistory, reason: '$gaps');
      }
    });

    test('the centre of the forecast is still the surviving intervals', () {
      // Confidence is withheld; the estimate itself is not thrown away.
      final s = snap([25, 50, 25, 50]);
      expect(s.prediction!.cycleDays, 25);
    });

    test('genuinely varying short cycles are untouched', () {
      // 20/40 survives both filters — 40 is under the floor — and must still
      // read as irregular rather than as anything else.
      final s = stats([20, 40, 20, 40]);
      expect(s.excludedObservations, 0);
      expect(s.isRegular, isFalse);
      expect(s.averageCycleDays, 30);
    });
  });

  group('ISSUE 6 — a rejected missed log withholds confidence', () {
    test('28,28,56,28,28 is not a flawless 28-day cycle', () {
      final s = snap([28, 28, 56, 28, 28]);
      expect(s.stats.excludedObservations, 1);
      expect(s.stats.isRegular, isNull);
      expect(s.hasConfidentDate, isFalse);
      // The surviving 28-day intervals still centre the prediction.
      expect(s.prediction!.cycleDays, 28);
    });

    test('but an untouched history still earns its confidence', () {
      final s = snap([28, 30, 28]);
      expect(s.stats.excludedObservations, 0);
      expect(s.stats.isRegular, isTrue);
      expect(s.hasConfidentDate, isTrue);
    });
  });

  group('ISSUE 7 — an out-of-range interval is remembered', () {
    test('28,28,62,28,28 does not become a confident 28-day history', () {
      final s = snap([28, 28, 62, 28, 28]);
      expect(s.stats.excludedObservations, 1,
          reason: '62 is outside the plausible range and must still count');
      expect(s.stats.isRegular, isNull);
      expect(s.hasConfidentDate, isFalse);
      expect(s.prediction!.cycleDays, 28);
    });

    test('the plausible-range bound itself is unchanged', () {
      expect(PeriodHistoryService.maxPlausibleCycle, 60);
      expect(PeriodHistoryService.minPlausibleCycle, 15);
    });
  });

  group('ISSUE 5 — one interval is not a measurement', () {
    for (final gap in [15, 20, 28, 35, 40, 48]) {
      test('a single $gap-day interval claims no measured regularity', () {
        final s = snap([gap]);
        expect(s.stats.usableGaps, 1);
        expect(s.stats.hasEnoughForMeasurement, isFalse);
        expect(s.stats.isRegular, isNull);
        expect(s.hasConfidentDate, isFalse,
            reason: 'one interval cannot support an exact day');
        expect(s.prediction!.hasWindow, isTrue);
        expect(s.state, PredictionState.insufficientHistory);
      });
    }

    test('zero intervals fall back to the signup cycle', () {
      final s = snap([]);
      expect(s.stats.usableGaps, 0);
      expect(s.prediction!.cycleDays, 28);
      expect(s.prediction!.isMeasured, isFalse);
      expect(s.hasConfidentDate, isFalse);
    });

    test('two clean intervals restore it', () {
      final s = snap([28, 29]);
      expect(s.stats.hasEnoughForMeasurement, isTrue);
      expect(s.stats.isRegular, isTrue);
      expect(s.hasConfidentDate, isTrue);
    });

    test('basedOnCycles counts the surviving chain, not every episode', () {
      final s = snap([28, 56, 28]);
      // Four episodes, but one interval was rejected.
      expect(s.stats.cycleCount, 4);
      expect(s.stats.usableGaps, 2);
      expect(s.prediction!.basedOnCycles, 3);
    });
  });

  group('ISSUE 8 — confidence never grows with the size of the anomaly', () {
    // 28,28,28,28,X for a rising X. Audit 2 found this non-monotonic: X=37
    // made her irregular, X=50 made her REGULAR with zero spread, because
    // past 49 days the interval stopped being an outlier and became
    // invisible. A worse anomaly bought more confidence.
    const xs = [35, 36, 37, 38, 39, 40, 41, 42, 45, 50];

    test('confidence never RISES as the anomaly grows', () {
      // The property section 8 asks for. Once the app has stopped offering an
      // exact day, a bigger anomaly must not bring it back.
      //
      // Before this pass it did: X=37 made her irregular (spread 5) while
      // X=50 made her REGULAR with zero spread, because past 49 days the
      // interval stopped being an outlier and became invisible to the
      // measurement entirely.
      var confidenceLost = false;
      final trace = <String>[];
      for (final x in xs) {
        final s = snap([28, 28, 28, 28, x]);
        trace.add('X=$x confident=${s.hasConfidentDate}');
        if (!s.hasConfidentDate) {
          confidenceLost = true;
        } else {
          expect(confidenceLost, isFalse,
              reason: 'confidence returned at X=$x: ${trace.join(", ")}');
        }
      }
      expect(confidenceLost, isTrue,
          reason: 'some X in this range should cost confidence');
    });

    test('the largest anomaly is no more confident than the smallest', () {
      final small = snap([28, 28, 28, 28, 35]);
      final large = snap([28, 28, 28, 28, 50]);

      // The 50 is filtered out; the 35 is not. The filtered one must not end
      // up the more confident of the two, which is exactly what it was.
      expect(large.stats.excludedObservations, 1);
      expect(small.stats.excludedObservations, 0);
      expect(large.hasConfidentDate, isFalse);
      expect(large.prediction!.hasWindow, isTrue);
      expect(large.stats.isRegular, isNull);
    });
    test('the average and spread definitions are unchanged by this pass', () {
      // Section 8: document, do not redefine. The trimmed average still
      // ignores the outlier; the spread still does not.
      final s = stats([28, 28, 28, 28, 40]);
      expect(s.averageCycleDays, 28, reason: 'trimmed average');
      expect(s.varianceDays, 6, reason: 'untrimmed spread');
    });

    test('order of the anomaly does not matter', () {
      for (final x in xs) {
        final last = stats([28, 28, 28, 28, x]);
        final first = stats([x, 28, 28, 28, 28]);
        expect(last.averageCycleDays, first.averageCycleDays, reason: 'X=$x');
        expect(last.varianceDays, first.varianceDays, reason: 'X=$x');
        expect(last.isRegular, first.isRegular, reason: 'X=$x');
      }
    });
  });

  group('INVARIANT 2 — an excluded observation never narrows the window', () {
    test('across every audited history', () {
      const histories = [
        [25, 50, 25, 50],
        [30, 55, 30, 55],
        [28, 55, 55, 28],
        [28, 28, 56, 28, 28],
        [28, 28, 62, 28, 28],
        [28, 28, 28, 28, 50],
        [23, 46, 23, 46],
      ];
      for (final h in histories) {
        final s = snap(h);
        expect(s.stats.excludedObservations, greaterThan(0), reason: '$h');
        expect(s.prediction!.hasWindow, isTrue,
            reason: '$h narrowed to a single date after filtering');
      }
    });
  });

  group('clinically undecided rules are untouched', () {
    test('PCOS still widens by exactly 7 days, unchanged', () {
      expect(PeriodHistoryService.pcosMarginDays, 7);
      final s = CycleSnapshot.build(
        entries: fromGaps([28, 29]),
        settings: const {
          'days_between_period': 28,
          'length_of_period': 5,
          'is_period_regular': true,
          'health_condition': {'Polycystic Ovary Syndrome': true},
        },
        today: today,
      );
      expect(s.reportsPcos, isTrue);
      expect(s.prediction!.to.difference(s.prediction!.from).inDays ~/ 2, 7);
    });

    test('the irregular margin and luteal constant are unchanged', () {
      expect(PeriodHistoryService.irregularMarginDays, 5);
      expect(PeriodHistoryService.lutealDays, 14);
    });

    test('the 21-35 regularity range is unchanged', () {
      // A steady 33-day cycle is still regular; a steady 36-day one is not.
      expect(stats([33, 33, 33]).isRegular, isTrue);
      expect(stats([36, 36, 36]).isRegular, isFalse);
    });
  });
}
