import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ananya/utils/constants.dart';

/// Every dialog in the app, over one backdrop.
///
/// Flutter's own `showDialog` dims with a flat 54% black and leaves the page
/// behind perfectly sharp. On the health-conditions step that meant a full
/// checklist stayed legible under the box, competing with the question in
/// front of it — the screen read as two things at once.
///
/// This blurs and tints the page instead, which is what current Material and
/// iOS dialogs do: what is behind is clearly still there, but no longer
/// readable, so the only thing to attend to is the question being asked.
///
/// Same signature as `showDialog`, so call sites only change name.
///
/// Note this cannot affect ANDROID's own dialogs — the notification-permission
/// prompt is drawn by the system, outside the app's control.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Transparent here because the scrim is painted in the transition below,
    // where it can be blurred and faded in with the dialog.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (ctx, animation, _, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return Stack(
        children: [
          Positioned.fill(
            // IgnorePointer so taps fall through to the modal barrier
            // underneath, which is what actually dismisses the dialog. Without
            // it this layer would swallow them and tapping outside would do
            // nothing.
            child: IgnorePointer(
              child: FadeTransition(
                opacity: curve,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  // Tinted with the brand ink rather than plain black, so the
                  // scrim belongs to the app instead of greying it out.
                  child: Container(color: ACCENT.withValues(alpha: 0.34)),
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              // Rises very slightly into place. Enough to read as "this came
              // forward", not enough to feel like an effect.
              scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
              child: child,
            ),
          ),
        ],
      );
    },
  );
}
