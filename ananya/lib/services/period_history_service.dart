import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:ananya/services/local_period_store.dart';

/// One recorded period.
class PeriodEntry {
  final DateTime start;
  final int lengthOfPeriod;

  /// Days since the previous recorded period. Null for the earliest entry.
  final int? daysSincePrevious;

  const PeriodEntry({
    required this.start,
    required this.lengthOfPeriod,
    this.daysSincePrevious,
  });
}

/// Summary of a user's recorded cycles. Fields are null until enough periods
/// have been logged to calculate them honestly — never estimated or filled in.
class CycleStats {
  /// How many periods have been recorded.
  final int cycleCount;

  /// Gap in days between the two most recent periods. Needs 2 entries.
  final int? lastCycleDays;

  /// Mean gap across all recorded cycles. Needs 2 entries.
  final int? averageCycleDays;

  /// Half the spread of recorded gaps, i.e. the "±n days" figure.
  /// Needs 3 entries to be meaningful.
  final int? varianceDays;

  /// Mean bleed length across recorded periods.
  final int? averageBleedDays;

  /// How many intervals between periods were actually usable — inside the
  /// plausible range, and within the averaging window.
  ///
  /// Reported, not used: the maths above is unchanged. It exists because the
  /// screen needs to say how much data the app really has, and [cycleCount]
  /// cannot answer that. Three logged periods with a ninety-day hole between
  /// two of them yield one usable interval, not two, and a progress line built
  /// on [cycleCount] would claim the app can measure her cycle when it cannot.
  final int usableGaps;

  /// Start of the most recent period, after normalisation.
  ///
  /// This is the app's single answer to "when did her last period begin". It
  /// is deliberately taken from the normalised history rather than from
  /// period/latest, which the logging flow overwrites on every save — a
  /// duplicate log three days after a real period would otherwise become the
  /// anchor for every prediction that follows.
  ///
  /// Null only when there is no history at all.
  final DateTime? canonicalLastStart;

  /// Intervals thrown away by either filter: outside the plausible range, or
  /// judged a probable missed log.
  ///
  /// Recorded so that discarding an observation can never make the app more
  /// confident. Both filters remove LONG gaps, so what survives an alternating
  /// history is its short half — which by construction has no spread at all.
  /// A 25/50 pattern was therefore reported as a flawless 25-day cycle with a
  /// single confident date, and a girl whose cycles genuinely swing was told
  /// she was regular. The intervals remain unmeasurable; what changed is that
  /// their absence is now remembered.
  final int excludedObservations;

  const CycleStats({
    required this.cycleCount,
    this.lastCycleDays,
    this.averageCycleDays,
    this.varianceDays,
    this.averageBleedDays,
    this.canonicalLastStart,
    this.usableGaps = 0,
    this.excludedObservations = 0,
  });

  static const empty = CycleStats(cycleCount: 0);

  /// True once there is enough data to describe the cycle as regular or not
  /// from measurement rather than from what the user said at signup.
  bool get hasMeasuredRegularity => varianceDays != null;

  /// Usable intervals needed before regularity can be measured.
  ///
  /// Kept beside [hasMeasuredRegularity] so the screen's progress line and the
  /// switch to measured data are driven by the same number. Two intervals is
  /// what varianceDays requires.
  static const int gapsForMeasurement = 2;

  /// The periods that form an unbroken usable chain, which is one more than
  /// the number of intervals between them. This is the figure to show her:
  /// she counts periods, not the gaps between them.
  int get usablePeriods => cycleCount == 0 ? 0 : usableGaps + 1;

  /// Periods needed in total before her cycle can be measured.
  static const int periodsForMeasurement = gapsForMeasurement + 1;

  /// Whether her cycles count as regular, measured rather than self-reported.
  ///
  /// Two conditions, both required: the spread of her gaps is no more than
  /// 4 days either side, and the average sits inside 21-35 days — the range
  /// normally described as a typical cycle. The old Django backend used
  /// 21-30; this widens it to the standard range so a consistent 33-day
  /// cycle is not called irregular merely for being long.
  ///
  /// Null until there are two usable gaps, because a spread needs at least
  /// two numbers to exist — and null, too, whenever an observation was
  /// excluded, because the sample the spread was taken over is then known to
  /// be missing something. See [excludedObservations].
  ///
  /// The 4-day spread limit and the 21-35 day range are unchanged by this
  /// pass and REMAIN UNVALIDATED CLINICALLY. They are the app's working
  /// definition, not a medical one.
  bool? get isRegular {
    if (!hasMeasuredRegularity || averageCycleDays == null) return null;
    if (excludedObservations > 0) return null;
    return varianceDays! <= 4 &&
        averageCycleDays! >= 21 &&
        averageCycleDays! <= 35;
  }

  /// Whether the app has enough surviving intervals to describe her cycle at
  /// all. One interval is not a measurement: an average exists from a single
  /// gap, but its variability cannot, so a lone 15-day interval — a
  /// breakthrough bleed, a mis-tap at the episode boundary — was setting the
  /// whole forecast and presenting it as measured.
  bool get hasEnoughForMeasurement => usableGaps >= gapsForMeasurement;
}

/// A predicted next period, and how much real data it rests on.
class CyclePrediction {
  /// Earliest likely start. Equals [to] when the cycle is regular.
  final DateTime from;

  /// Latest likely start.
  final DateTime to;

  /// Cycle length used for the prediction.
  final int cycleDays;

  /// Bleed length used for the prediction.
  final int bleedDays;

  /// Number of logged cycles the figures came from. 0 means the values the
  /// user gave at signup were used because there is not enough history yet.
  final int basedOnCycles;

  const CyclePrediction({
    required this.from,
    required this.to,
    required this.cycleDays,
    required this.bleedDays,
    required this.basedOnCycles,
  });

  bool get isMeasured => basedOnCycles > 0;
  bool get hasWindow => !from.isAtSameMomentAs(to);

  /// The single most likely start date on or after [today]: the middle of the
  /// prediction window, rolled forward whole cycles while the window has
  /// already fully passed. This is the one date reminders are aimed at, so
  /// every caller aims at the same day the home screen displays.
  DateTime nextExpected(DateTime today) {
    var f = from, t = to;
    if (cycleDays > 0) {
      while (t.isBefore(today)) {
        f = f.add(Duration(days: cycleDays));
        t = t.add(Duration(days: cycleDays));
      }
    }
    return f.add(Duration(days: t.difference(f).inDays ~/ 2));
  }
}

/// Stores every logged period in Firestore so cycle history accumulates.
///
/// Previously the app kept a single period/latest document and overwrote it
/// on each log, so nothing could be measured over time. This writes an
/// additional append-only record per period. period/latest is left untouched
/// so existing screens keep working.
///
/// Layout: users/{uid}/periods/{yyyy-MM-dd}
/// The date is the document id, which makes logging the same date twice
/// idempotent and keeps documents sorted chronologically by id.
class PeriodHistoryService {
  static final _fmt = DateFormat('yyyy-MM-dd');

  static CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('periods');

  /// Accepts 'yyyy-MM-dd' and also older values that were written as a full
  /// timestamp, so historical data still parses.
  static DateTime? _parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is! String) return null;
    try {
      final datePart = raw.trim().split(' ').first.split('T').first;
      return _fmt.parseStrict(datePart);
    } catch (_) {
      return null;
    }
  }

  /// Records one period. Safe to call repeatedly for the same date.
  /// Never throws — a history write must not block the user's flow.
  ///
  /// The device copy is written first and awaited, because that is the write
  /// that must not fail. The Firestore write is deliberately NOT awaited: its
  /// Future completes only when the SERVER acknowledges, so awaiting it hangs
  /// forever with no connection — which is exactly why logging a period
  /// appeared to need internet. Firestore still persists it locally straight
  /// away and replays it when the network returns.
  static Future<void> record({
    required String uid,
    required String periodStart,
    required int lengthOfPeriod,
  }) async {
    final parsed = _parse(periodStart);
    if (parsed == null) {
      debugPrint('PeriodHistory: unparseable date "$periodStart", skipping');
      return;
    }
    final id = _fmt.format(parsed);

    await LocalPeriodStore.recordPeriod(uid, id, lengthOfPeriod);
    await LocalPeriodStore.setPending(true);

    unawaited(_collection(uid).doc(id).set({
      'period_start': id,
      'length_of_period': lengthOfPeriod,
      'logged_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).then((_) {
      LocalPeriodStore.setPending(false);
      debugPrint('PeriodHistory: $id synced');
    }).catchError((e) {
      // A queued offline write does not land here; this is a real failure.
      debugPrint('PeriodHistory: failed to record $id: $e');
    }));
  }

  /// All recorded periods, oldest first, with the gap to the previous one
  /// computed on read. Gaps are derived rather than stored so that adding an
  /// older entry later corrects the figures instead of leaving them stale.
  ///
  /// The device copy and the server copy are unioned rather than one replacing
  /// the other: a period logged offline here and a period logged on another
  /// handset must both survive. Neither side is ever emptied by the other.
  static Future<List<PeriodEntry>> fetchAll(String uid) async {
    final dates = <DateTime, int>{};

    // Local first, so a total network failure still yields a full history.
    final local = await LocalPeriodStore.readHistory(uid);
    local.forEach((k, v) {
      final d = _parse(k);
      if (d != null) dates[DateTime(d.year, d.month, d.day)] = v;
    });

    try {
      final snap = await _collection(uid)
          .orderBy(FieldPath.documentId)
          .get()
          .timeout(const Duration(seconds: 12));

      final remote = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final start = _parse(data['period_start']) ?? _parse(doc.id);
        if (start == null) continue;
        final len = data['length_of_period'];
        final bleed = len is int ? len : 5;
        dates[DateTime(start.year, start.month, start.day)] = bleed;
        remote[_fmt.format(start)] = bleed;
      }
      // Bring anything logged elsewhere onto this device.
      await LocalPeriodStore.mergeHistory(uid, remote);
      if (!snap.metadata.hasPendingWrites) {
        await LocalPeriodStore.setPending(false);
      }
    } catch (e) {
      // Offline, or the read timed out. The local copy above still stands.
      debugPrint('PeriodHistory: remote fetch unavailable: $e');
    }

    final sorted = dates.keys.toList()..sort();
    final entries = <PeriodEntry>[];
    for (var i = 0; i < sorted.length; i++) {
      entries.add(PeriodEntry(
        start: sorted[i],
        lengthOfPeriod: dates[sorted[i]]!,
        daysSincePrevious:
            i == 0 ? null : sorted[i].difference(sorted[i - 1]).inDays,
      ));
    }

    // Normalised at the source, so no screen can read a raw history by
    // accident. The union above is what makes this safe across devices: both
    // handsets converge on the same set of dates, and [normalize] is a pure
    // function of that set, so both derive identical episodes.
    return normalize(entries);
  }

  /// Every raw log on this device, before normalisation, oldest first.
  ///
  /// The history list shows episodes, which is right for reading but wrong
  /// for correcting: a date logged by mistake and the corrected date logged
  /// afterwards collapse into one row bearing the WRONG date, and the only
  /// control removed both. She could see neither what she had added nor a way
  /// to take back just the mistake. This exposes the individual logs so one
  /// can be removed on its own.
  ///
  /// Deliberately reads the device copy only. Nothing here needs a
  /// connection, and a correction must never wait for one.
  static Future<List<DateTime>> fetchRawLocal(String uid) async {
    final local = await LocalPeriodStore.readHistory(uid);
    final dates = <DateTime>[];
    for (final key in local.keys) {
      final d = _parse(key);
      if (d != null) dates.add(_dayOnly(d));
    }
    dates.sort();
    return dates;
  }

  /// Removes exactly one raw log, leaving every other date untouched.
  ///
  /// [delete] removes a whole episode, which is what the history list needs.
  /// This is what a correction needs: it makes no guess about whether the
  /// remaining logs were duplicates or separate events, because the dates
  /// alone cannot say.
  static Future<void> deleteSingleLog({
    required String uid,
    required DateTime date,
  }) async {
    final id = _fmt.format(_dayOnly(date));
    await LocalPeriodStore.deletePeriod(uid, id);
    await LocalPeriodStore.setPending(true);

    unawaited(_collection(uid).doc(id).delete().then((_) {
      LocalPeriodStore.setPending(false);
      debugPrint('PeriodHistory: raw log $id deleted');
    }).catchError((e) {
      debugPrint('PeriodHistory: failed to delete raw log $id: $e');
    }));

    await _syncLatestToHistory(uid);
  }

  /// Removes one logged period.
  ///
  /// Mirrors [record] exactly: the device copy is awaited because that is the
  /// write that must not fail, and the Firestore delete is not awaited because
  /// its Future only completes on server acknowledgement — awaiting it would
  /// hang with no connection, which is the whole reason logging works offline.
  /// Firestore applies the delete to its own cache immediately and replays it
  /// when the network returns, so a later fetch does not resurrect the row.
  static Future<void> delete({
    required String uid,
    required DateTime start,
  }) async {
    // [start] is the canonical start of an episode, which may stand for more
    // than one logged date. All of them go, or the leftovers would surface as
    // a new period a few days after the one the user removed.
    final local = await LocalPeriodStore.readHistory(uid);
    final raw = [
      for (final e in local.entries)
        if (_parse(e.key) != null)
          PeriodEntry(start: _parse(e.key)!, lengthOfPeriod: e.value)
    ];
    final ids = datesInEpisode(raw, start).map(_fmt.format).toList();

    for (final id in ids) {
      await LocalPeriodStore.deletePeriod(uid, id);
    }
    await LocalPeriodStore.setPending(true);

    for (final id in ids) {
      unawaited(_collection(uid).doc(id).delete().then((_) {
        LocalPeriodStore.setPending(false);
        debugPrint('PeriodHistory: $id deleted');
      }).catchError((e) {
        debugPrint('PeriodHistory: failed to delete $id: $e');
      }));
    }

    // period/latest is a separate document that the logging flow overwrites on
    // every save, so it can still be pointing at the period just removed.
    // Since the prediction falls back to it when there is no history at all,
    // leaving it alone would let a deleted date go on driving the forecast.
    await _syncLatestToHistory(uid);
  }

  /// Realigns period/latest.last_period_start with the canonical history.
  ///
  /// Cleared to an empty string when nothing is left: with no logged periods
  /// there is no honest basis for a prediction, and inventing one from a date
  /// the user has just deleted would be the opposite of what she asked for.
  ///
  /// Reads the device copy rather than calling fetchAll. fetchAll also queries
  /// Firestore and merges what comes back into local storage — and the delete
  /// that just ran was deliberately not awaited, so that read could still see
  /// the removed document and write it straight back. The device copy has
  /// already had the row removed and is the authority here.
  static Future<void> _syncLatestToHistory(String uid) async {
    try {
      final local = await LocalPeriodStore.readHistory(uid);
      final remaining = normalize([
        for (final e in local.entries)
          if (_parse(e.key) != null)
            PeriodEntry(start: _parse(e.key)!, lengthOfPeriod: e.value)
      ]);
      final canonical =
          remaining.isEmpty ? '' : _fmt.format(remaining.last.start);

      await LocalPeriodStore.saveSettings(uid, {
        'last_period_start': canonical,
      });

      unawaited(FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('period')
          .doc('latest')
          .set({'last_period_start': canonical}, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('PeriodHistory: period/latest realign failed: $e');
      }));
    } catch (e) {
      debugPrint('PeriodHistory: period/latest realign failed: $e');
    }
  }

  /// Writes the one date the app already knows about, so existing users start
  /// with a real data point instead of an empty history. Only runs when no
  /// history exists yet; it never invents additional past cycles.
  static Future<void> seedFromLatest({
    required String uid,
    required dynamic lastPeriodStart,
    required int lengthOfPeriod,
  }) async {
    final parsed = _parse(lastPeriodStart);
    if (parsed == null) return;
    try {
      // Seeding is a one-off bootstrap for users who predate the history
      // collection. The flag matters because the emptiness test alone cannot
      // tell "never seeded" from "seeded, then the user deleted it" — without
      // it, removing a lone logged period would silently undo itself here on
      // the next load.
      if (await LocalPeriodStore.hasSeeded(uid)) return;

      // Checked against the device copy, not the server: offline this used to
      // throw, so the one real date a returning user had was never seeded.
      final local = await LocalPeriodStore.readHistory(uid);
      if (local.isNotEmpty) {
        await LocalPeriodStore.markSeeded(uid);
        return;
      }
      await record(
        uid: uid,
        periodStart: _fmt.format(parsed),
        lengthOfPeriod: lengthOfPeriod,
      );
      await LocalPeriodStore.markSeeded(uid);
      debugPrint('PeriodHistory: seeded from period/latest');
    } catch (e) {
      debugPrint('PeriodHistory: seed failed: $e');
    }
  }



  /// Keys used by PeriodState. Older builds (before the localisation-key fix)
  /// wrote the Bangla label instead, so both are checked.
  static const _pcosKeys = [
    'Polycystic Ovary Syndrome',
    'পলিসিস্টিক ওভারি সিনড্রোম',
  ];

  /// Whether the stored health-condition map reports PCOS.
  static bool hasPcos(dynamic healthCondition) {
    if (healthCondition is! Map) return false;
    for (final k in _pcosKeys) {
      if (healthCondition[k] == true) return true;
    }
    return false;
  }

  /// Extra days added to the window when PCOS is reported.
  ///
  /// PCOS is characterised by UNPREDICTABLE cycles, so the honest response is
  /// to widen the range — never to shift the date by a fixed amount. The old
  /// Django backend attempted "+10 days" with no cited basis, and that code
  /// never actually ran.
  ///
  /// This value is deliberately conservative and expresses uncertainty rather
  /// than making a clinical claim. It should be reviewed by a health
  /// professional before being treated as authoritative.
  static const int pcosMarginDays = 7;

  /// Only the most recent cycles are averaged, rather than all history.
  /// A cycle from two years ago should not pull a teenager's prediction toward
  /// a length her body has since moved past — and adolescent cycles change more
  /// than adult ones. Clue uses the same approach for the same reason.
  static const int averagingWindow = 6;

  /// A gap this many times her usual cycle is read as a cycle that was never
  /// logged rather than as one very long cycle.
  ///
  /// The two are the *same observation*: two 28-day cycles with the middle
  /// period unlogged look exactly like one 56-day cycle, and no arithmetic can
  /// separate them. What differs is the cost of being wrong. Reading a missed
  /// log as a real cycle doubles her predicted cycle length and pushes the
  /// forecast a month out, so she is told her period is weeks away on the day
  /// before it arrives. Reading a genuinely long cycle as a missed log predicts
  /// early, and she is merely prepared sooner than she needed to be. Missed
  /// logs are also far commoner than doubling cycles — this is an app for
  /// teenagers, and forgetting a month is the ordinary failure.
  static const double missedLogMultiple = 1.75;

  /// ...but never below this many days, whatever the multiple says.
  ///
  /// Adolescent cycles are genuinely erratic, and a 20-day month followed by a
  /// 40-day one is a real pattern rather than a lost log. Without this floor
  /// the multiple above would discard the long half of exactly the cycles that
  /// vary most, flatten the measured spread, and report a girl as regular when
  /// she is not. 45 days is above nearly every real cycle but comfortably
  /// below two of a normal one.
  static const int missedLogFloorDays = 45;

  /// Plausible range for a real cycle. A gap outside this almost always means a
  /// missed or mistyped log rather than a genuine cycle, and averaging it in
  /// would corrupt every future prediction.
  static const int minPlausibleCycle = 15;
  static const int maxPlausibleCycle = 60;

  /// The range of cycle lengths the app supports as INPUT.
  ///
  /// Deliberately the same numbers as the plausible-gap range above rather
  /// than a second pair invented for the purpose: the app already states that
  /// a gap outside 15-60 days is not something it can treat as a cycle, and a
  /// typed answer is no more measurable than a logged one. Nothing here is a
  /// clinical claim about which cycle lengths are normal.
  static const int minSupportedCycle = minPlausibleCycle;
  static const int maxSupportedCycle = maxPlausibleCycle;

  /// A period has to last at least a day to have been a period.
  static const int minSupportedBleed = 1;

  static bool isSupportedCycle(int? days) =>
      days != null && days >= minSupportedCycle && days <= maxSupportedCycle;

  /// Whether a bleed length can be RECORDED.
  ///
  /// Deliberately separate from whether ovulation can be estimated from it.
  /// Those were one rule, and the rule belonging to the estimate won: a
  /// 27-day period in a 28-day cycle was refused at signup because ovulation
  /// had nowhere to sit, even though the history, the averages, the calendar
  /// shading and the prediction all handle it perfectly well. An observation
  /// she is reporting about her own body must not be blocked by an estimate
  /// the app would like to make about something else.
  ///
  /// The upper bound is structural, NOT a clinical maximum for menstruation:
  /// it is the longest cycle this app supports, and a bleed longer than that
  /// cannot be placed on a calendar that draws cycles. Nothing here says
  /// anything about how long a period should be.
  static bool isRecordableBleed(int? days) =>
      days != null && days >= minSupportedBleed && days <= maxSupportedCycle;

  /// Whether an ovulation day can be derived from this pair.
  ///
  /// This is the question [ovulationDayOfCycle] answers; it is exposed so a
  /// caller can ask before drawing, and it is NOT a validity test for the
  /// bleed length itself — see [isRecordableBleed].
  static bool canEstimateOvulation(int? bleedDays, {required int? cycleDays}) =>
      bleedDays != null &&
      ovulationDayOfCycle(cycleDays ?? 0, bleedDays: bleedDays) != null;

  /// The cycle length a gap is judged against.
  ///
  /// Her own logs when there are enough of them, and what she reported at
  /// signup when there are not — which is the case that matters, because a
  /// single gap has nothing to be compared with and is exactly where one
  /// missed month does the most damage.
  static int? referenceCycle(List<int> gaps, int? reported) {
    if (gaps.length >= 2) {
      final sorted = [...gaps]..sort();
      // The lower of the two middle values on an even count, not their mean.
      // A missed log can only ever lengthen a gap, never shorten one, so when
      // the sample is split the shorter reading is the safer reference.
      return sorted[(sorted.length - 1) ~/ 2];
    }
    if (reported != null &&
        reported >= minPlausibleCycle &&
        reported <= maxPlausibleCycle) {
      return reported;
    }
    // Nothing to judge against. The gap is kept: excluding it would be a
    // guess, and a guess is what this is meant to avoid.
    return null;
  }

  /// Whether [gap] is better read as a cycle that was never logged.
  static bool looksLikeMissedLog(int gap, int reference) =>
      gap >= missedLogFloorDays && gap >= reference * missedLogMultiple;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The app's single canonical reading of a period history.
  ///
  /// Two starts less than [minPlausibleCycle] days apart cannot be two
  /// menstruations: the luteal phase alone runs about 12-14 days. Such a pair
  /// is one period logged more than once — she re-logged mid-flow, corrected a
  /// date, or tapped twice. This collapses each such run into a single episode.
  ///
  /// It exists because the rule used to be applied in exactly one place. The
  /// statistics dropped an implausible *gap*, while the calendar drew every
  /// *entry*, so the same log was a mistake to one half of the app and a period
  /// to the other — five test logs rendered as one 24-day band. Worse, the
  /// statistics were incoherent with themselves: given Jan 1, Jan 4, Feb 1 they
  /// discarded the 3-day gap as a mis-log and then measured the next cycle
  /// *from Jan 4*, anchoring the average on the very entry they had just
  /// rejected. Collapsing first gives Jan 1 -> Feb 1 = 31 days, and every
  /// consumer sees the same history.
  ///
  /// Two properties this relies on:
  ///
  ///  * **Idempotent.** Normalising an already-normalised list changes nothing,
  ///    so it is safe to apply at more than one layer.
  ///  * **Pure in the set of dates.** Two devices holding the same dates derive
  ///    the same episodes, so a local history and a synced one cannot be
  ///    interpreted differently.
  static List<PeriodEntry> normalize(List<PeriodEntry> entries) {
    final groups = _episodes(entries);
    if (groups.isEmpty) return const [];

    // Gaps are re-derived from the canonical starts, so they describe real
    // cycle boundaries. Every gap here is >= minPlausibleCycle by construction.
    return [
      for (var i = 0; i < groups.length; i++)
        PeriodEntry(
          start: groups[i].first.start,
          // Keep the longest bleed anyone reported for this episode rather than
          // the span from first start to last end. The span would invent days
          // she never reported bleeding on (Jan 1 +5d and Jan 4 +5d is not a
          // 9-day period); the longest report is the most she actually claimed.
          lengthOfPeriod: groups[i]
              .map((e) => e.lengthOfPeriod)
              .reduce((a, b) => a > b ? a : b),
          daysSincePrevious: i == 0
              ? null
              : groups[i]
                  .first
                  .start
                  .difference(groups[i - 1].first.start)
                  .inDays,
        ),
    ];
  }

  /// Every raw log that was collapsed into the episode beginning [start].
  ///
  /// The UI lists episodes, not raw logs, so deleting one has to remove all of
  /// the logs behind it. Removing only the canonical date would leave the
  /// duplicate in place, and it would immediately become an episode of its own
  /// — the period the user just deleted would reappear a few days later.
  static List<DateTime> datesInEpisode(
      List<PeriodEntry> entries, DateTime start) {
    final target = _dayOnly(start);
    for (final group in _episodes(entries)) {
      if (group.first.start == target) {
        return group.map((e) => e.start).toList();
      }
    }
    return [target];
  }

  /// Groups raw logs into episodes, oldest first. The canonical start of each
  /// episode is the first element of its group.
  ///
  /// Both [normalize] and [datesInEpisode] read the grouping from here, so the
  /// "less than 15 days apart" rule is stated exactly once.
  static List<List<PeriodEntry>> _episodes(List<PeriodEntry> entries) {
    if (entries.isEmpty) return const [];

    final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
    final groups = <List<PeriodEntry>>[];

    var current = <PeriodEntry>[
      PeriodEntry(
        start: _dayOnly(sorted.first.start),
        lengthOfPeriod: sorted.first.lengthOfPeriod,
      )
    ];

    for (var i = 1; i < sorted.length; i++) {
      final entry = PeriodEntry(
        start: _dayOnly(sorted[i].start),
        lengthOfPeriod: sorted[i].lengthOfPeriod,
      );

      // Measured from the episode's canonical start, never from the previous
      // raw log. Chaining off the previous log would let entries 14 days apart
      // swallow one another indefinitely — a year of fortnightly logs would
      // collapse into a single episode, hiding genuine cycles. Anchoring on the
      // episode start asks the right question: is this a new cycle relative to
      // when this period actually began?
      if (entry.start.difference(current.first.start).inDays <
          minPlausibleCycle) {
        current.add(entry);
        continue;
      }

      groups.add(current);
      current = <PeriodEntry>[entry];
    }
    groups.add(current);

    return groups;
  }

  /// Length of the luteal phase — ovulation to the next period.
  ///
  /// This is the part of the cycle that barely varies. When a cycle is longer
  /// or shorter than 28 days it is almost always the follicular phase (period
  /// to ovulation) that stretches or shortens; the luteal phase stays close to
  /// two weeks.
  static const int lutealDays = 14;

  /// Which day of the cycle ovulation is expected on.
  ///
  /// Counted back from the next period, not forward from the last one. The app
  /// used to place it at the midpoint of the cycle, which is right only when
  /// the cycle happens to be 28 days:
  ///
  ///   cycle 28 -> midpoint 14, counted back 14  (agree)
  ///   cycle 35 -> midpoint 17, counted back 21  (four days out)
  ///   cycle 21 -> midpoint 10, counted back  7  (three days out)
  ///
  /// Returns null when no valid day exists, and NEVER throws.
  ///
  /// It used to throw. `clamp` raises ArgumentError when its lower bound
  /// exceeds its upper one, which happens whenever `bleed >= cycle - 1` —
  /// 779 of the 2116 cycle/bleed pairs between 0 and 45. The calendar called
  /// it with unvalidated stored values from inside build(), so a signup typo
  /// of a 21-day cycle with a 25-day period stopped the home screen
  /// rendering. It also returned day 14 for cycles shorter than 8, placing
  /// ovulation outside the cycle entirely.
  ///
  /// Null means "no mathematically valid estimate" and callers must draw
  /// nothing. It does not mean she did not ovulate, and a returned day is an
  /// arithmetic estimate only — see [lutealDays], WHICH IS NOT CLINICALLY
  /// VALIDATED.
  static int? ovulationDayOfCycle(int cycleDays, {int bleedDays = 5}) {
    if (!isSupportedCycle(cycleDays)) return null;
    if (bleedDays < minSupportedBleed) return null;

    final earliest = bleedDays + 1; // never during the bleeding
    final latest = cycleDays - 1; // never on the next period's first day
    if (earliest > latest) return null; // the bleed fills the whole cycle

    return (cycleDays - lutealDays).clamp(earliest, latest);
  }

  /// Days either side of the expected date shown for an irregular cycle.
  /// Matches the window the Django backend used, so the two agree.
  static const int irregularMarginDays = 5;

  /// Predicts the next period.
  ///
  /// Uses the average of real logged cycles once there are enough of them, and
  /// falls back to the values given at signup until then — so a new user still
  /// gets a prediction, and it sharpens as she logs.
  ///
  /// This is the Firebase equivalent of the backend's get_period_date(). The
  /// Django path is untouched and still uses the server for its own prediction.
  ///
  /// [lastStart] is only a FALLBACK anchor, used when there is no history at
  /// all. Callers pass period/latest.last_period_start, which the logging flow
  /// overwrites on every save — including a duplicate log — so it cannot be
  /// trusted to mark a cycle boundary. When history exists the anchor comes
  /// from [CycleStats.canonicalLastStart] instead.
  static CyclePrediction predictNext({
    required DateTime lastStart,
    required int fallbackCycleDays,
    required int fallbackBleedDays,
    required bool selfReportedRegular,
    required CycleStats stats,
    bool reportsPcos = false,
  }) {
    final cycleDays = (stats.averageCycleDays != null && stats.averageCycleDays! > 0)
        ? stats.averageCycleDays!
        : fallbackCycleDays;
    final bleedDays = (stats.averageBleedDays != null && stats.averageBleedDays! > 0)
        ? stats.averageBleedDays!
        : fallbackBleedDays;

    // The canonical history wins over the settings document. Given Jan 1,
    // Jan 4 (duplicate), Feb 1, this anchors on Feb 1 as a real boundary and
    // never on Jan 4 — a mistaken tap cannot move her whole forecast.
    final anchor = stats.canonicalLastStart ?? lastStart;
    final expected = anchor.add(Duration(days: cycleDays));

    // Prefer what the logs actually show over what was reported at signup.
    //
    // When the logs cannot answer — fewer than two surviving intervals, or an
    // observation excluded by either filter — the app no longer falls back to
    // her signup answer for the WIDTH of the window. It used to, and because
    // that answer defaults to "regular" the result was a single confident
    // date resting on one interval, or on a history whose long half had just
    // been filtered away. An unknown is not a "yes".
    //
    // The width used instead is [irregularMarginDays], the margin the app
    // already applies when it knows the cycle is irregular. It is not a new
    // number and not a measurement of her uncertainty; it is the existing
    // "we cannot promise a day" width. What this expresses is the state, not
    // a quantity — see PredictionState.insufficientHistory.
    // [selfReportedRegular] is retained in the signature for callers but no
    // longer decides the width. It is a claim, not an observation, and it
    // defaults to "regular", so honouring it was how an unknown became a
    // promise.
    // Only a measured "regular" earns a single date. Measured-irregular and
    // not-yet-measurable both get the window.
    final measuredRegular = stats.isRegular;
    final irregular = measuredRegular != true;

    // PCOS always gets a window, even if the cycle looks regular so far —
    // presenting a single confident date to someone whose cycles are medically
    // unpredictable would overstate what this arithmetic can know.
    // Endometriosis and fibroids mainly affect bleeding rather than timing, and
    // infections (yeast, UTI, BV) do not affect cycle timing at all, so none of
    // them change the prediction.
    final int margin;
    if (reportsPcos) {
      margin = pcosMarginDays;
    } else if (irregular) {
      margin = irregularMarginDays;
    } else {
      margin = 0;
    }

    return CyclePrediction(
      from: expected.subtract(Duration(days: margin)),
      to: expected.add(Duration(days: margin)),
      cycleDays: cycleDays,
      bleedDays: bleedDays,
      // The chain the average actually rests on, not every row in the
      // history. It used to report cycleCount, which counts episodes whose
      // intervals were rejected — "based on 5 cycles" when two of the four
      // intervals had been discarded. Nothing rendered it, so this corrects a
      // latent overstatement rather than a visible one.
      basedOnCycles: stats.averageCycleDays != null ? stats.usablePeriods : 0,
    );
  }

  /// [reportedCycleDays] is what she told the app at signup. It is only used
  /// as the yardstick for spotting a missed log when her own history is too
  /// short to provide one, and never as a value to average.
  static CycleStats statsFrom(
    List<PeriodEntry> rawEntries, {
    int? reportedCycleDays,
  }) {
    if (rawEntries.isEmpty) return CycleStats.empty;

    // Collapse duplicate logs before anything is counted, so cycleCount, the
    // averages and the anchor all describe the same episodes the calendar
    // draws. fetchAll already returns normalised entries; repeating it here is
    // free (the operation is idempotent) and means a caller that builds
    // entries by hand still gets the canonical reading.
    final entries = normalize(rawEntries);

    // Which gaps feed which figure — stated here once, because they are three
    // different samples and reading the code out of order suggests otherwise:
    //
    //   allGaps    every interval between episodes
    //   plausible  allGaps minus anything outside 15..60          (filter 1)
    //   measured   plausible minus probable missed logs           (filter 2)
    //   gaps       the most recent `averagingWindow` of measured  (filter 3)
    //   forAverage gaps, minus the single highest and lowest when >= 5
    //              -> AVERAGE CYCLE comes from here
    //   gaps       -> SPREAD comes from here, untrimmed
    //   excluded   everything filter 1 or filter 2 removed
    //              -> CONFIDENCE is reduced by this, and by nothing else
    //
    // The average and the spread deliberately use different samples: the
    // average is trimmed so one unusual month does not move every future
    // prediction, while the spread is not, so the app stays honest about how
    // much her cycles actually vary. This pass does not change either
    // definition; it only writes them down.
    final allGaps =
        entries.map((e) => e.daysSincePrevious).whereType<int>().toList();

    // A gap above the maximum is a *missed* log rather than a duplicate — there
    // is no way to collapse it, so it is simply not measurable. Gaps below the
    // minimum can no longer occur; the bound is kept so the rule stays stated
    // in one place if normalisation is ever relaxed.
    final plausible = allGaps
        .where((g) => g >= minPlausibleCycle && g <= maxPlausibleCycle)
        .toList();

    // Inside that range there is a second kind of unmeasurable gap: one that
    // is really two cycles with the middle period never logged. It sits well
    // inside the bounds above — two 28-day cycles read as a single 58-day one
    // — so nothing so far rejects it, and averaging it in roughly doubles her
    // predicted cycle. That is the difference between "your period is due in
    // three days" and "in a month", from one forgotten log or one deleted
    // date.
    final recent = plausible.length > averagingWindow
        ? plausible.sublist(plausible.length - averagingWindow)
        : plausible;
    final reference = referenceCycle(recent, reportedCycleDays);
    final measured = reference == null
        ? plausible
        : plausible.where((g) => !looksLikeMissedLog(g, reference)).toList();

    // Then keep only the most recent few, so the figures follow her current
    // cycle rather than her all-time one.
    final gaps = measured.length > averagingWindow
        ? measured.sublist(measured.length - averagingWindow)
        : measured;

    // How many intervals were thrown away, by either filter.
    //
    // This is what stops a discarded observation from buying confidence. Both
    // filters remove LONG gaps, so what survives an alternating history is the
    // short half of it — which has, by construction, no spread at all. The app
    // was then reporting a 25/50 pattern as a flawless 25-day cycle with a
    // single confident date. The intervals are still not measurable; what
    // changes is that their absence is now recorded rather than forgotten.
    final excluded = allGaps.length - measured.length;

    final bleeds = entries.map((e) => e.lengthOfPeriod).toList();
    final avgBleed = bleeds.isEmpty
        ? null
        : (bleeds.reduce((a, b) => a + b) / bleeds.length).round();

    if (gaps.isEmpty) {
      return CycleStats(
        cycleCount: entries.length,
        averageBleedDays: avgBleed,
        canonicalLastStart: entries.last.start,
        usableGaps: 0,
        excludedObservations: excluded,
      );
    }

    // With five or more cycles, drop the single shortest and longest before
    // averaging. One unusual month — illness, exams, travel — should not shift
    // every prediction that follows.
    final forAverage = gaps.length >= 5
        ? (([...gaps]..sort()).sublist(1, gaps.length - 1))
        : gaps;
    final avg =
        (forAverage.reduce((a, b) => a + b) / forAverage.length).round();
    // Needs 3 periods (2 gaps) before a spread means anything.
    final variance = gaps.length >= 2
        ? ((gaps.reduce((a, b) => a > b ? a : b) -
                    gaps.reduce((a, b) => a < b ? a : b)) /
                2)
            .round()
        : null;

    return CycleStats(
      cycleCount: entries.length,
      lastCycleDays: gaps.last,
      averageCycleDays: avg,
      varianceDays: variance,
      averageBleedDays: avgBleed,
      canonicalLastStart: entries.last.start,
      usableGaps: gaps.length,
      excludedObservations: excluded,
    );
  }
}
