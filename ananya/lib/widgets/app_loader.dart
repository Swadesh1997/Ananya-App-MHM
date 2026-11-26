import 'package:flutter/material.dart';

import 'package:ananya/utils/constants.dart';

/// The app's loading indicator, in one place.
///
/// Every screen used to size this for itself, and the sizes did not agree:
/// `height: 400` in six places, `width: 400` with `BoxFit.fill` in another,
/// `height: 200` in signup, and four screens with a bare
/// CircularProgressIndicator instead. So the same wait looked different
/// depending on where you hit it.
///
/// It was also enormous. loading.gif is 150x150; drawn at 400 logical pixels
/// it was upscaled nearly three times, which on a phone fills most of the
/// screen and looks soft. Small and centred reads as the app working. Huge and
/// blurry reads as the app broken.
class AppLoader extends StatelessWidget {
  /// Optional line beneath the animation, for waits long enough to need
  /// explaining. Left off for ordinary ones — a caption on a half-second
  /// flash is just flicker.
  final String? message;

  /// 80 is deliberately below the source's 150px, so it stays crisp on a
  /// high-density screen instead of being stretched.
  final double size;

  const AppLoader({this.message, this.size = 80, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/gif/loading.gif',
            width: size,
            height: size,
            fit: BoxFit.contain,
            // Decoded at the file's own resolution. An animated GIF re-decodes
            // every frame for as long as it is on screen, so there is no point
            // holding it at more than it actually contains.
            cacheWidth: 150,
          ),
          if (message != null) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: ACCENT.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
