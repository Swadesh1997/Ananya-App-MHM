import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/services/period_reminder_service.dart';

/// Guards the reminder plumbing.
///
/// None of this can be exercised in a unit test — scheduling needs a real
/// AlarmManager — and that is exactly why it needs guarding: the bug these
/// tests were written for was a single enum value, it produced no error, no
/// log and no crash, and the only symptom was a notification quietly failing
/// to arrive on somebody's phone weeks later.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('alarms are exact where the OS allows it', () {
    final notif = read('lib/utils/local-notification.dart');

    test('scheduling asks for an exact alarm', () {
      // inexactAllowWhileIdle maps to setAndAllowWhileIdle, which Android
      // batches into Doze maintenance windows — a 9am reminder can surface
      // hours later, or on a phone with aggressive battery management not
      // until it is next unlocked.
      expect(notif, contains('AndroidScheduleMode.exactAllowWhileIdle'));
    });

    test('it falls back to inexact rather than failing', () {
      // Android 14 has exact alarms off until the user grants them. A late
      // reminder beats no reminder.
      expect(notif, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
      expect(notif, contains('on PlatformException'));
    });

    test('the permission is checked and can be requested', () {
      expect(notif, contains('canScheduleExactNotifications'));
      expect(notif, contains('requestExactAlarmsPermission'));
    });

    test('the manifest declares the permission', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
      // POST_NOTIFICATIONS for Android 13+, and the boot receiver so pending
      // reminders survive a restart.
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('ScheduledNotificationBootReceiver'));
    });

    test('the local timezone is set, not just loaded', () {
      // initializeTimeZones() only loads the database; without
      // setLocalLocation, tz.local stays UTC and every reminder fires six
      // hours late in Dhaka.
      expect(notif, contains('tz.setLocalLocation'));
      expect(notif, contains("'Asia/Dhaka'"));
    });
  });

  group('the countdown itself', () {
    test('reminds at 7, 3, 1 days and on the day', () {
      expect(PeriodReminderService.reminderDays, [7, 3, 1, 0]);
    });

    test('each reminder has its own id so one cannot overwrite another', () {
      final service = read('lib/services/period_reminder_service.dart');
      expect(service, contains('_baseId + i'));
    });

    test('a reminder whose time has passed is skipped, not fired at once', () {
      final service = read('lib/services/period_reminder_service.dart');
      expect(service, contains('if (!fireAt.isAfter(now)) continue;'));
    });
  });

  group('the update prompt', () {
    final update = read('lib/utils/app_update_service.dart');

    test('something actually calls it', () {
      // The check has to run somewhere on startup or it never happens. It was
      // absent from the release before this one, which is why no phone
      // offered the update.
      expect(read('lib/screens/landing/landing.dart'),
          contains('AppUpdateService.checkForUpdate('));
    });

    test('a failed check never blocks the app', () {
      expect(update, contains('catch'));
      expect(update, contains('In-app update check failed'));
    });
  });
}
