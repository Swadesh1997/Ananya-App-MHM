import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';

/// One knowledge-hub topic card: illustration on top, title on a white panel.
///
/// Sized by its parent — 150px wide in the horizontal home rows, narrower in
/// the 3-column grids — so the image takes whatever height is left after the
/// fixed text panel.
class KnowledgeContainer extends StatelessWidget {
  final String id;
  final Map<String, String> data;
  const KnowledgeContainer({
    required this.id,
    required this.data,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/knowledge-nexus-info',
          arguments: [id, data],
        );
      },
      child: Container(
        // Clips the image to the rounded corners.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          // Matches every other card surface in the app; these were the only
          // square-cornered tiles left.
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ACCENT.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Image.asset(
                  data['hero_image']!,
                  // contain, not cover or fill. The artwork ranges from 0.93 to
                  // 3.81 in aspect ratio, so cover cut heads and hands off the
                  // wider pieces and fill stretched the figures. The image box
                  // is about 1.24 wide-to-tall, close to the median artwork
                  // ratio, so most pieces very nearly fill it anyway.
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed two-line box so every card's title area is the same
                  // height and one-line titles don't shrink their card.
                  SizedBox(
                    height: 32,
                    child: Text(
                      data['question']!,
                      style: const TextStyle(
                        color: ACCENT,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        isBangla ? 'পড়ুন' : 'Read',
                        style: const TextStyle(
                          color: PRIMARY_COLOR,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward,
                        size: 11,
                        color: PRIMARY_COLOR,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
