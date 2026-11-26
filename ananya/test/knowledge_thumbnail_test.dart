import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/screens/process/knowledge_hub_page.dart';

/// The illustration beside each Knowledge Hub question.
///
/// It used to be `Image.asset(width: 132, height: 118, cacheWidth: 264,
/// cacheHeight: 236)`. Setting both cache dimensions decodes the file to
/// exactly those pixels and stretches it to fit — aspect ratio is not
/// preserved. The 29 hero images run from 0.93 to 3.81 in aspect against a
/// forced 1.119, so they arrived at the painter already the wrong shape, by as
/// much as 71%. That is what "the animations look shrinked" was.
///
/// And 264 assumed a 2x screen. On the 3x phones this app is actually used on,
/// a 132pt box is 396 device pixels, so every illustration was decoded smaller
/// than it was drawn and upscaled.
void main() {
  const item = <String, String>{
    'id': '1',
    'hero_image': 'assets/images/1.png',
    'question': 'পিএমএস (PMS) বা প্রিমেনস্ট্রুয়াল সিনড্রোম কী?',
  };

  Future<Image> pumpCard(
    WidgetTester tester, {
    double width = 400,
    double dpr = 3.0,
    Locale locale = const Locale('bn'),
  }) async {
    tester.view.physicalSize = Size(width * dpr, 900 * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: KnowledgeHubItemCard(item: item),
        ),
      ),
    ));
    await tester.pump();

    // The asset bundle is not populated in a widget test, so decoding fails.
    // Irrelevant here: every assertion below is on the widget's own
    // configuration, which is where both bugs lived.
    tester.takeException();

    return tester.widget<Image>(find.byType(Image));
  }

  group('the decode no longer distorts the artwork', () {
    testWidgets('cacheHeight is not set', (tester) async {
      final image = await pumpCard(tester);
      expect(image.height, isNull,
          reason: 'a fixed height on the Image forces the box, not the decode');
      final provider = image.image as ResizeImage;
      expect(provider.height, isNull,
          reason: 'setting both cache dimensions stretches the bitmap to fit '
              'them — this is the bug that squashed the illustrations');
      expect(provider.width, isNotNull,
          reason: 'width alone is what lets the decoder scale height to match');
    });

    testWidgets('the box keeps its designed shape', (tester) async {
      await pumpCard(tester);
      final size = tester.getSize(find.byType(Image));
      expect(size.width / size.height, closeTo(132 / 118, 0.01));
    });
  });

  group('it is decoded for the screen it is drawn on', () {
    for (final dpr in [1.0, 2.0, 3.0, 4.0]) {
      testWidgets('at ${dpr}x the decode matches the painted size',
          (tester) async {
        final image = await pumpCard(tester, dpr: dpr);
        final painted = tester.getSize(find.byType(Image)).width;
        final decoded = (image.image as ResizeImage).width!;

        expect(decoded, (painted * dpr).round(),
            reason: 'decoding below the painted size upscales and softens it; '
                'the old hardcoded 264 assumed every phone was 2x');
      });
    }
  });

  group('it scales with the device', () {
    testWidgets('a wider screen gives a wider thumbnail', (tester) async {
      final narrow = await pumpCard(tester, width: 320);
      final narrowSize = tester.getSize(find.byType(Image)).width;

      await pumpCard(tester, width: 600);
      final wideSize = tester.getSize(find.byType(Image)).width;

      expect(wideSize, greaterThan(narrowSize),
          reason: 'a fixed 132 was 41% of the row on a 320px phone');
      expect(narrow.image, isA<ResizeImage>());
    });

    testWidgets('it stays inside its clamps at both extremes', (tester) async {
      for (final width in [240.0, 320.0, 411.0, 800.0, 1400.0]) {
        await pumpCard(tester, width: width);
        final w = tester.getSize(find.byType(Image)).width;
        expect(w, greaterThanOrEqualTo(104.0), reason: 'at ${width}px');
        expect(w, lessThanOrEqualTo(168.0), reason: 'at ${width}px');
      }
    });

    testWidgets('the question always keeps more room than the picture',
        (tester) async {
      // The reason for the clamps: on the narrowest phone a fixed thumbnail
      // left the question a column barely wide enough for two words.
      for (final width in [320.0, 360.0, 411.0]) {
        await pumpCard(tester, width: width);
        final thumb = tester.getSize(find.byType(Image)).width;
        expect(thumb, lessThan(width / 2),
            reason: 'picture took $thumb of ${width}px');
      }
    });
  });
}
