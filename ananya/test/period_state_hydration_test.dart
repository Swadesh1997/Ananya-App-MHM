import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/models/period_state_questionnaire.dart';

/// The short "log new period" flow starts from her real settings.
///
/// PeriodState is constructed once at app start and holds defaults — a regular
/// 28-day cycle, a 5-day period, no birth control, "No health issues" — until
/// the setup questionnaire fills it in. The short flow skips that
/// questionnaire, so after any restart the defaults were what it carried: the
/// health screen offered "No health issues" pre-ticked to a girl who had
/// reported PCOS, and each logged period recorded a 5-day bleed regardless of
/// what she had said. Both feed the prediction directly.
void main() {
  group('hydrateFrom', () {
    test('restores every setting the short flow does not ask about', () {
      final state = PeriodState();

      state.hydrateFrom({
        'is_period_regular': false,
        'days_between_period': 34,
        'length_of_period': 7,
        'take_birth_control': true,
        'health_condition': {
          'Polycystic Ovary Syndrome': true,
          'No health issues': false,
        },
      });

      expect(state.isPeriodRegular, isFalse);
      expect(state.daysBetweenPeriod, 34);
      expect(state.lengthOfPeriod, 7);
      expect(state.takeBirthControl, isTrue);
      expect(state.healthCondition['Polycystic Ovary Syndrome'], isTrue);
      expect(state.healthCondition['No health issues'], isFalse);
    });

    test('PCOS survives, because the prediction window depends on it', () {
      // The one that costs most when lost: PCOS is what widens the predicted
      // window. Silently clearing it replaces an honest "sometime this week"
      // with a confident wrong day.
      final state = PeriodState()
        ..hydrateFrom({
          'health_condition': {'Polycystic Ovary Syndrome': true},
        });

      expect(state.healthCondition['Polycystic Ovary Syndrome'], isTrue);
    });

    test('does not touch the date the flow is about to ask for', () {
      final state = PeriodState();
      final before = state.lastPeriodStart;

      state.hydrateFrom({
        'last_period_start': '2026-01-01',
        'days_between_period': 30,
      });

      // Restoring it would offer last month's date as this month's answer and
      // enable Continue before she has chosen anything.
      expect(state.lastPeriodStart, before);
      expect(state.hasSelectedLastPeriodStart, isFalse);
    });

    test('nothing stored leaves the defaults alone', () {
      for (final empty in [null, <String, dynamic>{}]) {
        final state = PeriodState()..hydrateFrom(empty);
        expect(state.daysBetweenPeriod, 28);
        expect(state.lengthOfPeriod, 5);
        expect(state.healthCondition['No health issues'], isTrue);
      }
    });

    test('a partial document only overwrites what it contains', () {
      final state = PeriodState()..hydrateFrom({'days_between_period': 31});

      expect(state.daysBetweenPeriod, 31);
      expect(state.lengthOfPeriod, 5, reason: 'absent key must not reset');
      expect(state.isPeriodRegular, isTrue);
    });

    test('numbers stored as doubles still load', () {
      // Firestore hands back whichever numeric type it was written with, and
      // JSON round-tripping through the local store can widen an int.
      final state = PeriodState()
        ..hydrateFrom({'days_between_period': 30.0, 'length_of_period': 6.0});

      expect(state.daysBetweenPeriod, 30);
      expect(state.lengthOfPeriod, 6);
    });

    test('a stale key the app no longer offers is ignored', () {
      final state = PeriodState()
        ..hydrateFrom({
          'health_condition': {'Something retired': true},
        });

      expect(state.healthCondition.containsKey('Something retired'), isFalse);
    });

    test('it notifies, so a screen already built redraws', () {
      var notified = 0;
      PeriodState()
        ..addListener(() => notified++)
        ..hydrateFrom({'days_between_period': 30});

      expect(notified, 1);
    });
  });

  group('the flow calls it', () {
    String read(String path) => File(path).readAsStringSync();

    test('process 3 loads the settings before either screen is shown', () {
      final src = read('lib/screens/process/unlock_process3.dart');
      expect(src, contains('hydrateFrom'));
      expect(src, contains('LocalPeriodStore.readSettings'));
    });

    test('only on the short flow', () {
      // On first setup there is nothing stored, and the questionnaire itself
      // is the source of these values.
      final src = read('lib/screens/process/unlock_process3.dart');
      expect(src, contains('if (widget.updatePeriod) _restoreSettings();'));
    });

    test('the logged bleed length is the one she just gave', () {
      // Not her stored usual: the flow now asks for this period's length, and
      // recording anything else would make the question decorative.
      final src = read('lib/screens/process/unlock_process5.dart');
      final call = src.substring(src.indexOf('PeriodHistoryService.record('));
      expect(call, contains('lengthOfPeriod: periodState.lengthOfPeriod'));
    });

    test('hydration still seeds the length step', () {
      // The length chip opens pre-selected on her usual figure, which only
      // works because process 3 loaded it first.
      final src = read('lib/screens/process/period_length_page.dart');
      expect(src, contains('context.read<PeriodState>().lengthOfPeriod'));
    });
  });
}
