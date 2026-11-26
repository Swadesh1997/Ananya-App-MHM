import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one way "delete my data" can fail silently.
///
/// Deleting a Firestore document does NOT delete its subcollections, and the
/// client SDK has no recursive delete — so AccountDeletionService names the
/// subcollections it removes explicitly. If someone later stores something new
/// under users/{uid} and does not add it to that list, deletion will report
/// success while leaving her records on the server under an invisible parent.
///
/// Nothing at runtime would notice: no error, no warning, and the account is
/// gone so nobody can look. This test is the only thing that would.
void main() {
  test('every subcollection the app writes is one the deletion removes', () {
    final written = <String>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('account_deletion_service.dart')) continue;

      final source = entity.readAsStringSync();

      // Matches .collection('users').doc(...).collection('<name>') across the
      // line breaks the formatter introduces.
      final pattern = RegExp(
        r"collection\(\s*'users'\s*\)[\s\S]{0,200}?"
        r"\.collection\(\s*'([a-zA-Z_]+)'\s*\)",
      );
      for (final m in pattern.allMatches(source)) {
        written.add(m.group(1)!);
      }
    }

    final service =
        File('lib/services/account_deletion_service.dart').readAsStringSync();
    final declared = RegExp(r"_subcollections\s*=\s*\[([^\]]*)\]")
        .firstMatch(service)
        ?.group(1);

    expect(declared, isNotNull,
        reason: 'could not find the _subcollections list to check against');

    final removed = RegExp(r"'([a-zA-Z_]+)'")
        .allMatches(declared!)
        .map((m) => m.group(1)!)
        .toSet();

    expect(written, isNotEmpty,
        reason: 'the scan found no subcollections at all, so it is not '
            'actually checking anything');

    final missed = written.difference(removed).toList()..sort();
    expect(
      missed,
      isEmpty,
      reason: 'These subcollections are written under users/{uid} but would '
          'survive account deletion:\n'
          '${missed.map((s) => '  users/{uid}/$s').join('\n')}\n'
          'Add them to _subcollections in account_deletion_service.dart.',
    );
  });

  test('the deletion removes Firestore data before the account', () {
    // Ordering is a correctness requirement, not a style choice: the security
    // rules only let a signed-in user touch her own documents, so deleting the
    // credential first would leave her data stranded on the server with no
    // account able to reach it.
    final source =
        File('lib/services/account_deletion_service.dart').readAsStringSync();

    final firestoreStep = source.indexOf('_deleteFirestoreData(uid)');
    final authStep = source.indexOf('currentUser?.delete()');

    expect(firestoreStep, greaterThan(-1));
    expect(authStep, greaterThan(-1));
    expect(firestoreStep, lessThan(authStep),
        reason: 'Firestore data must be deleted while the account can still '
            'authenticate');
  });
}
