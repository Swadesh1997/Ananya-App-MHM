import 'package:ananya/widgets/home_carousel.dart';
import 'package:ananya/utils/probahini_gate.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/period_cycle_information.dart';
import 'package:ananya/widgets/knowledge_hub_row.dart';
import 'package:ananya/services/local_period_store.dart';
import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/period_history_service.dart';
import 'package:ananya/services/period_reminder_service.dart';
import 'package:ananya/utils/local-notification.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ananya/utils/app_dialog.dart';

class UserHome extends StatefulWidget {
  final Function(int)? onselect;

  /// Called when the last logged period is removed, so the screen above can
  /// send her back to the "set your calendar" banner. Without it she is left
  /// on a tracker with nothing in it and no way to start again.
  final VoidCallback? onCalendarCleared;

  const UserHome({this.onselect, this.onCalendarCleared, super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  static const Color bgColor = Color(0xFFF8F0E4);

  late StreamController<Map<String, dynamic>> _periodController;

  /// The one reading of the cycle for this load. Handed to the card so it
  /// cannot derive its own and disagree.
  CycleSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();

    _periodController = StreamController<Map<String, dynamic>>();
    _loadPeriodData();

  }

  @override
  void dispose() {
    _periodController.close();
    super.dispose();
  }

  /// Stored as 'yyyy-MM-dd', but older builds wrote a full timestamp.
  DateTime? _parseStoredDate(dynamic raw) {
    if (raw is! String) return null;
    try {
      return DateFormat('yyyy-MM-dd')
          .parseStrict(raw.trim().split(' ').first.split('T').first);
    } catch (_) {
      return null;
    }
  }

  // ================= PERIOD LOGIC =================
  Future<void> _loadPeriodData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('token');

    if (token == 'firebase') {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _periodController.add({});
        return;
      }

      // The device copy first: it renders immediately and is the only source
      // that is guaranteed to answer with no connection.
      Map<String, dynamic>? firebaseData =
          await LocalPeriodStore.readSettings(user.uid);

      // Whether the snapshot ends up resting on the device copy rather than
      // the server. Recorded on the snapshot so a stale reading is visible
      // instead of silently differing from another device's.
      var settingsFromDeviceCopy = true;

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('period')
            .doc('latest')
            .get()
            .timeout(const Duration(seconds: 12));
        if (doc.exists) {
          firebaseData = doc.data()!;
          settingsFromDeviceCopy = false;
          // Keep the device copy current so the next cold start is instant.
          // REPLACED, not merged: the server document is the authority, and a
          // field it no longer carries must not survive in the cache to be
          // read back on the next offline load.
          await LocalPeriodStore.replaceSettings(user.uid, firebaseData);
          if (!doc.metadata.hasPendingWrites) {
            await LocalPeriodStore.setPending(false);
          }
        }
      } catch (e) {
        debugPrint('period/latest unavailable, using device copy: $e');
      }

      if (firebaseData == null || firebaseData.isEmpty) {
        _periodController.add({});
        return;
      }

      // Existing users have one genuine period date stored but no history yet.
      // Write it as their first history entry so they don't start from zero.
      // Only ever seeds this one real date — no past cycles are invented.
      final bleed = firebaseData["length_of_period"];
      PeriodHistoryService.seedFromLatest(
        uid: user.uid,
        lastPeriodStart: firebaseData["last_period_start"],
        lengthOfPeriod: bleed is int ? bleed : 5,
      );

      // Predict from real logged cycles where possible. Previously this passed
      // the user's own last-period date straight through as the "prediction",
      // and always used the cycle length typed at signup — so the forecast
      // never improved no matter how many periods were logged.
      final lastStart = _parseStoredDate(firebaseData["last_period_start"]);
      if (lastStart == null) {
        // Reached when the user has removed every logged period: the delete
        // realigns period/latest with the (now empty) history. There is
        // nothing left to predict from, so any alarms still queued point at a
        // period that no longer exists and must be withdrawn too.
        try {
          await PeriodReminderService.cancelAll();
        } catch (e) {
          debugPrint('Reminder cancel failed: $e');
        }

        // "calendar_completed" gates which screen the app shows: true puts her
        // on this tracker, false on the banner with "Set your calendar". It was
        // only ever set to true, so after deleting every period she was left
        // staring at an empty tracker with no way back into the setup flow.
        // It means "has period data", so clearing the data must clear it.
        await prefs.setBool('calendar_completed', false);
        _periodController.add({});
        widget.onCalendarCleared?.call();
        return;
      }

      final entries = await PeriodHistoryService.fetchAll(user.uid);

      // One snapshot, built once, from one settings document. Everything the
      // screen shows is read from it: the ring, the calendar, the statistics
      // and the reminders. Three of those used to compute their own, from
      // settings they each fetched separately — and a stale device copy made
      // them disagree in public.
      final snapshot = CycleSnapshot.build(
        entries: entries,
        settings: firebaseData,
        today: DateTime.now(),
        settingsFromDeviceCopy: settingsFromDeviceCopy,
      );

      _snapshot = snapshot;

      // Nothing the engine will stand behind: no anchor, or no cycle length
      // from either the history or a usable signup answer. The banner is
      // shown rather than a number nobody can justify, and any alarms still
      // queued are withdrawn.
      if (snapshot.prediction == null) {
        try {
          await PeriodReminderService.cancelAll();
        } catch (e) {
          debugPrint("Reminder cancel failed: $e");
        }
        _periodController.add({});
        return;
      }

      final fmt = DateFormat("yyyy-MM-dd");
      _periodController.add({
        "period_start_from": fmt.format(snapshot.windowFrom!),
        "period_start_to": fmt.format(snapshot.windowTo!),
        "days_between_period": snapshot.prediction!.cycleDays,
        "length_of_period": snapshot.prediction!.bleedDays,
        // Only a measured reading may claim regular. "Not yet measured" is
        // not a yes, and it used to be treated as one via the signup answer.
        "anomalies": snapshot.stats.isRegular == true ? "Regular" : "Irregular",
      });

      // Keep the OS alarms aimed at the freshest prediction. Without this,
      // reminders only existed for the one cycle after a log: if she never
      // logged the next period, they simply stopped. Runs after the UI data
      // is published so it never delays the screen.
      //
      // A state the engine will not stand behind schedules nothing, and
      // withdraws whatever was scheduled before: an alarm for a period the
      // app has stopped predicting is worse than silence.
      try {
        if (!snapshot.allowsReminders) {
          await PeriodReminderService.cancelAll();
        } else if (await LocalNotifications.hasPermission()) {
          await PeriodReminderService.scheduleForNextPeriod(
              snapshot.prediction!.nextExpected(DateTime.now()));
        }
      } catch (e) {
        debugPrint('Reminder re-arm failed: $e');
      }

      return;
    }

    try {
      final api =
      ApiSettings(endPoint: 'user/get-prediction-period/$userId');
      final response = await api.getMethod();

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        // The legacy server path goes through the same validation and the
        // same nullable ovulation as everything else, so an out-of-range
        // value from the API cannot reach the calendar unchecked.
        _snapshot = CycleSnapshot.fromLegacyMap(body, today: DateTime.now());
        _periodController.add(body);
      } else {
        _periodController.add({});
      }
    } catch (e) {
      _periodController.add({});
    }
  }

  // ================= MAP PART (EXACTLY LIKE LANDING) =================
  Future<void> _launchMap(String query) async {
    final url =
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showMapSelectionDialog() {
    final loc = AppLocalizations.of(context);

    showAppDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc?.view_map ?? "View Map"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _launchMap("hospitals near me");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA2249),
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              child:
              Text(loc?.nearby_hospital ?? "Nearby Hospital"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _launchMap("pharmacies near me");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA2249),
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              child:
              Text(loc?.nearby_pharmacy ?? "Nearby Pharmacy"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc?.cancel ?? "Cancel"),
          ),
        ],
      ),
    );
  }

  // ================= CAROUSEL =================
  Widget _buildCarousel() {
    final loc = AppLocalizations.of(context)!;

    // No "set your calendar" slide here: this screen only exists once she
    // has one, so leading with it would be telling her to do something she
    // has already done.
    return HomeCarousel(
      slides: [
        CarouselSlide(
          image: 'assets/images/viewmap.png',
          description: loc.map_description,
          buttonText: loc.view_map,
          onPressed: _showMapSelectionDialog,
        ),
        CarouselSlide(
          image: 'assets/images/number.png',
          description: loc.emergency_description,
          buttonText: loc.view_numbers,
          onPressed: () => Navigator.pushNamed(context, '/help'),
        ),
        CarouselSlide(
          image: 'assets/images/insidecalendar2.png',
          description: loc.faqs_description,
          buttonText: loc.faqs,
          onPressed: () => Navigator.pushNamed(context, '/faq'),
        ),
      ],
    );
  }

  Widget _chatCard({
    required String image,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No card and no plate: the logo artwork sits on the same cream as
          // the page, so it blends on its own.
          //
          // Drawn whole, at its own proportions. It used to be scaled 1.3x and
          // clipped, because the artwork was 429x90 adrift in a 707x703 canvas
          // of empty background and would otherwise have floated tiny in the
          // middle. That crop depended on how wide the screen was: it cleared
          // the top of the wordmark by four pixels on a 360dp phone and cut
          // the logo outright on anything wide. The asset is now trimmed to
          // the artwork, so contain simply cannot clip it.
          Center(
            child: Image.asset(image, height: 64, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: ACCENT.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: PRIMARY_COLOR,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              buttonText,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildCarousel(),
            const SizedBox(height: 16),
            KnowledgeHubRow(
              onViewAll: () => Navigator.pushNamed(context, '/knowledge-hub'),
            ),
            const SizedBox(height: 36),
            StreamBuilder<Map<String, dynamic>>(
              stream: _periodController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.data!.isNotEmpty) {
                  return PeriodCycleInformation(
                    data: snapshot.data!,
                    snapshot: _snapshot!,
                    issuperuser: false,
                    // Removing a period changes the statistics, the prediction
                    // and the reminder dates, all of which are computed here.
                    onHistoryChanged: _loadPeriodData,
                  );
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 52),
            _chatCard(
              image: 'assets/images/chatbot.png',
              description: AppLocalizations.of(context)!
                  .hi_i_am_probahini_your_menstrual_companion_ask_me_anything,
              buttonText: AppLocalizations.of(context)!.chat,
              onPressed: () => openProbahini(context),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}