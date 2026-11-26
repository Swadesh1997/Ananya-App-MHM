import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/widgets/cycle_visuals.dart';

/// The countdown ring fits whatever it is given.
///
/// CycleRing is a fixed square with roughly 72% of its width available inside
/// the padding, and it sets the centre value at 30% of its size — 63pt in the
/// 210px ring on the home screen. That slot was built for a one- or two-digit
/// countdown and later handed words. It also carried a day-of-cycle pill,
/// since removed: it repeated the line under the ring and its extra height
/// pushed the top label up to where the circle narrows. "Today" wrapped to two lines and
/// overflowed the fixed box by 42 pixels; "Any day now" wrapped to three and
/// overflowed by 240. Debug builds paint the striped banner over the card;
/// release builds clip the text silently. Both were on the main screen, and
/// the second appears for several days each cycle for anyone whose cycle the
/// app has not measured — which is most users.
///
/// The value now scales down instead of wrapping. A number is far inside the
/// limit so its scale factor is 1 and it is untouched; only strings that would
/// not otherwise fit are shrunk.
///
/// Note on measurements: flutter_test renders with a fallback font whose
/// glyphs are all one em wide, so the natural widths below are roughly double
/// what a real font produces. They are useful for comparing cases, not for
/// predicting the on-device font size.
void main() {
  Future<Object?> overflowFor(
    WidgetTester tester,
    String value, {
    String? topLabel,
    String label = 'est. start',
    double size = 210,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: CycleRing(
            size: size,
            progress: 0.9,
            topLabel: topLabel,
            value: value,
            label: label,
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.takeException();
  }

  group('every value the widget can produce', () {
    // period_cycle_information gives the ring exactly three shapes.
    testWidgets('a one-digit countdown', (tester) async {
      expect(
          await overflowFor(tester, '3',
              topLabel: 'Next period in',
              label: 'days left'),
          isNull);
    });

    testWidgets('a two-digit countdown', (tester) async {
      expect(
          await overflowFor(tester, '21',
              topLabel: 'Next period in',
              label: 'days left'),
          isNull);
    });

    testWidgets('"Today" — used to overflow by 42px', (tester) async {
      expect(await overflowFor(tester, 'Today'),
          isNull);
    });

    testWidgets('"Any day now" — used to overflow by 240px', (tester) async {
      expect(
          await overflowFor(tester, 'Any day now'),
          isNull);
    });
  });

  group('Bangla', () {
    testWidgets('আজ', (tester) async {
      expect(
          await overflowFor(tester, 'আজ',
              label: 'সম্ভাব্য শুরু'),
          isNull);
    });

    testWidgets('যেকোনো দিন — used to overflow by 174px', (tester) async {
      expect(
          await overflowFor(tester, 'যেকোনো দিন',
              label: 'সম্ভাব্য শুরু'),
          isNull);
    });

    testWidgets('a Bangla countdown with its caption', (tester) async {
      expect(
          await overflowFor(tester, '২১',
              topLabel: 'পরের পিরিয়ড আসতে',
              label: 'দিন বাকি'),
          isNull);
    });
  });

  group('it cannot be overflowed by content at all', () {
    testWidgets('a string far longer than any real label', (tester) async {
      expect(
          await overflowFor(
              tester, 'Something very much longer than any real label'),
          isNull);
    });

    testWidgets('an empty value', (tester) async {
      expect(await overflowFor(tester, ''), isNull);
    });

    testWidgets('with and without the optional top line', (tester) async {
      for (final top in [null, 'Next period in']) {
        expect(
          await overflowFor(tester, 'Any day now', topLabel: top),
          isNull,
          reason: 'top=$top',
        );
      }
    });

    testWidgets('at the smaller default size used elsewhere', (tester) async {
      expect(await overflowFor(tester, 'Any day now', size: 92), isNull);
      expect(await overflowFor(tester, '12', label: 'days', size: 92), isNull);
    });
  });

  group('a number is not shrunk', () {
    testWidgets('it renders at the ring\'s full value size', (tester) async {
      await overflowFor(tester, '3',
          topLabel: 'Next period in', label: 'days left');
      final style = tester.widget<Text>(find.text('3')).style!;
      expect(style.fontSize, 210 * 0.30,
          reason: 'the countdown must keep its prominence');

      // And nothing scales it: its natural width is well inside the ring.
      final natural = tester.getSize(find.text('3')).width;
      expect(natural, lessThan(210 * 0.72),
          reason: 'scale factor is 1 for the common case');
    });
  });
}
