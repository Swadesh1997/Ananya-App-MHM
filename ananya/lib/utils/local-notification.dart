import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class LocalNotifications {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final onClickNotification = BehaviorSubject<String?>();

  /// Called when user taps a notification
  static void onNotificationTap(NotificationResponse notificationResponse) {
    onClickNotification.add(notificationResponse.payload);
  }

  /// Initialize notifications
  static Future<void> init() async {
    // Initialize timezone (VERY IMPORTANT for zonedSchedule)
    tz.initializeTimeZones();

    // initializeTimeZones() only loads the DATABASE. Without also setting the
    // local location, tz.local stays UTC — so scheduling 9am produced a
    // TZDateTime of 9am UTC, which is 3pm in Dhaka. Every reminder fired six
    // hours late, and nothing in the app would have reported it.
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (e) {
      // An unknown or unreadable zone must not leave it on UTC. The programme
      // runs in Bangladesh, so that is the honest default.
      debugPrint('Timezone lookup failed, defaulting to Asia/Dhaka: ');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
      } catch (_) {}
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const LinuxInitializationSettings initializationSettingsLinux =
    LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: onNotificationTap,
    );

    // NOTE: the permission is deliberately NOT requested here. Android 13+
    // permanently denies after the user dismisses the system prompt twice, so
    // it is only worth spending once the user knows what it is for — see
    // requestPermission(), called after the calendar is set up.
  }

  /// Whether notifications are currently allowed.
  static Future<bool> hasPermission() async {
    final android = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    // iOS reports through the request call itself; assume allowed until asked.
    return true;
  }

  /// Shows the OS permission prompt. Only call this once the user has agreed
  /// in our own dialog first.
  static Future<bool> requestPermission() async {
    final android = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  /// Show a simple notification
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'ananya_general',
      'Ananya Notifications',
      channelDescription: 'Your menstrual health companion',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show periodic notification
  static Future<void> showPeriodicNotifications({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'ananya_periodic',
      'Periodic Notifications',
      channelDescription: 'Periodic reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.periodicallyShow(
      1,
      title,
      body,
      RepeatInterval.everyMinute,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Whether this device will let us set an alarm for an exact time.
  ///
  /// False on Android 14+ until the user turns on "Alarms & reminders" for the
  /// app, and on Android 13 for a fresh install.
  static Future<bool> canScheduleExact() async {
    final android = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // iOS has no equivalent restriction.
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('canScheduleExact failed: $e');
      return false;
    }
  }

  /// Sends the user to the system screen where exact alarms are allowed.
  ///
  /// There is no in-app prompt for this one — Android opens its own settings
  /// page — so only call it once the user has said they want reminders.
  static Future<bool> requestExactAlarms() async {
    final android = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      return await android.requestExactAlarmsPermission() ?? false;
    } catch (e) {
      debugPrint('requestExactAlarms failed: $e');
      return false;
    }
  }

  /// Schedule a notification at a specific date & time.
  ///
  /// Exact where the OS allows it. This used to be inexact unconditionally,
  /// which is what `setAndAllowWhileIdle` gives you: Android batches inexact
  /// alarms into Doze maintenance windows, so a reminder set for 9am could
  /// surface hours later — and on handsets with aggressive battery management,
  /// not until the phone was next unlocked. For a reminder whose whole value
  /// is arriving on the right morning, that is indistinguishable from it never
  /// arriving, which is what users reported.
  ///
  /// Falls back to inexact rather than failing: on Android 14+ the exact-alarm
  /// permission is off until the user grants it, and a late reminder is still
  /// far better than none.
  static Future<void> scheduleNotification(
      int id,
      String title,
      String body,
      DateTime scheduledTime, {
        String? payload,
      }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ananya_reminder',
        'Reminder Notifications',
        channelDescription: 'Period & health reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final when = tz.TZDateTime.from(scheduledTime, tz.local);
    final exact = await canScheduleExact();

    Future<void> schedule(AndroidScheduleMode mode) =>
        _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          // One-shot: matchDateTimeComponents was set to dateAndTime, which
          // makes the OS repeat the notification every year. Countdown
          // reminders must fire exactly once.
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );

    try {
      await schedule(exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle);
    } on PlatformException catch (e) {
      // The permission can be revoked between the check above and the call.
      // Losing the reminder entirely would be the worst outcome.
      debugPrint('Exact alarm refused (${e.code}), scheduling inexact');
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Cancel a specific notification
  static Future<void> cancel(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
