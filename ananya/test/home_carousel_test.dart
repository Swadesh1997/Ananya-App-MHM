import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The carousel exists once.
///
/// landing.dart and user_home.dart each held a full copy — the same PageView,
/// timer, arrows and item builder, differing only in which slides they listed.
/// The copies then drifted: the dots, the pause-on-touch, the softened arrows
/// and the uncropped artwork were all added to one and none of it reached the
/// other, so a signed-in user and a signed-out user saw different carousels
/// with the same pictures in them.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final landing = read('lib/screens/landing/landing.dart');
  final userHome = read('lib/screens/landing/user_home.dart');
  final carousel = read('lib/widgets/home_carousel.dart');

  group('neither screen builds its own', () {
    test('no PageView outside the shared widget', () {
      expect(landing.contains('PageView('), isFalse,
          reason: 'landing.dart is building a carousel again');
      expect(userHome.contains('PageView('), isFalse,
          reason: 'user_home.dart is building a carousel again');
    });

    test('no carousel timer or controller left behind', () {
      for (final src in {'landing': landing, 'user_home': userHome}.entries) {
        expect(src.value.contains('_carouselTimer'), isFalse,
            reason: '${src.key} still owns a carousel timer');
        expect(src.value.contains('PageController()'), isFalse,
            reason: '${src.key} still owns a page controller');
      }
    });

    test('both use HomeCarousel', () {
      expect(landing, contains('HomeCarousel('));
      expect(userHome, contains('HomeCarousel('));
    });
  });

  group('the slides differ on purpose', () {
    test('signed-out leads with "set your calendar"', () {
      expect(landing, contains('setyourcalendar.png'));
    });

    test('signed-in does not — she already has one', () {
      expect(userHome.contains('setyourcalendar.png'), isFalse,
          reason: 'telling her to set a calendar she already set');
    });

    test('both carry the map, numbers and FAQ slides', () {
      for (final src in [landing, userHome]) {
        expect(src, contains('viewmap.png'));
        expect(src, contains('number.png'));
        expect(src, contains('insidecalendar2.png'));
      }
    });
  });

  group('what every screen now gets', () {
    test('a page indicator', () {
      expect(carousel, contains('Widget _dots()'));
    });

    test('touching it stops the slideshow', () {
      expect(carousel, contains('onPointerDown'));
      expect(carousel, contains('_pause()'));
    });

    test('artwork is contained, never cropped', () {
      expect(carousel, contains('BoxFit.contain'));
      expect(carousel.contains('BoxFit.cover'), isFalse);
    });

    test('the transition only ever scales down', () {
      // Scaling above 1 would push the drawing past the card edge, which is
      // the crop the contain above exists to avoid.
      expect(carousel, contains('scale: 0.93 + 0.07 * nearness'));
    });

    test('it respects the system reduce-motion setting', () {
      expect(carousel, contains('disableAnimations'));
    });

    test('a single slide gets no arrows, dots or timer', () {
      // Three affordances for a carousel that cannot move would all be lies.
      expect(carousel, contains('if (_count < 2) return;'));
      expect(carousel, contains('if (_count > 1)'));
    });
  });
}
