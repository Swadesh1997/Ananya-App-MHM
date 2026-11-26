import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/services/local_period_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/custom_app_bar_with_progress.dart';
import 'package:ananya/widgets/dynamic_calender.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ananya/l10n/app_localizations.dart';

class UnlockProcess3 extends StatefulWidget {
  final bool updatePeriod;
  const UnlockProcess3({required this.updatePeriod, super.key});

  @override
  State<UnlockProcess3> createState() => _UnlockProcess3State();
}

/// Stateful only so the flow can start from the user's real settings.
///
/// PeriodState is built once at app start and holds defaults until someone
/// fills it in. The full setup flow does that, step by step. The short "log
/// new period" flow — this screen, then the health screen — does not: it asks
/// for a date and health conditions and nothing else, so cycle length, period
/// length, regularity and birth control arrived at the save as defaults rather
/// than as her answers. Loading the stored settings here, before either screen
/// is shown, is what makes the short flow an edit of what she has rather than
/// a partial overwrite of it.
class _UnlockProcess3State extends State<UnlockProcess3> {
  @override
  void initState() {
    super.initState();
    if (widget.updatePeriod) _restoreSettings();
  }

  Future<void> _restoreSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // The device copy, not Firestore: this runs on the screen the user is
    // already looking at, and a server read with no connection would either
    // stall or come back empty — and empty here means "keep the defaults",
    // which is the bug this exists to fix.
    final saved = await LocalPeriodStore.readSettings(user.uid);
    if (!mounted) return;
    context.read<PeriodState>().hydrateFrom(saved);
  }

  void _goNext(BuildContext context) {
    if (widget.updatePeriod) {
      // The short flow asks for the length of *this* period next. It is a
      // property of the episode, not of her: months differ, and recording the
      // same number every time is what kept the measured average from ever
      // moving.
      Navigator.pushNamed(context, '/period-length');
    } else {
      Navigator.pushNamed(context, '/unlock-process/4');
    }
  }

  /// The picked date written out, e.g. "19 August, 2026 selected".
  String _selectedLabel(BuildContext context, bool isBangla) {
    final raw = context.read<PeriodState>().lastPeriodStart;
    try {
      final d = DateFormat('yyyy-MM-dd')
          .parse(raw.trim().split(' ').first.split('T').first);
      // intl's bn locale writes Bangla month names but keeps Latin digits, so
      // "19 আগস্ট, 2026" came out half-translated. Compose it ourselves.
      final pretty = '${localeNumber(d.day, isBangla)} '
          '${monthFull(d, isBangla)}, ${localeNumber(d.year, isBangla)}';
      return isBangla ? '$pretty নির্বাচিত' : '$pretty selected';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    // "I do not know" and "Continue" are mutually exclusive: exactly one is
    // available depending on whether a date has been picked.
    final hasPickedDate =
        context.watch<PeriodState>().hasSelectedLastPeriodStart;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    return Scaffold(
        appBar: CustomAppBarWithProgress(
          // Short "log new period" flow is 3 steps (date -> length -> health),
          // so this is 1 of 3. The full setup flow is 5 steps.
          progressValue: widget.updatePeriod ? 1 / 3 : 0.6,
          skipRoute: widget.updatePeriod ? null : '/unlock-process/4',
          stepText: widget.updatePeriod ? '1/3' : '3/5',
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: Theme.of(context).largemainPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: AppLocalizations.of(context)!.when_did_your,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.3,
                          color: ACCENT,
                        ),
                      ),
                      TextSpan(
                        text: AppLocalizations.of(context)!.last_period,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.3,
                          color: PRIMARY_COLOR,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: AppLocalizations.of(context)!.start,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.3,
                          color: ACCENT,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Explains why the question is being asked, as the other
                // onboarding steps do not.
                Text(
                  isBangla
                      ? 'এটি আপনার পরবর্তী মাসিকের সময় নির্ণয়ে সাহায্য করবে'
                      : 'This helps us predict your next period',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: ACCENT.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: 18),
                // Anchored in a card, matching every other surface in the app.
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ACCENT.withValues(alpha: 0.07),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const DynamicCalendar(),
                ),
                const SizedBox(height: 12),
                // Confirms the chosen date in words — a small red circle on the
                // grid is easy to miss, especially after changing month.
                if (hasPickedDate)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: PRIMARY_COLOR.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: PRIMARY_COLOR,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _selectedLabel(context, isBangla),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ACCENT,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // Primary action first: it is the one we want people to take.
                ElevatedButton(
                  onPressed: hasPickedDate ? () => _goNext(context) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ACCENT,
                    disabledBackgroundColor: ACCENT.withValues(alpha: 0.25),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.continues,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Always visible: a button that disappears reads as a missing
                // feature. Disabled instead once a date is picked, since the
                // two options are mutually exclusive.
                ElevatedButton(
                  onPressed: hasPickedDate
                      ? null
                      : () {
                          context.read<PeriodState>().clearLastPeriodStart();
                          _goNext(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: ACCENT.withValues(alpha: 0.60),
                    disabledForegroundColor: ACCENT.withValues(alpha: 0.25),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: ACCENT.withValues(alpha: hasPickedDate ? 0.07 : 0.13),
                      ),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.i_dont_know,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
