import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/l10n/app_localizations.dart';

/// What a statement is about. Shown on the card so a question has a subject
/// rather than arriving out of nowhere, and so a run of six feels varied
/// rather than random.
enum MythCategory { cycle, hygiene, food, stigma, health, products, fertility }

extension MythCategoryLabel on MythCategory {
  String label(AppLocalizations l) {
    switch (this) {
      case MythCategory.cycle:
        return l.myth_cat_cycle;
      case MythCategory.hygiene:
        return l.myth_cat_hygiene;
      case MythCategory.food:
        return l.myth_cat_food;
      case MythCategory.stigma:
        return l.myth_cat_stigma;
      case MythCategory.health:
        return l.myth_cat_health;
      case MythCategory.products:
        return l.myth_cat_products;
      case MythCategory.fertility:
        return l.myth_cat_fertility;
    }
  }
}

/// One statement the reader judges true or false.
class Myth {
  /// Stable identifier, matching the `myth_<id>_*` keys in the .arb files.
  final int id;

  final String Function(AppLocalizations) statement;
  final String Function(AppLocalizations) answer;

  /// What the statement actually is.
  final bool isTrue;

  final MythCategory category;

  const Myth(
    this.id,
    this.statement,
    this.answer, {
    required this.isTrue,
    required this.category,
  });
}

Myth _f(int id, String Function(AppLocalizations) s,
        String Function(AppLocalizations) a, MythCategory c) =>
    Myth(id, s, a, isTrue: false, category: c);

Myth _t(int id, String Function(AppLocalizations) s,
        String Function(AppLocalizations) a, MythCategory c) =>
    Myth(id, s, a, isTrue: true, category: c);

/// Everything the quiz can ask.
///
/// The false statements are myths the app's own content documents, plus
/// well-attested ones from NHS and UNICEF material. The true ones are facts
/// stated outright in the content or in those sources. Every answer condenses
/// existing text rather than asserting something new, and each carries its
/// source in the .arb description so a health reviewer can trace it.
///
/// The pool is deliberately larger than a round: at six a sitting, this
/// gives five full rounds before a single statement repeats.
///
/// Reviewed by WaterAid. Five of the original forty were rejected and
/// removed outright rather than left disabled, so what is here is exactly
/// what was approved.
final List<Myth> mythPool = [
  // ---------------------------------------------------------------- myths
  _f(1, (l) => l.myth_1_statement, (l) => l.myth_1_answer,
      MythCategory.food),
  _f(2, (l) => l.myth_2_statement, (l) => l.myth_2_answer,
      MythCategory.stigma),
  _f(3, (l) => l.myth_3_statement, (l) => l.myth_3_answer,
      MythCategory.hygiene),
  _f(4, (l) => l.myth_4_statement, (l) => l.myth_4_answer,
      MythCategory.stigma),
  _f(7, (l) => l.myth_7_statement, (l) => l.myth_7_answer,
      MythCategory.stigma),
  _f(8, (l) => l.myth_8_statement, (l) => l.myth_8_answer,
      MythCategory.stigma),
  _f(9, (l) => l.myth_9_statement, (l) => l.myth_9_answer,
      MythCategory.stigma),
  _f(10, (l) => l.myth_10_statement, (l) => l.myth_10_answer,
      MythCategory.food),
  _f(11, (l) => l.myth_11_statement, (l) => l.myth_11_answer,
      MythCategory.health),
  _f(17, (l) => l.myth_17_statement, (l) => l.myth_17_answer,
      MythCategory.health),
  _f(20, (l) => l.myth_20_statement, (l) => l.myth_20_answer,
      MythCategory.stigma),
  _f(35, (l) => l.myth_35_statement, (l) => l.myth_35_answer,
      MythCategory.stigma),
  _f(36, (l) => l.myth_36_statement, (l) => l.myth_36_answer,
      MythCategory.stigma),
  _f(37, (l) => l.myth_37_statement, (l) => l.myth_37_answer,
      MythCategory.stigma),
  _f(38, (l) => l.myth_38_statement, (l) => l.myth_38_answer,
      MythCategory.health),

  // ---------------------------------------------------------------- facts
  _t(5, (l) => l.myth_5_statement, (l) => l.myth_5_answer,
      MythCategory.cycle),
  _t(6, (l) => l.myth_6_statement, (l) => l.myth_6_answer,
      MythCategory.cycle),
  _t(12, (l) => l.myth_12_statement, (l) => l.myth_12_answer,
      MythCategory.hygiene),
  _t(14, (l) => l.myth_14_statement, (l) => l.myth_14_answer,
      MythCategory.hygiene),
  _t(15, (l) => l.myth_15_statement, (l) => l.myth_15_answer,
      MythCategory.cycle),
  _t(16, (l) => l.myth_16_statement, (l) => l.myth_16_answer,
      MythCategory.health),
  _t(18, (l) => l.myth_18_statement, (l) => l.myth_18_answer,
      MythCategory.cycle),
  _t(19, (l) => l.myth_19_statement, (l) => l.myth_19_answer,
      MythCategory.cycle),
  _t(21, (l) => l.myth_21_statement, (l) => l.myth_21_answer,
      MythCategory.food),
  _t(22, (l) => l.myth_22_statement, (l) => l.myth_22_answer,
      MythCategory.food),
  _t(23, (l) => l.myth_23_statement, (l) => l.myth_23_answer,
      MythCategory.cycle),
  _t(24, (l) => l.myth_24_statement, (l) => l.myth_24_answer,
      MythCategory.health),
  _t(25, (l) => l.myth_25_statement, (l) => l.myth_25_answer,
      MythCategory.cycle),
  _t(27, (l) => l.myth_27_statement, (l) => l.myth_27_answer,
      MythCategory.products),
  _t(28, (l) => l.myth_28_statement, (l) => l.myth_28_answer,
      MythCategory.fertility),
  _t(30, (l) => l.myth_30_statement, (l) => l.myth_30_answer,
      MythCategory.cycle),
  _t(31, (l) => l.myth_31_statement, (l) => l.myth_31_answer,
      MythCategory.health),
  _t(32, (l) => l.myth_32_statement, (l) => l.myth_32_answer,
      MythCategory.cycle),
  _t(39, (l) => l.myth_39_statement, (l) => l.myth_39_answer,
      MythCategory.cycle),
  _t(40, (l) => l.myth_40_statement, (l) => l.myth_40_answer,
      MythCategory.cycle),
];

/// How many statements one sitting asks. Short enough to finish in a minute.
const int mythRoundSize = 6;

/// Picks one round from [pool], skipping anything in [seen].
///
/// True and false are drawn from separate piles rather than sampling at
/// random, because chance would sooner or later deal an all-false round — and
/// a round where every answer is "false" teaches the pattern instead of the
/// facts. The halves are then shuffled together so the order gives nothing
/// away.
///
/// When what is left is too small to fill a round, the remainder is returned
/// rather than reaching back for statements already asked: repeating is the
/// one thing this is here to avoid. [MythProgress.isExhausted] is how the
/// screen knows to offer a fresh start instead.
List<Myth> buildMythRound(
  List<Myth> pool,
  Random rng, {
  int size = mythRoundSize,
  Set<int> seen = const {},
}) {
  final available = pool.where((m) => !seen.contains(m.id)).toList();

  final trues = available.where((m) => m.isTrue).toList()..shuffle(rng);
  final falses = available.where((m) => !m.isTrue).toList()..shuffle(rng);

  // Aim for an even split, then let whichever pile is larger cover any
  // shortfall in the other so a thinning pool still fills the round.
  var wantTrue = size ~/ 2;
  var wantFalse = size - wantTrue;
  if (trues.length < wantTrue) {
    wantFalse += wantTrue - trues.length;
    wantTrue = trues.length;
  }
  if (falses.length < wantFalse) {
    wantTrue += wantFalse - falses.length;
    wantFalse = falses.length;
  }
  wantTrue = wantTrue.clamp(0, trues.length);
  wantFalse = wantFalse.clamp(0, falses.length);

  return [
    ...trues.take(wantTrue),
    ...falses.take(wantFalse),
  ]..shuffle(rng);
}

/// Remembers which statements have already been asked, so that carrying on to
/// another round never serves up the same six again.
///
/// Kept on the device rather than in memory: coming back tomorrow should
/// continue where she left off, not start the same questions over.
class MythProgress {
  static const _key = 'myth_seen_ids';

  static Future<Set<int>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      return raw.map(int.tryParse).whereType<int>().toSet();
    } catch (e) {
      debugPrint('MythProgress: load failed: $e');
      return {};
    }
  }

  static Future<void> add(Set<int> seen, Iterable<Myth> asked) async {
    try {
      seen.addAll(asked.map((m) => m.id));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, seen.map((i) => '$i').toList());
    } catch (e) {
      debugPrint('MythProgress: save failed: $e');
    }
  }

  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('MythProgress: reset failed: $e');
    }
  }

  /// True when too little is left to ask another full round.
  static bool isExhausted(List<Myth> pool, Set<int> seen) =>
      pool.where((m) => !seen.contains(m.id)).length < mythRoundSize;

  /// How many statements remain unasked.
  static int remaining(List<Myth> pool, Set<int> seen) =>
      pool.where((m) => !seen.contains(m.id)).length;
}
