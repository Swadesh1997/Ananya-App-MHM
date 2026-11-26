import 'package:ananya/services/period_history_service.dart';

/// What the app is able to say about the next period right now.
///
/// The width of the prediction window is not enough on its own: a ±5 day
/// range drawn because her cycles genuinely vary and the same range drawn
/// because nothing has been measured yet look identical on screen but mean
/// opposite things. The state says which.
enum PredictionState {
  /// She has logged nothing yet.
  noHistory,

  /// Fewer than two surviving intervals, or an interval was thrown away by
  /// one of the filters. A date is still shown — it is the best estimate
  /// available — but nothing about her cycle has been measured.
  ///
  /// This says something about the DATA, not about her body. It must never be
  /// presented as irregularity: the app used to collapse every non-regular
  /// reading into "Irregular", so a girl who had logged one period was told
  /// her cycles were irregular on the strength of no evidence at all.
  insufficientHistory,

  /// Two or more clean intervals, and they are steady by the app's working
  /// definition. THAT DEFINITION IS NOT CLINICALLY VALIDATED.
  measuredRegular,

  /// Two or more clean intervals, and they vary.
  measuredIrregular,

  /// A long stretch with no logged period. Recognised only when the product
  /// supplies a threshold — see [CycleSnapshot.longAbsenceThresholdDays].
  /// NO THRESHOLD IS SET IN THIS CODEBASE; this state is currently
  /// unreachable by design and awaits a clinical decision.
  longAbsence,

  /// There is history, but no cycle length anyone can justify predicting
  /// from.
  noPrediction,
}

/// One reading of a user's cycle, computed once per load.
///
/// It exists because three widgets used to compute this independently. The
/// home ring read the reported cycle length from Firestore while the card
/// beneath it read the same value from the device copy, and those two sources
/// disagree whenever the local copy is stale or absent — which it is on a
/// cold start, because the write that syncs them races the card's own load.
/// With a 55-day interval in the history that disagreement is total: judged
/// against a reported 28 the interval is rejected and the app falls back to
/// 28 days, judged against nothing it is accepted and the app reports a
/// 55-day cycle. Both appeared on the same screen at the same time.
///
/// Everything below is derived from exactly one (history, settings) pair, so
/// the same inputs always produce the same snapshot and every consumer reads
/// the same numbers.
class CycleSnapshot {
  /// Normalised episodes, oldest first.
  final List<PeriodEntry> entries;

  final CycleStats stats;

  /// Null when there is nothing to predict from.
  final CyclePrediction? prediction;

  final PredictionState state;

  /// Days between the most recent logged period and [today]. Null when
  /// nothing has been logged.
  ///
  /// The engine had no concept of elapsed time — `predictNext` takes no
  /// "today" — so it could not tell a user who signed up yesterday from one
  /// who had not menstruated for a year. Both produced the same confident
  /// countdown. This is the value a threshold would be compared against.
  final int? daysSinceLastPeriod;

  /// How many whole cycles the prediction had to be rolled forward to reach a
  /// date that has not passed. Each one is a predicted period that did not
  /// arrive. Recorded, not acted on.
  final int cyclesRolledForward;

  /// What she reported at signup, after validation. Null when absent or
  /// outside the supported range.
  final int? reportedCycleDays;
  final int? reportedBleedDays;
  final bool reportsPcos;

  /// True when the settings came from the device copy rather than the server.
  /// Surfaced so a stale snapshot is visible rather than silently different.
  final bool settingsFromDeviceCopy;

  /// The upcoming window, already rolled forward past any cycles that did
  /// not arrive. Null when there is no prediction.
  final DateTime? windowFrom;
  final DateTime? windowTo;

  final DateTime today;

  const CycleSnapshot({
    required this.entries,
    required this.stats,
    required this.prediction,
    required this.state,
    required this.daysSinceLastPeriod,
    required this.cyclesRolledForward,
    required this.reportedCycleDays,
    required this.reportedBleedDays,
    required this.reportsPcos,
    required this.settingsFromDeviceCopy,
    required this.today,
    this.windowFrom,
    this.windowTo,
  });

  /// Days after which a run without a logged period becomes [
  /// PredictionState.longAbsence].
  ///
  /// Null, deliberately. A prolonged absence of menstruation is a clinical
  /// matter and the number belongs to a clinician, not to this file. The
  /// machinery is here so that supplying it later is a configuration change
  /// rather than a redesign; until then the state is never entered.
  static const int? longAbsenceThresholdDays = null;

  /// The one date every consumer counts to: the middle of the window.
  DateTime? get expectedDate {
    final p = prediction;
    if (p == null) return null;
    return windowFrom!
        .add(Duration(days: windowTo!.difference(windowFrom!).inDays ~/ 2));
  }

  int? get daysUntilExpected {
    final e = expectedDate;
    if (e == null) return null;
    return e.difference(today).inDays;
  }

  /// The day of the cycle ovulation is estimated for, or null when no valid
  /// estimate exists. Callers must draw nothing when it is null.
  int? get ovulationDayOfCycle {
    final p = prediction;
    if (p == null) return null;
    return PeriodHistoryService.ovulationDayOfCycle(
      p.cycleDays,
      bleedDays: p.bleedDays,
    );
  }

  /// The estimated ovulation date in the upcoming cycle, or null.
  DateTime? get ovulationDate {
    final day = ovulationDayOfCycle;
    final start = expectedDate;
    if (day == null || start == null) return null;
    // Day 1 of the cycle IS the start date, so day n is n-1 days after it.
    return start.add(Duration(days: day - 1));
  }

  /// Whether a single confident date may be shown. False whenever the engine
  /// cannot back one up.
  bool get hasConfidentDate =>
      state == PredictionState.measuredRegular &&
      prediction != null &&
      !prediction!.hasWindow;

  /// Whether the app has measured her cycle at all.
  ///
  /// The ONLY gate a consumer may use to decide between describing her cycle
  /// and describing the data. Note that this is not `varianceDays != null`:
  /// a spread can be computed from a sample an interval was removed from,
  /// and reading it back was exactly how "±0 days" survived the filtering of
  /// an alternating history.
  bool get isMeasured =>
      state == PredictionState.measuredRegular ||
      state == PredictionState.measuredIrregular;

  /// The half-width of the shown window, in days. Always agrees with
  /// [windowFrom]/[windowTo] because it is derived from them.
  int get windowHalfWidthDays {
    final f = windowFrom, t = windowTo;
    if (f == null || t == null) return 0;
    return t.difference(f).inDays ~/ 2;
  }

  /// The spread to print beside "based on n cycles", or null when there is
  /// nothing honest to print. Null unless the reading is measured.
  int? get measuredSpreadDays => isMeasured ? stats.varianceDays : null;

  /// How many logged periods the measurement rests on. Null when unmeasured.
  int? get measuredOnPeriods => isMeasured ? stats.usablePeriods : null;

  /// True once today has reached the window but passed the expected date.
  ///
  /// The window is rolled forward on its END, deliberately, so a wide window
  /// can straddle today — her period is due any day now. The date shown is
  /// the window's MIDDLE, so for up to a few days it sits behind today and
  /// the countdown goes negative. That was being rendered as "Today", every
  /// day, for as long as it lasted.
  bool get isWithinWindowPastExpected {
    final f = windowFrom, t = windowTo, e = expectedDate;
    if (f == null || t == null || e == null) return false;
    return !today.isBefore(f) && !today.isAfter(t) && today.isAfter(e);
  }

  /// Whether prediction reminders may be scheduled at all.
  bool get allowsReminders =>
      state != PredictionState.noPrediction &&
      state != PredictionState.longAbsence &&
      prediction != null;

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  /// Builds a snapshot from already-resolved inputs. Pure: no IO, no clock.
  static CycleSnapshot build({
    required List<PeriodEntry> entries,
    required Map<String, dynamic>? settings,
    required DateTime today,
    bool settingsFromDeviceCopy = false,
    int? longAbsenceThreshold = longAbsenceThresholdDays,
  }) {
    final day = DateTime(today.year, today.month, today.day);

    // Stored settings are validated here rather than trusted. Values written
    // before the signup form validated anything are still in Firestore, and
    // an out-of-range one used to reach the calendar's ovulation call and
    // crash it.
    final rawCycle = _asInt(settings?['days_between_period']);
    final rawBleed = _asInt(settings?['length_of_period']);
    final reportedCycle =
        PeriodHistoryService.isSupportedCycle(rawCycle) ? rawCycle : null;
    final reportedBleed =
        (rawBleed != null && rawBleed >= PeriodHistoryService.minSupportedBleed)
            ? rawBleed
            : null;
    final pcos = PeriodHistoryService.hasPcos(settings?['health_condition']);

    final normalised = PeriodHistoryService.normalize(entries);
    final stats = PeriodHistoryService.statsFrom(
      normalised,
      reportedCycleDays: reportedCycle,
    );

    final anchor = stats.canonicalLastStart;
    final daysSince =
        anchor == null ? null : day.difference(anchor).inDays;

    // With no anchor there is nothing to count from. The settings document
    // can still carry a last_period_start for a user who predates the history
    // collection; seeding turns it into an entry, so by the time this runs an
    // empty history means an empty history.
    if (anchor == null) {
      return CycleSnapshot(
        entries: normalised,
        stats: stats,
        prediction: null,
        state: PredictionState.noHistory,
        daysSinceLastPeriod: null,
        cyclesRolledForward: 0,
        reportedCycleDays: reportedCycle,
        reportedBleedDays: reportedBleed,
        reportsPcos: pcos,
        settingsFromDeviceCopy: settingsFromDeviceCopy,
        today: day,
      );
    }

    // A cycle length is needed to predict anything. Without a measured
    // average and without a usable signup answer there is no honest number to
    // add to the anchor, so the app declines rather than inventing one.
    final haveCycle = stats.averageCycleDays != null || reportedCycle != null;
    if (!haveCycle) {
      return CycleSnapshot(
        entries: normalised,
        stats: stats,
        prediction: null,
        state: PredictionState.noPrediction,
        daysSinceLastPeriod: daysSince,
        cyclesRolledForward: 0,
        reportedCycleDays: reportedCycle,
        reportedBleedDays: reportedBleed,
        reportsPcos: pcos,
        settingsFromDeviceCopy: settingsFromDeviceCopy,
        today: day,
      );
    }

    final prediction = PeriodHistoryService.predictNext(
      lastStart: anchor,
      fallbackCycleDays: reportedCycle ?? stats.averageCycleDays!,
      fallbackBleedDays: reportedBleed ?? stats.averageBleedDays ?? 5,
      // Retained for the signature; the window no longer rests on it.
      selfReportedRegular: settings?['is_period_regular'] == true,
      stats: stats,
      reportsPcos: pcos,
    );

    // Roll the window forward to the cycle that has not started yet, counting
    // how many were skipped. Rolls on the window END, not its start: for a
    // wide window the range can straddle today, and rolling on the start
    // would skip a month exactly when the forecast matters most.
    var from = prediction.from;
    var to = prediction.to;
    var rolls = 0;
    if (prediction.cycleDays > 0) {
      while (to.isBefore(day)) {
        from = from.add(Duration(days: prediction.cycleDays));
        to = to.add(Duration(days: prediction.cycleDays));
        rolls++;
      }
    }

    final longAbsence = longAbsenceThreshold != null &&
        daysSince != null &&
        daysSince >= longAbsenceThreshold;

    // One decision, made once, for every consumer. The regularity label, the
    // confidence line, the window and the reminders all read this — they used
    // to reach their own conclusions from varianceDays, isRegular and the
    // signup answer independently, which is how the card came to print
    // "±0 days" beside a ten-day window.
    //
    // Order matters: a measured reading is only reached when nothing was
    // excluded AND two intervals survived, so filtering can never promote a
    // history into a more confident state.
    final PredictionState state;
    if (longAbsence) {
      state = PredictionState.longAbsence;
    } else if (!stats.hasEnoughForMeasurement ||
        stats.excludedObservations > 0) {
      state = PredictionState.insufficientHistory;
    } else if (stats.isRegular == true) {
      state = PredictionState.measuredRegular;
    } else {
      state = PredictionState.measuredIrregular;
    }

    return CycleSnapshot(
      entries: normalised,
      stats: stats,
      prediction: prediction,
      state: state,
      daysSinceLastPeriod: daysSince,
      cyclesRolledForward: rolls,
      reportedCycleDays: reportedCycle,
      reportedBleedDays: reportedBleed,
      reportsPcos: pcos,
      settingsFromDeviceCopy: settingsFromDeviceCopy,
      today: day,
      windowFrom: from,
      windowTo: to,
    );
  }

  /// Adapter for the legacy Django screens, which receive a server-shaped map
  /// rather than a history.
  ///
  /// It exists so those screens go through the same validation and the same
  /// nullable ovulation as everything else. Their numbers still come from the
  /// server and are NOT produced by this engine.
  static DateTime? _parseDate(dynamic raw) {
    if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
    if (raw is! String) return null;
    try {
      final part = raw.trim().split(' ').first.split('T').first;
      final d = DateTime.parse(part);
      return DateTime(d.year, d.month, d.day);
    } catch (_) {
      return null;
    }
  }

  static CycleSnapshot fromLegacyMap(
    Map<String, dynamic> data, {
    required DateTime today,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final from = _parseDate(data['period_start_from']);
    final to = _parseDate(data['period_start_to']) ?? from;

    final rawCycle = _asInt(data['days_between_period']);
    final rawBleed = _asInt(data['length_of_period']);
    final cycle =
        PeriodHistoryService.isSupportedCycle(rawCycle) ? rawCycle : null;
    final bleed =
        (rawBleed != null && rawBleed >= PeriodHistoryService.minSupportedBleed)
            ? rawBleed
            : null;

    // Without a parseable window or a supported cycle length there is nothing
    // this screen can honestly draw. It used to draw it anyway, from whatever
    // the server sent, straight into the ovulation call that crashed.
    if (from == null || to == null || cycle == null || bleed == null) {
      return CycleSnapshot(
        entries: const [],
        stats: CycleStats.empty,
        prediction: null,
        state: PredictionState.noPrediction,
        daysSinceLastPeriod: null,
        cyclesRolledForward: 0,
        reportedCycleDays: cycle,
        reportedBleedDays: bleed,
        reportsPcos: false,
        settingsFromDeviceCopy: false,
        today: day,
      );
    }

    var rolledFrom = from, rolledTo = to, rolls = 0;
    while (rolledTo.isBefore(day)) {
      rolledFrom = rolledFrom.add(Duration(days: cycle));
      rolledTo = rolledTo.add(Duration(days: cycle));
      rolls++;
    }

    return CycleSnapshot(
      entries: const [],
      stats: CycleStats.empty,
      prediction: CyclePrediction(
        from: from,
        to: to,
        cycleDays: cycle,
        bleedDays: bleed,
        // The server's figures, not this engine's. Claiming otherwise would
        // let the screen say "based on n cycles" about a number it did not
        // compute.
        basedOnCycles: 0,
      ),
      // The legacy path has no history to measure, so it can never be more
      // than an unearned estimate as far as this engine is concerned.
      state: PredictionState.insufficientHistory,
      daysSinceLastPeriod: null,
      cyclesRolledForward: rolls,
      reportedCycleDays: cycle,
      reportedBleedDays: bleed,
      reportsPcos: false,
      settingsFromDeviceCopy: false,
      today: day,
      windowFrom: rolledFrom,
      windowTo: rolledTo,
    );
  }
}
