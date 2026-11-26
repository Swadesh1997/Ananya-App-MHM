import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The date picker must reach back far enough to enter past periods.
///
/// It was capped at `DateTime(now.year, now.month - 1, 1)` — last month and
/// this month, nothing earlier. Three period starts do not fit inside two
/// months, so the app asked for history it would not let her enter, and the
/// status card's "add an earlier date" prompt could not be acted on.
///
/// This is a source check because the widget needs a Provider and a
/// TableCalendar to build, but the regression it guards is a single constant.
void main() {
  final source = File('lib/widgets/dynamic_calender.dart').readAsStringSync();

  test('the picker does not stop at last month', () {
    expect(source.contains('now.month - 1'), isFalse,
        reason: 'a one-month window cannot hold three period starts');
  });

  test('it reaches at least a year back', () {
    expect(source.contains('DateTime(now.year - 1, now.month, 1)'), isTrue,
        reason: 'firstDay must be about twelve months back');
    expect(source.contains('firstDay: earliest'), isTrue);
  });

  test('a stored date older than the window widens it rather than crashing',
      () {
    // TableCalendar asserts when focusedDay falls outside first/lastDay.
    expect(source.contains('chosen.isBefore(earliest)'), isTrue,
        reason: 'an out-of-range stored date must extend the window');
  });

  test('future dates are still refused', () {
    expect(source.contains('lastDay: now'), isTrue,
        reason: 'a period cannot start in the future');
  });
}
