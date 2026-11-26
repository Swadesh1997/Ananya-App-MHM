import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/models/myth_data.dart';

/// These guard the content and the round-building, not the layout. The
/// dangerous failures for a health quiz are a statement carrying the wrong
/// verdict, a claim drifting from its reviewed source, an all-false round, or
/// a question coming round again when the user was promised it would not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> en;
  late Map<String, dynamic> bn;

  setUpAll(() {
    en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync());
    bn = jsonDecode(File('lib/l10n/app_bn.arb').readAsStringSync());
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the pool', () {
    test('every statement exists in both languages and is translated', () {
      final bengali = RegExp(r'[ঀ-৿]');
      for (final m in mythPool) {
        for (final part in ['statement', 'answer']) {
          final key = 'myth_${m.id}_$part';
          expect(en[key], isNotNull, reason: '$key missing from English');
          expect(bn[key], isNotNull, reason: '$key missing from Bangla');
          expect((en[key] as String).trim(), isNotEmpty);
          expect(bengali.hasMatch(bn[key] as String), isTrue,
              reason: '$key has no Bengali characters');
          expect(bn[key], isNot(equals(en[key])), reason: '$key untranslated');
        }
      }
    });

    test('ids are unique', () {
      final ids = mythPool.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('holds enough for several rounds without repeating', () {
      // The whole point of the pool: a few sittings should not exhaust it.
      expect(mythPool.length, greaterThanOrEqualTo(mythRoundSize * 5),
          reason: 'fewer than five distinct rounds available');
      expect(mythPool.length, 35,
          reason: 'the reviewer approved 35 statements; a change here needs sign-off');
    });

    test('both verdicts are well represented', () {
      final trues = mythPool.where((m) => m.isTrue).length;
      final falses = mythPool.where((m) => !m.isTrue).length;
      expect(trues, greaterThanOrEqualTo(mythRoundSize ~/ 2));
      expect(falses, greaterThanOrEqualTo(mythRoundSize ~/ 2));
    });

    test('every answer carries a review note in the template file', () {
      for (final m in mythPool) {
        final meta = en['@myth_${m.id}_answer'];
        expect(meta, isNotNull, reason: 'myth ${m.id} answer has no metadata');
        expect(meta['description'], contains('NEEDS HEALTH REVIEW'));
      }
    });

    test('externally sourced claims name their source', () {
      // Anything not taken from the app's own copy must say where it came
      // from, so a reviewer can check it against the original.
      var external = 0;
      for (final m in mythPool) {
        final d = en['@myth_${m.id}_answer']['description'] as String;
        if (d.contains('EXTERNAL')) {
          external++;
          expect(d, anyOf(contains('NHS'), contains('UNICEF')),
              reason: 'myth ${m.id} is external but names no source');
        }
      }
      expect(external, greaterThan(0));
    });
  });

  group('categories', () {
    test('every statement has a label in both languages', () {
      for (final c in MythCategory.values) {
        final key = 'myth_cat_${c.name}';
        expect(en[key], isNotNull, reason: '$key missing from English');
        expect(bn[key], isNotNull, reason: '$key missing from Bangla');
        expect(bn[key], isNot(equals(en[key])), reason: '$key untranslated');
      }
    });

    test('no category is left unused', () {
      final used = mythPool.map((m) => m.category).toSet();
      expect(used.length, MythCategory.values.length,
          reason: 'unused: ${MythCategory.values
                  .where((c) => !used.contains(c))
                  .map((c) => c.name)
                  .join(', ')}');
    });

    test('a round covers several subjects rather than one', () {
      for (var seed = 0; seed < 40; seed++) {
        final round = buildMythRound(mythPool, Random(seed));
        expect(round.map((m) => m.category).toSet().length,
            greaterThanOrEqualTo(2),
            reason: 'seed $seed asked about a single subject');
      }
    });
  });

  group('round building', () {
    test('a full round is the requested size', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(buildMythRound(mythPool, Random(seed)).length, mythRoundSize);
      }
    });

    test('no round is ever all-true or all-false', () {
      for (var seed = 0; seed < 200; seed++) {
        final round = buildMythRound(mythPool, Random(seed));
        final trues = round.where((m) => m.isTrue).length;
        expect(trues, greaterThan(0), reason: 'seed $seed had no true answers');
        expect(trues, lessThan(round.length),
            reason: 'seed $seed had no false answers');
      }
    });

    test('a round never repeats a statement within itself', () {
      for (var seed = 0; seed < 50; seed++) {
        final ids = buildMythRound(mythPool, Random(seed)).map((m) => m.id);
        expect(ids.toSet().length, ids.length, reason: 'duplicate on $seed');
      }
    });

    test('carrying on never re-asks anything from an earlier round', () {
      final rng = Random(11);
      final seen = <int>{};
      var rounds = 0;
      while (!MythProgress.isExhausted(mythPool, seen)) {
        final round = buildMythRound(mythPool, rng, seen: seen);
        for (final m in round) {
          expect(seen.contains(m.id), isFalse,
              reason: 'myth ${m.id} came round again in round ${rounds + 1}');
        }
        seen.addAll(round.map((m) => m.id));
        rounds++;
        expect(rounds, lessThan(50), reason: 'runaway loop');
      }
      expect(rounds, greaterThanOrEqualTo(5),
          reason: 'only $rounds rounds before repeating');
    });

    test('a thinning pool returns the remainder rather than repeating', () {
      // All but four seen: the next round should be those four, not six with
      // two of them asked a second time.
      final seen = mythPool.take(mythPool.length - 4).map((m) => m.id).toSet();
      final round = buildMythRound(mythPool, Random(2), seen: seen);
      expect(round.length, 4);
      expect(round.any((m) => seen.contains(m.id)), isFalse);
    });

    test('an exhausted pool yields an empty round, not a crash', () {
      final seen = mythPool.map((m) => m.id).toSet();
      expect(buildMythRound(mythPool, Random(3), seen: seen), isEmpty);
      expect(MythProgress.isExhausted(mythPool, seen), isTrue);
      expect(MythProgress.remaining(mythPool, seen), 0);
    });

    test('a pool with only one verdict does not crash or duplicate', () {
      final onlyFalse = mythPool.where((m) => !m.isTrue).toList();
      final round = buildMythRound(onlyFalse, Random(3));
      expect(round.length, mythRoundSize);
      expect(round.every((m) => !m.isTrue), isTrue);
      expect(round.map((m) => m.id).toSet().length, round.length);
    });
  });

  group('progress is remembered between visits', () {
    test('what was asked survives a reload', () async {
      final round = buildMythRound(mythPool, Random(5));
      await MythProgress.add(<int>{}, round);

      final reloaded = await MythProgress.load();
      expect(reloaded, containsAll(round.map((m) => m.id)));
      expect(reloaded.length, round.length);
    });

    test('a later round adds to the record rather than replacing it', () async {
      final seen = <int>{};
      final first = buildMythRound(mythPool, Random(5), seen: seen);
      await MythProgress.add(seen, first);
      final second = buildMythRound(mythPool, Random(6), seen: seen);
      await MythProgress.add(seen, second);

      final reloaded = await MythProgress.load();
      expect(reloaded.length, first.length + second.length);
    });

    test('starting over clears the record', () async {
      await MythProgress.add(<int>{}, buildMythRound(mythPool, Random(5)));
      await MythProgress.reset();
      expect(await MythProgress.load(), isEmpty);
    });

    test('a corrupt record reads as empty rather than throwing', () async {
      SharedPreferences.setMockInitialValues({
        'myth_seen_ids': ['not-a-number', '7'],
      });
      expect(await MythProgress.load(), {7});
    });
  });

  group('claims still match their cited sources', () {
    test('English source phrases are unchanged', () {
      expect(en['first_description_22'], contains('no medical reason'));
      expect(en['faq_a3'], contains('blood isn’t harmful'));
      expect(en['faq_a2'], contains('21 to 35 days'));
      expect(en['faq_a2'], contains('three to seven days'));
      expect(en['second_description_11'], contains('every 4 to 6 hours'));
      expect(en['third_description_1'], contains('10 and 16'));
      expect(en['first_description_8'], contains('kept secret'));
      expect(en['second_description_15'], contains('Polycystic Ovary Syndrome'));
      expect(en['first_description_13'], contains('medical-grade silicone'));
    });

    test('Bangla source phrases are unchanged', () {
      expect(bn['second_description_11'], contains('রোদে শুকা'));
      expect(bn['second_description_17'], contains('হালকা ব্যায়াম'));
      expect(bn['second_description_11'], contains('৪ থেকে ৬ ঘণ্টা'));
      expect(bn['third_description_1'], contains('১০ থেকে ১৬'));
      expect(bn['second_description_5'], contains('তিন মাস'));
      expect(bn['first_description_13'], contains('সিলিকন'));
    });
  });
}
