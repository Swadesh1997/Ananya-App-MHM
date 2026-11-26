import 'package:ananya/widgets/language_toggle.dart';
import 'package:ananya/utils/probahini_gate.dart';
import 'package:ananya/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ananya/services/period_reminder_service.dart';
import 'package:ananya/utils/local-notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/services/user_profile.dart';

class UserSidebar extends StatefulWidget {
  final Function(int) onselect;
  const UserSidebar({required this.onselect, super.key});

  @override
  State<UserSidebar> createState() => _UserSidebarState();
}

class _UserSidebarState extends State<UserSidebar> {
  bool _isSuperuser = false;
  Locale _currentLocale = const Locale('bn');
  String? _userName;
  bool _isLoggedIn = false;
  bool _remindersOn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _checkSuperuserStatus();
    _loadLocale();
    _loadReminderState();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    // Anyone already signed in never passes through the login screen again,
    // so the name is fetched here too — otherwise every existing user would
    // keep the blank they have now.
    String? userName = await UserProfile.resolve();

    setState(() {
      // Being signed in is about holding a token, not about having a
      // name — resolve() now returns null when no name is stored, and tying
      // the two together would hide Log out and Delete my data from anyone
      // whose name had not been fetched yet.
      _isLoggedIn = token != null;
      _userName = userName;
    });
  }

  Future<void> _checkSuperuserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isSuperuser = prefs.getBool('is_superuser');
    setState(() {
      _isSuperuser = isSuperuser ?? false;
    });
  }

  Future<void> _loadReminderState() async {
    // The switch reflects reality: reminders only actually fire when the user
    // wants them AND the OS permission is granted.
    final wanted = await PeriodReminderService.isEnabled();
    final allowed = await LocalNotifications.hasPermission();
    if (!mounted) return;
    setState(() => _remindersOn = wanted && allowed);
  }

  Future<void> _toggleReminders(bool value) async {
    if (value) {
      // Turning on may require the OS permission we never spent, or one the
      // user revoked in system settings.
      if (!await LocalNotifications.hasPermission()) {
        final granted = await LocalNotifications.requestPermission();
        if (!granted) {
          if (!mounted) return;
          final isBangla =
              Localizations.localeOf(context).languageCode == 'bn';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isBangla
                  ? 'মনে করিয়ে দিতে হলে ফোনের সেটিংসে অ্যানন্যার নোটিফিকেশন চালু করুন।'
                  : 'To get reminders, turn on notifications for Ananya in your phone settings.'),
              backgroundColor: ACCENT,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() => _remindersOn = false);
          return;
        }
      }

      // Notifications being allowed is not enough on Android 14+: without the
      // separate "Alarms & reminders" permission the alarm has to be inexact,
      // and Doze can hold it until long after the morning it was for.
      if (!await LocalNotifications.canScheduleExact()) {
        await LocalNotifications.requestExactAlarms();
      }
    }
    await PeriodReminderService.setEnabled(value);
    if (!mounted) return;
    setState(() => _remindersOn = value);
  }

  Future<void> _loadLocale() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('language_code');
    setState(() {
      // 'bn', matching main.dart. This read 'en' while the app itself started
      // in Bangla, so on a fresh install the sidebar disagreed with the screen
      // it was sitting on. The old ⋮ menu displayed no state at all, so the
      // mismatch was invisible until the toggle started showing it.
      _currentLocale = Locale(languageCode ?? 'bn');
    });
  }

  Future<void> _changeLanguage(String languageCode) async {
    setState(() => _currentLocale = Locale(languageCode));
    // Storing the choice, rebuilding pending reminders and rebuilding the app
    // all live in applyLanguage, so this and the home screen's toggle cannot
    // drift apart.
    await applyLanguage(context, languageCode);
  }

  /// The panel's top, in both signed-in and signed-out states.
  ///
  /// This was two UserAccountsDrawerHeaders. That widget is a fixed 160pt tall
  /// and lays the name out *under* the avatar, so signed out it left roughly
  /// eighty points of nothing between the logo and the divider, and signed in
  /// it pushed the name down a column it had all to itself.
  ///
  /// One row instead: the picture, and the name beside it on the same
  /// centreline. It costs the height of the picture plus its padding and
  /// nothing else, and because both states use the identical row the menu
  /// below does not move when someone signs in or out.
  Widget _header(BuildContext context) {
    const size = 64.0;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: _isLoggedIn
                  ? const CircleAvatar(
                      child: ClipOval(
                        child: Image(
                          image:
                              AssetImage('assets/images/default_person.png'),
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/images/logo.png',
                      // contain, never cover: cover crops whatever does not
                      // fit the box, and a logo is the one image that must
                      // arrive whole or not at all.
                      fit: BoxFit.contain,
                      cacheWidth: (size *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    ),
            ),
            // Signed out there is no name, and the row simply ends — no
            // placeholder, no reserved column.
            if (_isLoggedIn && (_userName ?? '').isNotEmpty) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _userName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // The app's own cream, not white. Every other screen uses BACKGROUND, so
      // a white drawer slid out over them looked like a different app's menu.
      backgroundColor: BACKGROUND,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context),
          const Divider(height: 1, thickness: 1),

          ListTile(
            leading: const Icon(Icons.home),
            title: Text(
              AppLocalizations.of(context)!.home,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context);
              widget.onselect(0);
            },
          ),

          if (_isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.track_changes),
              title: Text(
                AppLocalizations.of(context)!.log_new_period,
              ),
              onTap: () {
                if (_isSuperuser) {
                  Navigator.pushNamed(context, '/choose-user',
                      arguments: true);
                } else {
                  // Short flow (date + health only), matching the "Log new
                  // period" button on the home screen. Re-asking the whole
                  // questionnaire here made the two buttons behave differently
                  // despite having the same label.
                  Navigator.pushNamed(context, '/unlock-process/3',
                      arguments: true);
                }
              },
            ),
            if (_isSuperuser)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(
                  AppLocalizations.of(context)!.add_a_user,
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/add-user');
                },
              ),
          ],

          ListTile(
            leading: const Icon(Icons.chat),
            title: Text(
              AppLocalizations.of(context)!.chat_with_ananya,
            ),
            onTap: () {
              Navigator.pop(context);
              openProbahini(context);
            },
          ),

          ListTile(
            leading: const Icon(Icons.school),
            title: Text(AppLocalizations.of(context)!.knowledge_nexus),
            onTap: () {
              Navigator.pop(context);
              widget.onselect(1);
            },
          ),

          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(AppLocalizations.of(context)!.faqs),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/faq');
            },
          ),

          // A tint of the brand ink. This was 0xFF405070 — a hard blue-grey
          // belonging to no palette in the app, and the most jarring mark on
          // the panel once the background became cream.
          Divider(height: 1, color: ACCENT.withValues(alpha: 0.12)),

          if (_isLoggedIn)
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(
                Localizations.localeOf(context).languageCode == 'bn'
                    ? 'মাসিকের রিমাইন্ডার'
                    : 'Period reminders',
              ),
              subtitle: Text(
                Localizations.localeOf(context).languageCode == 'bn'
                    ? '৭, ৩ ও ১ দিন আগে জানানো হবে'
                    : 'Notified 7, 3 and 1 day before',
                style: TextStyle(
                    fontSize: 11.5, color: ACCENT.withValues(alpha: 0.60)),
              ),
              value: _remindersOn,
              activeThumbColor: PRIMARY_COLOR,
              onChanged: _toggleReminders,
            ),

          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(AppLocalizations.of(context)!.language),
            // Below the label, not beside it. As `trailing` the control took
            // 158 of the drawer's 304 logical pixels and left the title about
            // 42, so "Language" wrapped to "Langu / age". Narrowing it would
            // only move the breaking point — anyone using a larger system
            // font would hit it again. Stacked, the two never compete for
            // width at all.
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: LanguageToggle(
                  value: _currentLocale.languageCode,
                  onChanged: _changeLanguage,
                ),
              ),
            ),
          ),

          if (_isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(AppLocalizations.of(context)!.log_out),
              onTap: () async {
                // Firebase keeps its own session independently of
                // SharedPreferences. Without signOut() the account stayed
                // logged in on the device: FirebaseAuth.currentUser was still
                // populated after "logging out".
                await FirebaseAuth.instance.signOut();

                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                await FlutterLocalNotificationsPlugin().cancelAll();

                if (!context.mounted) return;
                // Clear the back stack so the previous user's screens cannot
                // be reached by pressing back.
                Navigator.pushNamedAndRemoveUntil(
                    context, '/signin', (route) => false);
              },
            ),
            // Only for Firebase accounts. A Django-backed login has its data in
            // Postgres, which this flow does not touch — offering it there
            // would show a success message while nothing of hers was removed,
            // which is exactly what the old "Request Data Purge" screen did.
            if (FirebaseAuth.instance.currentUser != null) ...[
              // Set apart from Log out above it. The two sat flush together,
              // same size, same spacing — one ends a session, the other
              // destroys every period she has ever logged, and a misplaced
              // thumb could not tell them apart. The rule and the gap are
              // there to make the second one a decision rather than a slip.
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: ACCENT.withValues(alpha: 0.10),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  // Softer than the label: the row should read as serious,
                  // not shout from across the panel.
                  color: INCORRECT.withValues(alpha: 0.85),
                ),
                title: Text(
                  AppLocalizations.of(context)!.delete_my_data,
                  style: const TextStyle(
                    color: INCORRECT,
                    fontSize: 14.5,
                  ),
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/delete-account');
                },
              ),
              const SizedBox(height: 8),
            ],
          ] else ...[
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(
                AppLocalizations.of(context)!.log_in,
                style: const TextStyle(color: ACCENT),
              ),
              onTap: () {
                Navigator.pushNamed(context, '/signin');
              },
            ),

            // ✅ Added Sign Up below Sign In
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text(
                AppLocalizations.of(context)!.sign_up,
                style: const TextStyle(color: ACCENT),
              ),
              onTap: () {
                Navigator.pushNamed(context, '/signup');
              },
            ),

            // Left-aligned App Version
            ListTile(
              leading: const Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.grey,
              ),
              title: Text(
                AppLocalizations.of(context)!.app_version,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}