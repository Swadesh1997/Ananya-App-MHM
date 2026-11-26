import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/widgets/user_sidebar.dart';

import 'support/firebase_test_seam.dart';

/// The drawer header, signed in and signed out.
///
/// It has been wrong twice. First it drew assets/images/45.png — 450x383 of
/// solid white, no artwork in it at all — which was invisible while the drawer
/// was also white and became a white rectangle once the drawer took the app's
/// cream background.
///
/// Then it used UserAccountsDrawerHeader, which is a fixed 160pt tall and puts
/// the name *under* the picture. Signed out that left about eighty points of
/// nothing above the divider; signed in it gave the name a column of its own.
///
/// It is now one row — picture, then name beside it on the same centreline —
/// costing the picture's height plus its padding and nothing more.
void main() {
  installFirebaseTestSeam();

  Future<void> pumpDrawer(WidgetTester tester, {required bool signedIn}) async {
    SharedPreferences.setMockInitialValues({
      if (signedIn) 'token': 'firebase',
      if (signedIn) 'userName': 'probahini',
      'language_code': 'bn',
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('bn'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: UserSidebar(onselect: (_) {})),
    ));
    await tester.pumpAndSettle();
    // UserProfile.resolve starts a 10-second Firestore timeout. Firestore is
    // not mocked, so let it expire rather than leaving a pending timer.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    tester.takeException(); // assets are not bundled in a widget test
  }

  /// Everything above the divider.
  Rect headerRect(WidgetTester tester) {
    final divider = tester.getRect(find.byType(Divider).first);
    return Rect.fromLTRB(0, 0, divider.right, divider.top);
  }

  group('signed out', () {
    testWidgets('the blank placeholder cannot come back', (tester) async {
      await pumpDrawer(tester, signedIn: false);
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        final provider = image.image;
        final asset = provider is ResizeImage ? provider.imageProvider : provider;
        if (asset is AssetImage) {
          expect(asset.assetName, isNot(contains('45.png')));
        }
      }
    });

    testWidgets('the logo is shown, and never cropped', (tester) async {
      await pumpDrawer(tester, signedIn: false);
      final picture = tester.widget<Image>(find.byType(Image).first);
      final provider = picture.image as ResizeImage;

      expect((provider.imageProvider as AssetImage).assetName,
          'assets/images/logo.png');
      expect(picture.fit, BoxFit.contain,
          reason: 'cover crops what does not fit, and a logo must arrive '
              'whole or not at all');
      expect(provider.height, isNull,
          reason: 'setting both cache dimensions stretches the bitmap');
    });

    testWidgets('no name and no space reserved for one', (tester) async {
      await pumpDrawer(tester, signedIn: false);
      expect(find.text('probahini'), findsNothing);
    });
  });

  group('the header is compact', () {
    testWidgets('it is not much taller than the picture it holds',
        (tester) async {
      // The old UserAccountsDrawerHeader was a fixed 160pt plus the status bar
      // for a 72pt picture. This asserts the gap that complaint was about
      // cannot silently return.
      for (final signedIn in [true, false]) {
        await pumpDrawer(tester, signedIn: signedIn);
        final header = headerRect(tester);
        final picture = tester.getRect(find.byType(SizedBox).evaluate()
            .map((e) => e.widget)
            .whereType<SizedBox>()
            .where((s) => s.height == 64.0 && s.width == 64.0)
            .map((s) => find.byWidget(s))
            .first);

        expect(header.height, lessThan(picture.height + 56),
            reason: 'signedIn=$signedIn: header ${header.height} around a '
                '${picture.height} picture is mostly empty space');
      }
    });
  });

  group('the two states line up', () {
    testWidgets('the picture is the same size and place either way',
        (tester) async {
      // Measured on the slot rather than the Image: assets are not bundled in
      // a widget test, so every Image collapses to zero size here.
      Rect slot(WidgetTester t) => t.getRect(find
          .byType(SizedBox)
          .evaluate()
          .map((e) => e.widget)
          .whereType<SizedBox>()
          .where((s) => s.height == 64.0 && s.width == 64.0)
          .map((s) => find.byWidget(s))
          .first);

      await pumpDrawer(tester, signedIn: true);
      final avatar = slot(tester);

      await pumpDrawer(tester, signedIn: false);
      expect(slot(tester), avatar,
          reason: 'the logo must take the avatar\'s exact size and position');
    });

    testWidgets('the first menu row is at the same height either way',
        (tester) async {
      await pumpDrawer(tester, signedIn: true);
      final signedIn = tester.getRect(find.byIcon(Icons.home)).top;

      await pumpDrawer(tester, signedIn: false);
      expect(tester.getRect(find.byIcon(Icons.home)).top, closeTo(signedIn, 0.5),
          reason: 'the menu must not jump when someone signs in or out');
    });
  });

  group('signed in', () {
    testWidgets('the name sits beside the picture, not under it',
        (tester) async {
      await pumpDrawer(tester, signedIn: true);

      final picture = tester.getRect(find
          .byType(SizedBox)
          .evaluate()
          .map((e) => e.widget)
          .whereType<SizedBox>()
          .where((s) => s.height == 64.0 && s.width == 64.0)
          .map((s) => find.byWidget(s))
          .first);
      final name = tester.getRect(find.text('probahini'));

      expect(name.left, greaterThan(picture.right),
          reason: 'the name belongs to the right of the picture');
      expect(name.center.dy, closeTo(picture.center.dy, 2.0),
          reason: 'and on the same centreline as it');
    });
  });
}
