import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';

/// A tappable answer row used across the onboarding questions.
///
/// White surface with a hairline border and a trailing chevron, matching the
/// health-conditions and textbook cards elsewhere in the app.
class ChoiceItem extends StatelessWidget {
  final String text;
  final ValueChanged<String>? onSelected;

  const ChoiceItem({
    required this.text,
    this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onSelected == null ? null : () => onSelected!(text),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: ACCENT.withValues(alpha: 0.09), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: ACCENT,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: ACCENT.withValues(alpha: 0.30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
