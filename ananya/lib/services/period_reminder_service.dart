import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/utils/local-notification.dart';

/// Schedules the countdown reminders leading up to a predicted period.
///
/// These are LOCAL notifications: the OS holds each alarm, so they fire with
/// the app closed, with no internet, and survive a reboot (the boot receiver is
/// already declared in AndroidManifest.xml). No server or push service needed.
///
/// The notification text is fixed at scheduling time — the OS stores the words,
/// not a translation key — so [rescheduleForCurrentLanguage] must be called
/// whenever the user switches language, otherwise pending reminders would stay
/// in the previous one.
class PeriodReminderService {
  /// Reserved notification id block, kept clear of the ids used elsewhere
  /// (0 = simple, 1 = periodic).
  static const int _baseId = 7000;

  /// Days before the predicted start on which to remind. 0 = the day itself.
  static const List<int> reminderDays = [7, 3, 1, 0];

  /// Local hour reminders fire at. Early morning is useless; 9am is when
  /// someone is likely to act on it.
  static const int _hour = 9;

  static const String _prefsKey = 'reminder_next_period';
  static const String _promptCountKey = 'reminder_prompt_count';
  static const String _enabledKey = 'reminders_enabled';

  /// Whether the user wants reminders. Defaults to on: someone who granted
  /// notification permission has already opted in.
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Turns reminders on or off, applying the change immediately.
  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
      if (value) {
        // Clear the nag counter: they have explicitly asked for reminders,
        // so the opt-in dialog is relevant again if permission is ever lost.
        await prefs.remove(_promptCountKey);
        await rescheduleForCurrentLanguage();
      } else {
        await cancelAll();
      }
    } catch (e) {
      debugPrint('PeriodReminder: setEnabled failed: $e');
    }
  }

  /// How many times we may ask about reminders before letting it go. Someone
  /// who has declined twice has made their choice; asking on every period log
  /// would be nagging.
  static const int maxPrompts = 2;

  /// Whether it is still reasonable to show the reminder opt-in dialog.
  static Future<bool> shouldOfferReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(_promptCountKey) ?? 0) < maxPrompts;
    } catch (_) {
      return false;
    }
  }

  /// Records that the opt-in dialog was shown.
  static Future<void> markOffered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = prefs.getInt(_promptCountKey) ?? 0;
      await prefs.setInt(_promptCountKey, n + 1);
    } catch (_) {
      // Not worth failing the flow over.
    }
  }

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  /// Bengali digits, so "৭ দিন" reads naturally rather than "7 দিন".
  static String _bnDigits(int n) {
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : bn[i];
    }).join();
  }

  static List<String> _message(int daysBefore, bool isBangla) {
    if (isBangla) {
      switch (daysBefore) {
        case 0:
          return [
            'আজ মাসিক শুরু হতে পারে',
            'শুরু হলে অ্যাপে লগ করুন — এতে পরবর্তী পূর্বাভাস আরও সঠিক হবে।'
          ];
        case 1:
          return [
            'আগামীকাল মাসিক শুরু হতে পারে',
            'প্রয়োজনীয় জিনিসপত্র হাতের কাছে রাখুন।'
          ];
        default:
          return [
            '${_bnDigits(daysBefore)} দিনে মাসিক শুরু হতে পারে',
            'আগে থেকেই প্রস্তুতি নিয়ে রাখুন।'
          ];
      }
    }
    switch (daysBefore) {
      case 0:
        return [
          'Your period may start today',
          'Log it in the app when it starts — it makes your next prediction more accurate.'
        ];
      case 1:
        return [
          'Your period may start tomorrow',
          'Keep what you need close at hand.'
        ];
      default:
        return [
          'Your period is expected in $daysBefore days',
          'A little notice so you can be ready.'
        ];
    }
  }

  /// Schedules the full countdown for [nextPeriodStart], replacing any
  /// previously scheduled set. Reminders whose time has already passed are
  /// skipped rather than firing immediately.
  static Future<void> scheduleForNextPeriod(DateTime nextPeriodStart) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isBangla = (prefs.getString('language_code') ?? 'bn') == 'bn';

      // Remember the date first: the user may re-enable reminders later and we
      // need to know what to schedule against.
      await prefs.setString(_prefsKey, _fmt.format(nextPeriodStart));

      await cancelAll();

      if (!(prefs.getBool(_enabledKey) ?? true)) {
        debugPrint('PeriodReminder: reminders are switched off, not scheduling');
        return;
      }

      final now = DateTime.now();
      var scheduled = 0;

      for (var i = 0; i < reminderDays.length; i++) {
        final daysBefore = reminderDays[i];
        final fireAt = DateTime(
          nextPeriodStart.year,
          nextPeriodStart.month,
          nextPeriodStart.day - daysBefore,
          _hour,
        );
        if (!fireAt.isAfter(now)) continue;

        final text = _message(daysBefore, isBangla);
        await LocalNotifications.scheduleNotification(
          _baseId + i,
          text[0],
          text[1],
          fireAt,
          payload: 'period_reminder',
        );
        scheduled++;
      }

      debugPrint('PeriodReminder: scheduled $scheduled reminder(s) for '
          '${_fmt.format(nextPeriodStart)}');
    } catch (e) {
      // A reminder failure must never block saving a period.
      debugPrint('PeriodReminder: scheduling failed: $e');
    }
  }

  /// Rebuilds the pending reminders in the currently selected language.
  /// Safe to call when nothing is scheduled.
  static Future<void> rescheduleForCurrentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored == null) return;
      final next = _fmt.parseStrict(stored);
      await scheduleForNextPeriod(next);
    } catch (e) {
      debugPrint('PeriodReminder: reschedule failed: $e');
    }
  }

  static Future<void> cancelAll() async {
    for (var i = 0; i < reminderDays.length; i++) {
      await LocalNotifications.cancel(_baseId + i);
    }
  }
}
