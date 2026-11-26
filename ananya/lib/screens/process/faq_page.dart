import 'package:flutter/material.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/screens/landing/landing.dart';
import 'package:ananya/screens/process/knowledge_hub_page.dart';

class FaqPage extends StatelessWidget {
  final Function(int)? onselect;

  const FaqPage({super.key, this.onselect});

  @override
  Widget build(BuildContext context) {
    final faqs = _getFaqItems(context);

    return Scaffold(
      backgroundColor: BACKGROUND,
      body: CustomScrollView(
        slivers: [
          // =================== COLLAPSING BANNER ===================
          // Was a fixed 500px image cropped with BoxFit.cover, which pushed the
          // questions off screen. It now shrinks as the user scrolls and then
          // scrolls away entirely, while the title stays pinned.
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: BACKGROUND,
            surfaceTintColor: BACKGROUND,
            elevation: 0,
            iconTheme: const IconThemeData(color: ACCENT),
            title: Text(
              AppLocalizations.of(context)!.faqs,
              style: const TextStyle(
                color: ACCENT,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Padding(
                padding: EdgeInsets.only(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top,
                  bottom: 8,
                ),
                child: Image.asset(
                  'assets/images/faq2.png',
                  // contain, not cover: the illustration is 374x453, so
                  // stretching it to 500 tall cropped her head and the question
                  // mark.
                  fit: BoxFit.contain,
                  cacheWidth: 700,
                ),
              ),
            ),
          ),

          // =================== FAQ LIST ===================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => FaqExpansionTile(
                  question: faqs[index]['question']!,
                  answer: faqs[index]['answer']!,
                ),
                childCount: faqs.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // FAQ tab
        onTap: (index) {
          if (onselect != null) {
            onselect!(index);
          } else {
            // fallback navigation like in landing page
            if (index == 0) {
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                  (route) => false);
            } else if (index == 1) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const KnowledgeHubPage()));
            }
          }
        },
        selectedItemColor: SECONDARY_COLOR,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.language), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: ""),
        ],
      ),
    );
  }

  // =================== FAQ DATA ===================
  List<Map<String, String>> _getFaqItems(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return [
      {"question": loc.faq_q4, "answer": loc.faq_a4},
      {"question": loc.faq_q5, "answer": loc.faq_a5},
      {"question": loc.faq_q6, "answer": loc.faq_a6},
      {"question": loc.faq_q7, "answer": loc.faq_a7},
      {"question": loc.faq_q8, "answer": loc.faq_a8},
      {"question": loc.faq_q9, "answer": loc.faq_a9},
      {"question": loc.faq_q10, "answer": loc.faq_a10},
      {"question": loc.faq_q11, "answer": loc.faq_a11},
      {"question": loc.faq_q12, "answer": loc.faq_a12},
    ];
  }
}

// =================== EXPANDABLE FAQ TILE ===================
/// A single question. Collapsed it is a plain white card; expanded it picks up
/// a brand-red border and tinted icon so the open one is obvious in a long
/// list.
class FaqExpansionTile extends StatefulWidget {
  final String question;
  final String answer;

  const FaqExpansionTile({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  State<FaqExpansionTile> createState() => _FaqExpansionTileState();
}

class _FaqExpansionTileState extends State<FaqExpansionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _open ? PRIMARY_COLOR.withValues(alpha: 0.45) : ACCENT.withValues(alpha: 0.09),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ACCENT.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Theme(
          // Removes ExpansionTile's default top/bottom hairlines, which fought
          // with the card border.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            onExpansionChanged: (v) => setState(() => _open = v),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            trailing: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _open ? PRIMARY_COLOR : ACCENT.withValues(alpha: 0.45),
                size: 24,
              ),
            ),
            title: Text(
              widget.question,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _open ? PRIMARY_COLOR : ACCENT,
              ),
            ),
            children: [
              Divider(color: ACCENT.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 12),
              Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: ACCENT.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
