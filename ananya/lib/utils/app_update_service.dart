import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/app_dialog.dart';

/// Handles Google Play "In-App Updates" (flexible flow).
///
/// When a newer version is published on the Play Store, this shows a popup
/// offering to update. If the user accepts, the update downloads in the
/// background (the user keeps using the app) and is installed after a restart.
///
/// Notes:
///  - Android only. On other platforms the check is skipped.
///  - Only works when the app was installed from Google Play (internal
///    testing track, closed/open testing, or production). It does NOT trigger
///    in debug builds, `flutter run`, or a directly-installed APK.
///  - Never throws to the UI — update problems must not block the app.
class AppUpdateService {
  // Ensures we only prompt once per app session.
  static bool _alreadyChecked = false;

  /// [forceImmediate]: set to `true` only for a critical release that breaks
  /// older versions (e.g. an incompatible backend/API change). It triggers
  /// Google's full-screen, blocking update flow that the user cannot skip.
  /// Leave it `false` (default) for normal releases — those use the friendly
  /// flexible flow (popup + background download).
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool forceImmediate = false,
  }) async {
    if (_alreadyChecked) return;
    _alreadyChecked = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      // Critical release: force a full-screen, blocking update (no popup).
      if (forceImmediate && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      // Normal release: flexible, background update behind a popup.
      if (!info.flexibleUpdateAllowed) return;
      if (!context.mounted) return;

      final accepted = await _showUpdatePopup(context);
      if (accepted != true) return;

      // Download in the background (flexible). Resolves when the download
      // finishes; the user can keep using the app meanwhile.
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) return;

      if (!context.mounted) return;
      _showRestartPrompt(context);
    } catch (e) {
      debugPrint('In-app update check failed: $e');
      // Intentionally ignored — the app must work even if updates can't check.
    }
  }

  static Future<bool?> _showUpdatePopup(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    return showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isBangla ? 'নতুন আপডেট এসেছে' : 'Update available'),
        content: Text(
          isBangla
              ? 'অ্যাপটির একটি নতুন সংস্করণ পাওয়া যাচ্ছে। এখনই আপডেট করবেন?'
              : 'A new version of the app is available. Would you like to update now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isBangla ? 'পরে' : 'Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PRIMARY_COLOR,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBangla ? 'আপডেট' : 'Update'),
          ),
        ],
      ),
    );
  }

  static void _showRestartPrompt(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 1), // stays until the user acts
        content: Text(
          isBangla
              ? 'আপডেট ডাউনলোড হয়েছে। ইনস্টল করতে রিস্টার্ট করুন।'
              : 'Update downloaded. Restart to install.',
        ),
        action: SnackBarAction(
          label: isBangla ? 'রিস্টার্ট' : 'Restart',
          onPressed: () => InAppUpdate.completeFlexibleUpdate(),
        ),
      ),
    );
  }
}
