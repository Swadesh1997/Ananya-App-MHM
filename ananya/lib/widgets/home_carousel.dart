import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ananya/utils/constants.dart';

/// One panel of the home carousel.
class CarouselSlide {
  final String image;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  const CarouselSlide({
    required this.image,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });
}

/// The rotating panel at the top of both home screens.
///
/// It exists as one widget because it used to exist as two. landing.dart and
/// user_home.dart each held their own copy — the same PageView, timer, arrows
/// and item builder, differing only in which slides they listed. The copies
/// then drifted: improvements made to one were invisible to the other, so a
/// signed-in user and a signed-out user were looking at different carousels
/// with the same pictures in them.
///
/// The slides still differ, and should: the signed-out screen leads with "set
/// your calendar", which is meaningless to someone who already has. That is
/// what the [slides] argument is for. Everything else — the timing, the
/// motion, the indicator — belongs to the carousel and not to the screen
/// showing it.
class HomeCarousel extends StatefulWidget {
  final List<CarouselSlide> slides;

  const HomeCarousel({required this.slides, super.key});

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  /// Long enough to read a two-line Bangla caption without hurrying. The five
  /// seconds this ran at previously turned the page mid-sentence.
  static const Duration _interval = Duration(seconds: 7);

  int get _count => widget.slides.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    if (_count < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_pageController.hasClients) return;

      // Someone who has asked the system to reduce motion should not have a
      // carousel turning itself. The arrows and swipe still work.
      if (MediaQuery.of(context).disableAnimations) return;

      _goTo((_currentPage + 1) % _count);
    });
  }

  void _pause() => _timer?.cancel();

  void _goTo(int page) {
    _currentPage = page;
    _pageController.animateToPage(
      page,
      // Slower and softer than the 500ms easeInOut this had. A page turning by
      // itself should drift; at that speed it snapped, which read as the
      // screen jumping rather than advancing.
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 376,
          // Touching the carousel stops it turning. Without this the page
          // could change between her reaching for a button and her thumb
          // landing, so she would tap "View numbers" and arrive at the FAQ —
          // and learn that the app moves under her.
          child: Listener(
            onPointerDown: (_) => _pause(),
            onPointerUp: (_) => _start(),
            onPointerCancel: (_) => _start(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView(
                  controller: _pageController,
                  // No setState: rebuilding the whole home screen on every
                  // auto-advance made the app hitch every few seconds. The
                  // dots listen to the controller directly instead, so they
                  // stay in step without this screen rebuilding at all.
                  onPageChanged: (index) => _currentPage = index,
                  children: [
                    for (var i = 0; i < _count; i++) _item(i, widget.slides[i]),
                  ],
                ),
                if (_count > 1) ...[
                  _arrow(isBack: true),
                  _arrow(isBack: false),
                ],
              ],
            ),
          ),
        ),
        if (_count > 1) ...[
          const SizedBox(height: 14),
          _dots(),
        ],
      ],
    );
  }

  /// A step arrow, sitting clear of the artwork.
  ///
  /// These used to be bare black chevrons laid over the illustration, which
  /// read as debug controls and competed with the picture. Swiping is not an
  /// obvious gesture to someone new to a smartphone, so they are worth
  /// keeping — just not on top of the thing they are meant to help you look
  /// at.
  Widget _arrow({required bool isBack}) {
    return Positioned(
      // Clear of the screen edge. Flush against it they looked like something
      // the layout had pushed off the side.
      left: isBack ? 10 : null,
      right: isBack ? null : 10,
      child: Material(
        color: BACKGROUND.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            _pause();
            // Wraps, so the arrows can reach every slide from anywhere rather
            // than dead-ending at the first and last.
            _goTo(((isBack ? _currentPage - 1 : _currentPage + 1) + _count) %
                _count);
            _start();
          },
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              isBack ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 22,
              color: ACCENT.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  /// Which slide she is on, and that there are others.
  ///
  /// There was no indicator at all, so nothing on screen said the carousel
  /// held more than the one picture in front of her.
  ///
  /// Driven straight off the controller so it tracks the swipe itself rather
  /// than snapping when the page settles — and so this screen never rebuilds
  /// to keep it current.
  Widget _dots() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        final page = _pageController.hasClients &&
                _pageController.position.haveDimensions
            ? (_pageController.page ?? _currentPage.toDouble())
            : _currentPage.toDouble();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _count; i++)
              GestureDetector(
                onTap: () {
                  _pause();
                  _goTo(i);
                  _start();
                },
                child: Padding(
                  // Padding rather than margin: it enlarges the tap target to
                  // something a thumb can hit, while the dot stays small.
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: _dot(
                    closeness: (1 - (page - i).abs()).clamp(0.0, 1.0),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// [closeness] is 1 on the current slide and 0 on any slide a full page
  /// away, so the active dot grows and colours as the page moves rather than
  /// after it lands.
  Widget _dot({required double closeness}) {
    return Container(
      width: 7 + 13 * closeness,
      height: 7,
      decoration: BoxDecoration(
        color: Color.lerp(
          ACCENT.withValues(alpha: 0.20),
          PRIMARY_COLOR,
          closeness,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _item(int index, CarouselSlide slide) {
    return _transition(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // contain, not cover. Three of the four illustrations are within a
            // few percent of the card's own aspect ratio, so cover had almost
            // nothing to crop horizontally and took it off the top and bottom
            // instead — cutting the girl's head and the handset. Their
            // transparent backgrounds mean the letterboxing is invisible: the
            // page's cream shows through where the picture does not reach.
            SizedBox(
              height: 250,
              width: double.infinity,
              child: Image.asset(slide.image, fit: BoxFit.contain),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: slide.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: PRIMARY_COLOR,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              child: Text(slide.buttonText),
            ),
            const SizedBox(height: 10),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: ACCENT.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Depth as the page turns: the slide arriving grows the last few percent
  /// into place while the one leaving shrinks and dims.
  ///
  /// A sliding parallax was tried first and removed: it needs empty margin
  /// inside the artwork to move into, and setyourcalendar.png has none — its
  /// drawing runs to the very edge on three sides, so any shift sliced it.
  /// Scaling cannot crop anything.
  Widget _transition({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, inner) {
        var delta = 0.0;
        if (_pageController.hasClients &&
            _pageController.position.haveDimensions) {
          delta = ((_pageController.page ?? 0) - index).clamp(-1.0, 1.0);
        }
        // Eased rather than linear. Straight off the page offset the scale
        // changed at a constant rate and stopped dead when the page landed,
        // which is what made the movement feel mechanical.
        final nearness = Curves.easeOutCubic.transform(1 - delta.abs());

        return Transform.scale(
          // Never above 1: scaling up would push the drawing past the card's
          // edges, which is the crop this exists to avoid.
          scale: 0.93 + 0.07 * nearness,
          child: inner,
        );
      },
      // RepaintBoundary so the illustration is composited rather than
      // repainted on every frame of the swipe.
      child: RepaintBoundary(child: child),
    );
  }
}
