import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:ananya/services/period_history_service.dart';

/// The manual release check, pinned.
///
/// This is the three-step walkthrough done by hand before a release — log one
/// period, then the month before, then one more — expressed as assertions so
/// the numbers on the screen can be checked against something other than
/// arithmetic done in a hurry. It runs the same two calls the home screen
/// makes and then repeats what the cycle card does with the result, so a
/// change to either shows up here rather than on a girl's phone.
void main() {
  final fmt = DateFormat('yyyy-MM-dd');

  /// Fixed, because "days left" is measured from it.
  final today = DateTime(2026, 9, 23);

  /// What she answered at signup: regular, 28-day cycle, 5-day period, no
  /// health conditions. These are the fallbacks until enough is logged to
  /// measure instead.
  const signupGap = 28;
  const signupBleed = 5;

  /// Runs the real engine over a set of logged start dates and returns what
  /// the card would display.
  ({
    int? measuredCycle,
    bool? regular,
    int basedOnCycles,
    String expected,
    int daysUntil,
    int cycleUsed,
    String shadedFrom,
    String shadedTo,
    String? ovulation,
    bool hasWindow,
  }) card(
    List<String> isoStarts, {
    bool selfReportedRegular = true,
    bool pcos = false,
  }) {
    final sorted = isoStarts.map(DateTime.parse).toList()..sort();
    final entries = <PeriodEntry>[
      for (var i = 0; i < sorted.length; i++)
        PeriodEntry(
          start: sorted[i],
          lengthOfPeriod: signupBleed,
          daysSincePrevious:
              i == 0 ? null : sorted[i].difference(sorted[i - 1]).inDays,
        ),
    ];

    final stats = PeriodHistoryService.statsFrom(entries);
    final prediction = PeriodHistoryService.predictNext(
      lastStart: sorted.last,
      fallbackCycleDays: signupGap,
      fallbackBleedDays: signupBleed,
      selfReportedRegular: selfReportedRegular,
      stats: stats,
      reportsPcos: pcos,
    );

    // The card rolls the window forward to the cycle that has not started yet.
    var from = prediction.from, to = prediction.to;
    while (to.isBefore(today)) {
      from = from.add(Duration(days: prediction.cycleDays));
      to = to.add(Duration(days: prediction.cycleDays));
    }
    final expected = from.add(Duration(days: to.difference(from).inDays ~/ 2));
    // Nullable now: the engine declines rather than throwing when no valid
    // day exists. Every cycle in this walkthrough is supported, so it is
    // never null here.
    final ovDay = PeriodHistoryService.ovulationDayOfCycle(
      prediction.cycleDays,
      bleedDays: prediction.bleedDays,
    );
    final ovOffset = ovDay == null ? null : ovDay - 1;

    return (
      measuredCycle: stats.averageCycleDays,
      regular: stats.isRegular,
      basedOnCycles: prediction.basedOnCycles,
      expected: fmt.format(expected),
      daysUntil: expected.difference(today).inDays,
      cycleUsed: prediction.cycleDays,
      shadedFrom: fmt.format(expected),
      shadedTo: fmt
          .format(expected.add(Duration(days: prediction.bleedDays - 1))),
      ovulation: ovOffset == null
          ? null
          : fmt.format(expected.add(Duration(days: ovOffset))),
      hasWindow: prediction.hasWindow,
    );
  }

  group('step 1 — one period logged (29 August)', () {
    final r = card(['2026-08-29']);

    test('nothing is measured yet, so her signup answer is used', () {
      expect(r.measuredCycle, isNull, reason: 'one date gives no gap');
      expect(r.basedOnCycles, 0, reason: 'the card must not claim a measurement');
      expect(r.cycleUsed, 28);
    });

    test('next period 26 September, 3 days away', () {
      expect(r.expected, '2026-09-26');
      expect(r.daysUntil, 3);
    });

    test('a range, not a single date — nothing has been measured yet', () {
      // This expected a single date on the strength of her signup answer.
      // One logged period gives zero measured intervals, so the app no
      // longer names an exact day. The date it centres on is unchanged.
      expect(r.hasWindow, isTrue);
    });

    test('period shaded 26-30 September, ovulation 9 October', () {
      expect(r.shadedFrom, '2026-09-26');
      expect(r.shadedTo, '2026-09-30');
      // Day 14 of the 28-day cycle that starts on 26 September, leaving the
      // 14 luteal days before the one after it.
      expect(r.ovulation, '2026-10-09');
    });
  });

  group('step 2 — plus 1 August', () {
    final r = card(['2026-08-29', '2026-08-01']);

    test('one real gap, so the figure is now measured', () {
      expect(r.measuredCycle, 28);
      expect(r.basedOnCycles, 2);
    });

    test('the date does not move — her cycle really is 28 days', () {
      // The point of this step: the prediction stops being a guess without
      // the answer changing, which is what it should look like when the
      // signup answer was right.
      expect(r.expected, '2026-09-26');
      expect(r.daysUntil, 3);
    });

    test('regularity still unknown — two gaps are needed to judge it', () {
      expect(r.regular, isNull);
    });
  });

  group('step 3 — plus 2 July', () {
    final r = card(['2026-08-29', '2026-08-01', '2026-07-02']);

    test('two gaps (30 and 28) average to 29', () {
      expect(r.measuredCycle, 29);
      expect(r.basedOnCycles, 3);
    });

    test('the forecast moves a day later: 27 September, 4 days away', () {
      expect(r.expected, '2026-09-27');
      expect(r.daysUntil, 4);
    });

    test('her cycles are now judged regular from the logs themselves', () {
      expect(r.regular, isTrue);
      expect(r.hasWindow, isFalse);
    });

    test('period 27 September to 1 October, ovulation 11 October', () {
      expect(r.shadedFrom, '2026-09-27');
      expect(r.shadedTo, '2026-10-01');
      // Day 15 of a 29-day cycle — the luteal phase stays at 14 days, so a
      // longer cycle moves ovulation later rather than lengthening the wait
      // after it.
      expect(r.ovulation, '2026-10-11');
    });
  });

  group('the same three logs, for someone who reported PCOS', () {
    // Worth pinning separately: this is the one input that changes a confident
    // date into an honest range, and it is also the value the short logging
    // flow used to discard.
    final r = card(['2026-08-29', '2026-08-01', '2026-07-02'], pcos: true);

    test('a range is shown even though the logs look regular', () {
      expect(r.hasWindow, isTrue);
    });

    test('centred on the same day the non-PCOS forecast gives', () {
      expect(r.expected, '2026-09-27');
      expect(r.daysUntil, 4);
    });
  });

  group('adding an earlier period does not drag the forecast back', () {
    // The walkthrough does exactly this: step 2 and step 3 log dates older
    // than the one already stored, and each log rewrites last_period_start in
    // period/latest. If the prediction anchored on that field it would jump
    // back to July and count down to a period two months gone. It anchors on
    // the newest real episode in the history instead; this is what proves it.
    final sorted = ['2026-07-02', '2026-08-01', '2026-08-29']
        .map(DateTime.parse)
        .toList();
    final entries = <PeriodEntry>[
      for (var i = 0; i < sorted.length; i++)
        PeriodEntry(
          start: sorted[i],
          lengthOfPeriod: 5,
          daysSincePrevious:
              i == 0 ? null : sorted[i].difference(sorted[i - 1]).inDays,
        ),
    ];

    final prediction = PeriodHistoryService.predictNext(
      // The stale settings value, as it is after logging 2 July last.
      lastStart: DateTime(2026, 7, 2),
      fallbackCycleDays: signupGap,
      fallbackBleedDays: signupBleed,
      selfReportedRegular: true,
      stats: PeriodHistoryService.statsFrom(entries),
    );

    test('it still forecasts from 29 August', () {
      expect(fmt.format(prediction.from), '2026-09-27');
    });
  });
}
