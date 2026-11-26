import 'package:ananya/models/help_data.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/help_card.dart';
import 'package:flutter/material.dart';

class Help extends StatelessWidget {
  const Help({super.key});

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    final data = HelpProvider.helpData(context);

    // Preserve the declared order of categories rather than sorting, so the
    // most urgent groups stay near the top.
    final order = <String>[];
    final grouped = <String, List<Map<String, String>>>{};
    for (final item in data) {
      final key = item['category'] ?? HelpProvider.medical;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        order.add(key);
      }
      grouped[key]!.add(item);
    }

    return Scaffold(
      backgroundColor: BACKGROUND,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- header ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ACCENT.withValues(alpha: 0.10)),
                      ),
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.arrow_back, color: ACCENT, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBangla ? 'জরুরি নম্বর' : 'Help numbers',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: ACCENT,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isBangla
                              ? 'কল করতে ট্যাপ করুন · যেকোনো অপারেটর থেকে ফ্রি'
                              : 'Tap to call · free from any operator',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: ACCENT.withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ACCENT.withValues(alpha: 0.08)),

            // ---- grouped list ----
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  for (final key in order) ...[
                    HelpSectionHeader(
                      label: HelpProvider.categoryLabel(key, isBangla),
                      urgent: key == HelpProvider.violence,
                    ),
                    HelpGroupCard(items: grouped[key]!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
