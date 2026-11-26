import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';

/// Text input styled to match the onboarding cards: white surface, hairline
/// border, and a brand-red border while focused so the active field is obvious.
class InputBox extends StatelessWidget {
  final String text;
  final TextEditingController controller;

  /// Shown under the box when the value given cannot be used. Null hides it.
  final String? errorText;

  const InputBox({
    required this.text,
    required this.controller,
    this.errorText,
    super.key,
  });

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: color, width: 1.5),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          color: ACCENT,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: text,
          hintStyle: TextStyle(
            color: ACCENT.withValues(alpha: 0.42),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          errorText: errorText,
          enabledBorder: _border(ACCENT.withValues(alpha: 0.09)),
          focusedBorder: _border(PRIMARY_COLOR),
          border: _border(ACCENT.withValues(alpha: 0.09)),
        ),
      ),
    );
  }
}
