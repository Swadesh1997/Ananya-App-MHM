import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/screens/process/unlock_process2.dart';
import 'package:ananya/services/period_history_service.dart';

/// Invalid answers are refused at the keyboard, not corrected behind her back.
///
/// The two signup boxes were a bare numeric TextField with no formatter, no
/// validator and no range check. Whatever was typed was parsed and stored,
/// then used as a real cycle length — a 21-day cycle with a 25-day period was
/// accepted, written to Firestore, and passed to the calendar's ovulation
/// call, which threw and stopped the home screen rendering.
///
/// Rejecting is deliberate. Clamping would replace her answer with one she
/// never gave, which is the class of behaviour this whole pass exists to
/// remove.
void main() {
  Widget harness(PeriodState state) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UnlockProcess2(),
          routes: {'/unlock-process/3': (_) => const Scaffold()},
        ),
      );

  Future<void> type(WidgetTester tester,
      {String? cycle, String? bleed}) async {
    final boxes = find.byType(TextField);
    if (cycle != null) await tester.enterText(boxes.at(0), cycle);
    if (bleed != null) await tester.enterText(boxes.at(1), bleed);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  group('cycle length', () {
    const rejected = [0, 1, 7, 8, 14, 61, 100, -1];
    const accepted = [15, 28, 60];

    for (final c in rejected) {
      testWidgets('$c is refused and nothing is stored', (tester) async {
        final state = PeriodState();
        await tester.pumpWidget(harness(state));
        await tester.pumpAndSettle();
        await type(tester, cycle: '$c');

        expect(find.textContaining('between'), findsWidgets,
            reason: 'no validation message for $c');
        expect(state.daysBetweenPeriod, 28,
            reason: '$c must not reach PeriodState');
      });
    }

    for (final c in accepted) {
      testWidgets('$c is accepted', (tester) async {
        final state = PeriodState();
        await tester.pumpWidget(harness(state));
        await tester.pumpAndSettle();
        await type(tester, cycle: '$c');

        expect(state.daysBetweenPeriod, c);
      });
    }

    testWidgets('an empty box is still allowed — "I do not know" is valid',
        (tester) async {
      final state = PeriodState();
      await tester.pumpWidget(harness(state));
      await tester.pumpAndSettle();
      await type(tester);

      expect(state.daysBetweenPeriod, 28, reason: 'the default stands');
    });
  });

  group('bleed length, judged on its own', () {
    // Recordability is no longer tied to whether ovulation fits. A long
    // period is something she is reporting about her body; the ovulation
    // estimate is something the app would like to derive. Only the first
    // decides whether she may save it.
    for (final b in [0, -1, 61, 100]) {
      testWidgets('$b days is refused — not a recordable length',
          (tester) async {
        final state = PeriodState();
        await tester.pumpWidget(harness(state));
        await tester.pumpAndSettle();
        await type(tester, cycle: '28', bleed: '$b');

        expect(state.lengthOfPeriod, 5, reason: '$b must not be stored');
      });
    }

    for (final b in [1, 7, 8, 20, 27, 28, 30, 60]) {
      testWidgets('$b days in a 28-day cycle is stored as given',
          (tester) async {
        // 27, 28, 30 and 60 leave no room for an ovulation day in a 28-day
        // cycle. That is the ovulation estimate's problem, not hers: the
        // value is stored exactly as reported and the band simply does not
        // appear. These four were previously REFUSED at the keyboard.
        final state = PeriodState();
        await tester.pumpWidget(harness(state));
        await tester.pumpAndSettle();
        await type(tester, cycle: '28', bleed: '$b');

        expect(state.lengthOfPeriod, b);
      });
    }

    testWidgets('25 days in a 21-day cycle is now storable', (tester) async {
      // The pair that used to crash the home screen, and which the first fix
      // then refused outright. It is now saved as given; ovulation is null.
      final state = PeriodState();
      await tester.pumpWidget(harness(state));
      await tester.pumpAndSettle();
      await type(tester, cycle: '21', bleed: '25');

      expect(state.lengthOfPeriod, 25);
      expect(state.daysBetweenPeriod, 21);
      expect(
          PeriodHistoryService.ovulationDayOfCycle(21, bleedDays: 25), isNull);
    });
  });
  group('INVARIANT 1 — nothing that gets through can crash the calculation',
      () {
    test('every recordable pair is either computable or cleanly null', () {
      // The invariant changed shape when recordability was decoupled from
      // ovulation: a recordable bleed no longer guarantees an ovulation day.
      // What must hold is that the pair never throws, and that a returned day
      // is always inside the cycle and after the bleeding.
      for (var cycle = PeriodHistoryService.minSupportedCycle;
          cycle <= PeriodHistoryService.maxSupportedCycle;
          cycle++) {
        for (var bleed = 0; bleed <= 60; bleed++) {
          if (!PeriodHistoryService.isRecordableBleed(bleed)) continue;
          final day = PeriodHistoryService.ovulationDayOfCycle(cycle,
              bleedDays: bleed);
          if (day == null) {
            expect(
                PeriodHistoryService.canEstimateOvulation(bleed,
                    cycleDays: cycle),
                isFalse,
                reason: 'cycle $cycle bleed $bleed');
            continue;
          }
          expect(day, greaterThan(bleed));
          expect(day, lessThan(cycle));
        }
      }
    });

    test('and every rejected pair simply declines', () {
      for (final pair in [
        [0, 5],
        [7, 5],
        [14, 5],
        [61, 5],
        [-1, 5],
        [28, 0],
        [28, -1],
        [28, 27],
        [21, 25],
      ]) {
        expect(
          () => PeriodHistoryService.ovulationDayOfCycle(pair[0],
              bleedDays: pair[1]),
          returnsNormally,
          reason: '${pair[0]}/${pair[1]}',
        );
      }
    });
  });
}
