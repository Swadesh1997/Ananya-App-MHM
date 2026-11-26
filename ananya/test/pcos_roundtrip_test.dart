import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/period_history_service.dart';

/// A reported health condition must survive being read back and written out.
///
/// Builds before the localisation-key fix stored the Bangla LABEL as the map
/// key. The prediction engine reads that form correctly — it widened her
/// window. `hydrateFrom` did not: it looked only for the English keys, found
/// nothing, and left the defaults standing. The health screen then showed
/// "No health issues" ticked, and the next save of any flow wrote those
/// defaults over her record. Logging a period destroyed her PCOS report and
/// the wider window that depends on it.
///
/// The ±7 day margin itself is unchanged and remains clinically unreviewed.
void main() {
  /// Everything that happens between opening the app and saving: the stored
  /// document is hydrated into PeriodState, and PeriodState is written back.
  Map<String, bool> roundTrip(Map<String, dynamic> stored) {
    final state = PeriodState()..hydrateFrom({'health_condition': stored});
    return state.healthCondition;
  }

  group('A3 — legacy Bangla keys', () {
    test('stored true survives hydrate -> save -> reload', () {
      const stored = {
        'পলিসিস্টিক ওভারি সিনড্রোম': true,
        'কোনো স্বাস্থ্য সমস্যা নেই': false,
      };

      expect(PeriodHistoryService.hasPcos(stored), isTrue,
          reason: 'the engine could always read it');

      final saved = roundTrip(stored);
      expect(PeriodHistoryService.hasPcos(saved), isTrue,
          reason: 'and now it survives being written back');

      // Reload from what was actually saved.
      final reloaded = roundTrip(saved);
      expect(PeriodHistoryService.hasPcos(reloaded), isTrue);
    });

    test('stored false stays false — migration invents nothing', () {
      const stored = {
        'পলিসিস্টিক ওভারি সিনড্রোম': false,
        'কোনো স্বাস্থ্য সমস্যা নেই': true,
      };
      final saved = roundTrip(stored);
      expect(PeriodHistoryService.hasPcos(saved), isFalse);
      expect(saved['No health issues'], isTrue);
    });

    test('every legacy condition maps, not just PCOS', () {
      const stored = {
        'ইস্ট সংক্রমণ': true,
        'এন্ডোমেট্রিওসিস': true,
        'ফাইব্রয়েড': false,
      };
      final saved = roundTrip(stored);
      expect(saved['Yeast infection'], isTrue);
      expect(saved['Endometriosis'], isTrue);
      expect(saved['Fibroids'], isFalse);
    });

    test('the alias table covers every offered condition', () {
      final offered = PeriodState().healthCondition.keys.toSet();
      expect(PeriodState.legacyBanglaKeys.keys.toSet(), offered,
          reason: 'a missing alias silently drops that condition');
    });
  });

  group('the current format is unaffected', () {
    test('English true round-trips', () {
      const stored = {
        'Polycystic Ovary Syndrome': true,
        'No health issues': false,
      };
      expect(PeriodHistoryService.hasPcos(roundTrip(stored)), isTrue);
    });

    test('English false round-trips', () {
      const stored = {
        'Polycystic Ovary Syndrome': false,
        'No health issues': true,
      };
      expect(PeriodHistoryService.hasPcos(roundTrip(stored)), isFalse);
    });

    test('a current key wins over a legacy one if both are present', () {
      // Mid-migration a document can carry both. The current key is the one
      // the app writes, so it is the more recent statement.
      const stored = {
        'Polycystic Ovary Syndrome': true,
        'পলিসিস্টিক ওভারি সিনড্রোম': false,
      };
      expect(roundTrip(stored)['Polycystic Ovary Syndrome'], isTrue);
    });
  });

  group('the window that depends on it', () {
    List<PeriodEntry> steady() => [
          PeriodEntry(start: DateTime(2026, 7, 4), lengthOfPeriod: 5),
          PeriodEntry(
              start: DateTime(2026, 8, 1),
              lengthOfPeriod: 5,
              daysSincePrevious: 28),
          PeriodEntry(
              start: DateTime(2026, 8, 29),
              lengthOfPeriod: 5,
              daysSincePrevious: 28),
        ];

    test('a legacy PCOS user keeps her wider window after a save', () {
      const legacy = {'পলিসিস্টিক ওভারি সিনড্রোম': true};
      final afterSave = roundTrip(legacy);

      final before = CycleSnapshot.build(
        entries: steady(),
        settings: const {
          'days_between_period': 28,
          'length_of_period': 5,
          'health_condition': legacy,
        },
        today: DateTime(2026, 9, 24),
      );
      final after = CycleSnapshot.build(
        entries: steady(),
        settings: {
          'days_between_period': 28,
          'length_of_period': 5,
          'health_condition': afterSave,
        },
        today: DateTime(2026, 9, 24),
      );

      expect(before.reportsPcos, isTrue);
      expect(after.reportsPcos, isTrue,
          reason: 'logging a period must not remove her report');
      expect(after.windowHalfWidthDays, before.windowHalfWidthDays);
      // Unchanged and still clinically unreviewed.
      expect(PeriodHistoryService.pcosMarginDays, 7);
      expect(after.windowHalfWidthDays, 7);
    });
  });
}
