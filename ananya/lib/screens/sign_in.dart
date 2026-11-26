import 'package:ananya/widgets/app_loader.dart';
import 'dart:async';
import 'dart:convert';
import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/custom_text_field.dart';
import 'package:ananya/widgets/form_field_shell.dart';
import 'package:ananya/screens/landing/landing.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ananya/utils/app_dialog.dart';
import 'package:ananya/services/user_profile.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  ApiSettings api = ApiSettings(endPoint: 'user/login');

  bool isEmail(String input) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);

  /// Bangla keyboard digits (০-৯) must derive the same address as Latin ones,
  /// otherwise the same person typing the same number cannot log back in.
  String _latinDigits(String input) {
    const bn = '০১২৩৪৫৬৭৮৯';
    final out = StringBuffer();
    for (final ch in input.split('')) {
      final i = bn.indexOf(ch);
      out.write(i >= 0 ? '$i' : ch);
    }
    return out.toString();
  }

  String phoneToFirebaseEmail(String phone) {
    final clean = _latinDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
    return 'user$clean@ananya.com';
  }

  /// Guards against a second tap starting a parallel sign-in. Two attempts in
  /// flight double the failed-request count against Firebase, which is what
  /// pushes a device into the lockout described on [_cachedEmailPrefix].
  bool _submitting = false;

  /// Where the address that actually worked for a phone number is remembered.
  ///
  /// A phone sign-in used to try up to four derived addresses on every attempt,
  /// so one wrong password cost four failed requests. A couple of typos was
  /// enough to trip Firebase's abuse protection — after which the CORRECT
  /// password also failed until the block expired. That is why sign-in worked
  /// only sometimes. Caching the known-good address caps a returning user at
  /// one request per attempt.
  static const String _cachedEmailPrefix = 'auth_email_';

  String _digits(String s) =>
      _latinDigits(s).replaceAll(RegExp(r'[^0-9]'), '');

  String _msg(String bn, String en) =>
      Localizations.localeOf(context).languageCode == 'bn' ? bn : en;

  /// One auth request, with a ceiling. Firebase applies no timeout of its own,
  /// so a stalled network held the spinner up indefinitely.
  Future<UserCredential> _signIn(String email, String password) {
    return FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 25));
  }

  void check() async {
    // A second tap while the first attempt is in flight only spends more of
    // the abuse budget.
    if (_submitting) return;

    if (identifierController.text.isEmpty) {
      _showErrorMessage(
          'Phone / Email ${AppLocalizations.of(context)!.is_required}');
      return;
    }

    if (passwordController.text.isEmpty) {
      _showErrorMessage(
          '${AppLocalizations.of(context)!.password} ${AppLocalizations.of(context)!.is_required}');
      return;
    }

    _submitting = true;
    setState(() => isLoading = true);

    String identifier = identifierController.text.trim();
    String password = passwordController.text;

    UserCredential? userCredential;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try Firebase first. Note: modern firebase_auth reports a bad password
      // as 'invalid-credential' (not 'wrong-password') when Email Enumeration
      // Protection is on, so we must never switch on a single code here.
      if (isEmail(identifier)) {
        try {
          userCredential = await _signIn(identifier, password);
        } on FirebaseAuthException catch (e) {
          if (_isFatalAuthError(e)) {
            _showErrorMessage(_messageForAuthError(e));
            return;
          }
          // Fall back to Django — the account may pre-date Firebase.
          await _djangoLogin(identifier, password);
          return;
        }
      } else {
        final phoneKey = _cachedEmailPrefix + _digits(identifier);
        final cached = prefs.getString(phoneKey);

        // A remembered address means any failure here is a wrong password, not
        // a wrong guess: the legacy variants cannot help and would only spend
        // more of the abuse budget.
        final List<String> emailAttempts = cached != null
            ? <String>[cached]
            : <String>[
                phoneToFirebaseEmail(identifier),
                '$identifier@ananya.com',
                '$identifier@ananya.app',
                'user${_digits(identifier)}@ananya.app',
              ];

        String? workingEmail;
        FirebaseAuthException? lastError;
        for (String email in emailAttempts) {
          try {
            userCredential = await _signIn(email, password);
            workingEmail = email;
            break;
          } on FirebaseAuthException catch (e) {
            lastError = e;
            if (_isFatalAuthError(e)) break;
          }
        }

        if (userCredential == null) {
          if (lastError != null && _isFatalAuthError(lastError)) {
            _showErrorMessage(_messageForAuthError(lastError));
            return;
          }
          // A remembered address means this IS a Firebase account, so a
          // refused credential is a wrong password, not a wrong guess. Django
          // cannot help — and with its database down the fallback burns its
          // full 15-second timeout before saying so, which reads as a hang.
          if (cached != null) {
            if (!mounted) return;
            _showErrorMessage(AppLocalizations.of(context)!.invalid_credentials);
            return;
          }

          // Not a Firebase account (or wrong derived address) — try Django.
          await _djangoLogin(identifier, password);
          return;
        }

        if (workingEmail != null) {
          await prefs.setString(phoneKey, workingEmail);
        }
      }

      final user = userCredential.user;
      if (user == null) {
        if (mounted) {
          _showErrorMessage(AppLocalizations.of(context)!.invalid_credentials);
        }
        return;
      }

      await prefs.setString('userNumber', identifier);
      await prefs.setString('userId', user.uid);
      // Not displayName: signup writes her name to Firestore, never to the
      // Firebase Auth profile, so displayName is always null here and this
      // used to store an empty string — which is why the sidebar showed a
      // blank where her name belongs.
      final storedName = await UserProfile.resolve();
      if (storedName != null) {
        await UserProfile.save(storedName);
      } else {
        await prefs.setString('userName', user.displayName ?? '');
      }
      await prefs.setBool('is_superuser', false);
      await prefs.setString('token', 'firebase');

      // Awaited rather than fired into a post-frame callback: the spinner used
      // to clear while this was still running, leaving an idle-looking login
      // screen that invited another tap — and another auth request.
      await _checkCalendarAndNavigate(userId: user.uid);
    } on TimeoutException {
      if (mounted) {
        _showErrorMessage(_msg(
          'ইন্টারনেট সংযোগে সমস্যা হচ্ছে। সংযোগ দেখে আবার চেষ্টা করুন।',
          'Network problem. Check your connection and try again.',
        ));
      }
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      if (mounted) {
        _showErrorMessage(AppLocalizations.of(context)!.invalid_credentials);
      }
    } finally {
      _submitting = false;
      // Always clear the overlay. Previously an unhandled error code left
      // isLoading true forever, freezing the screen behind a dark spinner.
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Errors where retrying against another backend is pointless.
  bool _isFatalAuthError(FirebaseAuthException e) {
    return e.code == 'too-many-requests' ||
        e.code == 'user-disabled' ||
        e.code == 'network-request-failed';
  }

  String _messageForAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        // Firebase's own wording is English-only and reads as though the
        // account is broken, when in fact sign-in is merely paused.
        return _msg(
          'অনেকবার চেষ্টা করা হয়েছে। নিরাপত্তার জন্য সাময়িকভাবে বন্ধ রাখা হয়েছে — কয়েক মিনিট পরে আবার চেষ্টা করুন।',
          'Too many attempts. Sign-in is paused for a few minutes for security — please try again shortly.',
        );
      case 'network-request-failed':
        return _msg(
          'ইন্টারনেট সংযোগে সমস্যা হচ্ছে। সংযোগ দেখে আবার চেষ্টা করুন।',
          'Network problem. Check your connection and try again.',
        );
      case 'user-disabled':
        return _msg(
          'এই অ্যাকাউন্টটি বন্ধ করা হয়েছে।',
          'This account has been disabled.',
        );
      default:
        return AppLocalizations.of(context)!.invalid_credentials;
    }
  }

  Future<void> _djangoLogin(String identifier, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {'phone': identifier, 'password': password};

    try {
      final response = await api.postMethodWithoutToken(json.encode(data));
      if (!mounted) return;

      // A 5xx means the backend itself is broken (its database is down as of
      // Aug 2026). Telling the user her password is wrong would be a lie.
      if (response.statusCode >= 500) {
        _showErrorMessage(_msg(
          'সার্ভারে সমস্যা হচ্ছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
          'The server is having a problem. Please try again later.',
        ));
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> user = responseData['user'];

        await prefs.setString('userNumber', identifier);
        await prefs.setString('userId', user['id'].toString());
        await prefs.setString('userName', user['name']);
        await prefs.setBool('is_superuser', user['is_superuser']);
        await prefs.setString('token', responseData['token']);

        if (responseData['managed_users'].isNotEmpty) {
          await prefs.setString(
              "cohort-user", responseData['managed_users'][0].toString());
        }

        await _checkCalendarAndNavigate(userId: user['id'].toString());
      } else {
        _showErrorMessage(AppLocalizations.of(context)!.invalid_credentials);
      }
    } catch (e) {
      // A dead or unreachable backend is not a wrong password, and saying so
      // sends the user off to reset a password that was never the problem.
      debugPrint('Django login failed: $e');
      if (!mounted) return;
      _showErrorMessage(_msg(
        'লগ ইন করা যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
        'Could not sign in. Check your connection and try again.',
      ));
    }
  }

  Future<void> _checkCalendarAndNavigate({required String userId}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasCalendar = false;
    final token = prefs.getString('token');

    if (token == 'firebase') {
      // If Firestore cannot answer (offline, slow network), assume no calendar
      // and continue — the user is already authenticated, and dead-ending here
      // left the screen silently frozen after a correct login.
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('period')
            .doc('latest')
            .get()
            .timeout(const Duration(seconds: 10));
        // Not doc.exists: removing every period leaves period/latest in place
        // with an empty last_period_start, so existence alone would send her
        // back to an empty tracker on her next login.
        final storedStart = doc.data()?['last_period_start'];
        hasCalendar = doc.exists &&
            storedStart is String &&
            storedStart.trim().isNotEmpty;
      } catch (e) {
        debugPrint('calendar check failed, continuing to home: $e');
      }
    } else {
      hasCalendar = prefs.getBool('calendar_completed') ?? false;
    }

    await prefs.setBool('calendar_completed', hasCalendar);

    _navigateSafely(() {
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  void _navigateSafely(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback();
    });
  }

  void _showErrorMessage(String message) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0E4),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              // Inside a SafeArea, so the navigation bar is already cleared;
              // this is the breathing room under the last row, matching the
              // sign-up form.
              padding: const EdgeInsets.fromLTRB(24, 0, 24, kFormBottomGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  // ✅ Clickable Home Icon at top-right
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.home, size: 32),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LandingPage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/signup.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    textAlign: TextAlign.center,
                    AppLocalizations.of(context)!
                        .login_with_your_mobile_number_and_password,
                    style: const TextStyle(
                      fontSize: 25,
                      color: ACCENT,
                      fontWeight: FontWeight.bold,
                      height: 1.28,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomTextField(
                    text:
                    "${AppLocalizations.of(context)!.phone_number} / ${AppLocalizations.of(context)!.email}",
                    controller: identifierController,
                    hintText: AppLocalizations.of(context)!.hint_phone_or_email,
                    icon: Icons.person_outline_rounded,
                  ),
                  CustomTextField(
                    text: AppLocalizations.of(context)!.password,
                    controller: passwordController,
                    hintText: AppLocalizations.of(context)!.hint_password,
                    helperText:
                        AppLocalizations.of(context)!.password_instruction,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    // Disabled while an attempt is in flight. The dark overlay
                    // below covers the screen, but only after the next frame —
                    // a fast double-tap slipped a second sign-in through.
                    onPressed: isLoading ? null : check,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ACCENT,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.log_in,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                            color: ACCENT.withValues(alpha: 0.12), height: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ACCENT,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: ACCENT.withValues(alpha: 0.35), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!
                          .dont_have_an_account_create_a_new_account,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // "Forgot password" is hidden, not deleted — the screen and
                  // its route are still there for whenever a real reset flow
                  // exists.
                  //
                  // Nothing behind it could work. It posts to Django's
                  // user/forget-password, which is switched off deliberately:
                  // the original took a phone number and a new password and
                  // set it, with no OTP or token, so anyone who knew a girl's
                  // number could take over her account from this very screen.
                  //
                  // It would not work even switched on. Sign-in goes through
                  // Firebase, so her credential lives there; resetting a row
                  // in Django's database would change nothing she logs in
                  // with. And Firebase's own reset needs an email, while
                  // phone signups are stored as user<number>@ananya.com,
                  // which can receive none.
                  //
                  // A coordinator can reset a password from the Firebase
                  // console. A button that asks her to type a new one and
                  // then fails is worse than no button.
                  const SizedBox(height: 32),
                ],
              ),
            ),
            // Opaque, in the page's own cream, so signing in looks the same
            // here as waiting looks anywhere else in the app. It used to be a
            // translucent black wash over the form, which left the whole
            // screen grey and murky behind a small animation — reading as
            // something having gone wrong rather than something in progress.
            //
            // Still covers the screen, so a second tap cannot start a second
            // sign-in while the first is in flight.
            if (isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: BACKGROUND,
                  child: AppLoader(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}