import 'package:flutter/material.dart';

import 'package:ananya/utils/constants.dart';

/// Renders the small slice of Markdown that Probahini actually replies with.
///
/// The model answers in Markdown — `**bold**`, dash bullets, numbered steps,
/// and pipe tables — which a plain Text widget shows raw: a girl reads
/// "**Apply a hot compress**" with the asterisks, and a table arrives as a
/// wall of pipes. This turns that into the formatting she is meant to see.
///
/// Deliberately not a Markdown package. The app is pinned to firebase_core 2.x
/// and firebase_auth 4.x, and a new dependency here risks dragging those
/// forward the way youtube_player_flutter did. The replies use perhaps a tenth
/// of Markdown, so a parser for that tenth is smaller than the risk.
///
/// Supported: bold, bullet lists, numbered lists, ATX headings, bold-only
/// lines as headings, pipe tables (including the `<br>` the model puts inside
/// cells), and paragraphs. Anything else is shown as written, which is the
/// right failure: unknown syntax reads as ordinary text rather than vanishing.

/// One parsed piece of a reply.
sealed class MdBlock {
  const MdBlock();
}

class MdParagraph extends MdBlock {
  final String text;
  const MdParagraph(this.text);
}

class MdHeading extends MdBlock {
  final String text;
  const MdHeading(this.text);
}

/// A run of list items. [ordered] picks the marker, and [start] keeps the
/// model's own numbering rather than assuming every list starts at 1.
class MdList extends MdBlock {
  final List<String> items;
  final bool ordered;
  final int start;
  const MdList(this.items, {required this.ordered, this.start = 1});
}

class MdTable extends MdBlock {
  final List<String> header;
  final List<List<String>> rows;
  const MdTable(this.header, this.rows);
}

final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
final _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
final _atxHeading = RegExp(r'^\s*#{1,6}\s+(.*)$');
/// The model writes section titles either way round — `**Title:**` and
/// `**Title**:` — so the colon is captured separately and put back, rather
/// than surviving in one spelling and vanishing in the other.
final _boldOnlyLine = RegExp(r'^\s*\*\*(.+?)\*\*(:?)\s*$');

/// A table's second line: |---|:---:|---| and similar.
final _tableDivider = RegExp(r'^\s*\|?[\s:|-]*-[\s:|-]*\|?\s*$');

/// Splits a reply into blocks.
///
/// Separate from the widget so the parsing can be tested without pumping a
/// widget tree — the fiddly parts here are all textual.
List<MdBlock> parseMarkdownBlocks(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];

  // Lines of the paragraph being accumulated; flushed whenever a different
  // kind of block starts, so a paragraph can span several wrapped lines.
  final para = <String>[];
  void flushParagraph() {
    if (para.isEmpty) return;
    final text = para.join(' ').trim();
    if (text.isNotEmpty) blocks.add(MdParagraph(text));
    para.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      flushParagraph();
      i++;
      continue;
    }

    // A table needs its divider on the next line; without one a lone piped
    // line is just text that happens to contain pipes.
    if (trimmed.startsWith('|') &&
        i + 1 < lines.length &&
        _tableDivider.hasMatch(lines[i + 1]) &&
        lines[i + 1].contains('-')) {
      flushParagraph();
      final header = _splitRow(trimmed);
      i += 2;
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add(_splitRow(lines[i].trim()));
        i++;
      }
      blocks.add(MdTable(header, rows));
      continue;
    }

    final heading = _atxHeading.firstMatch(line);
    if (heading != null) {
      flushParagraph();
      blocks.add(MdHeading(heading.group(1)!.trim()));
      i++;
      continue;
    }

    // "**What you can do right now:**" on a line of its own is how the model
    // writes a section title. Treated as one, or it renders as a stray bold
    // paragraph glued to the text beneath it.
    final boldLine = _boldOnlyLine.firstMatch(line);
    if (boldLine != null) {
      flushParagraph();
      blocks.add(MdHeading(boldLine.group(1)!.trim() + boldLine.group(2)!));
      i++;
      continue;
    }

    if (_bullet.hasMatch(line)) {
      flushParagraph();
      final items = <String>[];
      while (i < lines.length && _bullet.hasMatch(lines[i])) {
        items.add(_bullet.firstMatch(lines[i])!.group(1)!.trim());
        i++;
      }
      blocks.add(MdList(items, ordered: false));
      continue;
    }

    final firstNumber = _numbered.firstMatch(line);
    if (firstNumber != null) {
      flushParagraph();
      final items = <String>[];
      final start = int.tryParse(firstNumber.group(1)!) ?? 1;
      while (i < lines.length && _numbered.hasMatch(lines[i])) {
        items.add(_numbered.firstMatch(lines[i])!.group(2)!.trim());
        i++;
      }
      blocks.add(MdList(items, ordered: true, start: start));
      continue;
    }

    para.add(trimmed);
    i++;
  }

  flushParagraph();
  return blocks;
}

/// Cells of one table row.
///
/// The model writes `<br>` inside cells — it is describing a web page to
/// itself — so that becomes a real line break here.
List<String> _splitRow(String line) {
  var body = line.trim();
  if (body.startsWith('|')) body = body.substring(1);
  if (body.endsWith('|')) body = body.substring(0, body.length - 1);
  return body
      .split('|')
      .map((c) => c.trim().replaceAll(RegExp(r'<br\s*/?>'), '\n').trim())
      .toList();
}

/// Splits one line into runs of plain and bold text.
///
/// Returned as (text, isBold) pairs rather than TextSpans so it can be tested
/// without a widget tree.
List<(String, bool)> parseInlineSpans(String source) {
  final out = <(String, bool)>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);

  var index = 0;
  for (final m in pattern.allMatches(source)) {
    if (m.start > index) out.add((source.substring(index, m.start), false));
    out.add((m.group(1)!, true));
    index = m.end;
  }
  if (index < source.length) out.add((source.substring(index), false));

  if (out.isEmpty) out.add((source, false));
  return out;
}

/// Draws what [parseMarkdownBlocks] produced.
class MarkdownText extends StatelessWidget {
  final String data;

  /// Base style for body text. Headings and table headers derive from it, so
  /// the caller only sets colour and size once.
  final TextStyle? style;

  /// What sits behind this text. A wide table fades out at its edges to show
  /// it continues, and the fade has to end in the real background colour or it
  /// reads as a grey smear rather than as the table running off the edge.
  final Color? surfaceColor;

  const MarkdownText(this.data, {this.style, this.surfaceColor, super.key});

  @override
  Widget build(BuildContext context) {
    final base = (style ?? DefaultTextStyle.of(context).style)
        .copyWith(height: 1.42);
    final blocks = parseMarkdownBlocks(data);

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(SizedBox(height: _gapBefore(blocks[i])));
      children.add(_buildBlock(blocks[i], base));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// A heading needs more air above it than a following paragraph does.
  double _gapBefore(MdBlock block) => block is MdHeading ? 12 : 8;

  Widget _buildBlock(MdBlock block, TextStyle base) {
    switch (block) {
      case MdParagraph(:final text):
        return _inline(text, base);

      case MdHeading(:final text):
        return _inline(
          text,
          base.copyWith(fontWeight: FontWeight.w700, height: 1.3),
        );

      case MdList(:final items, :final ordered, :final start):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: ordered ? 24 : 16,
                      child: Text(
                        ordered ? '${start + i}.' : '•',
                        style: base,
                      ),
                    ),
                    Expanded(child: _inline(items[i], base)),
                  ],
                ),
              ),
          ],
        );

      case MdTable(:final header, :final rows):
        return _table(header, rows, base);
    }
  }

  Widget _inline(String text, TextStyle base) {
    return Text.rich(
      TextSpan(
        children: [
          for (final (run, bold) in parseInlineSpans(text))
            TextSpan(
              text: run,
              style: bold ? base.copyWith(fontWeight: FontWeight.w700) : base,
            ),
        ],
      ),
    );
  }

  /// Tables scroll sideways rather than squeezing.
  ///
  /// The three-column Bangla tables the model produces cannot fit a phone at a
  /// readable size, and a wrapped table is harder to read than one that moves.
  Widget _table(List<String> header, List<List<String>> rows, TextStyle base) {
    final columns = [
      header.length,
      ...rows.map((r) => r.length),
    ].reduce((a, b) => a > b ? a : b);

    List<Widget> cells(List<String> row, {required bool isHeader}) => [
          for (var c = 0; c < columns; c++)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              child: _inline(
                c < row.length ? row[c] : '',
                isHeader
                    ? base.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: (base.fontSize ?? 14) - 0.5,
                      )
                    : base,
              ),
            ),
        ];

    final ink = base.color ?? ACCENT;

    // Lines between rows, nothing around the outside — the rounded container
    // below draws that edge, and doubling them makes the table look boxed in.
    final table = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: ink.withValues(alpha: 0.10)),
        verticalInside: BorderSide(color: ink.withValues(alpha: 0.07)),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: PRIMARY_COLOR.withValues(alpha: 0.07),
          ),
          children: cells(header, isHeader: true),
        ),
        for (final row in rows)
          TableRow(children: cells(row, isHeader: false)),
      ],
    );

    return _ScrollableTable(
      table: table,
      ink: ink,
      surfaceColor: surfaceColor,
    );
  }
}

/// A table that shows it can be scrolled.
///
/// A plain horizontal scroll view gives no sign that anything is off-screen —
/// the table simply looks cut off, and the reader has no reason to try
/// dragging it. This fades the edge that has more content behind it, points an
/// arrow that way, and captions it once. All three disappear when the table
/// fits, and the caption goes as soon as she scrolls, so the hint never
/// outlives its usefulness.
class _ScrollableTable extends StatefulWidget {
  final Widget table;
  final Color ink;
  final Color? surfaceColor;

  const _ScrollableTable({
    required this.table,
    required this.ink,
    this.surfaceColor,
  });

  @override
  State<_ScrollableTable> createState() => _ScrollableTableState();
}

class _ScrollableTableState extends State<_ScrollableTable> {
  final ScrollController _controller = ScrollController();

  bool _overflows = false;
  bool _atStart = true;
  bool _atEnd = false;
  bool _hasScrolled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // Whether it overflows is only knowable after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    if (max > 0 != _overflows) setState(() => _overflows = max > 0);
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final atStart = p.pixels <= 1;
    final atEnd = p.pixels >= p.maxScrollExtent - 1;
    if (atStart != _atStart || atEnd != _atEnd || !_hasScrolled) {
      setState(() {
        _atStart = atStart;
        _atEnd = atEnd;
        _hasScrolled = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.surfaceColor ?? Theme.of(context).cardColor;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.ink.withValues(alpha: 0.13)),
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 220),
                    child: widget.table,
                  ),
                ),
                if (_overflows && !_atStart)
                  _edge(surface, Alignment.centerLeft),
                if (_overflows && !_atEnd) ...[
                  _edge(surface, Alignment.centerRight),
                  Positioned(
                    right: 5,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: PRIMARY_COLOR.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_overflows && !_hasScrolled)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swipe_left_alt_rounded,
                  size: 14,
                  color: widget.ink.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 5),
                // Flexible, not a bare Text: the bubble can be narrow, and a
                // hint that overflows its own row draws the debug stripe
                // across the very table it is trying to explain.
                Flexible(
                  child: Text(
                    isBangla ? 'পাশে সরিয়ে দেখুন' : 'Swipe to see more',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: widget.ink.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The table fading into the bubble behind it, rather than being chopped.
  Widget _edge(Color surface, Alignment side) {
    return Positioned(
      left: side == Alignment.centerLeft ? 0 : null,
      right: side == Alignment.centerRight ? 0 : null,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: side,
              end: side == Alignment.centerLeft
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              colors: [surface, surface.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
