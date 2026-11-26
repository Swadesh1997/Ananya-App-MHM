import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/services/local_period_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/choice_item.dart';
import 'package:ananya/widgets/custom_app_bar_with_progress.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ananya/l10n/app_localizations.dart';

class UnlockProcess1 extends StatefulWidget {
  const UnlockProcess1({super.key});

  @override
  State<UnlockProcess1> createState() => _UnlockProcess1State();
}

class _UnlockProcess1State extends State<UnlockProcess1> {
  @override
  void initState() {
    super.initState();
    _restoreSettings();
  }

  /// Start "Re-calibrate prediction" from her current answers.
  ///
  /// This screen is the head of the full five-step questionnaire, which is
  /// reached two ways: first setup, and the re-calibrate button on the
  /// tracker. Unlike the short logging flow, this one writes *every* field at
  /// the end — so each step she skips wrote a default over a real answer.
  /// Skipping step 2 reset her cycle to 28 days and her period to 5; skipping
  /// step 1 declared her regular; skipping step 4 said she takes no birth
  /// control; and the health screen came up with "No health issues" ticked,
  /// so a girl with PCOS lost the wider prediction window unless she noticed
  /// and re-ticked it. Loading her answers first makes a skipped step mean
  /// "leave this as it is", which is what skipping it looks like.
  ///
  /// On first setup nothing is stored, so this does nothing and the defaults
  /// stand — which is the one case where they are the right answer.
  Future<void> _restoreSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final saved = await LocalPeriodStore.readSettings(user.uid);
    if (!mounted) return;
    context.read<PeriodState>().hydrateFrom(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarWithProgress(
        progressValue: 0.2,
        skipRoute: '/unlock-process/2',
        stepText: '1/5',
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
                      text: AppLocalizations.of(context)!.are_your_periods,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        color: ACCENT,
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(context)!.regular,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        color: PRIMARY_COLOR,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text: '?',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        color: ACCENT,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                AppLocalizations.of(context)!
                    .regular_means_that_the_gap_between_your_periods_is_around_the_same_number_of_days_each_month,
              ),
              const SizedBox(
                height: 10,
              ),
              ChoiceItem(
                text: AppLocalizations.of(context)!.yes,
                onSelected: (choice) {
                  context.read<PeriodState>().updatePeriodRegularity(true);
                  Navigator.pushNamed(context, '/unlock-process/2');
                },
              ),
              ChoiceItem(
                text: AppLocalizations.of(context)!.no,
                onSelected: (choice) {
                  context.read<PeriodState>().updatePeriodRegularity(false);
                  Navigator.pushNamed(context, '/unlock-process/2');
                },
              ),
              ChoiceItem(
                text: AppLocalizations.of(context)!.dont_know,
                onSelected: (choice) {
                  context.read<PeriodState>().updatePeriodRegularity(true);
                  Navigator.pushNamed(context, '/unlock-process/2');
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
