import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Build configuration that only bites in a release build.
///
/// Everything here is about the shipped artefact rather than the app's
/// behaviour, so there is nothing to pump — the facts live in Gradle files and
/// the manifest, and the release build is the only place they are exercised.
/// Each of these has already gone wrong once.
void main() {
  final gradle = File('android/app/build.gradle').readAsStringSync();
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  group('R8 keep rules exist', () {
    test('the file build.gradle names is actually present', () {
      // It was named in proguardFiles from the first commit and never created,
      // so every release bundle was minified with no app rules at all.
      expect(gradle, contains("'proguard-rules.pro'"),
          reason: 'build.gradle should still name the rules file');
      expect(File('android/app/proguard-rules.pro').existsSync(), isTrue,
          reason: 'minifyEnabled is on — R8 needs this file');
    });

    test('the notification plugin is kept', () {
      // Period reminders are the feature that fails quietly: R8 renames the
      // Gson-serialised model classes the boot receiver reads back, so every
      // stored reminder deserialises to nulls and simply never fires. Nothing
      // crashes, so it survives any amount of debug-build testing.
      final rules = File('android/app/proguard-rules.pro').readAsStringSync();
      expect(rules, contains('com.dexterous'));
      expect(rules, contains('-keepattributes Signature'),
          reason: 'Gson needs generic signatures to survive minification');
    });
  });

  group('the manifest asks for nothing it does not use', () {
    test('no USE_FULL_SCREEN_INTENT', () {
      // Declared once with no code path behind it. Play restricts it to calling
      // and alarm apps and requires a declaration on Android 14+, so it was a
      // review risk bought for nothing.
      expect(manifest.contains('USE_FULL_SCREEN_INTENT'), isFalse);
    });

    test('no external storage permissions', () {
      // Their only consumer was lib/screens/knowledge_nexus.dart, which was
      // imported nowhere. Broad storage access on a menstrual health app is
      // the kind of permission a girl reads and a reviewer asks about.
      expect(manifest.contains('READ_EXTERNAL_STORAGE'), isFalse);
      expect(manifest.contains('WRITE_EXTERNAL_STORAGE'), isFalse);
      expect(manifest.contains('MANAGE_EXTERNAL_STORAGE'), isFalse);
    });

    test('the permissions the app does rely on are still declared', () {
      // The counterpart to the two tests above: a permission sweep that only
      // ever removes things eventually removes a needed one.
      for (final p in [
        'INTERNET',
        'POST_NOTIFICATIONS',
        'RECEIVE_BOOT_COMPLETED',
        'SCHEDULE_EXACT_ALARM',
        'VIBRATE',
      ]) {
        expect(manifest, contains(p), reason: '$p is used by the app');
      }
    });
  });

  test('the version was bumped past the last release', () {
    // 4.2.0+34 is on Play. Play refuses a duplicate versionCode, and the
    // rejection arrives after the upload, not before the build.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', multiLine: true)
            .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec must carry a version+build');
    expect(int.parse(match!.group(4)!), greaterThan(34),
        reason: 'versionCode 34 is already published');
  });
}
