import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/knowledge_nexus_data.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/knowledge_container.dart';
import 'package:flutter/material.dart';

/// The "Knowledge hub" strip shown on the landing and home screens.
///
/// Lives in one place because both screens showed the identical row and had
/// drifted apart. It owns its own scroll controller, so the arrows work
/// without either screen having to hold state for it.
class KnowledgeHubRow extends StatefulWidget {
  final VoidCallback onViewAll;
  final int itemCount;

  const KnowledgeHubRow({
    required this.onViewAll,
    this.itemCount = 5,
    super.key,
  });

  @override
  State<KnowledgeHubRow> createState() => _KnowledgeHubRowState();
}

class _KnowledgeHubRowState extends State<KnowledgeHubRow> {
  final ScrollController _controller = ScrollController();

  /// Card width plus the gap, so one tap moves exactly one card.
  static const double _step = 162;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nudge(double direction) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + direction * _step)
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Small circular nav button. Sits in the header rather than on top of the
  /// cards, which is where the previous pair used to overlap the artwork.
  Widget _arrow(IconData icon, VoidCallback onTap) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ACCENT.withValues(alpha: 0.12)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: ACCENT.withValues(alpha: 0.75)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final items = KnowledgeItemProvider.getKnowledgeItems(context)
        .take(widget.itemCount)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loc?.knowledge_hub ?? 'Knowledge Hub',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ACCENT,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _arrow(Icons.chevron_left, () => _nudge(-1)),
              const SizedBox(width: 6),
              _arrow(Icons.chevron_right, () => _nudge(1)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc?.view_all ?? 'View All',
                      style: const TextStyle(
                        color: PRIMARY_COLOR,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: PRIMARY_COLOR),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
          child: ListView.separated(
            controller: _controller,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 150,
              child: KnowledgeContainer(
                id: items[index]['id']!,
                data: items[index],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
