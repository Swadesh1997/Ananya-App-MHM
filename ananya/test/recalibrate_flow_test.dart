import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/screens/process/unlock_process2.dart';

/// "Re-calibrate prediction" edits her answers; it does not reset them.
///
/// The tracker has two buttons. "Log new period" runs the short flow, which
/// merges. "Re-calibrate prediction" runs the full five-step questionnaire,
/// which writes *every* field at the end — and it started from the blank
/// defaults, so each step skipped wrote a default over a real answer: step 2
/// reset her cycle to 28 days and her period to 5, step 1 declared her
/// regular, step 4 said she takes no birth control, and step 5 arrived with
/// "No health issues" ticked, quietly dropping a PCOS report and the wider
/// prediction window that depends on it.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('the flow loads her answers before asking anything', () {
    test('step 1 is where it happens — it heads the whole questionnaire', () {
      final p1 = read('lib/screens/process/unlock_process1.dart');
      expect(p1, contains('hydrateFrom'));
      expect(p1, contains('LocalPeriodStore.readSettings'));
    });

    test('unconditionally, because first setup simply finds nothing', () {
      // No updatePeriod flag to gate on here: this screen is both the start
      // of setup and the start of re-calibrate, and the difference between
      // them is whether anything is stored.
      final p1 = read('lib/screens/process/unlock_process1.dart');
      expect(p1, contains('_restoreSettings();'));
      expect(p1.contains('if (widget.updatePeriod)'), isFalse);
    });

    test('the Update-my-cycle-details button really does enter at step 1', () {
      final card = read('lib/widgets/period_cycle_information.dart');
      final at = card.indexOf('update_my_cycle_details');
      expect(at, greaterThan(-1), reason: 'the button is gone');
      expect(card.lastIndexOf("'/unlock-process/1'", at), greaterThan(-1));
    });
  });

  group('step 2 shows her what she is changing', () {
    Widget harness(PeriodState state) => ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const UnlockProcess2(),
            routes: {'/unlock-process/3': (_) => const Scaffold()},
          ),
        );

    testWidgets('pre-filled when she has answered before', (tester) async {
      await tester.pumpWidget(harness(PeriodState()..hydrateFrom({
            'days_between_period': 31,
            'length_of_period': 6,
          })));
      await tester.pumpAndSettle();

      expect(find.text('31'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('blank on first setup — 28 must not look like advice',
        (tester) async {
      await tester.pumpWidget(harness(PeriodState()));
      await tester.pumpAndSettle();

      expect(find.text('28'), findsNothing);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('skipping the step keeps her values, not the defaults',
        (tester) async {
      final state = PeriodState()..hydrateFrom({
        'days_between_period': 31,
        'length_of_period': 6,
      });
      await tester.pumpWidget(harness(state));
      await tester.pumpAndSettle();

      // "I do not know" leaves without saving anything.
      await tester.tap(find.text("I do not know"));
      await tester.pumpAndSettle();

      expect(state.daysBetweenPeriod, 31);
      expect(state.lengthOfPeriod, 6);
    });

    testWidgets('editing one box does not disturb the other', (tester) async {
      final state = PeriodState()..hydrateFrom({
        'days_between_period': 31,
        'length_of_period': 6,
      });
      await tester.pumpWidget(harness(state));
      await tester.pumpAndSettle();

      await tester.enterText(find.text('31'), '29');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(state.daysBetweenPeriod, 29);
      expect(state.lengthOfPeriod, 6);
    });
  });

  group('hasStoredAnswers', () {
    test('false until something is actually loaded', () {
      expect(PeriodState().hasStoredAnswers, isFalse);
      expect((PeriodState()..hydrateFrom(null)).hasStoredAnswers, isFalse);
      expect((PeriodState()..hydrateFrom({})).hasStoredAnswers, isFalse);
    });

    test('true once it is', () {
      final state = PeriodState()..hydrateFrom({'days_between_period': 30});
      expect(state.hasStoredAnswers, isTrue);
    });
  });
}
