import 'package:flutter/material.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/services/account_deletion_service.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/app_dialog.dart';

/// "Delete my data" — the account and everything stored under it.
///
/// Deliberately not a one-tap action. The page states plainly what disappears
/// before asking for anything, and the password field is both an identity
/// check and a moment to stop: on a shared or unlocked handset, tapping a red
/// button should not be enough to erase someone's health history.
class DeleteAccount extends StatefulWidget {
  const DeleteAccount({super.key});

  @override
  State<DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscured = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmThenDelete() async {
    final loc = AppLocalizations.of(context)!;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.delete_my_data),
        content: Text(loc.delete_cannot_be_undone),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: INCORRECT),
            child: Text(loc.delete_button),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final outcome = await AccountDeletionService.deleteEverything(
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (outcome == DeletionOutcome.success) {
      // Nothing of hers is left on the handset, so the whole back stack goes
      // too — no screen behind this one still holds her data.
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/signin', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.delete_success)),
      );
      return;
    }

    setState(() {
      _busy = false;
      _error = switch (outcome) {
        DeletionOutcome.wrongPassword => loc.delete_wrong_password,
        DeletionOutcome.noConnection => loc.delete_no_connection,
        DeletionOutcome.tooManyAttempts => loc.delete_too_many_attempts,
        DeletionOutcome.notSignedIn => loc.delete_failed,
        DeletionOutcome.failed => loc.delete_failed,
        DeletionOutcome.success => null,
      };
    });
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: const BoxDecoration(
              color: INCORRECT,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: ACCENT,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: BACKGROUND,
      appBar: AppBar(
        title: Text(loc.delete_my_data),
        backgroundColor: BACKGROUND,
        elevation: 0,
        foregroundColor: ACCENT,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: INCORRECT.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.delete_data_heading,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: INCORRECT,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _bullet(loc.delete_removes_periods),
                    _bullet(loc.delete_removes_settings),
                    _bullet(loc.delete_removes_profile),
                    _bullet(loc.delete_removes_account),
                    const SizedBox(height: 4),
                    Text(
                      loc.delete_cannot_be_undone,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: ACCENT.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                loc.delete_confirm_with_password,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: ACCENT,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscured,
                enabled: !_busy,
                // Rebuilds on every keystroke, not only to clear the error:
                // the button below is enabled from this field's contents and
                // would otherwise stay greyed out no matter what was typed.
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: loc.password,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ACCENT.withValues(alpha: 0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ACCENT.withValues(alpha: 0.12)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: ACCENT.withValues(alpha: 0.5),
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.delete_needs_connection,
                style: TextStyle(
                  fontSize: 12,
                  color: ACCENT.withValues(alpha: 0.55),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: INCORRECT.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: INCORRECT,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                // Disabled until something is typed, so the destructive button
                // cannot be reached by tapping through the screen.
                onPressed: _busy || _passwordController.text.isEmpty
                    ? null
                    : _confirmThenDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: INCORRECT,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: INCORRECT.withValues(alpha: 0.3),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            loc.delete_in_progress,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        loc.delete_button,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: ACCENT,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(loc.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
