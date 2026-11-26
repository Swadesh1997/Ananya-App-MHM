import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

class PeriodState with ChangeNotifier {
  bool isPeriodRegular = true;
  int daysBetweenPeriod = 28;
  int lengthOfPeriod = 5;

  // Always 'yyyy-MM-dd'. Previously this defaulted to DateTime.now().toString(),
  // which produced a full timestamp that later failed to parse as a date.
  String lastPeriodStart = _today();

  /// Whether the user actually picked a date on the calendar. Used to keep
  /// "I do not know" and "Continue" mutually exclusive.
  bool hasSelectedLastPeriodStart = false;

  bool takeBirthControl = false;

  Map<String, bool> healthCondition = {
    "Yeast infection": false,
    "Urinary track infections": false,
    "Bacterial Vaginosis": false,
    "Polycystic Ovary Syndrome": false,
    "Endometriosis": false,
    "Fibroids": false,
    "I’m not sure": false,
    "No health issues": true,
  };

  /// Whether [hydrateFrom] found stored answers to load.
  ///
  /// Distinguishes "she has not told us yet", where the values above are
  /// placeholders, from "these are her answers". A screen that pre-fills its
  /// inputs must only do so in the second case: showing 28 and 5 to someone
  /// setting up for the first time puts words in her mouth, and she will
  /// reasonably accept them as the app's suggestion.
  bool hasStoredAnswers = false;

  /// Loads the settings the user already gave the app.
  ///
  /// This object is created once, at app start, holding the defaults above —
  /// a regular 28-day cycle, a 5-day period, no birth control and no health
  /// conditions. Nothing ever read her stored answers back into it, so after
  /// any restart those defaults were what the logging flow carried: the health
  /// screen showed "No health issues" ticked for a girl who had said she has
  /// PCOS, and every logged period recorded a 5-day bleed whatever she had
  /// actually reported. The prediction is built from exactly these values, so
  /// the defaults quietly stood in for her own answers.
  ///
  /// [lastPeriodStart] is deliberately not restored. The flow that calls this
  /// is asking for a *new* start date, and pre-filling the old one would both
  /// enable "Continue" before she has chosen anything and offer last month's
  /// date as this month's answer.
  void hydrateFrom(Map<String, dynamic>? saved) {
    if (saved == null || saved.isEmpty) return;

    hasStoredAnswers = true;

    final regular = saved['is_period_regular'];
    if (regular is bool) isPeriodRegular = regular;

    final gap = saved['days_between_period'];
    if (gap is num) daysBetweenPeriod = gap.round();

    final bleed = saved['length_of_period'];
    if (bleed is num) lengthOfPeriod = bleed.round();

    final birthControl = saved['take_birth_control'];
    if (birthControl is bool) takeBirthControl = birthControl;

    final conditions = saved['health_condition'];
    if (conditions is Map) {
      // Read through the legacy aliases as well as the current keys.
      //
      // Builds before the localisation-key fix stored the Bangla LABEL as the
      // map key, so a girl who reported PCOS in Bangla has
      // {'পলিসিস্টিক ওভারি সিনড্রোম': true} on record. The prediction engine
      // already reads that form — it widens her window correctly. This did
      // not: it looked only for the English keys, found nothing, and left the
      // defaults in place. The health screen then showed "No health issues"
      // ticked, and the next save of any flow wrote those defaults over her
      // record. Her PCOS report, and the wider window that depends on it,
      // were destroyed by logging a period.
      //
      // Reading both forms and writing the current one is the migration:
      // nothing is lost, and the stored document converges on today's keys.
      for (final key in healthCondition.keys.toList()) {
        final value = conditions[key] ?? conditions[legacyKeyFor(key)];
        if (value is bool) healthCondition[key] = value;
      }
    }

    notifyListeners();
  }

  void updatePeriodRegularity(bool value) {
    isPeriodRegular = value;
    notifyListeners();
  }

  void updateDaysBetweenPeriod(int value) {
    daysBetweenPeriod = value;
    notifyListeners();
  }

  void updateLengthOfPeriod(int value) {
    lengthOfPeriod = value;
    notifyListeners();
  }

  void updateLastPeriodStart(String value) {
    lastPeriodStart = value;
    hasSelectedLastPeriodStart = true;
    notifyListeners();
  }

  /// Used by "I do not know" — forget any picked date and fall back to today.
  void clearLastPeriodStart() {
    lastPeriodStart = _today();
    hasSelectedLastPeriodStart = false;
    notifyListeners();
  }

  void updateBirthControl(bool value) {
    takeBirthControl = value;
    notifyListeners();
  }

  /// Options that cannot coexist with an actual condition.
  static const exclusiveConditions = ["I’m not sure", "No health issues"];

  /// The Bangla label each condition was stored under before the
  /// localisation-key fix, keyed by the English key used now.
  ///
  /// These are historical DATA, not translations — changing one orphans real
  /// stored records. The Bangla the app displays comes from the ARB files and
  /// may diverge from these without consequence.
  static const legacyBanglaKeys = <String, String>{
    "Yeast infection": "ইস্ট সংক্রমণ",
    "Urinary track infections": "মূত্রনালী সংক্রমণ",
    "Bacterial Vaginosis": "ব্যাকটেরিয়াল ভ্যাজিনোসিস",
    "Polycystic Ovary Syndrome": "পলিসিস্টিক ওভারি সিনড্রোম",
    "Endometriosis": "এন্ডোমেট্রিওসিস",
    "Fibroids": "ফাইব্রয়েড",
    "I’m not sure": "আমি নিশ্চিত নই",
    "No health issues": "কোনো স্বাস্থ্য সমস্যা নেই",
  };

  /// The legacy key a current key may also be stored under, or null.
  static String? legacyKeyFor(String key) => legacyBanglaKeys[key];

  void updateHealthCondition(String condition, bool value) {
    if (value) {
      if (exclusiveConditions.contains(condition)) {
        // "Not sure" / "No health issues" clear everything else.
        for (final k in healthCondition.keys.toList()) {
          healthCondition[k] = false;
        }
      } else {
        // Picking a real condition clears the exclusive options.
        for (final k in exclusiveConditions) {
          healthCondition[k] = false;
        }
      }
    }
    healthCondition[condition] = value;
    notifyListeners();
  }
}
