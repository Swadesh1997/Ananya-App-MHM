import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/widgets/cycle_visuals.dart';

/// The Home screen's copy fits the widgets it sits in, in both languages.
///
/// The Bangla was reworked to read naturally rather than as a literal
/// translation, and several labels got longer as a result: the timeline key's
/// last phase became "পরের পিরিয়ডের অপেক্ষায়" and the section heading became
/// "আপনার চক্রের বর্তমান অবস্থা". Both ran past the edge of their rows on a
/// 320px screen.
///
/// flutter_test renders with a fallback font whose glyphs are all one em
/// wide, so Bangla measures far wider here than it does on a device. That
/// makes these a worst case rather than a prediction — which is exactly what
/// is worth pinning, because copy edits and system font scaling both push in
/// the same direction.
void main() {
  Future<Object?> phaseBar(
    WidgetTester tester,
    double width,
    Locale locale, {
    int? day,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: CyclePhaseTimeline(
            cycleDays: 28,
            bleedDays: 5,
            cycleDay: day,
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.takeException();
  }

  Future<Object?> ring(
    WidgetTester tester,
    double width, {
    required String topLabel,
    required String value,
    required String label,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: Center(
            child: CycleRing(
              size: 210,
              progress: 0.5,
              topLabel: topLabel,
              value: value,
              label: label,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.takeException();
  }

  group('the cycle timeline', () {
    for (final width in [320.0, 360.0, 400.0]) {
      for (final code in ['en', 'bn']) {
        testWidgets('$code at ${width.toInt()}px, mid-cycle', (tester) async {
          expect(await phaseBar(tester, width, Locale(code), day: 24), isNull);
        });

        testWidgets('$code at ${width.toInt()}px, nothing logged',
            (tester) async {
          expect(await phaseBar(tester, width, Locale(code)), isNull);
        });
      }
    }

    testWidgets('the longest key label is present and not clipped',
        (tester) async {
      // "পরের পিরিয়ডের অপেক্ষায়" is the longest thing in the key, and the
      // reason the row scales.
      expect(await phaseBar(tester, 320, const Locale('bn'), day: 24), isNull);
      expect(find.text('পরের পিরিয়ডের অপেক্ষায়'), findsWidgets);
    });

    testWidgets('the heading and the day line share one row', (tester) async {
      await phaseBar(tester, 320, const Locale('bn'), day: 24);
      expect(find.text('আপনার চক্রের বর্তমান অবস্থা'), findsOneWidget);
      expect(find.textContaining('চক্রের ২৪তম দিন'), findsWidgets);
    });
  });

  group('the countdown ring', () {
    for (final width in [320.0, 400.0]) {
      testWidgets('Bangla at ${width.toInt()}px', (tester) async {
        expect(
          await ring(tester, width,
              topLabel: 'পরের পিরিয়ড আসতে',
              value: '১৪',
              label: 'দিন বাকি'),
          isNull,
        );
      });

      testWidgets('English at ${width.toInt()}px', (tester) async {
        expect(
          await ring(tester, width,
              topLabel: 'Next period in',
              value: '14',
              label: 'days left'),
          isNull,
        );
      });
    }
  });

  group('one line, not two', () {
    // The Bangla wrapped where English did not: the heading split in half,
    // the day beside it was cut to "আজ · চক্রের ২৪তম …", and the key's last
    // phase dropped onto a row of its own. All three now shrink instead.
    Future<void> bar(WidgetTester t, double w, String code) async {
      await t.pumpWidget(MaterialApp(
        locale: Locale(code),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: w,
            child: const CyclePhaseTimeline(
                cycleDays: 28, bleedDays: 5, cycleDay: 24),
          ),
        ),
      ));
      await t.pump();
    }

    for (final code in ['en', 'bn']) {
      for (final w in [320.0, 360.0, 411.0]) {
        testWidgets('the key sits on one line: $code at ${w.toInt()}px',
            (t) async {
          await bar(t, w, code);
          final labels = code == 'bn'
              ? [
                  'পিরিয়ড',
                  'পিরিয়ডের পর',
                  'ডিম্বস্ফোটন',
                  'পরের পিরিয়ডের অপেক্ষায়'
                ]
              : ['Period', 'After period', 'Ovulation', 'Before next period'];

          // Same vertical position for all four means one row.
          // .first because in Bangla the last phase's key label and the
          // status headline below are deliberately the same words.
          final tops = [
            for (final l in labels) t.getTopLeft(find.text(l).first).dy
          ];
          expect(tops.every((y) => (y - tops.first).abs() < 0.5), isTrue,
              reason: '$code at ${w.toInt()}px: key tops $tops');
        });

        testWidgets('the heading and day line do not wrap: $code at '
            '${w.toInt()}px', (t) async {
          await bar(t, w, code);
          final heading = code == 'bn'
              ? 'আপনার চক্রের বর্তমান অবস্থা'
              : 'Your cycle right now';
          final day =
              code == 'bn' ? 'আজ · চক্রের ২৪তম দিন' : 'Today · day 24';

          // One line at 12.5pt is comfortably under 30 logical pixels.
          expect(t.getSize(find.text(heading).first).height, lessThan(30),
              reason: 'the heading wrapped');
          expect(t.getSize(find.text(day).first).height, lessThan(30),
              reason: 'the day line wrapped');
        });
      }
    }
  });

  group('dates are spelled out where there is room', () {
    test('the last-period tile gives the full month', () {
      final d = DateTime(2026, 9, 2);
      expect(dayAndMonthFull(d, false), '2 September');
      expect(dayAndMonthFull(d, true), '২ সেপ্টেম্বর');
    });

    test('the short form still exists for dense lists', () {
      final d = DateTime(2026, 9, 2);
      expect(dayAndMonthShort(d, false), '2 Sep');
    });
  });

  group('text stays inside the arc, not merely inside the padding', () {
    // The padding reserves a rectangle 72% of the ring wide. That is right at
    // the vertical middle and far too generous near the top, where the circle
    // has curved in — which is why "পরের পিরিয়ড আসতে" measured as fitting and
    // still ran over the stroke on a real handset.
    const size = 210.0;
    final stroke = (size * 0.075).clamp(6.0, 16.0);
    final innerRadius = size / 2 - stroke;

    double worstRadius(WidgetTester t, Finder f, Rect ring) {
      final r = t.getRect(f);
      var worst = 0.0;
      for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final d = math.sqrt(math.pow(p.dx - ring.center.dx, 2) +
            math.pow(p.dy - ring.center.dy, 2));
        if (d > worst) worst = d;
      }
      return worst;
    }

    final cases = <String, List<String>>{
      'bn, counting down': ['পরের পিরিয়ড আসতে', '৭', 'দিন বাকি'],
      'en, counting down': ['Next period in', '7', 'days left'],
      'bn, two digits': ['পরের পিরিয়ড আসতে', '১৪', 'দিন বাকি'],
      'en, today': ['', 'Today', 'expected start'],
      'bn, today': ['', 'আজ', 'সম্ভাব্য শুরু'],
      'en, any day now': ['', 'Any day now', 'expected start'],
      'bn, any day now': ['', 'যেকোনো দিন', 'সম্ভাব্য শুরু'],
    };

    cases.forEach((name, parts) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: CycleRing(
                size: size,
                progress: 0.75,
                topLabel: parts[0].isEmpty ? null : parts[0],
                value: parts[1],
                label: parts[2],
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);

        final ring = tester.getRect(find.byType(CycleRing));
        for (final text in parts.where((s) => s.isNotEmpty)) {
          expect(
            worstRadius(tester, find.text(text), ring),
            lessThanOrEqualTo(innerRadius),
            reason: '"$text" reaches the arc',
          );
        }
      });
    });
  });
}
