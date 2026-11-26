import 'package:flutter/material.dart';

import 'package:ananya/utils/constants.dart';

/// Shared shape for every form field in the app.
///
/// The old fields were white rectangles with a 5px radius, no border, and the
/// only label sitting inside as hint text — so the moment she typed, the field
/// stopped saying what it was for. On the cream page they read as gaps rather
/// than as inputs. These tokens give every field one silhouette, a persistent
/// label above it, and a focus state that uses the brand red.
const double kFieldRadius = 14;
const double kFieldHeight = 56;

/// Resting outline. Low contrast on purpose — enough to define the shape
/// against the cream page without drawing attention to itself.
final Color kFieldBorder = ACCENT.withValues(alpha: 0.10);
const Color kFieldFocus = PRIMARY_COLOR;
final Color kFieldIcon = ACCENT.withValues(alpha: 0.42);
final Color kFieldHint = ACCENT.withValues(alpha: 0.34);
final Color kFieldLabel = ACCENT.withValues(alpha: 0.72);
final Color kFieldHelper = ACCENT.withValues(alpha: 0.50);

OutlineInputBorder appFieldBorder(Color color, [double width = 1.4]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(kFieldRadius),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// The label that sits above a field.
///
/// A trailing "*" is split out and coloured red, so "required" is carried by
/// the mark itself rather than by the whole label shouting.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final required = text.trimRight().endsWith('*');
    final label = required
        ? text.trimRight().substring(0, text.trimRight().length - 1).trimRight()
        : text;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Text.rich(
        TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: kFieldLabel,
            letterSpacing: 0.15,
          ),
          children: required
              ? [
                  TextSpan(
                    text: '  *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: PRIMARY_COLOR.withValues(alpha: 0.85),
                    ),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Small line under a field: a hint while things are fine, an error when not.
class FieldFootnote extends StatelessWidget {
  final String text;
  final bool isError;
  const FieldFootnote(this.text, {this.isError = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError) ...[
            const Icon(Icons.error_outline_rounded, size: 13, color: INCORRECT),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: isError ? INCORRECT : kFieldHelper,
                fontWeight: isError ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blank space under the last row of a form.
///
/// The sign-in link at the foot of the sign-up form was hidden underneath the
/// Android navigation bar. Adding only the system inset fixed that but left the
/// link sitting against the bar, which still reads as though it is falling off
/// the screen. This is the gap on top of the inset, not instead of it, and it
/// costs nothing on a form that already scrolls.
const double kFormBottomGap = 48;
