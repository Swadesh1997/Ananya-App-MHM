import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app asks for earlier periods, permits them, and explains why they help.
/// These pin the part that was missing: a way to act on that from where it is
/// asked.
///
/// The accuracy card said "add an earlier date if you remember it" as plain
/// text, and the only route to the picker was a button labelled "log NEW
/// period" — which reads as the wrong door for an old one. Nothing was broken;
/// the path simply contradicted the instruction.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final card = read('lib/widgets/period_cycle_information.dart');

  group('the hint is a route, not just words', () {
    test('it is tappable', () {
      final hintAt = card.indexOf('add_earlier_period_hint');
      expect(hintAt, greaterThan(-1), reason: 'the hint text is gone');

      // The InkWell wrapping it opens the log flow.
      final wrapperAt = card.lastIndexOf('onTap: _openPeriodLog', hintAt);
      expect(wrapperAt, greaterThan(-1),
          reason: 'the hint must be inside the tappable row');
    });

    test('it looks tappable', () {
      // Plain grey text alongside other plain grey text is not an affordance,
      // however tappable it is underneath.
      expect(card, contains('TextDecoration.underline'));
      expect(card, contains('Icons.arrow_forward_rounded'));
    });
  });

  group('one destination, not two', () {
    test('the hint and the button call the same thing', () {
      // Duplicating the navigation is how the two end up pointing at
      // different screens after a later edit.
      expect('onPressed: _openPeriodLog'.allMatches(card).length, 1);
      expect('onTap: _openPeriodLog'.allMatches(card).length, 1);
    });

    test('a superuser is sent to pick a girl first, from either route', () {
      final fn = card.substring(card.indexOf('void _openPeriodLog()'));
      expect(fn, contains('widget.issuperuser'));
      expect(fn, contains("'/choose-user'"));
      expect(fn, contains("'/unlock-process/3'"));
    });
  });

  group('the picker actually accepts earlier dates', () {
    final picker = read('lib/widgets/dynamic_calender.dart');

    test('twelve months back, not two', () {
      // Three period starts do not fit inside two months, so a shorter window
      // would make the hint impossible to follow.
      expect(picker, contains('DateTime(now.year - 1, now.month, 1)'));
    });

    test('and never a future date', () {
      expect(picker, contains('lastDay: now'));
    });
  });
}
