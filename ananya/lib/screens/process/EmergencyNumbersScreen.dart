import 'package:flutter/material.dart';
import 'package:ananya/l10n/app_localizations.dart';

import '../help.dart';

class EmergencyNumbersScreen extends StatelessWidget {
  const EmergencyNumbersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.help),
        backgroundColor: Colors.pinkAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // Add your existing Help card(s)
          Help(),
          // If you have more numbers, you can add multiple HelpCard widgets here
        ],
      ),
    );
  }
}
