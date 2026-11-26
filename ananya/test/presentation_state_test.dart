import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/period_history_service.dart';

/// What the app SAYS must follow from what the engine knows.
///
/// Audit 3 found the fix to the prediction window had not reached the words
/// beside it. The card printed "Irregular" for a girl who had logged one
/// period, and "based on 3 cycles · ±0 days" next to a ten-day window for an
/// alternating history whose long half had just been filtered away. Both
/// figures were derived independently of the prediction, from varianceDays
/// and from a fallback that treated "not measured" as "not regular".
///
/// Nothing here is a clinical statement. "Regular" and "Irregular" mean only
/// what CycleStats.isRegular means, which is the app's working definition and
/// is still awaiting review.
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

  CycleSnapshot snap(List<int> gaps,
          {int? threshold, DateTime? when, List<PeriodEntry>? entries}) =>
      CycleSnapshot.build(
        entries: entries ?? fromGaps(gaps),
        settings: const {
          'days_between_period': 28,
          'length_of_period': 5,
          'is_period_regular': true,
        },
        today: when ?? today,
        longAbsenceThreshold: threshold,
      );

  group('A1 — the five required states', () {
    test('brand-new user is not called irregular', () {
      final s = CycleSnapshot.build(
          entries: const [], settings: const {}, today: today);
      expect(s.state, PredictionState.noHistory);
      expect(s.isMeasured, isFalse);
    });

    test('one period is not called irregular', () {
      final s = snap([]);
      expect(s.state, PredictionState.insufficientHistory);
      expect(s.isMeasured, isFalse);
    });

    test('one usable gap is not called irregular', () {
      final s = snap([28]);
      expect(s.state, PredictionState.insufficientHistory);
      expect(s.isMeasured, isFalse);
    });

    test('a rejected gap is not called irregular', () {
      final s = snap([28, 56]);
      expect(s.stats.excludedObservations, greaterThan(0));
      expect(s.state, PredictionState.insufficientHistory);
      expect(s.isMeasured, isFalse);
    });

    test('two clean steady gaps ARE measured regular', () {
      final s = snap([28, 29]);
      expect(s.state, PredictionState.measuredRegular);
      expect(s.isMeasured, isTrue);
    });

    test('two clean varying gaps ARE measured irregular', () {
      final s = snap([22, 35, 26]);
      expect(s.state, PredictionState.measuredIrregular);
      expect(s.isMeasured, isTrue);
    });
  });

  group('A1 — the label the chip renders', () {
    test('only the two measured states use a regularity word', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('String _regularityLabel('));
      final body = fn.substring(0, fn.indexOf('\n  }'));

      expect(body, contains('case PredictionState.measuredRegular:'));
      expect(body, contains('case PredictionState.measuredIrregular:'));
      // Every other state shares the neutral label.
      for (final s in [
        'noHistory',
        'insufficientHistory',
        'longAbsence',
        'noPrediction'
      ]) {
        expect(body, contains('case PredictionState.$s:'), reason: s);
      }
      expect(body, contains('loc.not_measured_yet'));
    });

    test('the chip no longer reads the anomalies string', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      expect(src.contains("translateAnnomalies(context, widget.data"), isFalse,
          reason: 'the label must come from the snapshot state');
    });
  });

  group('A2 — the status line cannot contradict the window', () {
    // The exact histories the brief names.
    const histories = {
      '25,50,25,50': [25, 50, 25, 50],
      '28,56,28,56': [28, 56, 28, 56],
      '30,60,30,60': [30, 60, 30, 60],
      '35,55,35,55': [35, 55, 35, 55],
    };

    histories.forEach((label, gaps) {
      test('$label — text and window agree', () {
        final s = snap(gaps);
        if (s.isMeasured) {
          // A measured reading may quote a spread, and the window must be
          // consistent with it: zero spread only ever beside a single date.
          if (s.measuredSpreadDays == 0) {
            expect(s.windowHalfWidthDays, 0,
                reason: '$label printed ±0 beside a window');
          }
        } else {
          // Unmeasured: no spread and no cycle count may be printed at all.
          expect(s.measuredSpreadDays, isNull, reason: label);
          expect(s.measuredOnPeriods, isNull, reason: label);
        }
      });
    });

    test('no filtered history can ever print a spread', () {
      for (var n = 20; n <= 35; n++) {
        final s = snap([n, n * 2, n, n * 2]);
        if (s.stats.excludedObservations > 0) {
          expect(s.measuredSpreadDays, isNull, reason: '$n/${n * 2}');
          expect(s.isMeasured, isFalse, reason: '$n/${n * 2}');
        }
      }
    });

    test('the rising-anomaly series never regains a spread', () {
      // X=48 printed "±10", X=49 printed "±0" — more confident for a worse
      // anomaly, purely because it crossed the filter threshold.
      final small = snap([28, 28, 28, 28, 48]);
      final large = snap([28, 28, 28, 28, 49]);
      expect(small.measuredSpreadDays, 10);
      expect(large.measuredSpreadDays, isNull);
      expect(large.isMeasured, isFalse);
    });

    test('the status widget reads the snapshot, not varianceDays', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('Widget _buildStatusSource()'));
      final body = fn.substring(0, fn.indexOf('\n  Widget ', 10));

      expect(body, contains('widget.snapshot.isMeasured'));
      expect(body, contains('widget.snapshot.measuredSpreadDays'));
      expect(body.contains('_stats.hasMeasuredRegularity'), isFalse,
          reason: 'confidence must not be re-derived here');
    });
  });

  group('A4 — the countdown never calls a negative number "Today"', () {
    test('a window straddling today puts the expected date behind it', () {
      // 28-day cycle from 1 September, ±5 -> 24 Sep..4 Oct, expected 29 Sep.
      final s = CycleSnapshot.build(
        entries: [PeriodEntry(start: DateTime(2026, 9, 1), lengthOfPeriod: 5)],
        settings: const {'days_between_period': 28, 'length_of_period': 5},
        today: DateTime(2026, 10, 2),
      );
      expect(s.daysUntilExpected, lessThan(0));
      expect(s.isWithinWindowPastExpected, isTrue);
    });

    test('every day across a straddling window behaves coherently', () {
      for (var day = 24; day <= 31; day++) {
        final s = CycleSnapshot.build(
          entries: [
            PeriodEntry(start: DateTime(2026, 9, 1), lengthOfPeriod: 5)
          ],
          settings: const {'days_between_period': 28, 'length_of_period': 5},
          today: DateTime(2026, 9, day),
        );
        final d = s.daysUntilExpected!;
        if (d < 0) {
          expect(s.isWithinWindowPastExpected, isTrue, reason: 'Sep $day');
        }
        // The countdown and the window always agree about which side of the
        // expected date today is on.
        expect(d == 0, s.today == s.expectedDate, reason: 'Sep $day');
      }
    });

    test('a measured regular cycle has a zero-width window and cannot go '
        'negative before rolling', () {
      final s = snap([28, 28]);
      expect(s.windowHalfWidthDays, 0);
      expect(s.daysUntilExpected, greaterThanOrEqualTo(0));
    });

    test('the ring distinguishes the three cases', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      final ring = src.substring(src.indexOf('child: CycleRing('));
      // Ends at the comment that replaced the day-of-cycle pill, which is
      // the last thing inside the CycleRing call.
      final body = ring.substring(0, ring.indexOf('// No day-of-cycle pill'));

      // Comment lines are stripped first: the rationale beside the fix quotes
      // the old condition it replaced.
      final code = const LineSplitter()
          .convert(body)
          .where((l) => !l.trimLeft().startsWith('//'))
          .join(' ');

      // "Today" only when the count is exactly zero.
      expect(code, contains('daysUntil == 0'));
      expect(code, contains('loc.any_day_now'));
      expect(code.contains('daysUntil <= 0'), isFalse,
          reason: 'negative days must not share the "Today" branch');
      expect('daysUntil > 0'.allMatches(code).length, 3,
          reason: 'topLabel, value and label must each guard the same way');
    });
  });

  group('A5 — recordable bleed is independent of ovulation', () {
    for (final b in [27, 28, 30]) {
      test('cycle 28, bleed $b', () {
        expect(PeriodHistoryService.isRecordableBleed(b), isTrue,
            reason: 'must be storable');

        final s = CycleSnapshot.build(
          entries: fromGaps([28, 28], bleed: b),
          settings: {'days_between_period': 28, 'length_of_period': b},
          today: today,
        );

        // Preserved, exactly as reported.
        expect(s.stats.averageBleedDays, b);
        expect(s.reportedBleedDays, b);
        // The calendar shades what she recorded.
        expect(s.prediction!.bleedDays, b);
        // The prediction is unaffected.
        expect(s.prediction!.cycleDays, 28);
        expect(s.expectedDate, isNotNull);
        // And no ovulation is invented.
        expect(s.ovulationDayOfCycle, isNull);
        expect(s.ovulationDate, isNull);
        expect(
            PeriodHistoryService.canEstimateOvulation(b, cycleDays: 28),
            isFalse);
      });
    }

    test('the signup check no longer consults the cycle length', () {
      final src =
          File('lib/screens/process/unlock_process2.dart').readAsStringSync();
      expect(src, contains('isRecordableBleed'));
      expect(src.contains('isSupportedBleed'), isFalse);
    });
  });

  group('section 9 — the UI matrix', () {
    final matrix = <String, CycleSnapshot>{
      'A no history': CycleSnapshot.build(
          entries: const [], settings: const {}, today: today),
      'B one period': snap([]),
      'C one usable gap': snap([28]),
      'D two gaps, regular': snap([28, 29]),
      'E two gaps, irregular': snap([22, 35, 26]),
      'F filtered observation': snap([28, 28, 56, 28, 28]),
      'G long absence': snap([],
          entries: [
            PeriodEntry(start: DateTime(2026, 1, 1), lengthOfPeriod: 5)
          ],
          threshold: 90),
    };

    test('each row has exactly one state and no contradictions', () {
      matrix.forEach((label, s) {
        // A regularity word is used only where the cycle was measured.
        final usesRegularityWord = s.isMeasured;
        expect(usesRegularityWord,
            s.state == PredictionState.measuredRegular ||
                s.state == PredictionState.measuredIrregular,
            reason: label);

        // A spread is printed only where it was measured.
        if (!s.isMeasured) {
          expect(s.measuredSpreadDays, isNull, reason: label);
        }

        // A confident single date requires measured regularity.
        if (s.hasConfidentDate) {
          expect(s.state, PredictionState.measuredRegular, reason: label);
          expect(s.windowHalfWidthDays, 0, reason: label);
        }

        // Ovulation is drawn only when it exists.
        if (s.ovulationDate != null) {
          expect(s.ovulationDayOfCycle, isNotNull, reason: label);
        }

        // Reminders follow the state, not the window.
        if (s.state == PredictionState.longAbsence ||
            s.state == PredictionState.noPrediction ||
            s.state == PredictionState.noHistory) {
          expect(s.allowsReminders, isFalse, reason: label);
        }
      });
    });

    test('the seven rows are genuinely distinct states', () {
      expect(matrix['A no history']!.state, PredictionState.noHistory);
      expect(matrix['B one period']!.state,
          PredictionState.insufficientHistory);
      expect(matrix['C one usable gap']!.state,
          PredictionState.insufficientHistory);
      expect(matrix['D two gaps, regular']!.state,
          PredictionState.measuredRegular);
      expect(matrix['E two gaps, irregular']!.state,
          PredictionState.measuredIrregular);
      expect(matrix['F filtered observation']!.state,
          PredictionState.insufficientHistory);
      expect(matrix['G long absence']!.state, PredictionState.longAbsence);
    });
  });
}
