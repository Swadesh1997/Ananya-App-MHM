import 'package:ananya/services/local_period_store.dart';
import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/period_history_service.dart';
import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/calender.dart';
import 'package:ananya/widgets/cycle_visuals.dart';
import 'package:ananya/widgets/circle_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/app_dialog.dart';
import 'package:ananya/services/user_profile.dart';

class PeriodCycleInformation extends StatefulWidget {
  /// The one reading of her cycle, computed once by the screen above.
  /// Every number this widget shows comes from here.
  final CycleSnapshot snapshot;

  final Map<String, dynamic> data;
  final Map<String, dynamic>? cohort;
  final bool issuperuser;

  /// Called after a logged period is removed, so the screen that owns the
  /// prediction can recompute it. Without this the calendar would drop the
  /// deleted band while the ring above it went on counting down to a date
  /// derived from the period that no longer exists.
  final VoidCallback? onHistoryChanged;

  const PeriodCycleInformation(
      {required this.issuperuser,
      required this.snapshot,
      this.cohort,
      required this.data,
      this.onHistoryChanged,
      super.key});

  @override
  State<PeriodCycleInformation> createState() => _PeriodCycleInformationState();
}

class _PeriodCycleInformationState extends State<PeriodCycleInformation> {
  String? selectedUserId;

  /// Read from the snapshot rather than recomputed here.
  ///
  /// This widget used to call statsFrom itself, with a reportedCycleDays it
  /// fetched from the device copy while the screen above it used the value
  /// from Firestore. When those two disagree — a cold start, a first sign-in,
  /// any load where the local copy has not been written yet — the ring and
  /// the statistics under it were computed with the missed-log filter in
  /// opposite states, and a single 55-day interval made them disagree
  /// completely: 28 days and "not yet measured" above, "average cycle 55,
  /// based on 2 cycles" below, at the same moment on the same screen.
  CycleStats get _stats => widget.snapshot.stats;

  /// Every period the user has actually logged. Needed by the calendar, which
  /// otherwise has nothing to draw in the current month — the prediction is by
  /// definition in the future.
  List<PeriodEntry> get _entries => widget.snapshot.entries;

  /// Every stored date, before normalisation. Needed so the logs collapsed
  /// into one episode can still be seen and removed individually.
  List<DateTime> _rawDates = const [];

  /// True while a logged period is saved on this device but not yet on the
  /// server. Shown so that someone tracking without a connection can see her
  /// data was kept, rather than wondering whether it was lost.
  bool _pendingSync = false;

  /// The period currently being removed, so its row can show progress and
  /// refuse a second tap.
  DateTime? _removingDate;

  /// Greeting name. Null until resolved, and null when there is none stored —
  /// the greeting then simply drops the name rather than trailing a comma.
  String? _firstName;

  @override
  void initState() {
    super.initState();
    getSelectedUser().then((id) {
      setState(() {
        selectedUserId = id;
      });
    });
    _loadStats();
    _loadRawDates();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await UserProfile.resolve();
    if (!mounted || name == null) return;
    setState(() => _firstName = UserProfile.firstNameOf(name));
  }

  /// Only the sync marker is loaded here now. The history and the statistics
  /// arrive in the snapshot, so this widget can no longer reach a different
  /// answer from the screen above it.
  Future<void> _loadStats() async {
    final pending = await LocalPeriodStore.hasPending();
    if (!mounted) return;
    setState(() => _pendingSync = pending);
  }

  /// The raw logs collapsed into the episode starting on [start], shown only
  /// when there is more than one.
  ///
  /// An episode is one period as far as the maths is concerned, and the row
  /// above says so. But the dates behind it are what she actually tapped, and
  /// until now they were unreachable: logging 1 January by mistake and then
  /// the real date, 10 January, produced a single row reading "1 January",
  /// no sign that a second date existed, and a delete that removed both.
  ///
  /// This makes no guess about which she meant. It shows what is stored and
  /// lets her take one away.
  List<Widget> _extraLogsFor(
      DateTime start, bool isBangla, AppLocalizations loc) {
    final dates = PeriodHistoryService.datesInEpisode(
      [for (final d in _rawDates) PeriodEntry(start: d, lengthOfPeriod: 0)],
      start,
    );
    if (dates.length < 2) return const [];

    return [
      const SizedBox(height: 6),
      Text(
        loc.logged_dates_in_entry,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.3,
          color: ACCENT.withValues(alpha: 0.45),
        ),
      ),
      for (final d in dates)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          // Wrap, not Row. The date and the link together are wider than the
          // column they sit in once the text is long — a Bangla date beside
          // "এই তারিখটি মুছুন", or any label at a large system font size —
          // and a Row has nowhere to put the excess but off the edge. This
          // drops the link onto its own line instead of clipping it, which
          // matters because the link is the only way to correct a date.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                dayAndMonthShort(d, isBangla),
                style: TextStyle(
                  fontSize: 11,
                  color: ACCENT.withValues(alpha: 0.7),
                ),
              ),
              InkWell(
                onTap: _removingDate == d ? null : () => _removeSingleLog(d),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  child: _removingDate == d
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : Text(
                          loc.remove_this_date,
                          style: TextStyle(
                            fontSize: 10.5,
                            decoration: TextDecoration.underline,
                            color: ACCENT.withValues(alpha: 0.6),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// Removes one stored date, leaving the others in its episode alone.
  Future<void> _removeSingleLog(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _removingDate = date);
    try {
      await PeriodHistoryService.deleteSingleLog(uid: uid, date: date);
      await _loadRawDates();
    } catch (e) {
      debugPrint('single log delete failed: $e');
    }
    if (!mounted) return;
    setState(() => _removingDate = null);
    widget.onHistoryChanged?.call();
  }

  Future<void> _loadRawDates() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final dates = await PeriodHistoryService.fetchRawLocal(uid);
    if (!mounted) return;
    setState(() => _rawDates = dates);
  }

  Future<String?> getSelectedUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('cohort-user');
  }

  void onSelectUser(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cohort-user', id);
    setState(() {
      selectedUserId = id;
    });
  }

  Map<String, dynamic> getData() {
    // Every figure below comes from the snapshot. The roll-forward, the
    // window and the cycle length were all recomputed here previously, from
    // values this widget sourced separately — which is how the ring and the
    // card under it came to disagree.
    final snapshot = widget.snapshot;
    final DateTime nextFrom = snapshot.windowFrom!;
    final DateTime nextTo = snapshot.windowTo!;
    final int daysBetweenCycle = snapshot.prediction!.cycleDays;
    final int cycleLength = snapshot.prediction!.bleedDays;

    // Periods the user actually recorded. Without these the calendar showed
    // nothing at all in the current month: it was drawn only from the
    // prediction, which always sits in a future month.
    final List<DateTime> loggedDays = [];
    for (final e in _entries) {
      for (int i = 0; i < e.lengthOfPeriod; i++) {
        loggedDays.add(DateTime(e.start.year, e.start.month, e.start.day + i));
      }
    }

    // Forecasts, projected from the upcoming cycle rather than from a start
    // date that may already have passed.
    //
    // Periods only. The calendar no longer marks ovulation: the blue discs
    // and their key answered a question this screen is not for, and an
    // estimate counted back from a predicted date is the least certain thing
    // the app computes — drawn on a calendar it reads as a fact about a
    // specific day. The phase timeline above still names ovulation as one
    // stretch of the cycle, which is a shape rather than a date.
    List<DateTime> menstrualDays = [];

    // Projected from the expected date rather than the window's near edge,
    // for the same reason as the countdown above: marking the calendar from
    // the earliest possible day puts the shaded period five days before it is
    // actually due, and the calendar then disagrees with the ring.
    final projectionStart = nextFrom.add(
      Duration(days: nextTo.difference(nextFrom).inDays ~/ 2),
    );

    for (int j = 0; j < 3; j++) {
      DateTime currentCycleStartDate =
      projectionStart.add(Duration(days: j * daysBetweenCycle));

      for (int i = 0; i < cycleLength; i++) {
        menstrualDays.add(currentCycleStartDate.add(Duration(days: i)));
      }
    }
    final bool singleDay = nextFrom.isAtSameMomentAs(nextTo);
    final bool bn = Localizations.localeOf(context).languageCode == 'bn';

    final nowDay = DateTime.now();

    // The date the period is actually expected — the middle of the window,
    // not its near edge.
    //
    // This counted down to nextFrom, which for an irregular cycle is the
    // earliest day it could conceivably start. With a 1 September period, a
    // 28-day cycle and the ±5 day irregular margin, the window runs 24
    // September to 4 October and the expected date is the 29th. On the 23rd
    // the ring therefore read "1 day to go" for something six days away —
    // presenting the edge of the uncertainty as though it were the forecast,
    // which is both alarming and wrong.
    final expectedStart = nextFrom.add(
      Duration(days: nextTo.difference(nextFrom).inDays ~/ 2),
    );

    final daysUntil = expectedStart
        .difference(DateTime(nowDay.year, nowDay.month, nowDay.day))
        .inDays;

    return {
      'next_start': nextFrom,
      'days_until': daysUntil,
      // Full month name for the headline date — "5 September", not "5 Sep".
      // A window that straddles two months keeps the short forms: two full
      // names side by side ("September - October") cannot fit beside the day
      // number and the countdown ring on a narrow phone.
      'next_period_month': singleDay || nextFrom.month == nextTo.month
          ? monthFull(nextFrom, bn)
          : "${monthShort(nextFrom, bn)} - ${monthShort(nextTo, bn)}",
      'next_period_day': singleDay
          ? localeNumber(nextFrom.day, bn)
          : "${localeNumber(nextFrom.day, bn)} - ${localeNumber(nextTo.day, bn)}",
      'period_date_range': singleDay
          ? dayAndMonthShort(nextFrom, bn)
          : "${dayAndMonthShort(nextFrom, bn)} - ${dayAndMonthShort(nextTo, bn)}",
      'menstrual_days': menstrualDays,
      'logged_days': loggedDays,
      'last_start': _entries.isEmpty ? null : _entries.last.start,
      // Which day of the current cycle today is. Null until something has been
      // logged — it is counted from a real period, never from the forecast.
      'cycle_day': _entries.isEmpty
          ? null
          : DateTime(nowDay.year, nowDay.month, nowDay.day)
                  .difference(_entries.last.start)
                  .inDays +
              1,
      'cycle_length': daysBetweenCycle,
      'bleed_length': cycleLength,
    };
  }

  /// Ring countdown to the predicted start. The arc shows how far through the
  /// current cycle she is, so the number has something to sit against — "17
  /// days" alone says nothing about whether that is early or nearly due.
  /// One statistic in its own soft tile.
  /// Base sizes for a tile's figure and its unit, before the shared scale.
  static const double _statValueSize = 18;
  static const double _statUnitSize = 11.5;

  /// Everything between a tile's outer edge and its text: the padding either
  /// side plus the hairline border, which is a pixel on each side.
  static const double _statInnerPadding = 12 + 10 + 2;
  static const double _statGap = 8;

  /// The figure and unit of one tile, as one span.
  ///
  /// Built here rather than inline so the same span can be measured before it
  /// is drawn — see [_sharedStatScale].
  TextSpan _statValueSpan(String value, String? unit, double scale,
      {bool muted = false}) {
    return TextSpan(
      children: [
        TextSpan(
          text: value,
          style: TextStyle(
            fontSize: _statValueSize * scale,
            fontWeight: FontWeight.bold,
            color: muted ? ACCENT.withValues(alpha: 0.45) : ACCENT,
          ),
        ),
        if (unit != null)
          TextSpan(
            text: ' $unit',
            style: TextStyle(
              fontSize: _statUnitSize * scale,
              fontWeight: FontWeight.w600,
              color: ACCENT.withValues(alpha: 0.70),
            ),
          ),
      ],
    );
  }

  /// One scale for all three tiles, set by whichever value is widest.
  ///
  /// Each tile used to shrink on its own, which meant they disagreed: a
  /// spelled-out "2 September" overran its tile and was scaled down while
  /// "2 October" beside it fitted and was not, so two figures of the same
  /// kind were drawn at two sizes. Measuring all three first and applying the
  /// tightest fit to every one keeps them a set.
  ///
  /// Measured with the real text engine, so the answer follows whatever font
  /// and system text size are actually in use rather than an assumption about
  /// character widths.
  ///
  /// The measurement must carry the SAME inherited style the tile will be
  /// drawn with. Without it the painter fell back to the platform font while
  /// the app draws in Inter, which is wider — so every value measured
  /// narrower than it rendered, the scale came out too generous, and
  /// "30 September" was cut to "30 Septembe".
  double _sharedStatScale(
      BuildContext context, List<TextSpan> spans, double available) {
    if (available <= 0) return 1;
    final inherited = DefaultTextStyle.of(context).style;

    var widest = 0.0;
    for (final span in spans) {
      final painter = TextPainter(
        text: TextSpan(style: inherited, children: [span]),
        textDirection: Directionality.of(context),
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }
    if (widest <= available) return 1;
    // A margin under the exact ratio. Shaping a Bangla conjunct, or a font
    // the measurement resolves slightly differently from the rasteriser, can
    // each cost a fraction of a pixel, and the cost of being a shade small is
    // nothing next to the cost of a clipped date.
    return (available / widest) * 0.96;
  }

  Widget _statTile(String label, TextSpan value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 13),
        decoration: BoxDecoration(
          // Was a 5% wash with no edge, which on the cream page left the tile
          // with no boundary at all — three figures floating rather than three
          // cards. The fill carries a little more weight now and the hairline
          // gives it a shape to sit in.
          color: PRIMARY_COLOR.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PRIMARY_COLOR.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: ACCENT.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 6),
            // The span arrives already sized by the scale all three tiles
            // share, so the common case is that this changes nothing and the
            // figures match. It is here only so that a measurement which is
            // off by a fraction shrinks a date rather than cutting it: a
            // slightly smaller "30 September" is readable, "30 Septembe" is
            // not.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                value,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cycle statistics measured from recorded history. A dash is shown until
  /// enough periods have been logged — never an invented number.
  Widget _buildStatTiles(Map<String, dynamic> periodData) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    final dayUnit = isBangla ? 'দিন' : 'days';

    final DateTime? lastStart = periodData['last_start'];

    // The same date the countdown ring aims at, read off the one snapshot
    // every part of this screen shares.
    final DateTime? nextExpected = widget.snapshot.expectedDate;

    // Tiles are stretched to a common height so a label that wraps to two lines
    // does not leave its neighbours short.
    //
    // LayoutBuilder because the shared scale needs to know how much room one
    // tile actually has, which depends on the width this row is given.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - _statGap * 2) / 3;
        final available = tileWidth - _statInnerPadding;

        // Averages rather than "last": one unusual month says little, and the
        // average is the figure the prediction actually runs on.
        final cycleValue = _stats.averageCycleDays == null
            ? '—'
            : localeNumber(_stats.averageCycleDays!, isBangla);

        // Measured at full size first; the scale that comes back is whatever
        // the widest of the three needs, and every tile then uses it.
        final atFullSize = [
          _statValueSpan(cycleValue,
              _stats.averageCycleDays == null ? null : dayUnit, 1,
              muted: _stats.averageCycleDays == null),
          _statValueSpan(
              lastStart == null ? '—' : dayAndMonthFull(lastStart, isBangla),
              null,
              1,
              muted: lastStart == null),
          _statValueSpan(
              nextExpected == null
                  ? '—'
                  : dayAndMonthFull(nextExpected, isBangla),
              null,
              1,
              muted: nextExpected == null),
        ];
        final scale = _sharedStatScale(context, atFullSize, available);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statTile(
                isBangla ? 'গড় চক্র' : 'Average cycle',
                _statValueSpan(cycleValue,
                    _stats.averageCycleDays == null ? null : dayUnit, scale,
                    muted: _stats.averageCycleDays == null),
              ),
              const SizedBox(width: _statGap),
              _statTile(
                isBangla ? 'শেষ পিরিয়ড' : 'Last period',
                _statValueSpan(
                    lastStart == null
                        ? '—'
                        : dayAndMonthFull(lastStart, isBangla),
                    null,
                    scale,
                    muted: lastStart == null),
              ),
              const SizedBox(width: _statGap),
              // The predicted date, in words.
              //
              // It was nowhere on this screen: the ring counts down in days
              // and the calendar shades the band, so finding the actual date
              // meant scrolling and counting squares. This is the same date
              // the ring counts to — the middle of the window — so the two
              // cannot disagree.
              _statTile(
                isBangla ? 'পরের পিরিয়ড' : 'Next period',
                _statValueSpan(
                    nextExpected == null
                        ? '—'
                        : dayAndMonthFull(nextExpected, isBangla),
                    null,
                    scale,
                    muted: nextExpected == null),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Says where the regular/irregular reading comes from. Deliberately does not
  /// quote a variance figure — a "±n days" number implies more precision than a
  /// handful of self-reported cycles supports.
  /// How many of the periods needed are in, as dots and as a figure.
  ///
  /// Filled dots are periods forming an unbroken usable chain, not simply rows
  /// logged. Bare dots read as decoration, so the count sits beside them and
  /// carries the weight — it is the one thing the eye should land on. Held in a
  /// white chip so it reads as a single component rather than stray marks, and
  /// so it lifts off the card without needing colour to do it.
  Widget _progressChip(int filled, int total, bool isBangla) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 11, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 7,
              height: 7,
              margin: EdgeInsets.only(right: i == total - 1 ? 9 : 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? ACCENT : Colors.transparent,
                // An outline rather than a faint fill: an empty step still
                // needs to look deliberate, not like a dot that failed to draw.
                border: i < filled
                    ? null
                    : Border.all(color: ACCENT.withValues(alpha: 0.28), width: 1.2),
              ),
            ),
          Text(
            '${localeNumber(filled, isBangla)}/${localeNumber(total, isBangla)}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: ACCENT,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// How much the estimate rests on, and what would improve it.
  ///
  /// The counting here has to match the algorithm rather than approximate it.
  /// Regularity is measurable once there are two usable intervals between
  /// periods, which is an unbroken run of three. Counting logged periods
  /// instead would claim the app can measure her cycle when a rejected gap
  /// means it cannot — and the old "3 - cycleCount" could also stick at "1
  /// more" forever, because it was floored at 1 and never allowed to reach 0.
  Widget _buildStatusSource() {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    final loc = AppLocalizations.of(context)!;
    final quiet = TextStyle(
      fontSize: 11.5,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: ACCENT.withValues(alpha: 0.55),
    );

    if (widget.snapshot.isMeasured) {
      // Only a measured reading may quote a spread. This used to branch on
      // `varianceDays != null`, which is computable from a sample an interval
      // was removed from — so an alternating 25/50 history printed
      // "based on 3 cycles · ±0 days" beside a ten-day window, the false
      // confidence simply having moved from the window into the text.
      //
      // Both figures now come from the snapshot, which withholds them unless
      // the state is measured.
      final v = widget.snapshot.measuredSpreadDays;
      final basis =
          localeNumber(widget.snapshot.measuredOnPeriods ?? 0, isBangla);
      final spread = v == null
          ? ''
          : ' · ${loc.estimate_variation(localeNumber(v, isBangla))}';
      return Text('${loc.estimate_based_on_cycles(basis)}$spread',
          style: quiet);
    }

    // Unmeasured. Two shapes, because the reasons differ: she has not logged
    // enough yet, or something she logged could not be used. Neither says
    // anything about her cycle.
    final have = _stats.usablePeriods;
    const need = CycleStats.periodsForMeasurement;

    if (have >= need) {
      // Enough periods, but an interval was excluded, so there is no count to
      // count towards. Saying "1 more period" here would be a lie.
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(loc.keep_logging_to_learn_pattern, style: quiet),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _progressChip(have, need, isBangla),
        const SizedBox(height: 9),
        Text(
          have == 0
              ? loc.no_period_data_yet
              : loc.periods_added_of_total(
                  localeNumber(have, isBangla),
                  localeNumber(need, isBangla),
                ),
          style: TextStyle(
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: ACCENT.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 2),
        // The remedy, which nothing used to mention: a date she remembers can
        // be entered today, so she need not wait months for the app to catch
        // up. It is also the fix for a rejected gap, which means a period is
        // missing from the middle of her history. Wraps freely — on a narrow
        // phone this is the line that runs long.
        //
        // Tappable, because telling her to add an earlier date and leaving her
        // to find the way was the whole problem: the only route is a button
        // labelled "log NEW period", which reads as the wrong door for an old
        // one. The picker behind it already accepts twelve months back — the
        // capability was there, the path to it was not.
        InkWell(
          onTap: _openPeriodLog,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            // Padding, not margin: it makes the row a thumb-sized target
            // without moving the text away from the line above it.
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    loc.add_earlier_period_hint,
                    style: quiet.copyWith(
                      color: PRIMARY_COLOR,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: PRIMARY_COLOR.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 14, color: PRIMARY_COLOR),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the period-logging flow.
  ///
  /// Shared by the hint above and the button at the bottom of the screen, so
  /// the two cannot end up pointing at different places — and so a superuser
  /// is sent to pick a girl first from either one.
  void _openPeriodLog() {
    if (widget.issuperuser) {
      Navigator.pushNamed(context, '/choose-user', arguments: true);
    } else {
      Navigator.pushNamed(context, '/unlock-process/3', arguments: true);
    }
  }

  /// Reassurance, not an error: the data is safe on the phone and will go up
  /// on its own. Deliberately worded so it never reads as "something failed".
  Widget _buildOfflineNotice() {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: SECONDARY_COLOR.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 18, color: SECONDARY_COLOR.withValues(alpha: 0.75)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isBangla
                    ? 'আপনার তথ্য এই ফোনে সংরক্ষিত আছে। ইন্টারনেট এলে নিজে থেকেই সংরক্ষণ হয়ে যাবে।'
                    : 'Your data is saved on this phone. It will back up on its own once you are online.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: ACCENT.withValues(alpha: 0.70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The logged periods, each removable.
  ///
  /// A mis-typed date used to be permanent: there was no way to correct or
  /// delete one from inside the app, so a wrong entry sat in the history
  /// skewing every prediction after it. Rows are the canonical episodes, so a
  /// duplicate that was collapsed into another period is not offered as a
  /// separate thing to delete.
  Widget _buildLoggedPeriods() {
    final loc = AppLocalizations.of(context)!;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    // Newest first: the entry someone wants to correct is almost always the
    // one just logged.
    final rows = _entries.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Text(
            loc.logged_periods,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ACCENT,
            ),
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text(
              loc.no_periods_logged_yet,
              style: TextStyle(
                fontSize: 12.5,
                color: ACCENT.withValues(alpha: 0.55),
              ),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                // A hairline between rows rather than three free-floating
                // lines. Not on the last one, so the list ends cleanly.
                border: i == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: ACCENT.withValues(alpha: 0.07),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 4, right: 11),
                    decoration: BoxDecoration(
                      color: PRIMARY_COLOR.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayAndMonthShort(rows[i].start, isBangla),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ACCENT,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          loc.bleed_days_label(
                              localeNumber(rows[i].lengthOfPeriod, isBangla)),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: ACCENT.withValues(alpha: 0.48),
                          ),
                        ),
                        ..._extraLogsFor(rows[i].start, isBangla, loc),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _removingDate == rows[i].start
                        ? null
                        : () => _confirmRemove(rows[i]),
                    style: TextButton.styleFrom(
                      // Muted ink, not brand red. Red is what marks a
                      // period on the calendar above; spending it on three
                      // delete links made them the loudest thing in a list
                      // whose subject is the dates.
                      foregroundColor: ACCENT.withValues(alpha: 0.55),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _removingDate == rows[i].start
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                loc.remove,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// Asks before removing. Deleting health data is not undoable and the row is
  /// one tap away from the calendar, so it must not happen on a stray tap.
  Future<void> _confirmRemove(PeriodEntry entry) async {
    final loc = AppLocalizations.of(context)!;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.remove_period_title),
        content: Text(
          loc.remove_period_message(dayAndMonthShort(entry.start, isBangla)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: INCORRECT),
            child: Text(loc.remove),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removingDate = entry.start);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _removingDate = null);
      return;
    }

    try {
      await PeriodHistoryService.delete(uid: uid, start: entry.start);
    } catch (e) {
      debugPrint('Period delete failed: $e');
      if (!mounted) return;
      setState(() => _removingDate = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.period_remove_failed),
          backgroundColor: INCORRECT,
        ),
      );
      return;
    }

    // Reload this widget's own history, then let the owner recompute the
    // prediction from it, so the ring, the statistics and the calendar all
    // move together.
    await _loadStats();
    if (!mounted) return;
    setState(() => _removingDate = null);
    widget.onHistoryChanged?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.period_removed)),
    );
  }

  /// Small colour dot with a label — no chip background, kept left-aligned.
  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A short band, not a dot. The swatch is the exact tone of the mark
        // it names, and the softer of the two is faint by design — at 8
        // pixels across it was barely there. A band's width gives the same
        // colour enough area to read, and matches the shape it stands for.
        Container(
          width: 16,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: ACCENT.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }

  /// The dashboard card: predicted start date, countdown ring, the phases of
  /// the cycle, measured health status and cycle statistics.
  /// Greeting that changes through the day, so opening the app in the evening
  /// does not say "good morning".
  String _timeGreeting(bool isBangla) {
    final h = DateTime.now().hour;
    if (h < 12) return isBangla ? 'সুপ্রভাত' : 'Good morning';
    if (h < 17) return isBangla ? 'শুভ অপরাহ্ন' : 'Good afternoon';
    return isBangla ? 'শুভ সন্ধ্যা' : 'Good evening';
  }

  /// The current week, Sunday to Saturday.
  ///
  /// Today is filled; a day the period is predicted to start is outlined in the
  /// brand red. It gives the countdown somewhere to land — "2 days left" means
  /// more when the day it lands on is visible on the same screen.
  Widget _weekStrip(DateTime predictedStart, bool isBangla) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // DateTime.weekday is Monday=1..Sunday=7; the strip starts on Sunday.
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    final due = DateTime(
        predictedStart.year, predictedStart.month, predictedStart.day);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = sunday.add(Duration(days: i));
        final isToday = day == today;
        final isDue = day == due;

        return Expanded(
          child: Column(
            children: [
              Text(
                weekdayInitial(day, isBangla),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ACCENT.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 34,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? ACCENT : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: isDue && !isToday
                      ? Border.all(color: PRIMARY_COLOR, width: 1.6)
                      : null,
                ),
                child: Text(
                  localeNumber(day.day, isBangla),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isToday
                        ? Colors.white
                        : isDue
                            ? PRIMARY_COLOR
                            : ACCENT.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// What the chip says about her cycle.
  ///
  /// Three outcomes, not two. The unmeasured states describe the DATA and
  /// must never be phrased as a finding about her body — the app previously
  /// printed "Irregular" for a brand-new user, for one logged interval, and
  /// for any history an interval had been filtered out of.
  ///
  /// Its own strings, not the questionnaire's. That asked "Are your periods
  /// regular?", so its word is lowercase and mid-sentence; reused on a chip
  /// it rendered "regular" beside a capitalised "Irregular".
  ///
  /// NOT A CLINICAL STATEMENT: "Regular" and "Irregular" here mean only what
  /// CycleStats.isRegular means, which is the app's working definition and is
  /// still awaiting clinical review.
  String _regularityLabel(PredictionState state, AppLocalizations loc) {
    switch (state) {
      case PredictionState.measuredRegular:
        return loc.cycle_status_regular;
      case PredictionState.measuredIrregular:
        return loc.cycle_status_irregular;
      case PredictionState.noHistory:
      case PredictionState.insufficientHistory:
      case PredictionState.longAbsence:
      case PredictionState.noPrediction:
        return loc.not_measured_yet;
    }
  }

  Widget _buildCycleCard(Map<String, dynamic> periodData) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    // Straight from the snapshot's state. This read widget.data['anomalies'],
    // which the screen above derived as "anything not measured-regular is
    // Irregular" — so a girl with one logged period was told her cycles were
    // irregular on no evidence at all.
    final loc = AppLocalizations.of(context)!;
    final state = widget.snapshot.state;
    final bool regular = state == PredictionState.measuredRegular;
    final DateTime start = periodData['next_start'];
    final Color statusColor = regular ? SECONDARY_COLOR : PRIMARY_COLOR;
    final int? cycleDay = periodData['cycle_day'];
    final int cycleLen = periodData['cycle_length'] ?? 28;
    final int bleedLen = periodData['bleed_length'] ?? 5;
    final int daysUntil = periodData['days_until'] ?? 0;
    final now = DateTime.now();


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- today's date, with the regularity reading opposite it
          //
          // spaceBetween with two Flexible children, not Expanded plus
          // Flexible. Two flex children share the free space between them, so
          // the chip was laid out at the start of its own half and came to
          // rest near the middle of the row with empty space to its right.
          // Loose children take their natural width and the alignment pushes
          // them to opposite edges, which is what "opposite it" should mean.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${weekdayFull(now, isBangla)}, '
                  '${localeNumber(now.day, isBangla)} '
                  '${monthFull(now, isBangla)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ACCENT.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Flexible, and the label inside it wraps.
              //
              // The chip was built for one short word — "Regular",
              // "নিয়মিত" — and now also carries "Not measured yet", which in
              // Bangla is "এখনও নির্ণয় করা হয়নি". At a 320px screen width
              // that is wider than the space left beside the date, and a
              // fixed-size chip in a Row has nowhere to put the excess but
              // over the edge. Letting it wrap keeps the whole phrase
              // readable; ellipsising it would leave "এখনও নির্ণয়…", which
              // says something different from what it means.
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: ACCENT.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _regularityLabel(state, loc),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ACCENT,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ---- greeting
          Text(
            _firstName == null
                ? _timeGreeting(isBangla)
                : '${_timeGreeting(isBangla)}, $_firstName',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: ACCENT,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 20),
          _weekStrip(start, isBangla),
          const SizedBox(height: 26),

          // ---- the countdown, given the whole width
          Center(
            child: CycleRing(
              size: 210,
              progress: cycleLen > 0 ? (cycleLen - daysUntil) / cycleLen : 0.0,
              // Three cases, not two.
              //
              // The window is rolled forward on its END so that a wide range
              // straddling today is kept rather than skipped — her period is
              // due any day now, which is exactly when the forecast matters.
              // But the date shown is the window's MIDDLE, so once today
              // passes it the countdown goes negative while the window is
              // still open. That read `daysUntil <= 0` and printed "Today",
              // every day, for as long as it lasted: up to five consecutive
              // days each cycle, all of them claiming to be the day.
              //
              // Past the expected date but inside the window is its own
              // state, and says so.
              // The three lines read as one sentence top to bottom:
              // "পরের পিরিয়ড আসতে / ১৪ / দিন বাকি". The old "পিরিয়ড আসছে"
              // above a number said the period was arriving now, which is the
              // opposite of what a countdown means.
              topLabel: daysUntil > 0
                  ? (isBangla ? 'পরের পিরিয়ড আসতে' : 'Next period in')
                  : null,
              value: daysUntil > 0
                  ? localeNumber(daysUntil, isBangla)
                  : (daysUntil == 0
                      ? (isBangla ? 'আজ' : 'Today')
                      : loc.any_day_now),
              label: daysUntil > 0
                  ? (isBangla
                      ? 'দিন বাকি'
                      : (daysUntil == 1 ? 'day left' : 'days left'))
                  : (isBangla ? 'সম্ভাব্য শুরু' : 'expected start'),
              // No day-of-cycle pill. It repeated what the line directly
              // under the ring already says — "আজ · চক্রের ২৪তম দিন" — and
              // the extra row pushed the label above the number up to where
              // the circle has narrowed, which is how that label came to sit
              // on top of the arc.
            ),
          ),

          const SizedBox(height: 24),

          // ---- where she is in the cycle: the timeline owns its own header
          // and caption, so the words and the drawing come from one model.
          CyclePhaseTimeline(
            cycleDays: cycleLen,
            bleedDays: bleedLen,
            cycleDay: cycleDay,
          ),

          const SizedBox(height: 20),

          // ---- health status, tinted by the reading itself
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              // Neutral, not tinted by the regular/irregular reading. Washing
              // the card blue when regular and red when irregular colour-codes
              // her cycle as good or bad, which is not what this box reports.
              color: ACCENT.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: ACCENT,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    // Was an up or down arrow depending on regularity. A
                    // direction reads as better or worse, and a girl seeing a
                    // downward arrow on her own health card can take it to mean
                    // something is wrong with her. Regularity has no direction.
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        // Optically centres the heading against the 38px icon
                        // beside it.
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          AppLocalizations.of(context)!.estimate_accuracy_title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: ACCENT,
                            letterSpacing: -0.15,
                          ),
                        ),
                      ),
                      _buildStatusSource(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _buildStatTiles(periodData),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // A snapshot with no prediction has nothing for this card to draw. The
    // screen above shows the "set your calendar" banner in that case; this is
    // the belt-and-braces so the widget can never be asked to render a
    // forecast that does not exist.
    if (widget.snapshot.prediction == null ||
        widget.snapshot.windowFrom == null) {
      return const SizedBox();
    }
    Map<String, dynamic> periodData = getData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        if (widget.cohort != null && widget.cohort!['predicted'] != null) ...[
          const SizedBox(height: 15),
          Wrap(
            direction: Axis.horizontal,
            spacing: 15,
            runSpacing: 15,
            children: widget.cohort!['predicted'].map<Widget>((user) {
              return CircleImage(
                image: 'assets/images/default_person.png',
                isHighlighted: user['id'].toString() == selectedUserId,
                id: user['id'].toString(),
                anomalies: widget.data['anomalies'],
                onSelect: onSelectUser,
              );
            }).toList(),
          ),
        ],
        if (_pendingSync) _buildOfflineNotice(),
        const SizedBox(height: 12),
        _buildCycleCard(periodData),

        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              // Matches the cycle card above so the two read as one system.
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: ACCENT.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Calender(
                  menstrual: periodData['logged_days'],
                  predictedMenstrual: periodData['menstrual_days'],
                  subtitle: Localizations.localeOf(context).languageCode == 'bn'
                      ? 'চক্রের ইতিহাস'
                      : 'Cycle history',
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  // Wrapped rather than a Row: three labels in Bangla do not
                  // always fit on one line on a narrow phone.
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      // The forecast leads, because it is the stronger band
                      // and the thing the calendar is read for. Each swatch
                      // is the exact tone of the band it names, taken from
                      // Calender itself so the two cannot drift apart.
                      _legendChip(Calender.expectedBandColour,
                          AppLocalizations.of(context)!.expected_period),
                      _legendChip(Calender.loggedBandColour,
                          AppLocalizations.of(context)!.logged_period),
                      // No ovulation key: the calendar no longer marks it.
                      // See the note beside menstrualDays in getData.
                    ],
                  ),
                ),
                // Only on a girl's own screen. In the cohort view the calendar
                // shows one account's data while the history behind these rows
                // belongs to the signed-in manager, so offering deletion here
                // would risk removing the wrong person's records.
                if (!widget.issuperuser) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: ACCENT.withValues(alpha: 0.07),
                  ),
                  const SizedBox(height: 10),
                  _buildLoggedPeriods(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ================== BUTTONS ==================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _openPeriodLog,
                // Primary action: solid, no border, taller and more rounded.
                style: ElevatedButton.styleFrom(
                  backgroundColor: ACCENT,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(
                  AppLocalizations.of(context)!.log_new_period,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (widget.issuperuser) {
                    Navigator.pushNamed(context, '/choose-user', arguments: false);
                  } else {
                    Navigator.pushNamed(context, '/unlock-process/1', arguments: true);
                  }
                },
                // Secondary action. It used to be filled with BACKGROUND —
                // the exact colour of the page behind it — and outlined at 12%
                // opacity, so it read as a faint rectangle rather than a
                // button. White against the beige page gives it an edge of its
                // own, matching the cards above, and the border and label are
                // dark enough to see while still sitting below the primary.
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ACCENT,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: ACCENT.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(
                  AppLocalizations.of(context)!.update_my_cycle_details,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
