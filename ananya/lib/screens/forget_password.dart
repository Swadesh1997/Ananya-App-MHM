import 'dart:convert';
import 'package:ananya/widgets/app_loader.dart';

import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/custom_text_field.dart';
import 'package:ananya/widgets/form_field_shell.dart';
import 'package:flutter/material.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/app_dialog.dart';


class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  void changePassword() async {
    if (passwordController.text.isEmpty) {
      _showErrorMessage(
          '${AppLocalizations.of(context)!.password} ${AppLocalizations.of(context)!.is_required}');
      return;
    }
    if (phoneController.text.isEmpty) {
      _showErrorMessage(
          '${AppLocalizations.of(context)!.phone_number} ${AppLocalizations.of(context)!.is_required}');
      return;
    }
    setState(() {
      isLoading = true;
    });

    Map<String, String> data = {
      "number": phoneController.text,
      "password": passwordController.text,
    };
    ApiSettings api = ApiSettings(endPoint: 'user/forget-password');
    try {
      final response = await api.postMethodWithoutToken(json.encode(data));
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      final isBangla = Localizations.localeOf(context).languageCode == 'bn';

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.password_changed_successfully),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushNamed('/signin');
        return;
      }

      // The endpoint is deliberately switched off server-side: the old one
      // reset any account from a phone number alone, with no verification.
      // Say that plainly — reporting it as "invalid credentials" would send
      // her off retyping a password that was never the problem.
      if (response.statusCode == 503) {
        _showErrorMessage(isBangla
            ? 'পাসওয়ার্ড পরিবর্তন এই মুহূর্তে বন্ধ আছে। আপনার প্রোগ্রাম '
                'সমন্বয়কারীর সাথে যোগাযোগ করুন।'
            : 'Password reset is temporarily unavailable. Please contact your '
                'programme coordinator.');
        return;
      }

      if (response.statusCode >= 500) {
        _showErrorMessage(isBangla
            ? 'সার্ভারে সমস্যা হচ্ছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।'
            : 'The server is having a problem. Please try again later.');
        return;
      }

      _showErrorMessage(AppLocalizations.of(context)!.invalid_credentials);
    } catch (e) {
      // Previously this returned silently, so a failed request looked to the
      // user exactly like nothing had happened at all.
      debugPrint('Password reset failed: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorMessage(
        Localizations.localeOf(context).languageCode == 'bn'
            ? 'অনুরোধটি পাঠানো যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।'
            : 'Could not send the request. Check your connection and try again.',
      );
    }
  }

  void _showErrorMessage(String message) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 235, 239),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.forget_password),
      ),
      body: Center(
        child: isLoading
            ? const AppLoader()
            : SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  // No SafeArea on this screen, so the system navigation bar
                  // has to be cleared here or the last row hides beneath it.
                  padding: Theme.of(context).largemainPadding.add(EdgeInsets.only(
                      bottom: MediaQuery.viewPaddingOf(context).bottom + kFormBottomGap)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        width: 200,
                      ),
                      Text(
                        textAlign: TextAlign.center,
                        AppLocalizations.of(context)!
                            .reset_your_account_password,
                        style: const TextStyle(
                          fontSize: 32,
                          color: ACCENT,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 50,
                      ),
                      CustomTextField(
                        text: AppLocalizations.of(context)!.phone_number,
                        controller: phoneController,
                        hintText: AppLocalizations.of(context)!.hint_phone,
                      ),
                      CustomTextField(
                        text: AppLocalizations.of(context)!.new_password,
                        controller: passwordController,
                        hintText: AppLocalizations.of(context)!.hint_new_password,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      ElevatedButton(
                        onPressed: changePassword,
                        style: const ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(ACCENT),
                          minimumSize:
                              WidgetStatePropertyAll(Size(double.infinity, 20)),
                          shadowColor: WidgetStatePropertyAll(Colors.black),
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.change,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
