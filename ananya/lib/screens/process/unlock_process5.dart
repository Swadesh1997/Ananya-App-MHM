import 'dart:async';
import 'dart:convert';
import 'package:ananya/screens/loading.dart';
import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/custom_app_bar_with_progress.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/period_history_service.dart';
import 'package:ananya/services/local_period_store.dart';
import 'package:ananya/services/period_reminder_service.dart';
import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/local-notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ananya/utils/app_dialog.dart';

/// One selectable health condition.
///
/// [conditionKey] is the stable English key used by PeriodState; [label] is
/// what the user sees. Previously the localized label was used as the map key,
/// so in Bangla every tap wrote a brand-new key instead of updating the English
/// one — leaving the real values at their defaults and saving mixed-language
/// data.
class ChoiceItemWithCheckbox extends StatelessWidget {
  final String conditionKey;
  final String label;

  const ChoiceItemWithCheckbox({
    required this.conditionKey,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final periodState = context.watch<PeriodState>();
    final selected = periodState.healthCondition[conditionKey] ?? false;

    return GestureDetector(
      onTap: () => periodState.updateHealthCondition(conditionKey, !selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? PRIMARY_COLOR.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? PRIMARY_COLOR : ACCENT.withValues(alpha: 0.09),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? PRIMARY_COLOR : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? PRIMARY_COLOR : ACCENT.withValues(alpha: 0.22),
                  width: 1.8,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: ACCENT,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UnlockProcess5 extends StatefulWidget {
  final bool updatePeriod;
  const UnlockProcess5({required this.updatePeriod, super.key});

  @override
  State<UnlockProcess5> createState() => _UnlockProcess5State();
}

class _UnlockProcess5State extends State<UnlockProcess5> {
  bool isLoading = false;

  // Takes no context: it used to accept one from build, which shadowed the
  // State's own and meant the `mounted` checks below guarded a different
  // object than the one being used. Same context, now actually guarded.
  void predictPeriod() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (!mounted) return;
    final periodState = context.read<PeriodState>();

    // Firebase user -> skip backend completely
    if (token == 'firebase') {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final periodDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('period')
          .doc('latest');

      // "Log new period" (updatePeriod) is the SHORT flow: it only asks for
      // the date and health conditions. Steps 1, 2 and 5 are skipped, so
      // PeriodState still holds defaults (28-day regular cycle, no birth
      // control) for those fields. Writing them would silently wipe the
      // settings the user gave during setup, so only the fields this flow
      // actually collected are written, merged over the existing document.
      // Read the device copy to decide the merge: offline, a server read
      // either stalls or returns nothing, and treating "nothing" as "no
      // existing settings" would overwrite the user's real cycle with the
      // defaults this short flow never asked about.
      final localSettings = await LocalPeriodStore.readSettings(user.uid);
      var hasExisting = localSettings != null && localSettings.isNotEmpty;
      if (!hasExisting) {
        try {
          final existing =
              await periodDoc.get().timeout(const Duration(seconds: 8));
          hasExisting = existing.exists;
        } catch (e) {
          debugPrint('period/latest unreadable, assuming none: $e');
        }
      }
      final canMerge = widget.updatePeriod && hasExisting;

      // Whether the date she just logged is the most recent one on record.
      //
      // The length she gave belongs to this episode and is always recorded
      // against it. Whether it also becomes her "usual" — the figure
      // period/latest carries, which seeds the next log and stands in until
      // there is enough history to measure — depends on where the episode
      // sits. Back-filling a three-day period from July should not tell the
      // app that her periods are now three days long.
      var isLatestEpisode = true;
      final loggedOn = DateTime.tryParse(periodState.lastPeriodStart.trim());
      if (loggedOn != null) {
        final history = await LocalPeriodStore.readHistory(user.uid);
        for (final iso in history.keys) {
          final known = DateTime.tryParse(iso);
          if (known != null && known.isAfter(loggedOn)) {
            isLatestEpisode = false;
            break;
          }
        }
      }

      final data = canMerge
          ? {
              "last_period_start": periodState.lastPeriodStart,
              "health_condition": periodState.healthCondition,
              if (isLatestEpisode)
                "length_of_period": periodState.lengthOfPeriod,
              "updated_at": FieldValue.serverTimestamp(),
            }
          : {
              "is_period_regular": periodState.isPeriodRegular,
              "days_between_period": periodState.daysBetweenPeriod,
              "length_of_period": periodState.lengthOfPeriod,
              "last_period_start": periodState.lastPeriodStart,
              "take_birth_control": periodState.takeBirthControl,
              "health_condition": periodState.healthCondition,
              "updated_at": FieldValue.serverTimestamp(),
            };

      // The device copy is the one that must succeed, so it is awaited.
      await LocalPeriodStore.saveSettings(user.uid, data);
      await LocalPeriodStore.setPending(true);

      // The Firestore write is deliberately NOT awaited. Its Future resolves
      // only on server acknowledgement, so awaiting it never returned without
      // a connection — the spinner simply span forever and the period looked
      // unsaved. Firestore persists it locally at once and replays it when the
      // network comes back.
      unawaited(periodDoc.set(data, SetOptions(merge: true)).then((_) {
        LocalPeriodStore.setPending(false);
      }).catchError((e) {
        debugPrint('period/latest sync failed: $e');
      }));

      // Append to the append-only history so cycles accumulate over time.
      // period/latest above is still the single "current settings" record;
      // this is what makes averages, variance and a history screen possible.
      //
      // The length recorded here is the one she just gave for this period,
      // not her usual figure. That is the whole point of asking: the average
      // bleed length is computed across these entries, so if it never varied
      // the measurement could never move off her signup answer.
      await PeriodHistoryService.record(
        uid: user.uid,
        periodStart: periodState.lastPeriodStart,
        lengthOfPeriod: periodState.lengthOfPeriod,
      );

      // Schedule the countdown reminders for the predicted next period.
      // Read back the merged document so the cycle length is the user's real
      // saved value, not whatever PeriodState happens to hold in the short flow.
      // Read back from the device copy, which already reflects the write
      // above and is available with or without a connection.
      // The whole settings document, handed to the snapshot builder rather
      // than unpacked here. Pulling individual fields out is how this flow
      // and the home screen came to validate them differently.
      final saved = await LocalPeriodStore.readSettings(user.uid) ?? data;
      final startedOn = DateTime.tryParse(periodState.lastPeriodStart.trim());

      // Predict with the same engine the home screen uses. Previously this was
      // a bare lastStart + signup gap, so once real cycles had been logged the
      // reminders and the displayed date could quietly disagree.
      // Built through the same snapshot the home screen uses, so the reminder
      // can never aim at a different date from the one she is shown — and so
      // a state the engine will not stand behind schedules nothing at all.
      DateTime? nextStart;
      if (startedOn != null) {
        final entries = await PeriodHistoryService.fetchAll(user.uid);
        final snapshot = CycleSnapshot.build(
          entries: entries,
          settings: saved,
          today: DateTime.now(),
        );
        if (snapshot.allowsReminders) {
          nextStart = snapshot.prediction!.nextExpected(DateTime.now());
        } else {
          try {
            await PeriodReminderService.cancelAll();
          } catch (e) {
            debugPrint('Reminder cancel failed: $e');
          }
        }
      }

      await prefs.setBool("calendar_completed", true);
      if (!mounted) return;
      setState(() => isLoading = false);

      // Ask about reminders now that we can say exactly what they are for and
      // when the first one would arrive.
      if (nextStart != null) {
        await _offerReminders(nextStart);
        if (!mounted) return;
      }

      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    // Django users continue normal flow
    String url =
        widget.updatePeriod ? 'user/log-new-period/' : 'user/add-period-info/';

    String? id = prefs.getString('cohort-user') ?? prefs.getString('userId');

    if (id == null) {
      setState(() => isLoading = false);
      return;
    }

    ApiSettings api = ApiSettings(endPoint: '$url$id');

    Map<String, dynamic> data = {
      "is_period_regular": periodState.isPeriodRegular,
      "days_between_period": periodState.daysBetweenPeriod,
      "length_of_period": periodState.lengthOfPeriod,
      "last_period_start": periodState.lastPeriodStart,
      "take_birth_control": periodState.takeBirthControl,
      "health_condition": periodState.healthCondition
    };

    try {
      final response = widget.updatePeriod
          ? await api.putMethod(json.encode(data))
          : await api.postMethod(json.encode(data));

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setBool("calendar_completed", true);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint(e.toString());
    }
  }

  /// Explains what the reminders are before spending the OS permission prompt.
  ///
  /// Android 13+ permanently denies notifications once the system dialog has
  /// been dismissed twice, and it cannot be shown again from the app. Asking in
  /// our own dialog first means a "not now" costs nothing — we can ask again
  /// next time — while the system prompt is only reached by someone who has
  /// already said yes.
  Future<void> _offerReminders(DateTime nextStart) async {
    // Already allowed: schedule silently, never ask again.
    if (await LocalNotifications.hasPermission()) {
      await PeriodReminderService.scheduleForNextPeriod(nextStart);
      return;
    }
    // Declined before: ask a limited number of times, then stop.
    if (!await PeriodReminderService.shouldOfferReminders()) return;
    if (!mounted) return;

    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    // Quote the first reminder that will actually fire — when the period is
    // less than 7 days away, the 7-day one is already in the past.
    final now = DateTime.now();
    DateTime firstReminder = nextStart;
    for (final d in PeriodReminderService.reminderDays) {
      final t = DateTime(nextStart.year, nextStart.month, nextStart.day - d, 9);
      if (t.isAfter(now)) {
        firstReminder = t;
        break;
      }
    }
    final pretty = '${localeNumber(firstReminder.day, isBangla)} '
        '${monthFull(firstReminder, isBangla)}';

    final accepted = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isBangla ? 'মাসিকের আগে মনে করিয়ে দেব?' : 'Remind you before your period?',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: ACCENT),
        ),
        content: Text(
          isBangla
              ? 'আপনার মাসিক শুরুর ৭, ৩ ও ১ দিন আগে এবং শুরুর দিন আমরা আপনাকে জানিয়ে দেব, যাতে আগেই প্রস্তুতি নিতে পারেন।\n\nপ্রথম বার্তাটি আসবে $pretty তারিখে।'
              : 'We will let you know 7, 3 and 1 day before your period starts, and on the day itself, so you can be prepared.\n\nYour first reminder would arrive on $pretty.',
          style: TextStyle(
              fontSize: 13.5, height: 1.5, color: ACCENT.withValues(alpha: 0.75)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isBangla ? 'এখন নয়' : 'Not now',
              style: TextStyle(color: ACCENT.withValues(alpha: 0.55)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ACCENT,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isBangla ? 'হ্যাঁ, মনে করিয়ে দিন' : 'Yes, remind me',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    await PeriodReminderService.markOffered();
    if (accepted != true) return;

    // Only now is the one-shot system prompt spent.
    final granted = await LocalNotifications.requestPermission();
    if (!granted) return;

    // Android 14 switched exact alarms off by default, and an inexact alarm
    // can slip hours past the morning it was meant for. This opens a system
    // settings page rather than a prompt, so it is only reasonable here —
    // immediately after she has said yes to reminders — and it is not asked
    // again if she declines.
    if (!await LocalNotifications.canScheduleExact()) {
      await LocalNotifications.requestExactAlarms();
    }

    await PeriodReminderService.scheduleForNextPeriod(nextStart);
  }

  @override
  Widget build(BuildContext context) {
    final periodState = context.watch<PeriodState>();
    final loc = AppLocalizations.of(context)!;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    // Keys must match PeriodState.healthCondition exactly — they are what gets
    // saved, independent of the display language.
    final conditions = <List<String>>[
      ['Yeast infection', loc.yeast_infection],
      ['Urinary track infections', loc.urinary_track_infections],
      ['Bacterial Vaginosis', loc.bacterial_vaginosis],
      ['Polycystic Ovary Syndrome', loc.polycystic_ovary_syndrome],
      ['Endometriosis', loc.endometriosis],
      ['Fibroids', loc.fibroids],
    ];
    final exclusive = <List<String>>[
      [PeriodState.exclusiveConditions[0], loc.i_m_not_sure],
      [PeriodState.exclusiveConditions[1], loc.no_health_issues],
    ];

    final selectedCount =
        periodState.healthCondition.values.where((v) => v).length;

    return Scaffold(
      appBar: isLoading
          ? AppBar()
          : CustomAppBarWithProgress(
              progressValue: 1,
              stepText: widget.updatePeriod ? '3/3' : '5/5',
            ),
      body: isLoading
          ? const Center(child: Loading())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: loc.do_you_have_any_of_these,
                          style: const TextStyle(
                              fontSize: 24, height: 1.3, color: ACCENT),
                        ),
                        TextSpan(
                          text: loc.health_conditions,
                          style: const TextStyle(
                              fontSize: 24,
                              height: 1.3,
                              color: PRIMARY_COLOR,
                              fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                            text: '?',
                            style: TextStyle(
                                fontSize: 24, height: 1.3, color: ACCENT)),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBangla
                          ? 'প্রযোজ্য সবগুলো বেছে নিন · এই তথ্য গোপন থাকবে'
                          : '${loc.choose_all_that_apply} · this stays private',
                      style: TextStyle(
                          fontSize: 12.5, color: ACCENT.withValues(alpha: 0.62)),
                    ),
                    const SizedBox(height: 16),
                    ...conditions.map((c) => ChoiceItemWithCheckbox(
                          conditionKey: c[0],
                          label: c[1],
                        )),
                    // "Not sure" and "No health issues" cannot coexist with a
                    // real condition, so they sit below a divider.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color: ACCENT.withValues(alpha: 0.10), height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              isBangla ? 'অথবা' : 'OR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: ACCENT.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(
                                  color: ACCENT.withValues(alpha: 0.10), height: 1)),
                        ],
                      ),
                    ),
                    ...exclusive.map((c) => ChoiceItemWithCheckbox(
                          conditionKey: c[0],
                          label: c[1],
                        )),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        isBangla
                            ? '$selectedCount টি নির্বাচিত'
                            : '$selectedCount selected',
                        style: TextStyle(
                            fontSize: 12, color: ACCENT.withValues(alpha: 0.55)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => predictPeriod(),
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
                        loc.continues,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
