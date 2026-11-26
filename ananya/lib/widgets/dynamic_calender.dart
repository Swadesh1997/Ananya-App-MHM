import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

/// Rounded-square month navigation button, matching the app bar's back button.
class _NavBtn extends StatelessWidget {
  final IconData icon;
  const _NavBtn(this.icon);

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ACCENT.withValues(alpha: 0.10)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: ACCENT, size: 19),
      );
}

class DynamicCalendar extends StatefulWidget {
  const DynamicCalendar({super.key});

  @override
  State<DynamicCalendar> createState() => _DynamicCalendarState();
}

class _DynamicCalendarState extends State<DynamicCalendar> {
  /// Day numeral in the digits of the active language.
  Widget _dayText(BuildContext context, DateTime day, TextStyle style) {
    final bn = Localizations.localeOf(context).languageCode == 'bn';
    return Center(child: Text(localeNumber(day.day, bn), style: style));
  }

  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    // PeriodState survives navigation but this widget's local selection does
    // not. Without re-hydrating, returning to this step shows an empty
    // calendar while the page still believes a date was chosen.
    final state = Provider.of<PeriodState>(context, listen: false);
    if (state.hasSelectedLastPeriodStart) {
      try {
        final raw =
            state.lastPeriodStart.trim().split(' ').first.split('T').first;
        final parsed = DateFormat('yyyy-MM-dd').parseStrict(raw);
        _selectedDay = parsed;
        _focusedDay = parsed;
      } catch (_) {
        // Unparseable stored value: leave the calendar unselected.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();

    // A year back, not one month.
    //
    // This used to open on last month and refuse to go further, so only two
    // months were ever reachable. Entering past periods is the one way to
    // reach a measured cycle without waiting months for it, and three period
    // starts do not fit inside two months — so the screen was asking for
    // history it would not let her enter.
    DateTime earliest = DateTime(now.year - 1, now.month, 1);

    // A date already stored from outside that window would put focusedDay
    // out of range, which TableCalendar asserts on.
    final chosen = _selectedDay;
    if (chosen != null && chosen.isBefore(earliest)) {
      earliest = DateTime(chosen.year, chosen.month, 1);
    }

    return TableCalendar(
      firstDay: earliest,
      lastDay: now,
      focusedDay: _focusedDay,
      // Same reason as the home calendar: the default vertical drag
      // fights the scroll view this step sits in.
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay!);
        Provider.of<PeriodState>(context, listen: false)
            .updateLastPeriodStart(formattedDate);
      },
      rowHeight: 46,
      daysOfWeekHeight: 24,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ACCENT,
        ),
        leftChevronMargin: EdgeInsets.only(left: 8),
        rightChevronMargin: EdgeInsets.only(right: 8),
        leftChevronPadding: EdgeInsets.zero,
        rightChevronPadding: EdgeInsets.zero,
        leftChevronIcon: _NavBtn(Icons.chevron_left),
        rightChevronIcon: _NavBtn(Icons.chevron_right),
      ),
      calendarBuilders: CalendarBuilders(
        headerTitleBuilder: (context, month) {
          final bn = Localizations.localeOf(context).languageCode == 'bn';
          return Center(
            child: Text(
              monthAndYear(month, bn),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ACCENT,
              ),
            ),
          );
        },
        dowBuilder: (context, day) {
          final bn = Localizations.localeOf(context).languageCode == 'bn';
          return Center(
            child: Text(
              weekdayInitial(day, bn),
              style: const TextStyle(
                color: SECONDARY_BACKGROUND,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          );
        },
        defaultBuilder: (context, day, _) => _dayText(
            context, day, const TextStyle(color: ACCENT, fontSize: 13)),
        outsideBuilder: (context, day, _) => _dayText(
            context, day, const TextStyle(color: BORDER_COLOR, fontSize: 13)),
        disabledBuilder: (context, day, _) => _dayText(
            context, day, const TextStyle(color: BORDER_COLOR, fontSize: 13)),
        todayBuilder: (context, day, _) => Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ACCENT, width: 2),
          ),
          alignment: Alignment.center,
          child: _dayText(
              context,
              day,
              const TextStyle(
                  color: ACCENT, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        selectedBuilder: (context, day, _) => Container(
          margin: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: PRIMARY_COLOR,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: _dayText(
              context,
              day,
              const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600)),
        ),
      ),
      calendarStyle: const CalendarStyle(
        // Tighter margin makes the selected-day circle noticeably larger.
        cellMargin: EdgeInsets.all(5),
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: ACCENT, width: 2)),
        ),
        selectedDecoration: BoxDecoration(
          color: PRIMARY_COLOR,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        todayTextStyle: TextStyle(
          color: ACCENT,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        defaultTextStyle: TextStyle(color: ACCENT, fontSize: 13),
        weekendTextStyle: TextStyle(color: ACCENT, fontSize: 13),
        outsideTextStyle: TextStyle(color: BORDER_COLOR, fontSize: 13),
        disabledTextStyle: TextStyle(color: BORDER_COLOR, fontSize: 13),
      ),
    );
  }
}
