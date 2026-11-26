import 'package:ananya/models/knowledge_nexus_data.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/rich_description.dart';
import 'package:ananya/widgets/topic_extras.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/knowledge_container.dart';
import 'package:ananya/widgets/video_player.dart';
import 'package:flutter/material.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/screens/landing/landing.dart';
import 'package:ananya/screens/process/knowledge_hub_page.dart';

class KnowledgeNexusInfo extends StatefulWidget {
  final String id;
  final Map<String, String> data;

  const KnowledgeNexusInfo({
    required this.data,
    required this.id,
    super.key,
  });

  @override
  State<KnowledgeNexusInfo> createState() => _KnowledgeNexusInfoState();
}

class _KnowledgeNexusInfoState extends State<KnowledgeNexusInfo> {
  final int _selectedIndex = 1; // Highlight Knowledge tab

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
            (route) => false,
      );
    } else if (index == 1) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const KnowledgeHubPage()),
            (route) => false,
      );
    } else if (index == 2) {
      Navigator.pushNamed(context, '/faq');
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatedInfo =
    KnowledgeItemProvider.getAdditionalInfo(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.knowledge_nexus),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HERO IMAGE =================
            if (widget.data['hero_image'] != null)
              Image.asset(
                widget.data['hero_image']!,
                height: 370,
                width: double.infinity,
                fit: BoxFit.cover,
              ),

            const SizedBox(height: 20),

            Container(
              padding: Theme.of(context).largemainPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= QUESTION =================
                  if (widget.data['question'] != null)
                    Text(
                      widget.data['question']!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ACCENT,
                      ),
                    ),

                  const SizedBox(height: 10),

                  // ================= FIRST DESCRIPTION =================
                  if (widget.data['first_description'] != null)
                    RichDescription(widget.data['first_description']!),

                  // ================= ADDITIONAL IMAGE =================
                  if (widget.data['additional_image_1'] != null) ...[
                    const SizedBox(height: 30),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        widget.data['additional_image_1']!,
                        width: double.infinity,
                        // fitWidth, not fill: fill stretched the diagram to
                        // whatever height was left over and distorted it.
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                  ],

                  // ================= SECOND DESCRIPTION =================
                  if (widget.data['second_description'] != null) ...[
                    const SizedBox(height: 22),
                    RichDescription(widget.data['second_description']!),
                  ],

                  // ================= VIDEO =================
                  if (widget.data['video_id'] != null) ...[
                    const SizedBox(height: 20),
                    VideoPlayer(id: widget.data['video_id']!),
                  ],

                  // ================= THIRD DESCRIPTION =================
                  if (widget.data['third_description'] != null) ...[
                    const SizedBox(height: 22),
                    RichDescription(widget.data['third_description']!),
                  ],

                  const SizedBox(height: 26),

                  if (widget.data['question'] != null)
                    AskProbahiniButton(question: widget.data['question']!),

                  const SizedBox(height: 26),

                  Divider(
                    color: ACCENT.withValues(alpha: 0.15),
                    thickness: 1,
                  ),

                  const SizedBox(height: 12),

                  // ================= RECOMMENDED =================
                  Text(
                    AppLocalizations.of(context)!
                        .recomended_reading_for_you,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ACCENT,
                    ),
                  ),

                  const SizedBox(height: 10),

                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 15.0,
                      mainAxisSpacing: 15.0,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: relatedInfo.length >= 3
                        ? 3
                        : relatedInfo.length,
                    itemBuilder: (context, index) {
                      return KnowledgeContainer(
                        id: relatedInfo[index]['id']!,
                        data: relatedInfo[index],
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),

      // ================= BOTTOM NAVIGATION =================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: SECONDARY_COLOR,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: ""),
          BottomNavigationBarItem(
              icon: Icon(Icons.language), label: ""),
          BottomNavigationBarItem(
              icon: Icon(Icons.help_outline), label: ""),
        ],
      ),
    );
  }
}