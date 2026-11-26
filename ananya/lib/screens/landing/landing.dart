import 'package:ananya/widgets/home_carousel.dart';
import 'package:ananya/utils/probahini_gate.dart';
import 'package:ananya/widgets/app_loader.dart';
import 'dart:async';
import 'package:ananya/screens/landing/superuser_home.dart';
import 'package:ananya/screens/landing/user_home.dart';
import 'package:ananya/screens/process/unlock_process1.dart';
import 'package:ananya/widgets/user_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/app_update_service.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/screens/process/knowledge_hub_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ananya/widgets/knowledge_hub_row.dart';
import 'package:ananya/widgets/language_toggle.dart';
import 'package:ananya/utils/app_dialog.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int _selectedIndex = 0;
  late Future<bool> userPresent;
  late Future<bool> calendarCompleted;

  /// Resolved once, in initState.
  ///
  /// This used to be written inline as `future: _isSuperuser()` inside build.
  /// That created a NEW future on every rebuild, which sent the FutureBuilder
  /// back to `waiting` and replaced the entire home screen with a spinner —
  /// throwing away UserHome's state and restarting its data load. Tapping a
  /// bottom-bar item calls setState, so the tap itself caused the flash, which
  /// is why the buttons looked like they had done nothing.
  late Future<bool> superuser;

  /// Stops a second tap opening a duplicate page while the first is still on
  /// its way. The knowledge hub is slow enough to build that an impatient
  /// double-tap could stack two copies of it.
  bool _navigating = false;
  static const Color bgColor = Color(0xFFF8F0E4);

  // Scroll controller for Knowledge Hub

  @override
  void initState() {
    super.initState();
    userPresent = _safeGetUserStatus();
    calendarCompleted = _safeGetCalendarStatus();
    superuser = _isSuperuser();

    // Check Google Play for a newer version once the screen is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppUpdateService.checkForUpdate(context);
    });
  }

  Future<bool> _safeGetUserStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');

      if (userId == null || token == null) return false;
      if (token == 'firebase') return true;

      final api = ApiSettings(endPoint: 'user/get-user/$userId');
      final response = await api.getMethod();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("getUserStatus error: $e");
      return false;
    }
  }

  Future<bool> _safeGetCalendarStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool("calendar_completed") ?? false;
    } catch (e) {
      debugPrint("getCalendarStatus error: $e");
      return false;
    }
  }

  Future<bool> _isSuperuser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == 'firebase') return false;
      return prefs.getBool('is_superuser') ?? false;
    } catch (e) {
      debugPrint("isSuperuser error: $e");
      return false;
    }
  }

  Future<void> _onItemTapped(int index) async {
    if (_navigating) return;

    // 1 and 2 open a page over this one; 0 is this page, so it only needs to
    // select the tab.
    if (index == 1 || index == 2) {
      _navigating = true;
      try {
        if (index == 1) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KnowledgeHubPage()),
          );
        } else {
          await Navigator.pushNamed(context, '/faq');
        }
      } finally {
        if (mounted) _navigating = false;
      }
      return;
    }

    // Nothing to redraw when the tab is already selected, and a needless
    // setState here is what used to trigger the spinner flash.
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              child: Text(loc?.nearby_hospital ?? "Nearby Hospital"),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              child: Text(loc?.nearby_pharmacy ?? "Nearby Pharmacy"),
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

  Widget _homeBody() {
    final loc = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCarousel(),
          const SizedBox(height: 16),

          // Knowledge Hub Section with arrows
          KnowledgeHubRow(
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KnowledgeHubPage()),
            ),
          ),

          const SizedBox(height: 52),

          // Chatbot Section with styled button
          _chatCard(
            image: 'assets/images/chatbot.png',
            description: loc
                    ?.hi_i_am_probahini_your_menstrual_companion_ask_me_anything ??
                "Hi, I am Probahini, your menstrual companion.",
            buttonText: loc?.chat ?? "Chat",
            onPressed: () => openProbahini(context),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    final loc = AppLocalizations.of(context);

    return HomeCarousel(
      slides: [
        CarouselSlide(
          image: 'assets/images/setyourcalendar.png',
          description: loc?.calendar_description ?? "",
          buttonText: loc?.set_your_calendar ?? "Set Your Calendar",
          onPressed: () async {
            if (!(await userPresent)) {
              _showLoginPrompt();
              return;
            }
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UnlockProcess1()),
            );
          },
        ),
        CarouselSlide(
          image: 'assets/images/viewmap.png',
          description: loc?.map_description ?? "",
          buttonText: loc?.view_map ?? "View Map",
          onPressed: _showMapSelectionDialog,
        ),
        CarouselSlide(
          image: 'assets/images/number.png',
          description: loc?.emergency_description ?? "",
          buttonText: loc?.view_numbers ?? "View Numbers",
          onPressed: () => Navigator.pushNamed(context, '/help'),
        ),
        CarouselSlide(
          image: 'assets/images/insidecalendar2.png',
          description: loc?.faqs_description ?? "",
          buttonText: loc?.faqs ?? "FAQ",
          onPressed: () => Navigator.pushNamed(context, '/faq'),
        ),
      ],
    );
  }

  /// Probahini section: the logo across the top, the greeting beneath it,
  /// and a full-width call to action. Deliberately not a card — the logo's own
  /// cream background matches the page, so any container would show a seam.
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

  /// Shown when a signed-out user taps something that needs an account.
  void _showLoginPrompt() {
    final loc = AppLocalizations.of(context);
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          loc?.please_login_to_continue ?? "Please login to continue",
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: ACCENT),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              loc?.cancel ?? "Cancel",
              style: TextStyle(color: ACCENT.withValues(alpha: 0.55)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PRIMARY_COLOR,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              minimumSize: const Size(120, 40),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/signup');
            },
            child: Text(
              loc?.sign_up ?? "Sign Up",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getBodyWidget() {
    return FutureBuilder<bool>(
      future: userPresent,
      builder: (_, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }
        if (userSnap.hasError || userSnap.data != true) return _homeBody();

        return FutureBuilder<bool>(
          future: calendarCompleted,
          builder: (_, calSnap) {
            if (calSnap.connectionState == ConnectionState.waiting) {
              return const AppLoader();
            }
            if (calSnap.hasError || calSnap.data != true) return _homeBody();

            return FutureBuilder<bool>(
              future: superuser,
              builder: (_, superSnap) {
                if (superSnap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                if (superSnap.hasError) return _homeBody();

                return superSnap.data == true
                    ? SuperuserHome(onselect: _onItemTapped)
                    : UserHome(
                        onselect: _onItemTapped,
                        // The flag is read once in initState, so clearing it
                        // is not enough on its own — this re-reads it and
                        // rebuilds, which swaps the tracker back for the
                        // "Set your calendar" banner.
                        onCalendarCleared: () {
                          if (!mounted) return;
                          setState(() {
                            calendarCompleted = _safeGetCalendarStatus();
                          });
                        },
                      );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      drawer: UserSidebar(onselect: _onItemTapped),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        // The same switch as the drawer, on the screen everyone lands on.
        // Finding it meant opening the menu first, which is a tap too many for
        // the one control a girl who cannot read the current language needs.
        //
        // The current value is read from Localizations rather than held here:
        // applyLanguage rebuilds the whole app, so local state would only be a
        // second copy of the truth waiting to disagree with it.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: LanguageToggle(
                value: Localizations.localeOf(context).languageCode,
                compact: true,
                onChanged: (code) => applyLanguage(context, code),
              ),
            ),
          ),
        ],
      ),
      body: _getBodyWidget(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: SECONDARY_COLOR,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.language), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: ""),
        ],
      ),
    );
  }
}