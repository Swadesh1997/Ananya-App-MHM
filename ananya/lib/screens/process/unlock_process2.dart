import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/services/period_history_service.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/custom_app_bar_with_progress.dart';
import 'package:ananya/widgets/input_box.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ananya/l10n/app_localizations.dart';

class UnlockProcess2 extends StatefulWidget {
  const UnlockProcess2({super.key});

  @override
  State<UnlockProcess2> createState() => _UnlockProcess2State();
}

class _UnlockProcess2State extends State<UnlockProcess2> {
  final TextEditingController _daysBetweenPeriodController =
      TextEditingController();
  final TextEditingController _lengthOfPeriodController =
      TextEditingController();

  /// Validation messages, shown under the box they belong to. Null when the
  /// answer is usable or absent.
  String? _gapError;
  String? _bleedError;

  @override
  void initState() {
    super.initState();

    // Pre-fill with her current answers when there are any. The boxes used to
    // open blank on "Re-calibrate prediction", which hid what she was
    // changing and made "leave it alone" indistinguishable from "clear it".
    //
    // Only when something is stored: on first setup these would read as the
    // app's suggestion, and a suggested 28 is the number most people would
    // simply accept.
    final state = context.read<PeriodState>();
    if (state.hasStoredAnswers) {
      _daysBetweenPeriodController.text = '${state.daysBetweenPeriod}';
      _lengthOfPeriodController.text = '${state.lengthOfPeriod}';
    }
  }

  @override
  void dispose() {
    _daysBetweenPeriodController.dispose();
    _lengthOfPeriodController.dispose();
    super.dispose();
  }

  /// Validates and stores the two answers.
  ///
  /// Out-of-range values are refused rather than silently corrected. A typed
  /// 21-day cycle with a 25-day period used to be accepted, stored, and then
  /// passed to the calendar's ovulation calculation, which threw and stopped
  /// the home screen rendering. Clamping it instead would have replaced her
  /// answer with one she never gave, which is the behaviour this whole pass
  /// exists to remove.
  ///
  /// Both boxes may still be left empty — "I do not know" is a valid answer
  /// and the app has defaults for it. Only a value that IS given and cannot
  /// be used is rejected.
  void _onContinuePressed(BuildContext context) {
    final periodState = context.read<PeriodState>();
    final t = AppLocalizations.of(context)!;

    final gapText = _daysBetweenPeriodController.text.trim();
    final bleedText = _lengthOfPeriodController.text.trim();
    final int? daysBetweenPeriod = int.tryParse(gapText);
    final int? lengthOfPeriod = int.tryParse(bleedText);

    String? gapError;
    String? bleedError;

    if (gapText.isNotEmpty &&
        !PeriodHistoryService.isSupportedCycle(daysBetweenPeriod)) {
      gapError = t.cycle_out_of_range(
        '${PeriodHistoryService.minSupportedCycle}',
        '${PeriodHistoryService.maxSupportedCycle}',
      );
    }

    // Judged on its own, not against the cycle length.
    //
    // This used to refuse any bleed that left no room for an ovulation day —
    // 27 days in a 28-day cycle — which blocked her from recording something
    // she was telling the app about her own body because of an estimate the
    // app wanted to make about something else. A long period is now stored,
    // averaged, shaded and predicted from exactly as reported; only the
    // ovulation band goes missing, which is the honest consequence.
    if (bleedText.isNotEmpty &&
        !PeriodHistoryService.isRecordableBleed(lengthOfPeriod)) {
      bleedError = t.bleed_out_of_range('${PeriodHistoryService.maxSupportedCycle}');
    }

    if (gapError != null || bleedError != null) {
      setState(() {
        _gapError = gapError;
        _bleedError = bleedError;
      });
      return;
    }

    setState(() {
      _gapError = null;
      _bleedError = null;
    });

    if (daysBetweenPeriod != null) {
      periodState.updateDaysBetweenPeriod(daysBetweenPeriod);
    }
    if (lengthOfPeriod != null) {
      periodState.updateLengthOfPeriod(lengthOfPeriod);
    }

    Navigator.pushNamed(context, '/unlock-process/3',
                      arguments: false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarWithProgress(
        progressValue: 0.4,
        skipRoute: '/unlock-process/3',
        skipArguments: false,
        stepText: '2/5',
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
                      text: AppLocalizations.of(context)!.what_is_the,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        color: ACCENT,
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(context)!.number_of_days,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        color: PRIMARY_COLOR,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(context)!
                          .between_your_periods_and,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        color: ACCENT,
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(context)!.how_long,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        color: PRIMARY_COLOR,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(context)!.does_it_last,
                      style: const TextStyle(
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
                    .generally_periods_occur_every_21_to_35_days_and_last_2_to_7_days,
              ),
              const SizedBox(
                height: 10,
              ),
              InputBox(
                text: AppLocalizations.of(context)!
                    .number_of_days_between_period_eg_27_days,
                controller: _daysBetweenPeriodController,
                errorText: _gapError,
              ),
              InputBox(
                text: AppLocalizations.of(context)!
                    .length_of_your_period_eg_6_days,
                controller: _lengthOfPeriodController,
                errorText: _bleedError,
              ),
              const SizedBox(
                height: 50,
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/unlock-process/3',
                      arguments: false);
                },
                style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.white),
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
                  AppLocalizations.of(context)!.i_dont_know,
                  style: const TextStyle(
                    color: ACCENT,
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              ElevatedButton(
                onPressed: () => _onContinuePressed(context),
                style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(ACCENT),
                  minimumSize:
                      WidgetStatePropertyAll(Size(double.infinity, 20)),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      width: 1,
                    ),
                  ),
                ),
                child: Text(AppLocalizations.of(context)!.continues),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
