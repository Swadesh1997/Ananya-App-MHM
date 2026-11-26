import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ananya/chat/chat_page.dart';
import 'firebase_options.dart';
import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/utils/local-notification.dart';
import 'package:ananya/utils/scheme.dart';
import 'package:ananya/utils/splash-screen.dart';
import 'package:ananya/l10n/app_localizations.dart';

// Screens
import 'package:ananya/screens/landing/landing.dart';
import 'package:ananya/screens/sign_in.dart';
import 'package:ananya/screens/sign_up.dart';
import 'package:ananya/screens/forget_password.dart';
import 'package:ananya/screens/add_a_user.dart';
import 'package:ananya/screens/choose_user.dart';
import 'package:ananya/screens/process/unlock_process1.dart';
import 'package:ananya/screens/process/unlock_process2.dart';
import 'package:ananya/screens/process/unlock_process3.dart';
import 'package:ananya/screens/process/period_length_page.dart';
import 'package:ananya/screens/process/unlock_process4.dart';
import 'package:ananya/screens/process/unlock_process5.dart';
import 'package:ananya/screens/history/individual.dart';
import 'package:ananya/screens/history/cohort.dart';
import 'package:ananya/screens/process/knowledge_hub_page.dart';
import 'package:ananya/screens/process/faq_page.dart';
import 'package:ananya/screens/knowledge_nexus_info.dart';
import 'package:ananya/screens/myth_buster.dart';
import 'package:ananya/screens/help.dart';
import 'package:ananya/screens/delete_account.dart';

/// Helper function to safely initialize Firebase.
///
/// On Android the native SDK auto-initialises the default app from
/// google-services.json before Dart code runs. Checking `Firebase.apps` first
/// does not prevent that: the list can read empty at check time and the native
/// app can exist by the time initializeApp() actually executes, which threw
/// "[core/duplicate-app] A Firebase App named [DEFAULT] already exists" on
/// every launch. Catching the race is the reliable form — the app that already
/// exists is the one we want.
Future<FirebaseApp> initFirebase() async {
  try {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') return Firebase.app();
    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone first
  tz.initializeTimeZones();

  // Initialize Firebase safely
  try {
    await initFirebase();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Offline persistence is on by default on mobile, but the default cache is
  // capped and can evict. Ananya is used where a connection appears only
  // occasionally, so the cache must be allowed to hold a full cycle history
  // however long the device stays offline. Set before any Firestore call.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore settings error: $e');
  }

  // Initialize local notifications
  await LocalNotifications.init();

  // Load language preference
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? languageCode = prefs.getString('language_code');

  runApp(
    MyApp(
      initialLocale: Locale(languageCode ?? 'bn'),
    ),
  );
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;
  const MyApp({super.key, required this.initialLocale});

  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_MyAppState>()?.setLocale(locale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PeriodState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Scheme.lightTheme,
        themeMode: ThemeMode.system,
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SplashScreen(),
        routes: {
          '/chat': (c) {
            // Arriving from a knowledge-hub article carries that topic's
            // question, so Probahini opens mid-conversation.
            final args = ModalRoute.of(c)?.settings.arguments;
            return ChatPage(openingQuestion: args is String ? args : null);
          },
          '/home': (_) => const LandingPage(),
          '/signin': (_) => const SignIn(),
          '/signup': (_) => const SignUp(),
          '/forget-password': (_) => const ForgetPassword(),
          '/add-user': (_) => const AddAUser(),
          '/choose-user': (c) {
            final args = ModalRoute.of(c)!.settings.arguments as bool;
            return ChooseUser(updateperiod: args);
          },
          '/unlock-process/1': (_) => const UnlockProcess1(),
          '/unlock-process/2': (_) => const UnlockProcess2(),
          '/unlock-process/3': (c) {
            // Defensive cast: a bare 'as bool' threw whenever this screen was
            // reached without arguments, which is easy to do from any of the
            // several places that deep-link into it.
            final args = ModalRoute.of(c)!.settings.arguments;
            final bool updatePeriod = args is bool ? args : false;
            return UnlockProcess3(updatePeriod: updatePeriod);
          },
          '/period-length': (_) => const PeriodLengthPage(),
          '/unlock-process/4': (_) => const UnlockProcess4(),
          '/unlock-process/5': (c) {
            final args = ModalRoute.of(c)!.settings.arguments;
            final bool updatePeriod = args is bool ? args : false;

            return UnlockProcess5(updatePeriod: updatePeriod);
          },
          // '/loading' removed: nothing ever pushed it. The Loading widget
          // itself is alive and used inline as a spinner.
          '/history/individual': (_) => const IndividualHistory(),
          '/history/cohort': (_) => const CohortHistory(),
          '/knowledge-hub': (_) => const KnowledgeHubPage(),
          '/myth-buster': (_) => const MythBusterScreen(),
          '/faq': (_) => const FaqPage(),
          '/knowledge-nexus-info': (c) {
            final args = ModalRoute.of(c)!.settings.arguments as List;
            return KnowledgeNexusInfo(id: args[0], data: args[1]);
          },
          '/help': (_) => const Help(),
          '/delete-account': (_) => const DeleteAccount(),
        },
      ),
    );
  }
}