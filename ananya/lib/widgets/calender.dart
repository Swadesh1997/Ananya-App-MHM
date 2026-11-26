import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Cycle calendar.
///
/// Recorded days and forecast days are both drawn as bands, and told apart by
/// weight: the forecast carries the stronger tone because it is what she
/// opens the screen to find, and the record sits back behind it. The key
/// under the calendar names which is which, since weight alone cannot say
/// what the difference means.
class Calender extends StatefulWidget {
  /// Days that actually happened — a logged period, or dates the user picked.
  /// Drawn as the softer band.
  final List<DateTime> menstrual;

  /// Days that are only forecast. Drawn as the stronger band.
  final List<DateTime> predictedMenstrual;

  // No ovulation. The calendar marked an estimated ovulation window in blue,
  // which is the least certain thing this app computes presented as a fact
  // about three specific days — and it answered a question the screen is not
  // for. The parameters are gone rather than left accepting data, so a later
  // change cannot bring the marks back without a deliberate decision.

  /// The two band tones, in one place so the key beside the calendar cannot
  /// drift from the calendar itself — it reads them from here.
  ///
  /// Both are the app's own brand colour at opacities it already uses; no new
  /// colour is introduced. The forecast carries the stronger of the two
  /// because it is what she opens the screen to find; the record sits back
  /// behind it.
  static final Color expectedBandColour = PRIMARY_COLOR.withValues(alpha: 0.38);
  static final Color loggedBandColour = PRIMARY_COLOR.withValues(alpha: 0.16);

  /// Small caption under the month name, e.g. "Cycle history".
  final String? subtitle;

  const Calender({
    required this.menstrual,
    this.predictedMenstrual = const [],
    this.subtitle,
    super.key,
  });

  @override
  State<Calender> createState() => _CalenderState();
}

class _CalenderState extends State<Calender> {
  DateTime focusedDay = DateTime.now();

  /// The day the user tapped. Null until she taps one — the calendar is
  /// readable without any selection, so nothing is pre-selected.
  DateTime? _selected;

  bool get _bn => Localizations.localeOf(context).languageCode == 'bn';

  String _n(int v) => localeNumber(v, _bn);

  bool _contains(List<DateTime> days, DateTime day) =>
      days.any((d) => DateUtils.isSameDay(d, day));

  /// Which day of its own run [day] is, counting from the first. Used to say
  /// "day 5 of that period" rather than just naming the date.
  int _dayIndexWithin(List<DateTime> days, DateTime day) {
    var n = 1;
    var cursor = day.subtract(const Duration(days: 1));
    while (_contains(days, cursor)) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---------------------------------------------------------------- day cells

  /// Consecutive days are drawn as one continuous band instead of separate
  /// blocks, so a period reads as a single event. Rounding is dropped only
  /// where the band actually continues — and always kept at the row edges
  /// (Sun/Sat) so it never looks sliced off.
  ///
  /// [fill] is used as given. It used to apply its own opacity, which meant
  /// the one caller could not vary the weight of a band.
  Widget _band(DateTime day, List<DateTime> days, Color fill) {
    final joinsLeft = day.weekday != DateTime.sunday &&
        _contains(days, day.subtract(const Duration(days: 1)));
    final joinsRight = day.weekday != DateTime.saturday &&
        _contains(days, day.add(const Duration(days: 1)));

    const radius = Radius.circular(999);

    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: joinsLeft ? 0 : 2,
        right: joinsRight ? 0 : 2,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.horizontal(
          left: joinsLeft ? Radius.zero : radius,
          right: joinsRight ? Radius.zero : radius,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _n(day.day),
        style: const TextStyle(
          color: ACCENT,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _plain(DateTime day, bool isToday) => Center(
        child: Text(
          _n(day.day),
          style: TextStyle(
            color: ACCENT,
            fontSize: 13,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );

  Widget _ring(Color color) => Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      );

  /// Today with nothing logged or forecast: the ring, digits localised.
  Widget _todayPlain(DateTime day) => Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ACCENT, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          _n(day.day),
          style: const TextStyle(
            color: ACCENT,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  /// A recorded day always wins over a forecast for the same date.
  Widget? _markerFor(DateTime day) {
    if (_contains(widget.menstrual, day)) {
      return _band(day, widget.menstrual, Calender.loggedBandColour);
    }
    if (_contains(widget.predictedMenstrual, day)) {
      // A band, not an outline. The forecast is what the calendar is for,
      // and an outlined circle read as the fainter of the two marks —
      // the opposite of its importance. The legend names which is which.
      return _band(day, widget.predictedMenstrual, Calender.expectedBandColour);
    }
    return null;
  }

  Widget? _dayBuilder(DateTime day, {required bool isToday}) {
    final selected = _selected != null && DateUtils.isSameDay(_selected!, day);
    final marker = _markerFor(day);

    // Nothing to draw: let TableCalendar render the day itself, which also
    // gives today its default ring.
    if (marker == null && !selected) return null;
    if (!selected) return marker;

    // Selection sits on top of whatever is underneath rather than replacing it,
    // so tapping a period day does not hide the band.
    return Stack(
      alignment: Alignment.center,
      children: [marker ?? _plain(day, isToday), _ring(PRIMARY_COLOR)],
    );
  }

  // ------------------------------------------------------------------- chrome

  Widget _navButton(IconData icon) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: ACCENT.withValues(alpha: 0.10)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: ACCENT, size: 19),
      );

  Widget _header(DateTime month) => Column(
        children: [
          Text(
            monthAndYear(month, _bn),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ACCENT,
              letterSpacing: 0.2,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: ACCENT.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      );

  /// What the tapped day actually is. Without this the colours are decoration —
  /// there is no way to find out that a pink day is a forecast and not a record.
  Widget _dayDetail(DateTime day) {
    final Color tone;
    final String title;
    final String sub;

    if (_contains(widget.menstrual, day)) {
      tone = PRIMARY_COLOR;
      title = _bn ? 'লগ করা পিরিয়ড' : 'Logged period';
      final n = _dayIndexWithin(widget.menstrual, day);
      sub = _bn ? 'সেই পিরিয়ডের ${_n(n)} নম্বর দিন' : 'Day $n of that period';
    } else if (_contains(widget.predictedMenstrual, day)) {
      tone = PRIMARY_COLOR;
      title = _bn ? 'সম্ভাব্য পিরিয়ড' : 'Expected period';
      sub = _bn ? 'পূর্বাভাস · নিশ্চিত নয়' : 'A forecast, not a record';
    } else {
      tone = ACCENT;
      title = dayAndMonthShort(day, _bn);
      sub = _bn ? 'কিছু লগ করা হয়নি' : 'Nothing logged';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 14, 6, 0),
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              _n(day.day),
              style: TextStyle(
                color: tone,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ACCENT,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ACCENT.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
          lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
          focusedDay: focusedDay,
          // Horizontal only. The default is AvailableGestures.all, whose
          // vertical drag competes with the page this sits inside — the
          // calendar swallowed the gesture, so months would not swipe and
          // the page fought back when scrolled over the grid.
          availableGestures: AvailableGestures.horizontalSwipe,
          rowHeight: 46,
          daysOfWeekHeight: 26,
          onPageChanged: (newFocusedDay) {
            setState(() => focusedDay = newFocusedDay);
          },
          onDaySelected: (selected, focused) {
            setState(() {
              // Tapping the selected day again clears it, so the detail row can
              // be dismissed without leaving the screen.
              _selected = (_selected != null &&
                      DateUtils.isSameDay(_selected!, selected))
                  ? null
                  : selected;
              focusedDay = focused;
            });
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            headerPadding: const EdgeInsets.symmetric(vertical: 8),
            leftChevronMargin: const EdgeInsets.only(left: 4),
            rightChevronMargin: const EdgeInsets.only(right: 4),
            leftChevronPadding: EdgeInsets.zero,
            rightChevronPadding: EdgeInsets.zero,
            leftChevronIcon: _navButton(Icons.chevron_left),
            rightChevronIcon: _navButton(Icons.chevron_right),
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: const TextStyle(color: ACCENT, fontSize: 13),
            weekendTextStyle: const TextStyle(color: ACCENT, fontSize: 13),
            outsideTextStyle:
                TextStyle(color: ACCENT.withValues(alpha: 0.22), fontSize: 13),
            // Replaces table_calendar's default marker, which was a pale
            // lavender that does not belong to the brand palette.
            todayDecoration: const BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.fromBorderSide(BorderSide(color: ACCENT, width: 2)),
            ),
            todayTextStyle: const TextStyle(
              color: ACCENT,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            headerTitleBuilder: (context, month) => _header(month),
            dowBuilder: (context, day) => Center(
              child: Text(
                weekdayInitial(day, _bn),
                style: const TextStyle(
                  color: SECONDARY_BACKGROUND,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            // Never fall through to TableCalendar's own day renderer: it only
            // knows Latin digits, which left "16" sitting beside "১৩".
            defaultBuilder: (context, day, _) =>
                _dayBuilder(day, isToday: false) ?? _plain(day, false),
            // Today gets its own builder, otherwise the ring would replace the
            // band whenever today falls inside a period or ovulation window.
            todayBuilder: (context, day, _) =>
                _dayBuilder(day, isToday: true) ?? _todayPlain(day),
            outsideBuilder: (context, day, _) => Center(
              child: Text(
                _n(day.day),
                style: TextStyle(
                  color: ACCENT.withValues(alpha: 0.22),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        if (_selected != null) _dayDetail(_selected!),
      ],
    );
  }
}
