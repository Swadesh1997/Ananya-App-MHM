import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/main.dart';
import 'package:ananya/services/period_reminder_service.dart';
import 'package:ananya/utils/constants.dart';

/// A two-state language switch that shows both options at once.
///
/// It replaces a PopupMenuButton with no child, which Flutter renders as a
/// bare ⋮. That had three problems, and the first is the serious one:
///
///  1. It never showed which language was selected. The only way to find out
///     was to open the menu — on a screen whose whole purpose is telling you.
///  2. Switching took two taps.
///  3. A ⋮ means "more options" everywhere else in Android; nothing about it
///     said "language".
///
/// Both labels are drawn in their own script — বাংলা, English — so someone who
/// cannot read the current language can still find her way out. That matters
/// here more than usual: a girl who has landed in English by accident cannot
/// read a settings row that says "Language" to fix it, but she can recognise
/// বাংলা.
class LanguageToggle extends StatelessWidget {
  /// 'bn' or 'en'.
  final String value;
  final ValueChanged<String> onChanged;

  /// A smaller build of the same control, for the app bar.
  ///
  /// The drawer keeps the full size on purpose. It is the one place someone who
  /// has landed in a language she cannot read will go looking, so it stays a
  /// comfortable target there and only shrinks where it sits beside other
  /// chrome.
  final bool compact;

  const LanguageToggle({
    required this.value,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  double get _height => compact ? 28.0 : 34.0;
  double get _width => compact ? 126.0 : 158.0;
  double get _radius => _height / 2;
  double get _fontSize => compact ? 11.0 : 13.0;

  @override
  Widget build(BuildContext context) {
    final isBangla = value == 'bn';

    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        children: [
          // The track.
          Container(
            decoration: BoxDecoration(
              color: ACCENT.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: ACCENT.withValues(alpha: 0.10)),
            ),
          ),

          // The thumb, sliding between halves. Animated rather than jumping so
          // the change reads as one control moving, not two buttons blinking.
          AnimatedAlign(
            alignment: isBangla ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                margin: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: PRIMARY_COLOR,
                  borderRadius: BorderRadius.circular(_radius - 2.5),
                ),
              ),
            ),
          ),

          Row(
            children: [
              _half('বাংলা', selected: isBangla, code: 'bn'),
              _half('English', selected: !isBangla, code: 'en'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _half(String label, {required bool selected, required String code}) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          // Opaque so the whole half is tappable, not just the glyphs.
          behavior: HitTestBehavior.opaque,
          // Re-selecting the current language would rebuild every pending
          // reminder for nothing.
          onTap: selected ? null : () => onChanged(code),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : ACCENT.withValues(alpha: 0.65),
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

/// Applies a language choice everywhere it has to land.
///
/// Three things must happen together, and they were written out separately at
/// each call site: the choice is stored, pending reminders are rebuilt, and
/// the app is told to rebuild.
///
/// The reminder step is the one that is easy to forget. A scheduled reminder
/// holds its own text rather than a translation key, so a girl who switches to
/// Bangla would otherwise keep receiving English reminders for the rest of the
/// cycle — from an app that is now entirely in Bangla.
Future<void> applyLanguage(BuildContext context, String languageCode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language_code', languageCode);
  await PeriodReminderService.rescheduleForCurrentLanguage();
  if (!context.mounted) return;
  MyApp.setLocale(context, Locale(languageCode));
}
