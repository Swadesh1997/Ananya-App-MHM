import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:ananya/l10n/app_localizations.dart';

class CustomAppBarWithProgress extends StatelessWidget
    implements PreferredSizeWidget {
  final double progressValue;

  /// Where "Skip" goes. Null hides the button entirely — used on the steps
  /// that actually save data, and on the short "log new period" flow.
  ///
  /// This was previously derived as '/unlock-process/${id + 1}', which broke
  /// the moment a step was added or removed and silently sent users to a route
  /// that no longer existed. Naming the destination keeps it honest.
  final String? skipRoute;

  /// Arguments passed with [skipRoute]. The date step requires a bool.
  final Object? skipArguments;

  /// Shown beside the progress bar, e.g. "3/5". Omit to hide.
  final String? stepText;

  const CustomAppBarWithProgress(
      {super.key,
      required this.progressValue,
      this.skipRoute,
      this.skipArguments,
      this.stepText});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: ACCENT.withValues(alpha: 0.10)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back, color: ACCENT, size: 19),
              ),
            ),
          ),
          title: Container(),
          actions: [
            if (skipRoute != null)
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    skipRoute!,
                    arguments: skipArguments,
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.skip,
                  style: const TextStyle(
                    color: ACCENT,
                  ),
                ),
              ),
          ],
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        // Fixed height so preferredSize below is exact — letting the row size
        // itself to the step-counter text caused a bottom overflow.
        SizedBox(
          height: _progressAreaHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 6,
                      backgroundColor: ACCENT.withValues(alpha: 0.10),
                      valueColor: const AlwaysStoppedAnimation<Color>(ACCENT),
                    ),
                  ),
                ),
                if (stepText != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    stepText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ACCENT.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const double _progressAreaHeight = 24;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _progressAreaHeight);
}
