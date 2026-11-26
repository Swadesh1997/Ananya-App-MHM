import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/screens/process/period_length_page.dart';

/// "How long did this period last?" — asked every time a period is logged.
///
/// It used to be asked once, at signup, and then treated as a fact about the
/// user rather than about a period. Every logged entry carried the same
/// number, so the average bleed length could never move off the signup answer
/// however much her actual periods varied.
void main() {
  String read(String path) => File(path).readAsStringSync();

  Widget harness(PeriodState state) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PeriodLengthPage(),
          // The health step is the real destination; a stub is enough to
          // prove Continue leaves with the right value recorded.
          routes: {'/unlock-process/5': (_) => const Scaffold()},
        ),
      );
  group('the screen', () {
    testWidgets('opens with her usual length already chosen', (tester) async {
      // The common case is "this month was like the others", and that should
      // cost one tap on Continue, not a decision.
      await tester.pumpWidget(harness(PeriodState()..hydrateFrom({
            'length_of_period': 6,
          })));
      await tester.pumpAndSettle();

      expect(find.text('6'), findsOneWidget);
      expect(find.textContaining('Your usual'), findsOneWidget);
    });

    testWidgets('offers 1 to 10 days', (tester) async {
      await tester.pumpWidget(harness(PeriodState()));
      await tester.pumpAndSettle();

      for (final days in ['1', '2', '5', '7', '10']) {
        expect(find.text(days), findsWidgets, reason: '$days missing');
      }
      expect(find.text('11'), findsNothing);
    });

    testWidgets('tapping a different length records that one', (tester) async {
      final state = PeriodState()..hydrateFrom({'length_of_period': 5});
      await tester.pumpWidget(harness(state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(state.lengthOfPeriod, 8);
    });

    testWidgets('continuing without touching it keeps her usual',
        (tester) async {
      final state = PeriodState()..hydrateFrom({'length_of_period': 7});
      await tester.pumpWidget(harness(state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(state.lengthOfPeriod, 7);
    });

    testWidgets('a stored length outside the offered range still opens',
        (tester) async {
      // Signup takes a typed number, so 14 or 0 can be stored. The screen has
      // to show something sensible rather than no selection at all.
      await tester.pumpWidget(harness(PeriodState()..hydrateFrom({
            'length_of_period': 14,
          })));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('10'), findsWidgets);
    });
  });

  group('where it sits in the flow', () {
    test('after the date, before the health conditions', () {
      final p3 = read('lib/screens/process/unlock_process3.dart');
      expect(p3, contains("Navigator.pushNamed(context, '/period-length')"));

      final page = read('lib/screens/process/period_length_page.dart');
      expect(page, contains("'/unlock-process/5'"));
    });

    test('every exit from the date step goes through it', () {
      // "I do not know" is a second way off that screen; routing it straight
      // to the health step would skip the question for exactly the users
      // least likely to have a usual length worth reusing.
      final p3 = read('lib/screens/process/unlock_process3.dart');
      expect('Navigator.pushNamed'.allMatches(p3).length, 2,
          reason: 'both exits must go through _goNext');
    });

    test('the short flow now says three steps, not two', () {
      final p3 = read('lib/screens/process/unlock_process3.dart');
      final p5 = read('lib/screens/process/unlock_process5.dart');
      expect(p3, contains("'1/3'"));
      expect(p5, contains("'3/3'"));
    });

    test('setup is untouched — it still asks on step 2', () {
      final p2 = read('lib/screens/process/unlock_process2.dart');
      expect(p2, contains('length_of_your_period_eg_6_days'));
      final p3 = read('lib/screens/process/unlock_process3.dart');
      expect(p3, contains("Navigator.pushNamed(context, '/unlock-process/4')"));
    });
  });

  group('back-filling an old period does not rewrite her usual', () {
    test('the write is conditional on this being the newest episode', () {
      // Adding a short period from July should be recorded as a short period
      // in July — not taken as news that her periods are now short.
      final p5 = read('lib/screens/process/unlock_process5.dart');
      expect(p5, contains('isLatestEpisode'));
      expect(p5, contains('if (isLatestEpisode)\n                "length_of_period"'));
    });

    test('but the episode itself always records what she said', () {
      final p5 = read('lib/screens/process/unlock_process5.dart');
      final call = p5.substring(p5.indexOf('PeriodHistoryService.record('));
      expect(call, contains('lengthOfPeriod: periodState.lengthOfPeriod'));
      expect(call.substring(0, call.indexOf(');')).contains('isLatestEpisode'),
          isFalse);
    });
  });
}
