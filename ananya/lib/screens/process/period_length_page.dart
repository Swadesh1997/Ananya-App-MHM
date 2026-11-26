import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/period_state_questionnaire.dart';
import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/custom_app_bar_with_progress.dart';

/// How long this particular period lasted.
///
/// The length used to be asked once, at signup, and then treated as a fact
/// about the user rather than about a period — so every log recorded the same
/// number and the measured average could never move. It is a property of the
/// episode: months differ, and the app is meant to learn that.
///
/// It is chips rather than the typed number box the signup questionnaire uses.
/// That box is answered once; this is answered every month, and typing a
/// number each time is both slower and a place to fumble a digit. The usual
/// length is already chosen when the screen opens, so the common case — this
/// month was like the others — is a single tap on Continue.
class PeriodLengthPage extends StatefulWidget {
  const PeriodLengthPage({super.key});

  @override
  State<PeriodLengthPage> createState() => _PeriodLengthPageState();
}

class _PeriodLengthPageState extends State<PeriodLengthPage> {
  /// The range offered. One day is a real, if short, period; the top end is
  /// generous on purpose, because a long one is exactly the thing worth
  /// recording accurately.
  static const int _min = 1;
  static const int _max = 10;

  /// What she has reported before, so the chip carrying it can say so. Read
  /// once, in initState, rather than from the live value — that changes as
  /// soon as she taps something else.
  late final int _usual;

  int? _picked;

  @override
  void initState() {
    super.initState();
    final stored = context.read<PeriodState>().lengthOfPeriod;
    _usual = stored.clamp(_min, _max);
    _picked = _usual;
  }

  void _continue() {
    final picked = _picked;
    if (picked != null) {
      context.read<PeriodState>().updateLengthOfPeriod(picked);
    }
    Navigator.pushNamed(context, '/unlock-process/5', arguments: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    return Scaffold(
      appBar: const CustomAppBarWithProgress(
        // Step 2 of the three-step "log new period" flow: date, length,
        // health conditions.
        progressValue: 2 / 3,
        stepText: '2/3',
        // No Skip. The answer is already filled in with her usual length, so
        // skipping and continuing would do the same thing — and one of the
        // two would look like it discarded something.
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: Theme.of(context).largemainPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.how_long_did_this_period_last,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.3,
                  color: ACCENT,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t.choose_the_days_you_bled,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: ACCENT.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var days = _min; days <= _max; days++)
                    _dayChip(days, isBangla),
                ],
              ),
              const SizedBox(height: 18),
              // Named so the pre-filled answer is visibly hers and not a
              // number the app invented. Without it the chosen chip looks
              // like a default she has to think about.
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 15, color: PRIMARY_COLOR.withValues(alpha: 0.75)),
                  const SizedBox(width: 6),
                  Text(
                    '${t.your_usual_length}: ${localeNumber(_usual, isBangla)} ${t.days}',
                    style: TextStyle(
                      fontSize: 13,
                      color: ACCENT.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _continue,
                style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(ACCENT),
                  minimumSize:
                      WidgetStatePropertyAll(Size(double.infinity, 20)),
                  side: WidgetStatePropertyAll(BorderSide(width: 1)),
                ),
                child: Text(t.continues),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayChip(int days, bool isBangla) {
    final selected = _picked == days;

    return GestureDetector(
      onTap: () => setState(() => _picked = days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        // Wide enough for two Bangla digits without the chips changing size
        // as the selection moves.
        width: 58,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? PRIMARY_COLOR : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? PRIMARY_COLOR : ACCENT.withValues(alpha: 0.13),
            width: 1.5,
          ),
        ),
        child: Text(
          localeNumber(days, isBangla),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : ACCENT,
          ),
        ),
      ),
    );
  }
}
