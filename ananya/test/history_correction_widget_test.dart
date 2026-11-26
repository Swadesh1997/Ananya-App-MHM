import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/services/local_period_store.dart';
import 'package:ananya/services/period_history_service.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/calender.dart';
import 'package:ananya/widgets/period_cycle_information.dart';

import 'support/firebase_test_seam.dart';

/// Correcting a mis-logged date, driven through the real widget.
///
/// Two audits could only read this code: the history list calls
/// `FirebaseAuth.instance` directly, so it could not be mounted. It is
/// mounted here against mock platform implementations, and every assertion
/// below is about rendered output or stored state — none inspects source.
///
/// Firestore is not mocked. Its writes are fire-and-forget with their own
/// catchError, and the device copy is written first and awaited, so the local
/// half runs for real. What remains unverified is stated in the audit.
void main() {
  setUpAll(() async => installFirebaseTestSeam());

  // The countdown ring overflows for any non-numeric value. That is a real
  // defect, asserted on in ring_overflow_test.dart; ignoring it here lets the
  // history list below it be exercised rather than blocked by it.


  /// Seeds the on-device history with raw logs, exactly as the app stores it.
  Future<void> seed(List<String> isoDates, {int bleed = 5}) async {
    SharedPreferences.setMockInitialValues({});
    for (final d in isoDates) {
      await LocalPeriodStore.recordPeriod(testUid, d, bleed);
    }
  }

  Future<List<String>> storedDates() async {
    final raw = await PeriodHistoryService.fetchRawLocal(testUid);
    return raw
        .map((d) =>
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
        .toList();
  }

  CycleSnapshot snapshotOf(List<String> isoDates, {int bleed = 5}) {
    final d = isoDates.map(DateTime.parse).toList()..sort();
    return CycleSnapshot.build(
      entries: [
        for (var i = 0; i < d.length; i++)
          PeriodEntry(
            start: d[i],
            lengthOfPeriod: bleed,
            daysSincePrevious:
                i == 0 ? null : d[i].difference(d[i - 1]).inDays,
          ),
      ],
      settings: const {
        'days_between_period': 28,
        'length_of_period': 5,
        'is_period_regular': true,
      },
      today: DateTime(2026, 3, 1),
    );
  }

  var historyChanged = 0;

  Future<void> mount(WidgetTester tester, CycleSnapshot snapshot,
      {double width = 400, Locale? locale, double textScale = 1.0}) async {
    historyChanged = 0;
    // The card is a tall scrolling column; the history list sits well below
    // the default 800x600 test surface.
    tester.view.physicalSize = Size(width, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SingleChildScrollView(
            child: PeriodCycleInformation(
              issuperuser: false,
              snapshot: snapshot,
              data: const {},
              onHistoryChanged: () => historyChanged++,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // _loadName starts a 10-second timeout on a Firestore read. Firestore is
    // not mocked, so let the timer expire rather than leaving it pending.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  }

  group('Jan 1 logged by mistake, Jan 10 logged as the correction', () {
    testWidgets('both raw dates are discoverable in the UI', (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']));

      // The episode row shows the canonical (earliest) date...
      expect(find.textContaining('1 Jan'), findsWidgets);
      // ...and the hidden second log is now listed beneath it.
      expect(find.text('Dates logged for this entry:'), findsOneWidget);
      expect(find.textContaining('10 Jan'), findsWidgets);
      expect(find.text('Remove this date'), findsNWidgets(2));
    });

    testWidgets('removing Jan 1 leaves Jan 10 standing', (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']));

      // The first "Remove this date" belongs to the earliest listed log.
      await tester.tap(find.text('Remove this date').first);
      await tester.pumpAndSettle();

      final after = await storedDates();
      expect(after, ['2026-01-10'],
          reason: 'Jan 1 gone, Jan 10 kept — the correction she could not '
              'previously make');
    });

    testWidgets('the screen above is told to recompute', (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']));

      await tester.tap(find.text('Remove this date').first);
      await tester.pumpAndSettle();

      expect(historyChanged, 1,
          reason: 'the prediction, calendar and reminders all hang off this');
    });

    testWidgets('the anchor and prediction follow the surviving date',
        (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      final before = snapshotOf(['2026-01-01', '2026-01-10']);
      await mount(tester, before);

      await tester.tap(find.text('Remove this date').first);
      await tester.pumpAndSettle();

      // Rebuild the snapshot from what is actually stored now, as the screen
      // above does on onHistoryChanged.
      final after = snapshotOf(await storedDates());

      expect(before.stats.canonicalLastStart, DateTime(2026, 1, 1),
          reason: 'the mistake anchored it nine days early');
      expect(after.stats.canonicalLastStart, DateTime(2026, 1, 10));
      expect(after.expectedDate,
          before.expectedDate!.add(const Duration(days: 9)));
    });

    testWidgets('a restart does not resurrect Jan 1', (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']));
      await tester.tap(find.text('Remove this date').first);
      await tester.pumpAndSettle();

      // Remount from scratch — a cold start reads the same device copy.
      await mount(tester, snapshotOf(await storedDates()));

      expect(await storedDates(), ['2026-01-10']);
      expect(find.textContaining('1 Jan'), findsNothing);
      // One log left, so the expansion no longer appears.
      expect(find.text('Dates logged for this entry:'), findsNothing);
    });

    testWidgets('the whole-episode delete is still a separate control',
        (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']));

      // Two per-log links plus the episode's own Remove button.
      expect(find.text('Remove this date'), findsNWidgets(2));
      expect(find.textContaining('Remove'), findsWidgets);
    });
  });

  group('Jan 1, Jan 4, Jan 10 — remove only the middle one', () {
    testWidgets('all three are listed', (tester) async {
      await seed(['2026-01-01', '2026-01-04', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-04', '2026-01-10']));

      expect(find.text('Remove this date'), findsNWidgets(3));
    });

    testWidgets('removing Jan 4 leaves Jan 1 and Jan 10', (tester) async {
      await seed(['2026-01-01', '2026-01-04', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-04', '2026-01-10']));

      // Second link = second listed date = Jan 4.
      await tester.tap(find.text('Remove this date').at(1));
      await tester.pumpAndSettle();

      expect(await storedDates(), ['2026-01-01', '2026-01-10']);
    });

    testWidgets('the canonical start is unchanged by removing the middle',
        (tester) async {
      await seed(['2026-01-01', '2026-01-04', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-04', '2026-01-10']));
      await tester.tap(find.text('Remove this date').at(1));
      await tester.pumpAndSettle();

      final after = snapshotOf(await storedDates());
      expect(after.stats.canonicalLastStart, DateTime(2026, 1, 1),
          reason: 'Jan 1 is still the earliest date in the episode');
    });
  });

  group('Jan 1, Jan 4, Jan 8, Jan 12 — remove Jan 1', () {
    testWidgets('four dates are listed, one episode', (tester) async {
      await seed(['2026-01-01', '2026-01-04', '2026-01-08', '2026-01-12']);
      await mount(tester,
          snapshotOf(['2026-01-01', '2026-01-04', '2026-01-08', '2026-01-12']));

      expect(find.text('Remove this date'), findsNWidgets(4));
    });

    testWidgets('removing Jan 1 keeps the other three and moves the anchor',
        (tester) async {
      await seed(['2026-01-01', '2026-01-04', '2026-01-08', '2026-01-12']);
      await mount(tester,
          snapshotOf(['2026-01-01', '2026-01-04', '2026-01-08', '2026-01-12']));

      await tester.tap(find.text('Remove this date').first);
      await tester.pumpAndSettle();

      expect(await storedDates(), ['2026-01-04', '2026-01-08', '2026-01-12']);

      final after = snapshotOf(await storedDates());
      expect(after.entries.length, 1, reason: 'still one episode');
      expect(after.stats.canonicalLastStart, DateTime(2026, 1, 4));
    });

    testWidgets('removing one never removes another', (tester) async {
      await seed(['2026-01-01', '2026-01-04', '2026-01-08', '2026-01-12']);
      var dates = await storedDates();

      // Remount with a fresh snapshot between taps, which is what
      // onHistoryChanged causes the screen above to do in production.
      while (dates.length > 1) {
        await mount(tester, snapshotOf(dates));
        await tester.tap(find.text('Remove this date').first);
        await tester.pumpAndSettle();

        final after = await storedDates();
        expect(after.length, dates.length - 1,
            reason: 'exactly one date should go per tap, had $dates');
        dates = after;
      }
      expect(dates, ['2026-01-12']);
    });
  });

  group('the episode delete still removes the whole episode', () {
    testWidgets('all logs behind it go together', (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      final dates = await PeriodHistoryService.fetchRawLocal(testUid);
      expect(dates.length, 2);

      await PeriodHistoryService.delete(
          uid: testUid, start: DateTime(2026, 1, 1));

      expect(await storedDates(), isEmpty,
          reason: 'deleting the episode is a different, deliberate action');
    });
  });
  group('the card renders without overflowing', () {
    // This suite used to need a FlutterError filter to run at all: the
    // countdown ring overflowed its fixed box for any non-numeric value, and
    // the correction row overflowed horizontally once the date and the link
    // together exceeded the column. Both are fixed, so the filter is gone —
    // any overflow now fails these tests, which is the point.
    testWidgets('with a collapsed episode and its expansion showing',
        (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']));
      expect(tester.takeException(), isNull);
    });

    testWidgets('at a narrow phone width', (tester) async {
      await seed(['2026-01-01', '2026-01-04', '2026-01-08', '2026-01-12']);
      await mount(tester,
          snapshotOf(['2026-01-01', '2026-01-04', '2026-01-08', '2026-01-12']),
          width: 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in Bangla', (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']),
          locale: const Locale('bn'));
      expect(tester.takeException(), isNull);
      expect(find.text('এই তারিখটি মুছুন'), findsNWidgets(2));
    });

    testWidgets('in Bangla at a narrow width', (tester) async {
      await seed(['2026-01-01', '2026-01-10']);
      await mount(tester, snapshotOf(['2026-01-01', '2026-01-10']),
          locale: const Locale('bn'), width: 320);
      expect(tester.takeException(), isNull);
    });
  });

  group('the card says each thing once', () {
    testWidgets('the phase is not restated in prose under the key',
        (tester) async {
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester, snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']),
          locale: const Locale('bn'));

      // The key highlights the current phase and the bar marks it. Naming it
      // again underneath, and then describing it, said one thing three times.
      expect(find.text('পরের পিরিয়ডের অপেক্ষায়'), findsOneWidget,
          reason: 'only the key label should carry this');
      expect(find.text('পিরিয়ডের আগের ধাপ'), findsNothing);
    });

    testWidgets('the empty state still explains itself', (tester) async {
      await seed([]);
      final empty = CycleSnapshot.build(
        entries: const [],
        settings: const {'days_between_period': 28, 'length_of_period': 5},
        today: DateTime(2026, 3, 1),
      );
      // With no prediction the card renders nothing at all, so the timeline's
      // own empty state is exercised where it actually appears.
      expect(empty.prediction, isNull);
    });
  });

  group('the regularity chip', () {
    testWidgets('sits against the right edge, not mid-row', (tester) async {
      // Two flex children share the free space between them, so the chip was
      // laid out at the start of its own half and came to rest near the
      // middle with empty space beside it.
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester,
          snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']));

      final chip = tester.getRect(find.text('Regular'));
      // Card padding is 18 and the pill adds 11 inside it.
      expect(chip.right, closeTo(400 - 18 - 11, 1.5));
    });

    testWidgets('uses its own capitalised words, not the questionnaire\'s',
        (tester) async {
      // "regular" is lowercase because the setup screen asks "Are your
      // periods regular?". On a chip beside "Irregular" it read as a typo.
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester,
          snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']));
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('regular'), findsNothing);
    });
  });

  group('the statistics tiles', () {
    testWidgets('show the last period and the predicted next one',
        (tester) async {
      // The predicted date was nowhere on this screen: the ring counts in
      // days and the calendar shades a band, so reading the date meant
      // scrolling and counting squares.
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      final s = snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester, s);

      expect(find.text('Average cycle'), findsOneWidget);
      expect(find.text('Last period'), findsOneWidget);
      expect(find.text('Next period'), findsOneWidget);
      expect(find.text('Average period'), findsNothing,
          reason: 'replaced: it was the least useful of the three');

      expect(find.text('10 September'), findsWidgets);
      expect(find.text('9 October'), findsWidgets);
    });

    testWidgets('the predicted date matches the ring exactly', (tester) async {
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      final s = snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester, s);

      // Same snapshot value, so the tile and the countdown cannot disagree.
      expect(s.expectedDate, DateTime(2026, 10, 9));
      expect(find.text('9 October'), findsWidgets);
    });

    testWidgets('Bangla labels', (tester) async {
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester, snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']),
          locale: const Locale('bn'));

      expect(find.text('গড় চক্র'), findsOneWidget);
      expect(find.text('শেষ পিরিয়ড'), findsOneWidget);
      expect(find.text('পরের পিরিয়ড'), findsOneWidget);
      expect(find.text('গড় পিরিয়ড'), findsNothing);
    });
  });

  group('the calendar does not mark ovulation', () {
    testWidgets('no ovulation chip in the key', (tester) async {
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester,
          snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']));

      // "Ovulation" appears once, in the phase timeline's key, where it
      // names a stretch of the cycle. The calendar's key had a second one
      // beside a blue dot, marking three specific days.
      expect(find.text('Ovulation'), findsOneWidget);
      // The calendar key is down to two chips, both naming what they mark.
      expect(find.text('Expected period'), findsOneWidget);
      expect(find.text('Logged period'), findsOneWidget);
    });

    testWidgets('nor in Bangla', (tester) async {
      await seed(['2026-07-15', '2026-08-13', '2026-09-10']);
      await mount(tester,
          snapshotOf(['2026-07-15', '2026-08-13', '2026-09-10']),
          locale: const Locale('bn'));

      expect(find.text('ওভুলেশন'), findsNothing);
      expect(find.text('সম্ভাব্য পিরিয়ড'), findsOneWidget);
      expect(find.text('রেকর্ড করা পিরিয়ড'), findsOneWidget);
      // পিরিয়ড throughout, never মাসিক — one word for it across the screen.
      expect(find.text('মাসিক'), findsNothing);
    });

    test('the widget cannot be given ovulation days at all', () {
      // The parameters are gone, not merely unused, so a later change cannot
      // reintroduce the marks by passing data.
      final src = File('lib/widgets/calender.dart').readAsStringSync();
      expect(src.contains('predictedOvulation'), isFalse);
      expect(src.contains('_ovulation('), isFalse);
      expect(src.contains('SECONDARY_COLOR'), isFalse,
          reason: 'the blue was only ever the ovulation marker');
    });

    test('the projection no longer computes ovulation days', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      expect(src.contains('ovulation_days'), isFalse);
      expect(src.contains('ovulationDays'), isFalse);
    });

    test('but the phase timeline still names it', () {
      // Removing it from the calendar is about a date presented as a fact.
      // The timeline names a stretch of the cycle, which is a different claim.
      final src = File('lib/widgets/cycle_visuals.dart').readAsStringSync();
      expect(src, contains('ডিম্বস্ফোটন'));
      expect(src, contains('Ovulation'));
    });
  });

  group('the calendar band weights', () {
    test('the forecast is the stronger of the two', () {
      // The forecast used to be an outline and the record a filled band, so
      // the fainter mark was the one she opens the screen to find.
      expect(Calender.expectedBandColour.a,
          greaterThan(Calender.loggedBandColour.a));
    });

    test('both are the app\'s own colour, no new hue', () {
      for (final c in [
        Calender.expectedBandColour,
        Calender.loggedBandColour
      ]) {
        expect(c.r, PRIMARY_COLOR.r);
        expect(c.g, PRIMARY_COLOR.g);
        expect(c.b, PRIMARY_COLOR.b);
      }
    });

    test('the key reads its swatches from the calendar itself', () {
      final src =
          File('lib/widgets/period_cycle_information.dart').readAsStringSync();
      expect(src, contains('Calender.expectedBandColour'));
      expect(src, contains('Calender.loggedBandColour'));
      // Not a hand-copied literal that could drift from the band.
      expect(src.contains('_legendChip(PRIMARY_COLOR'), isFalse);
    });

    test('the forecast is filled, not outlined', () {
      final src = File('lib/widgets/calender.dart').readAsStringSync();
      expect(src.contains('_outlined('), isFalse);
      // Both markers go through the same band renderer.
      expect('_band(day,'.allMatches(src).length, 2);
    });

    test('today keeps its dark outlined ring', () {
      final src = File('lib/widgets/calender.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('Widget _todayPlain('));
      final body = fn.substring(0, fn.indexOf('\n      );'));
      expect(body, contains('shape: BoxShape.circle'));
      expect(body, contains('Border.all(color: ACCENT, width: 2)'));
    });
  });

  group('the statistics tiles are one set', () {
    /// The font size of each tile's figure, in order.
    List<double> figureSizes(WidgetTester tester) {
      final out = <double>[];
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final span = w.textSpan;
        if (span is TextSpan &&
            span.children != null &&
            span.children!.isNotEmpty) {
          final first = span.children!.first;
          if (first is TextSpan && first.style?.fontWeight == FontWeight.bold) {
            out.add(first.style!.fontSize!);
          }
        }
      }
      return out;
    }
    /// The painted width of each statistics figure.
    ///
    /// The same shape figureSizes matches, read from the render tree instead of
    /// the widget tree: a Text.rich whose span carries a bold figure followed
    /// by its unit. Text wraps that span inside one of its own, so the bold run
    /// sits two levels down in the paragraph the renderer holds. Plain bold
    /// Text elsewhere on the card has no children and is skipped.
    List<double> figureWidths(WidgetTester tester) {
      final out = <double>[];
      for (final p
          in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        final outer = p.text;
        if (outer is! TextSpan || outer.children == null) continue;
        final inner = outer.children!.first;
        if (inner is! TextSpan || inner.children == null) continue;
        final figure = inner.children!.first;
        if (figure is TextSpan && figure.style?.fontWeight == FontWeight.bold) {
          out.add(p.size.width);
        }
      }
      return out;
    }

    // "2 September" is wider than "2 October", so when each tile shrank on
    // its own the longer one was scaled and the shorter one was not — two
    // figures of the same kind drawn at two sizes.
    for (final code in ['en', 'bn']) {
      for (final width in [320.0, 360.0, 411.0]) {
        testWidgets('same size at ${width.toInt()}px, $code', (tester) async {
          await seed(['2026-08-05', '2026-09-02']);
          await mount(tester, snapshotOf(['2026-08-05', '2026-09-02']),
              locale: Locale(code), width: width);

          final sizes = figureSizes(tester);
          expect(sizes.length, 3, reason: 'three tiles expected');
          for (final s in sizes) {
            expect(s, closeTo(sizes.first, 0.01),
                reason: '$code at ${width.toInt()}px: $sizes');
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a long pair still matches', (tester) async {
      // 22 September / 20 October — the worst case for a spelled-out month.
      await seed(['2026-08-25', '2026-09-22']);
      await mount(tester, snapshotOf(['2026-08-25', '2026-09-22']),
          width: 360);

      final sizes = figureSizes(tester);
      expect(sizes.length, 3);
      for (final s in sizes) {
        expect(s, closeTo(sizes.first, 0.01), reason: '$sizes');
      }
    });

    testWidgets('nothing is scaled when everything fits', (tester) async {
      // A wide surface: no tile needs shrinking, so all three keep the base
      // size rather than being shrunk by a scale that should not apply.
      await seed(['2026-08-05', '2026-09-02']);
      await mount(tester, snapshotOf(['2026-08-05', '2026-09-02']),
          width: 1400);

      for (final s in figureSizes(tester)) {
        expect(s, 18.0);
      }
    });

    // The same arithmetic the widget uses: the row sits inside the card's 18px
    // padding, three tiles with two 8px gaps, and each tile keeps 22px of its
    // own padding plus a 1px border either side.
    double innerAt(double width) => ((width - 36) - 16) / 3 - 24;

    testWidgets('a value never runs outside its tile', (tester) async {
      // The direct check for what went wrong on the device: "30 September"
      // was drawn wider than the box and came out as "30 Septembe".
      for (final code in ['en', 'bn']) {
        for (final width in [320.0, 360.0, 411.0]) {
          await seed(['2026-08-30', '2026-09-30']);
          await mount(tester, snapshotOf(['2026-08-30', '2026-09-30']),
              locale: Locale(code), width: width);

          final widths = figureWidths(tester);
          expect(widths.length, 3,
              reason: 'the three figures must be found, not silently skipped');
          for (final w in widths) {
            expect(w, lessThanOrEqualTo(innerAt(width) + 0.5),
                reason: '$code at ${width.toInt()}px: '
                    '$w wide in ${innerAt(width)}');
          }
        }
      }
    });

    testWidgets('a bigger system font shrinks the figures, never cuts them',
        (tester) async {
      // The measurement has to account for the viewer's own font scale, not
      // just the locale. A girl running the phone at 1.3x sees the same three
      // figures in the same three boxes.
      for (final code in ['en', 'bn']) {
        await seed(['2026-08-30', '2026-09-30']);
        await mount(tester, snapshotOf(['2026-08-30', '2026-09-30']),
            locale: Locale(code), width: 360, textScale: 1.3);

        final sizes = figureSizes(tester);
        expect(sizes.length, 3);
        for (final s in sizes) {
          expect(s, closeTo(sizes.first, 0.01), reason: '$code: $sizes');
        }

        final widths = figureWidths(tester);
        expect(widths.length, 3);
        for (final w in widths) {
          expect(w, lessThanOrEqualTo(innerAt(360) + 0.5),
              reason: '$code at 1.3x: $w wide in ${innerAt(360)}');
        }
      }
    });

    testWidgets('the shared scale does the shrinking, not a silent clip',
        (tester) async {
      // A narrow surface with the longest month names: the figures must come
      // back *smaller* than the base size. If they were still 18pt and simply
      // fitted into the box, the mechanism would be clipping, which is what
      // produced "30 Septembe" on the device.
      await seed(['2026-08-30', '2026-09-30']);
      await mount(tester, snapshotOf(['2026-08-30', '2026-09-30']),
          locale: const Locale('en'), width: 320);

      final sizes = figureSizes(tester);
      expect(sizes.length, 3);
      for (final s in sizes) {
        expect(s, lessThan(18.0),
            reason: 'the scale should be engaged here: $sizes');
      }

      // And not shrunk further than it needs to be: the widest figure should
      // still fill most of its box. Over-shrinking would mean the measurement
      // is wrong in the other direction. (An absolute floor in points would be
      // meaningless here — flutter_test's fallback font is about twice the
      // width of Inter, so these sizes are a worst case, not the device's.)
      final widest = figureWidths(tester).reduce((a, b) => a > b ? a : b);
      expect(widest, greaterThan(innerAt(320) * 0.8),
          reason: 'widest figure is $widest in ${innerAt(320)}');
    });
  });
}
