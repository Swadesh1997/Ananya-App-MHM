import 'dart:convert';
import 'package:ananya/widgets/app_loader.dart';

import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/app_dialog.dart';


class AddAUser extends StatefulWidget {
  const AddAUser({super.key});

  @override
  State<AddAUser> createState() => _AddAUserState();
}

class _AddAUserState extends State<AddAUser> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  void addUser() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Failed to load SharedPreferences: $e');
      return;
    }
    if (usernameController.text.isEmpty) {
      _showErrorMessage("Username is required.");
      return;
    }
    if (phoneController.text.isEmpty) {
      _showErrorMessage("Phone Number is required.");
      return;
    }
    setState(() {
      isLoading = true;
    });
    String? id = prefs.getString('userId');
    ApiSettings api = ApiSettings(endPoint: 'user/add-user/$id');
    Map<String, dynamic> data = {
      "name": usernameController.text,
      "phone": phoneController.text,
      "email": emailController.text,
    };
    try {
      final response = await api.postMethod(json.encode(data));
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      if (response.statusCode == 201) {
        json.decode(response.body);
        // '/' is the splash screen, so this replayed the four-second
        // splash and left the finished page on the stack underneath.
        // Go to the landing page and clear what came before it.
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      } else {
        debugPrint('Failed to post data. Status code: ${response.statusCode}');
        debugPrint('Response body: $response');
        final Map<String, dynamic> responseMap = jsonDecode(response.body);
        if (responseMap.containsKey('phone') &&
            responseMap['phone'] is List &&
            responseMap['phone'].isNotEmpty) {
          _showErrorMessage(responseMap['phone'][0]);
        } else if (responseMap.containsKey('email') &&
            responseMap['email'] is List &&
            responseMap['email'].isNotEmpty) {
          _showErrorMessage(responseMap['email'][0]);
        } else {
          _showErrorMessage(responseMap['error']);
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error occurred: $e');
    }
  }

  void _showErrorMessage(String message) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
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
        title: Text(AppLocalizations.of(context)!.add_a_user),
      ),
      body: Center(
        child: isLoading
            ? const AppLoader()
            : SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: Theme.of(context).largemainPadding,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/splash.png',
                        fit: BoxFit.cover,
                        width: 200,
                      ),
                      Text(
                        textAlign: TextAlign.center,
                        AppLocalizations.of(context)!.add_a_user,
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
                        text: AppLocalizations.of(context)!.name,
                        controller: usernameController,
                      ),
                      CustomTextField(
                        text: AppLocalizations.of(context)!.phone_number,
                        controller: phoneController,
                      ),
                      CustomTextField(
                        text: AppLocalizations.of(context)!.email,
                        controller: emailController,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      ElevatedButton(
                        onPressed: addUser,
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
                          AppLocalizations.of(context)!.add,
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
