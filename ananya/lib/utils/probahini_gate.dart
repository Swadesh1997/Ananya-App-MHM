import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/app_dialog.dart';
import 'package:ananya/utils/constants.dart';

/// The single way into Probahini.
///
/// Four screens open the chat — the public landing page, the signed-in home,
/// the sidebar, and "ask this" on a knowledge-hub article. Each checking for
/// itself would be four chances to forget, and the landing page is reachable
/// without an account at all: the splash screen goes straight there regardless
/// of whether anyone is signed in.
///
/// Sign-in is required because every question is recorded with the asker's age
/// and district, and a signed-out user has neither.
///
/// It is a real trade. Probahini used to answer anyone who opened the app, and
/// some girls will now turn away at this dialog rather than make an account.
/// The programme accepted that in exchange for knowing what is actually being
/// asked, and where.
///
/// The dialog deliberately matches the one the period tracker already shows —
/// same words, same shape, same buttons. Two different-looking prompts for the
/// same requirement read as two different rules.
Future<void> openProbahini(BuildContext context, {String? question}) async {
  if (FirebaseAuth.instance.currentUser != null) {
    Navigator.pushNamed(context, '/chat', arguments: question);
    return;
  }

  final loc = AppLocalizations.of(context);

  await showAppDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        loc?.please_login_to_continue ?? 'Please sign up or log in to continue',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: ACCENT,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(loc?.cancel ?? 'Cancel'),
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
            loc?.sign_up ?? 'Sign up',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
