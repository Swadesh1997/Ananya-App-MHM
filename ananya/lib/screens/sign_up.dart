import 'dart:async';
import 'package:ananya/widgets/app_loader.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/custom_text_field.dart';
import 'package:ananya/widgets/form_field_shell.dart';
import 'package:ananya/widgets/custom_drop_down.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/app_dialog.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final nameController = TextEditingController();
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  String? selectedDistrict;
  String? selectedProject; // STS or Others
  String? selectedProjectArea;
  String? selectedBirthYear;

  bool isLoading = false;

  bool isEmail(String input) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);
  }

  /// Bangla keyboard digits (০-৯) must derive the same address as Latin ones,
  /// otherwise she cannot log back in typing the number the same way.
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

  Future<void> submit() async {
    // Project is deliberately absent from this list. Its label carries no *,
    // so requiring it rejected the form with a "field is required" message
    // while every field marked required was filled in — and nothing on screen
    // said which one was missing. The fields checked here are exactly the
    // ones marked with an asterisk.
    if (nameController.text.isEmpty ||
        identifierController.text.isEmpty ||
        passwordController.text.isEmpty ||
        selectedDistrict == null ||
        selectedBirthYear == null) {
      showError(AppLocalizations.of(context)!.is_required);
      return;
    }

    setState(() => isLoading = true);

    String identifier = identifierController.text.trim();
    String firebaseEmail =
    isEmail(identifier) ? identifier : phoneToFirebaseEmail(identifier);
    String actualEmail = isEmail(identifier) ? identifier : firebaseEmail;

    try {
      // Firebase applies no timeout of its own, so on a stalled connection
      // this never returned and the spinner ran forever. Matches sign-in.
      UserCredential credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: firebaseEmail,
            password: passwordController.text,
          )
          .timeout(const Duration(seconds: 25));

      final user = credential.user;
      if (user == null) throw Exception("Firebase user creation failed");

      // Tell sign-in which address this account actually lives at, so her first
      // login costs one auth request instead of guessing through four. Key and
      // format must stay in step with _cachedEmailPrefix in sign_in.dart.
      if (!isEmail(identifier)) {
        final prefs = await SharedPreferences.getInstance();
        final digits = _latinDigits(identifier).replaceAll(RegExp(r'[^0-9]'), '');
        await prefs.setString('auth_email_$digits', firebaseEmail);
      }

      // A Firestore write Future only completes when the SERVER acknowledges
      // it, so awaiting this outright hung forever whenever the connection
      // dropped between the account being created and the profile being saved
      // — leaving her staring at a spinner with an account that already
      // existed. Firestore persists the write locally at once and replays it
      // when the network returns, so a timeout here loses nothing.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'name': nameController.text,
              'phone': identifier,
              'email': actualEmail,
              'birth_year': selectedBirthYear,
              'dob': "$selectedBirthYear-01-01",
              'location': selectedDistrict,
              'beneficiaries': selectedProjectArea,
              'created_at': FieldValue.serverTimestamp(),
              'source': 'firebase',
            })
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        debugPrint('Signup: profile write queued, will sync when online');
      }

      final api = ApiSettings(endPoint: 'user/signup');
      final body = {
        'name': nameController.text,
        'email': actualEmail,
        'date_of_birth': "$selectedBirthYear-01-01",
        'phone': identifier,
        'password': passwordController.text,
        'district': selectedDistrict,
        'project': selectedProject,
        'project_area': selectedProjectArea,
      };

      // Mirror the account into the Django backend. This is a SECONDARY store:
      // the app is fully usable on Firebase alone (see the token == 'firebase'
      // paths in landing.dart, user_home.dart and unlock_process5.dart).
      // So if Django is unreachable or errors, we must NOT destroy the Firebase
      // account the user just created — we keep it, flag it as unsynced, and
      // let them use the app. A background retry can reconcile it later.
      bool syncedToDjango = false;
      try {
        final response = await api.postMethodWithoutToken(jsonEncode(body));
        syncedToDjango = response.statusCode == 201;
        if (!syncedToDjango) {
          debugPrint(
              'Django signup returned ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Django signup unreachable: $e');
      }

      if (!syncedToDjango) {
        // Same server-acknowledgement trap as the profile write above, and
        // with the Django backend currently down this branch runs on every
        // single signup — so an unbounded await here would hang the flow for
        // everyone on a weak connection.
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'synced_to_django': false}, SetOptions(merge: true))
              .timeout(const Duration(seconds: 15));
        } on TimeoutException {
          debugPrint('Signup: unsynced flag queued, will sync when online');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text(AppLocalizations.of(context)!.account_created_successfully),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/signin');
    } on TimeoutException {
      showError(_msg(
        'সংযোগ খুব ধীর, তাই অ্যাকাউন্ট তৈরি করা যায়নি। ইন্টারনেট দেখে আবার '
            'চেষ্টা করুন।',
        'The connection was too slow to create your account. Check your '
            'internet and try again.',
      ));
    } on FirebaseAuthException catch (e) {
      // Firebase's own text is English-only and written for developers — the
      // raw wording that used to appear here was "A network error (such as
      // timeout, interrupted connection or unreachable host) has occurred",
      // which tells a girl in Bangla-first UI nothing she can act on.
      showError(_messageForSignupError(e));
    } catch (e) {
      // Never show a raw exception. It used to print e.toString() straight
      // into the dialog.
      debugPrint('Signup failed: $e');
      showError(_msg(
        'অ্যাকাউন্ট তৈরি করা যায়নি। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
        'Could not create your account. Please try again in a moment.',
      ));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _msg(String bn, String en) =>
      Localizations.localeOf(context).languageCode == 'bn' ? bn : en;

  String _messageForSignupError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return _msg(
          'ইন্টারনেট সংযোগে সমস্যা হচ্ছে। অ্যাকাউন্ট তৈরি করতে ইন্টারনেট '
              'প্রয়োজন। সংযোগ দেখে আবার চেষ্টা করুন।',
          'Network problem. Creating an account needs an internet connection. '
              'Check your connection and try again.',
        );
      case 'email-already-in-use':
        // Reached after a signup that half-succeeded: the account was created
        // and then the connection dropped. Saying "email already in use" would
        // baffle someone who typed a phone number.
        return _msg(
          'এই নম্বরে ইতিমধ্যে একটি অ্যাকাউন্ট আছে। লগ ইন করার চেষ্টা করুন।',
          'An account already exists for this number. Please try logging in '
              'instead.',
        );
      case 'weak-password':
        return _msg(
          'পাসওয়ার্ডটি খুব সহজ। অন্তত ৬টি অক্ষর দিন।',
          'That password is too simple. Please use at least 6 characters.',
        );
      case 'invalid-email':
        return _msg(
          'ইমেইল বা ফোন নম্বরটি সঠিক নয়।',
          'That email or phone number is not valid.',
        );
      case 'too-many-requests':
        return _msg(
          'অনেকবার চেষ্টা করা হয়েছে। কয়েক মিনিট পরে আবার চেষ্টা করুন।',
          'Too many attempts. Please wait a few minutes and try again.',
        );
      default:
        debugPrint('Signup auth error: ${e.code}');
        return _msg(
          'অ্যাকাউন্ট তৈরি করা যায়নি। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
          'Could not create your account. Please try again in a moment.',
        );
    }
  }

  void showError(String msg) {
    // Every caller reaches this after an await, and she can leave the screen
    // while a slow request is still in flight.
    if (!mounted) return;
    showAppDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Full district list
    final districts = [
      AppLocalizations.of(context)!.dhaka,
      AppLocalizations.of(context)!.khulna,
      AppLocalizations.of(context)!.sylhet,
      AppLocalizations.of(context)!.cumilla,
      AppLocalizations.of(context)!.feni,
      AppLocalizations.of(context)!.brahmanbaria,
      AppLocalizations.of(context)!.rangamati,
      AppLocalizations.of(context)!.noakhali,
      AppLocalizations.of(context)!.chandpur,
      AppLocalizations.of(context)!.lakshmipur,
      AppLocalizations.of(context)!.chattogram,
      AppLocalizations.of(context)!.coxsbazar,
      AppLocalizations.of(context)!.khagrachhari,
      AppLocalizations.of(context)!.bandarban,
      AppLocalizations.of(context)!.sirajganj,
      AppLocalizations.of(context)!.pabna,
      AppLocalizations.of(context)!.bogura,
      AppLocalizations.of(context)!.rajshahi,
      AppLocalizations.of(context)!.natore,
      AppLocalizations.of(context)!.joypurhat,
      AppLocalizations.of(context)!.chapainawabganj,
      AppLocalizations.of(context)!.naogaon,
      AppLocalizations.of(context)!.jashore,
      AppLocalizations.of(context)!.satkhira,
      AppLocalizations.of(context)!.meherpur,
      AppLocalizations.of(context)!.narail,
      AppLocalizations.of(context)!.chuadanga,
      AppLocalizations.of(context)!.kushtia,
      AppLocalizations.of(context)!.magura,
      AppLocalizations.of(context)!.bagerhat,
      AppLocalizations.of(context)!.jhenaidah,
      AppLocalizations.of(context)!.jhalakathi,
      AppLocalizations.of(context)!.patuakhali,
      AppLocalizations.of(context)!.pirojpur,
      AppLocalizations.of(context)!.barishal,
      AppLocalizations.of(context)!.bhola,
      AppLocalizations.of(context)!.barguna,
      AppLocalizations.of(context)!.moulvibazar,
      AppLocalizations.of(context)!.habiganj,
      AppLocalizations.of(context)!.sunamganj,
      AppLocalizations.of(context)!.narsingdi,
      AppLocalizations.of(context)!.gazipur,
      AppLocalizations.of(context)!.shariatpur,
      AppLocalizations.of(context)!.narayanganj,
      AppLocalizations.of(context)!.tangail,
      AppLocalizations.of(context)!.kishoreganj,
      AppLocalizations.of(context)!.manikganj,
      AppLocalizations.of(context)!.munshiganj,
      AppLocalizations.of(context)!.rajbari,
      AppLocalizations.of(context)!.madaripur,
      AppLocalizations.of(context)!.gopalganj,
      AppLocalizations.of(context)!.faridpur,
      AppLocalizations.of(context)!.panchagarh,
      AppLocalizations.of(context)!.dinajpur,
      AppLocalizations.of(context)!.lalmonirhat,
      AppLocalizations.of(context)!.nilphamari,
      AppLocalizations.of(context)!.gaibandha,
      AppLocalizations.of(context)!.thakurgaon,
      AppLocalizations.of(context)!.rangpur,
      AppLocalizations.of(context)!.kurigram,
      AppLocalizations.of(context)!.sherpur,
      AppLocalizations.of(context)!.mymensingh,
      AppLocalizations.of(context)!.jamalpur,
      AppLocalizations.of(context)!.netrokona,
    ];

    // Projects
    final projects = [
      AppLocalizations.of(context)!.sts_project,
      AppLocalizations.of(context)!.others,
    ];

    // BRAC project areas — 22 upazilas, grouped by district.
    final stsAreas = [
      // Rajshahi
      AppLocalizations.of(context)!.tanore,
      // Naogaon
      AppLocalizations.of(context)!.naogaon_sadar,
      AppLocalizations.of(context)!.manda,
      AppLocalizations.of(context)!.raninagar,
      AppLocalizations.of(context)!.atrai,
      AppLocalizations.of(context)!.patnitala,
      AppLocalizations.of(context)!.sapahar,
      AppLocalizations.of(context)!.dhamoirhat,
      AppLocalizations.of(context)!.mohadevpur,
      AppLocalizations.of(context)!.badalgachi,
      // Patuakhali
      AppLocalizations.of(context)!.bauphal,
      AppLocalizations.of(context)!.dashmina,
      AppLocalizations.of(context)!.dumki,
      AppLocalizations.of(context)!.golachipa,
      AppLocalizations.of(context)!.kalapara,
      AppLocalizations.of(context)!.mirzaganj,
      AppLocalizations.of(context)!.patuakhali_sadar,
      // Barguna
      AppLocalizations.of(context)!.amtali,
      AppLocalizations.of(context)!.barguna_sadar,
      AppLocalizations.of(context)!.betagi,
      AppLocalizations.of(context)!.patharghata,
      AppLocalizations.of(context)!.bamna,
    ];

    // Others Areas
    final othersAreas = [
      AppLocalizations.of(context)!.dhaka_north_city_corporation,
      AppLocalizations.of(context)!.dhaka_south_city_corporation,
      AppLocalizations.of(context)!.khulna_city_corporation,
      AppLocalizations.of(context)!.chattogram_city_corporation,
      AppLocalizations.of(context)!.paikgacha_municipality,
      AppLocalizations.of(context)!.savar,
      AppLocalizations.of(context)!.gazipur,
      AppLocalizations.of(context)!.lalmonirhat,
    ];

    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 1949, (i) => '${1950 + i}');

    List<String> getProjectAreas() {
      if (selectedProject == AppLocalizations.of(context)!.sts_project) return stsAreas;
      if (selectedProject == AppLocalizations.of(context)!.others) return othersAreas;
      return [];
    }

    return Scaffold(
      backgroundColor: BACKGROUND,
      body: Center(
        child: isLoading
            ? const AppLoader()
            : SingleChildScrollView(
          // viewPadding, not padding: the bottom inset is what the system
          // navigation bar occupies, and the last row — the link to sign in —
          // was sitting underneath it. viewPadding keeps that room even while
          // the keyboard is up, where padding would report zero.
          //
          // kFormBottomGap on top of the inset, not instead of it. Clearing the
          // bar by a hair still reads as though the link is falling off the
          // screen, and the gap costs nothing on a form that already scrolls.
          padding: EdgeInsets.fromLTRB(24, 24, 24,
              kFormBottomGap + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.home, size: 32),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (route) => false);
                  },
                ),
              ),
              Image.asset('assets/images/signup.png', width: 400),
              const SizedBox(height: 18),
              // The form opened straight onto input boxes with no heading, so
              // there was nothing saying what the page was for.
              Text(
                AppLocalizations.of(context)!.create_a_new_account,
                style: const TextStyle(
                  fontSize: 23,
                  color: ACCENT,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 22),
              CustomTextField(
                text: "${AppLocalizations.of(context)!.name} *",
                controller: nameController,
                icon: Icons.person_outline_rounded,
                hintText: AppLocalizations.of(context)!.hint_your_name,
              ),
              CustomTextField(
                text:
                "${AppLocalizations.of(context)!.phone_number} / ${AppLocalizations.of(context)!.email} *",
                controller: identifierController,
                icon: Icons.phone_iphone_rounded,
                hintText: AppLocalizations.of(context)!.hint_phone_or_email,
              ),
              CustomTextField(
                text: "${AppLocalizations.of(context)!.password} *",
                controller: passwordController,
                hintText: AppLocalizations.of(context)!.hint_password,
                helperText: AppLocalizations.of(context)!.password_instruction,
              ),
              CustomDropdown(
                header: "${AppLocalizations.of(context)!.date_of_birth} *",
                options: years,
                icon: Icons.cake_outlined,
                onChanged: (v) => selectedBirthYear = v,
              ),
              CustomDropdown(
                header: "${AppLocalizations.of(context)!.district} *",
                options: districts,
                icon: Icons.location_on_outlined,
                onChanged: (v) => selectedDistrict = v,
              ),
              CustomDropdown(
                header: AppLocalizations.of(context)!.project,
                options: projects,
                icon: Icons.workspaces_outline,
                onChanged: (v) {
                  setState(() {
                    selectedProject = v;
                    selectedProjectArea = null;
                  });
                },
              ),
              if (getProjectAreas().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: CustomDropdown(
                    header:
                    AppLocalizations.of(context)!.select_your_area,
                    options: getProjectAreas(),
                    icon: Icons.map_outlined,
                    onChanged: (v) => selectedProjectArea = v,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: submit,
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
                  AppLocalizations.of(context)!.create_a_new_account,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signin'),
                child: Text(
                  AppLocalizations.of(context)!
                      .already_have_an_account_click_here_for_login,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}