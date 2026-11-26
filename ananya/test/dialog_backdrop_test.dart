import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every dialog must go through showAppDialog, so they all share one backdrop.
///
/// Flutter's showDialog leaves the page behind sharp under a flat grey wash —
/// on the health-conditions step the whole checklist stayed readable beneath
/// the question, so the screen read as two things at once. showAppDialog blurs
/// and tints instead.
///
/// A bare showDialog added later would look almost right in isolation and only
/// be noticeable next to the others, which is exactly the kind of drift nobody
/// catches by eye.
void main() {
  test('no screen calls showDialog directly', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The helper is the one place allowed to open a raw dialog route.
      if (entity.path.endsWith('app_dialog.dart')) continue;

      final rel = entity.path.replaceAll(r'\', '/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Word boundary keeps showAppDialog and showGeneralDialog out of it.
        if (RegExp(r'(?<![A-Za-z_])showDialog\s*(<[^>]*>)?\s*\(')
            .hasMatch(lines[i])) {
          offenders.add('  $rel:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These open a dialog without the shared backdrop. Use '
          'showAppDialog from lib/utils/app_dialog.dart instead:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the shared backdrop actually blurs and dims', () {
    final helper = File('lib/utils/app_dialog.dart').readAsStringSync();

    expect(helper.contains('BackdropFilter'), isTrue,
        reason: 'the scrim must blur what is behind it');
    expect(helper.contains('ImageFilter.blur'), isTrue);
    expect(helper.contains('IgnorePointer'), isTrue,
        reason: 'the scrim must let taps reach the barrier beneath, or '
            'tapping outside the dialog stops dismissing it');
  });
}
