import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/chat/typing_indicator.dart';
import 'package:ananya/widgets/markdown_text.dart';

/// The replies below are real ones captured from the Probahini service, not
/// invented examples — the point of these tests is that the shapes the model
/// actually produces survive parsing, including the ones that used to reach
/// the screen as raw asterisks and pipes.
void main() {
  group('inline bold', () {
    test('**bold** becomes a bold run and loses its asterisks', () {
      final spans = parseInlineSpans('Please **rest** today');
      expect(spans, [('Please ', false), ('rest', true), (' today', false)]);
    });

    test('several bold runs in one line', () {
      final spans = parseInlineSpans('**a** and **b**');
      expect(spans.where((s) => s.$2).map((s) => s.$1), ['a', 'b']);
    });

    test('a lone asterisk is left alone', () {
      final spans = parseInlineSpans('2 * 3 = 6');
      expect(spans, [('2 * 3 = 6', false)]);
    });

    test('plain text comes back as one plain run', () {
      final spans = parseInlineSpans('কেমন আছেন?');
      expect(spans, [('কেমন আছেন?', false)]);
    });
  });

  group('blocks', () {
    test('a wrapped paragraph is joined into one block', () {
      final blocks = parseMarkdownBlocks(
        'Back pain during your period is usually\n'
        'caused by the uterus tightening.',
      );
      expect(blocks, hasLength(1));
      expect(
        (blocks.single as MdParagraph).text,
        'Back pain during your period is usually caused by the uterus tightening.',
      );
    });

    test('a blank line separates paragraphs', () {
      final blocks = parseMarkdownBlocks('First para.\n\nSecond para.');
      expect(blocks, hasLength(2));
      expect(blocks.every((b) => b is MdParagraph), isTrue);
    });

    test('a bold-only line is a heading, not a paragraph', () {
      final blocks = parseMarkdownBlocks('**What you can do right now:**');
      expect(blocks.single, isA<MdHeading>());
      expect((blocks.single as MdHeading).text, 'What you can do right now:');
    });

    test('the colon survives whichever side of the asterisks it is on', () {
      // The model uses both spellings; neither should lose the colon.
      expect(
        (parseMarkdownBlocks('**Summary**:').single as MdHeading).text,
        'Summary:',
      );
      expect(
        (parseMarkdownBlocks('**Summary:**').single as MdHeading).text,
        'Summary:',
      );
    });

    test('### headings are headings', () {
      final blocks = parseMarkdownBlocks('### Summary');
      expect((blocks.single as MdHeading).text, 'Summary');
    });

    test('dash bullets group into one list', () {
      final blocks = parseMarkdownBlocks(
        '- **Apply a hot compress** to the lower back.\n'
        '- **Rest** and avoid heavy lifting.\n'
        '- Take over-the-counter pain relief if needed.',
      );
      final list = blocks.single as MdList;
      expect(list.ordered, isFalse);
      expect(list.items, hasLength(3));
      // Markers are stripped; the bold inside the item is not.
      expect(list.items.first, startsWith('**Apply a hot compress**'));
    });

    test('numbered lists keep the number they started at', () {
      final blocks = parseMarkdownBlocks(
        '2. মাসিকের সময় কোন কোন লক্ষণ দেখা যায়?\n'
        '3. মাসিকের সময়কাল কতদিন হওয়া স্বাভাবিক?',
      );
      final list = blocks.single as MdList;
      expect(list.ordered, isTrue);
      expect(list.start, 2);
      expect(list.items, hasLength(2));
    });
  });

  group('tables', () {
    test('a pipe table parses into header and rows', () {
      final blocks = parseMarkdownBlocks(
        '| ধরণ | সাধারণ সমস্যা | মোকাবিলার ব্যবস্থা |\n'
        '|------|--------------|----------------|\n'
        '| **শারীরিক** | পেটের ব্যথা | গরম পানির ব্যাগ |\n'
        '| **মানসিক** | মেজাজ-বদল | পর্যাপ্ত ঘুম |',
      );
      final table = blocks.single as MdTable;
      expect(table.header, ['ধরণ', 'সাধারণ সমস্যা', 'মোকাবিলার ব্যবস্থা']);
      expect(table.rows, hasLength(2));
      expect(table.rows.first.last, 'গরম পানির ব্যাগ');
    });

    test('<br> inside a cell becomes a real line break', () {
      final blocks = parseMarkdownBlocks(
        '| a | b |\n'
        '|---|---|\n'
        '| one<br>two | three |',
      );
      expect((blocks.single as MdTable).rows.first.first, 'one\ntwo');
    });

    test('a piped line with no divider under it is NOT a table', () {
      // Otherwise an ordinary sentence containing a pipe would silently
      // become a one-row table and lose its text.
      final blocks = parseMarkdownBlocks('Use a pad | or a cloth, both work.');
      expect(blocks.single, isA<MdParagraph>());
    });
  });

  group('a whole reply', () {
    test('the real backpain answer keeps every part', () {
      final blocks = parseMarkdownBlocks(
        'Back pain during your period is usually caused by the uterus '
        'tightening (uterine contractions).\n'
        '\n'
        '**What you can do right now:**\n'
        '\n'
        '- **Apply a hot compress** to the lower back.\n'
        '- **Rest** and avoid heavy lifting.\n'
        '\n'
        'If the pain is severe, see a healthcare provider.',
      );

      expect(blocks.map((b) => b.runtimeType.toString()), [
        'MdParagraph',
        'MdHeading',
        'MdList',
        'MdParagraph',
      ]);
    });

    test('an answer with no Markdown at all survives unchanged', () {
      const plain = 'মাসিক হলো নারীর শরীরের একটি স্বাভাবিক প্রক্রিয়া।';
      final blocks = parseMarkdownBlocks(plain);
      expect((blocks.single as MdParagraph).text, plain);
    });

    test('empty input yields no blocks rather than throwing', () {
      expect(parseMarkdownBlocks(''), isEmpty);
      expect(parseMarkdownBlocks('   \n\n  '), isEmpty);
    });
  });

  _widgetTests();
}

// Widget-level checks for the two things that are not textual: whether a wide
// table advertises that it scrolls, and whether the typing bubble draws.
void _widgetTests() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  group('table scroll affordance', () {
    testWidgets('a table too wide for the screen offers a swipe hint',
        (tester) async {
      const wide = '| আমার প্রথম দীর্ঘ কলামের শিরোনাম এখানে | দ্বিতীয় দীর্ঘ '
          'কলামের শিরোনাম | তৃতীয় দীর্ঘ কলামের শিরোনাম লেখা |\n'
          '|---|---|---|\n'
          '| একটি বেশ লম্বা ঘরের লেখা যেটি জায়গা নেয় | আরেকটি লম্বা ঘরের লেখা '
          'এখানে | তৃতীয় ঘরের অনেক লম্বা লেখা |';

      await tester.pumpWidget(host(const SizedBox(
        width: 260,
        child: MarkdownText(wide),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Swipe'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('a table that fits shows no hint and no arrow', (tester) async {
      await tester.pumpWidget(host(const SizedBox(
        width: 600,
        child: MarkdownText('| a | b |\n|---|---|\n| 1 | 2 |'),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Swipe'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('typing indicator', () {
    testWidgets('draws three dots and does not throw', (tester) async {
      await tester.pumpWidget(host(const TypingIndicator()));
      await tester.pump(const Duration(milliseconds: 300));

      // Three dots plus the avatar's icon.
      expect(find.byType(TypingIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
