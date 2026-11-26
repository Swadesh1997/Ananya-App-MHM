import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';

/// Renders a knowledge-hub description as structured, scannable content
/// instead of one unbroken wall of text.
///
/// The source strings already carry structure that plain [Text] threw away:
/// bullet markers, and above all lines of the form "Label: explanation" —
/// 67 of them in the English copy and 72 in the Bangla. Those become rows the
/// reader can open, so a 1,000-character block arrives as four or five
/// headings she can scan, rather than a page she has to wade through.
///
/// Nothing here invents or rewrites content: every heading is text that was
/// already in the string.

/// What a parsed line turned out to be. Public because DescriptionNode
/// exposes it.
enum NodeKind { paragraph, bullet, subheading, expandable }

class DescriptionNode {
  final NodeKind kind;

  /// Paragraph/bullet text, or the title of an expandable row.
  final String text;

  /// Body of an expandable row; empty otherwise.
  final String body;

  const DescriptionNode(this.kind, this.text, {this.body = ''});

  bool get isExpandable => kind == NodeKind.expandable;
  bool get isBullet => kind == NodeKind.bullet;
  bool get isSubheading => kind == NodeKind.subheading;
  bool get isParagraph => kind == NodeKind.paragraph;
}

class DescriptionParser {
  /// Leading bullet or list marker: •, -, *, "1.", "1)", "a)".
  static final _marker =
      RegExp(r'^\s*(?:[•●·•\-\*]|\d+[.)]|[A-Za-z]\))\s*');

  /// "Label: explanation". The label is capped at 60 characters and may not
  /// contain sentence-ending punctuation, so a colon in the middle of a real
  /// sentence is not mistaken for a heading. The body must be substantial —
  /// hiding one short clause behind a tap would be worse than showing it.
  static final _labelled = RegExp(r'^([^.।?!]{3,60}?):\s+(.{20,})$');

  static final _endsSentence = RegExp(r'[.।?!]$');

  static bool _looksLikeHeading(String line) =>
      line.length <= 70 && !_endsSentence.hasMatch(line);

  static List<DescriptionNode> parse(String raw) {
    final nodes = <DescriptionNode>[];

    for (final original in raw.split('\n')) {
      // Tabs are used as spacing after bullet markers in the source strings.
      var line = original.replaceAll('\t', ' ').trim();
      if (line.isEmpty) continue;

      var isBullet = false;
      final m = _marker.firstMatch(line);
      if (m != null && m.end < line.length) {
        isBullet = true;
        line = line.substring(m.end).trim();
      }
      if (line.isEmpty) continue;

      final labelled = _labelled.firstMatch(line);
      if (labelled != null) {
        nodes.add(DescriptionNode(
          NodeKind.expandable,
          labelled.group(1)!.trim(),
          body: labelled.group(2)!.trim(),
        ));
        continue;
      }

      if (!isBullet && _looksLikeHeading(line)) {
        nodes.add(DescriptionNode(
          NodeKind.subheading,
          line.endsWith(':') ? line.substring(0, line.length - 1) : line,
        ));
        continue;
      }

      nodes.add(DescriptionNode(isBullet ? NodeKind.bullet : NodeKind.paragraph, line));
    }

    return nodes;
  }
}

class RichDescription extends StatelessWidget {
  final String text;

  const RichDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final nodes = DescriptionParser.parse(text);

    // A single collapsed row is pointless UI — it just hides one paragraph
    // behind a tap. Only fold when there are at least two to scan between.
    final foldable =
        nodes.where((n) => n.kind == NodeKind.expandable).length >= 2;

    final children = <Widget>[];
    var run = <DescriptionNode>[];

    void flushRun() {
      if (run.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 14),
        child: _ExpandableGroup(items: List.of(run)),
      ));
      run = [];
    }

    for (final node in nodes) {
      if (foldable && node.kind == NodeKind.expandable) {
        run.add(node);
        continue;
      }
      flushRun();

      switch (node.kind) {
        case NodeKind.subheading:
          children.add(Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 16, bottom: 6),
            child: Text(
              node.text,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: ACCENT,
              ),
            ),
          ));
          break;

        case NodeKind.bullet:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 9, left: 2),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: PRIMARY_COLOR,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(node.text, style: _bodyStyle)),
              ],
            ),
          ));
          break;

        // An expandable that was not folded (fewer than two in the block)
        // still keeps its label as a heading — the structure is real even
        // when hiding it would not help.
        case NodeKind.expandable:
          children.add(Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 14, bottom: 4),
            child: Text(
              node.text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: ACCENT,
              ),
            ),
          ));
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(node.body, style: _bodyStyle),
          ));
          break;

        case NodeKind.paragraph:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(node.text, style: _bodyStyle),
          ));
          break;
      }
    }
    flushRun();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static const TextStyle _bodyStyle = TextStyle(
    fontSize: 15,
    height: 1.65,
    color: ACCENT,
  );
}

/// A numbered list of openable rows, drawn directly on the page.
///
/// This deliberately paints no surface of its own. A white card on the app's
/// cream page cut a hard rectangle out of the background; here the rows are
/// separated by hairlines and anchored by their numbers instead, so the list
/// reads as part of the article rather than a panel dropped on top of it.
class _ExpandableGroup extends StatelessWidget {
  final List<DescriptionNode> items;

  const _ExpandableGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    Widget rule() => Container(height: 1, color: ACCENT.withValues(alpha: 0.10));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rule(),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) rule(),
          _ExpandableRow(
            // Two digits so the numbers form a straight column, and in the
            // reader's own numerals.
            number: localeNumber(
                (i + 1).toString().padLeft(2, '0'), isBangla),
            title: items[i].text,
            body: items[i].body,
            // The first row opens on arrival: an entirely collapsed list gives
            // the reader nothing to start reading, and hides the fact that the
            // rows open at all.
            initiallyOpen: i == 0,
          ),
        ],
        rule(),
      ],
    );
  }
}

class _ExpandableRow extends StatefulWidget {
  final String number;
  final String title;
  final String body;
  final bool initiallyOpen;

  const _ExpandableRow({
    required this.number,
    required this.title,
    required this.body,
    required this.initiallyOpen,
  });

  @override
  State<_ExpandableRow> createState() => _ExpandableRowState();
}

class _ExpandableRowState extends State<_ExpandableRow> {
  late bool _open = widget.initiallyOpen;

  /// Width of the numeral column; the body lines up under the title.
  static const double _numberColumn = 34;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // No InkWell: an ink splash across a full-width row reads as a grey
      // flash every time someone opens one.
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _numberColumn,
                  child: Text(
                    widget.number,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      // The open row's number carries full colour; the rest sit
                      // back so the list reads as one quiet column.
                      color: PRIMARY_COLOR.withValues(alpha: _open ? 0.95 : 0.35),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: ACCENT,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 21,
                    color: ACCENT.withValues(alpha: 0.45),
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
                padding: const EdgeInsets.only(
                    left: _numberColumn, top: 10, right: 8),
                child: Container(
                  // A hairline down the left edge ties the explanation to the
                  // heading above it without needing a box.
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: PRIMARY_COLOR.withValues(alpha: 0.30),
                        width: 2,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(
                    widget.body,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.65,
                      color: ACCENT.withValues(alpha: 0.72),
                    ),
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
