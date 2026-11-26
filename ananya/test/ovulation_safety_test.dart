import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/period_history_service.dart';

/// Ovulation is either a valid day inside the cycle, or nothing.
///
/// It used to throw. `clamp` raises ArgumentError when its lower bound
/// exceeds its upper one, which is every pair where the bleed reaches within
/// a day of the cycle length — 779 of the 2116 combinations between 0 and 45.
/// The calendar called it from inside build() with values read straight out
/// of storage, so a signup typo stopped the home screen rendering. It also
/// returned day 14 for cycles shorter than 8, placing ovulation outside the
/// cycle it was meant to sit in.
void main() {
  group('INVARIANT 5 — null, or inside the cycle. Never anything else', () {
    test('no pair from 0..60 x 0..60 throws', () {
      var pairs = 0;
      for (var cycle = 0; cycle <= 60; cycle++) {
        for (var bleed = 0; bleed <= 60; bleed++) {
          pairs++;
          expect(
            () => PeriodHistoryService.ovulationDayOfCycle(cycle,
                bleedDays: bleed),
            returnsNormally,
            reason: 'cycle $cycle, bleed $bleed',
          );
        }
      }
      expect(pairs, 61 * 61);
    });

    test('a returned day is never below 1 and never above the cycle', () {
      for (var cycle = 0; cycle <= 60; cycle++) {
        for (var bleed = 0; bleed <= 60; bleed++) {
          final day = PeriodHistoryService.ovulationDayOfCycle(cycle,
              bleedDays: bleed);
          if (day == null) continue;
          expect(day, greaterThanOrEqualTo(1), reason: 'cycle $cycle');
          expect(day, lessThanOrEqualTo(cycle), reason: 'cycle $cycle');
        }
      }
    });

    test('a returned day is never during the bleeding', () {
      for (var cycle = 0; cycle <= 60; cycle++) {
        for (var bleed = 0; bleed <= 60; bleed++) {
          final day = PeriodHistoryService.ovulationDayOfCycle(cycle,
              bleedDays: bleed);
          if (day == null) continue;
          expect(day, greaterThan(bleed), reason: 'cycle $cycle bleed $bleed');
        }
      }
    });

    test('and never on the first day of the next period', () {
      for (var cycle = 15; cycle <= 60; cycle++) {
        final day = PeriodHistoryService.ovulationDayOfCycle(cycle);
        expect(day, isNotNull);
        expect(day!, lessThan(cycle));
      }
    });
  });

  group('when it declines', () {
    test('a cycle outside the supported range', () {
      for (final c in [0, 1, 7, 8, 14, 61, 100, -1]) {
        expect(PeriodHistoryService.ovulationDayOfCycle(c), isNull,
            reason: 'cycle $c');
      }
    });

    test('a bleed of zero days or fewer', () {
      for (final b in [0, -1, -30]) {
        expect(PeriodHistoryService.ovulationDayOfCycle(28, bleedDays: b),
            isNull,
            reason: 'bleed $b');
      }
    });

    test('a bleed that leaves no room inside the cycle', () {
      // The exact boundary: bleed <= cycle - 2 is usable, anything more is not.
      expect(
          PeriodHistoryService.ovulationDayOfCycle(28, bleedDays: 26), 27);
      expect(PeriodHistoryService.ovulationDayOfCycle(28, bleedDays: 27),
          isNull);
      expect(PeriodHistoryService.ovulationDayOfCycle(28, bleedDays: 30),
          isNull);
      expect(PeriodHistoryService.ovulationDayOfCycle(21, bleedDays: 20),
          isNull);
    });
  });

  group('the cases that used to crash the home screen', () {
    test('every one of them now returns null', () {
      const crashers = [
        [21, 20],
        [21, 21],
        [21, 25],
        [28, 30],
        [28, 27],
        [15, 20],
        [20, 19],
      ];
      for (final pair in crashers) {
        expect(
          PeriodHistoryService.ovulationDayOfCycle(pair[0],
              bleedDays: pair[1]),
          isNull,
          reason: 'cycle ${pair[0]} bleed ${pair[1]}',
        );
      }
    });
  });

  group('the ordinary cases still work', () {
    test('counted back from the next period, not the midpoint', () {
      expect(PeriodHistoryService.ovulationDayOfCycle(28), 14);
      expect(PeriodHistoryService.ovulationDayOfCycle(35), 21);
      expect(PeriodHistoryService.ovulationDayOfCycle(21), 7);
    });

    test('bleed lengths that are abnormal but recordable still compute', () {
      // Section 13: historical values may be abnormal and must remain
      // recordable. They must not crash, and they must not silently change.
      for (final b in [1, 7, 8, 14, 20]) {
        final day =
            PeriodHistoryService.ovulationDayOfCycle(28, bleedDays: b);
        expect(day, isNotNull, reason: 'bleed $b in a 28-day cycle');
        expect(day!, greaterThan(b));
      }
      // 30 days of bleeding in a 28-day cycle is arithmetically impossible,
      // not merely unusual.
      expect(PeriodHistoryService.ovulationDayOfCycle(28, bleedDays: 30),
          isNull);
    });
  });

  group('supported ranges', () {
    test('cycle', () {
      for (final c in [15, 28, 60]) {
        expect(PeriodHistoryService.isSupportedCycle(c), isTrue, reason: '$c');
      }
      for (final c in [0, 1, 7, 8, 14, 61, 100, -1]) {
        expect(PeriodHistoryService.isSupportedCycle(c), isFalse, reason: '$c');
      }
      expect(PeriodHistoryService.isSupportedCycle(null), isFalse);
    });

    test('bleed, recordable on its own terms', () {
      // Recordability is now independent of whether ovulation can be
      // estimated from it. 27 or 28 days inside a 28-day cycle is storable;
      // it simply yields no ovulation day. Tying the two together refused a
      // real observation because of an estimate about something else.
      for (final b in [1, 7, 8, 20, 27, 28, 30, 60]) {
        expect(PeriodHistoryService.isRecordableBleed(b), isTrue, reason: '$b');
      }
      for (final b in [0, -1, 61, 100]) {
        expect(PeriodHistoryService.isRecordableBleed(b), isFalse, reason: '$b');
      }
      expect(PeriodHistoryService.isRecordableBleed(null), isFalse);
    });

    test('ovulation estimability is a separate question', () {
      expect(
          PeriodHistoryService.canEstimateOvulation(26, cycleDays: 28), isTrue);
      expect(PeriodHistoryService.canEstimateOvulation(27, cycleDays: 28),
          isFalse);
      expect(PeriodHistoryService.canEstimateOvulation(5, cycleDays: 7),
          isFalse);
      expect(PeriodHistoryService.canEstimateOvulation(5, cycleDays: null),
          isFalse);
    });
  });
}
