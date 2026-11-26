import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ananya/utils/constants.dart';

/// Uppercase category label followed by a hairline rule.
///
/// [urgent] renders it in the brand red — used for the violence and safety
/// group so it stands out while scrolling.
class HelpSectionHeader extends StatelessWidget {
  final String label;
  final bool urgent;

  const HelpSectionHeader({
    required this.label,
    this.urgent = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = urgent ? PRIMARY_COLOR : ACCENT.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.25)),
          ),
        ],
      ),
    );
  }
}

/// A group of helplines sharing one white card, separated by hairlines rather
/// than sitting in separate cards — it reads as one list instead of eight
/// competing blocks.
class HelpGroupCard extends StatelessWidget {
  final List<Map<String, String>> items;

  const HelpGroupCard({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ACCENT.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                // Inset to line up with the text rather than the avatar — the
                // detail that makes a grouped list feel considered, not boxy.
                indent: 78,
                endIndent: 18,
                color: ACCENT.withValues(alpha: 0.07),
              ),
            HelpRow(
              number: items[i]['number']!,
              name: items[i]['name']!,
              description: items[i]['description']!,
              badge: items[i]['badge'],
              isFirst: i == 0,
              isLast: i == items.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

/// One helpline: a round call button, the number and who answers it, and the
/// full description on tap.
class HelpRow extends StatefulWidget {
  final String number;
  final String name;
  final String description;

  /// Optional pill beside the number, e.g. "24/7".
  final String? badge;

  final bool isFirst;
  final bool isLast;

  const HelpRow({
    required this.number,
    required this.name,
    required this.description,
    this.badge,
    this.isFirst = false,
    this.isLast = false,
    super.key,
  });

  @override
  State<HelpRow> createState() => _HelpRowState();
}

class _HelpRowState extends State<HelpRow> {
  bool _open = false;

  /// Groups an 11-digit Bangladeshi mobile number as "01779 554391" so it can
  /// be read and repeated aloud. Short codes are left as they are.
  String get _displayNumber {
    final digits = widget.number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return widget.number;
  }

  Future<void> _call() async {
    // Entries like "01779554391/01779554392" hold two numbers; dial the first.
    final cleaned = widget.number.split(RegExp(r'[^0-9+]')).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => widget.number,
        );
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch $cleaned');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // No InkWell: an ink splash across a full-width row reads as a grey flash
      // every time someone expands one.
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          widget.isFirst ? 18 : 15,
          16,
          widget.isLast && !_open ? 18 : 15,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Round call button, leading: the primary action sits where the
                // eye lands first, and a circle reads as an action while a
                // square reads as a container.
                Semantics(
                  button: true,
                  label: 'Call ${widget.number}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _call,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: ACCENT,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _displayNumber,
                              style: const TextStyle(
                                color: ACCENT,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                height: 1.15,
                              ),
                            ),
                          ),
                          if (widget.badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: SECONDARY_COLOR.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.badge!,
                                style: const TextStyle(
                                  color: SECONDARY_COLOR,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.name,
                        style: TextStyle(
                          color: ACCENT.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chevron in a soft circle: without it nothing signalled that
                // the row opens at all.
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: ACCENT.withValues(alpha: _open ? 0.10 : 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ACCENT.withValues(alpha: 0.55),
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
                  _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                // Aligned with the text column, clear of the avatar.
                padding: const EdgeInsets.only(left: 60, top: 12, right: 4),
                child: Text(
                  widget.description,
                  style: TextStyle(
                    color: ACCENT.withValues(alpha: 0.68),
                    fontSize: 12.5,
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
