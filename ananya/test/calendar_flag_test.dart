import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the "Set your calendar" banner coming back after all periods are
/// deleted.
///
/// `calendar_completed` decides which screen the app shows: true puts her on
/// the tracker, false on the banner. It used to be written only as `true`, so
/// deleting every logged period left her on an empty tracker with no route
/// back into the setup flow — the calendar gone, and no button to rebuild it.
///
/// Nothing at runtime would flag a regression here: the app would simply show
/// a blank screen and look like it had broken.
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('calendar_completed is cleared somewhere, not only ever set', () {
    final sources = [
      'lib/screens/landing/user_home.dart',
      'lib/screens/landing/landing.dart',
      'lib/screens/sign_in.dart',
      'lib/screens/process/unlock_process5.dart',
    ].map(read).join('\n');

    // Both quote styles are used across these files for the key.
    final clears = sources.contains("'calendar_completed', false") ||
        sources.contains('"calendar_completed", false');

    expect(clears, isTrue,
        reason: 'Nothing clears calendar_completed, so removing every period '
            'leaves the user stranded on an empty tracker with no way back '
            'to the "Set your calendar" flow.');
  });

  test('clearing the flag also notifies the screen that reads it', () {
    // landing.dart resolves calendarCompleted once in initState, so setting
    // the flag is not enough on its own — the parent has to re-read it.
    final userHome = read('lib/screens/landing/user_home.dart');
    final landing = read('lib/screens/landing/landing.dart');

    expect(userHome.contains('onCalendarCleared'), isTrue,
        reason: 'UserHome must expose a callback for the cleared state');
    expect(userHome.contains('widget.onCalendarCleared?.call()'), isTrue,
        reason: 'UserHome must actually invoke it');
    expect(landing.contains('onCalendarCleared:'), isTrue,
        reason: 'LandingPage must pass a handler, or the banner never returns');
    expect(
      RegExp(r'onCalendarCleared:[\s\S]{0,400}?_safeGetCalendarStatus\(\)')
          .hasMatch(landing),
      isTrue,
      reason: 'the handler must re-read the flag, not merely call setState',
    );
  });

  test('sign-in does not resurrect the flag from a bare doc.exists', () {
    // Deleting every period leaves period/latest in place with an empty
    // last_period_start, so document existence alone would send her back to an
    // empty tracker on her next login.
    final signIn = read('lib/screens/sign_in.dart');

    expect(signIn.contains('hasCalendar = doc.exists;'), isFalse,
        reason: 'doc.exists alone is still true after the date is cleared');
    expect(signIn.contains('last_period_start'), isTrue,
        reason: 'the check must read the stored date, not just the document');
  });
}
