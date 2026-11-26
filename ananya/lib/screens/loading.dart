import 'package:flutter/material.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/widgets/app_loader.dart';

/// The wait while her cycle prediction is worked out.
///
/// This drew the animation at 400px wide from a 150px file and set the
/// caption at 32pt, so on a phone it filled the screen — an ordinary few
/// seconds of arithmetic looked like something had gone wrong. It is the same
/// loader as everywhere else now, with the line underneath explaining what the
/// wait is for.
class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AppLoader(
      message: '${loc.calculating} ${loc.your_cycle_prediction}...',
    );
  }
}
