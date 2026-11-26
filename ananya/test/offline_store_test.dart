import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/services/local_period_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('settings survive with no network', () {
    test('written settings read back identically', () async {
      await LocalPeriodStore.saveSettings('u1', {
        'is_period_regular': true,
        'days_between_period': 29,
        'length_of_period': 5,
        'last_period_start': '2026-08-14',
        'health_condition': {'Polycystic Ovary Syndrome': true},
      });

      final read = await LocalPeriodStore.readSettings('u1');
      expect(read, isNotNull);
      expect(read!['days_between_period'], 29);
      expect(read['last_period_start'], '2026-08-14');
      expect(read['health_condition']['Polycystic Ovary Syndrome'], true);
    });

    test('a second save merges rather than replaces', () async {
      await LocalPeriodStore.saveSettings('u1', {
        'days_between_period': 29,
        'length_of_period': 5,
        'take_birth_control': false,
      });
      // The short "log new period" flow writes only these two fields.
      await LocalPeriodStore.saveSettings('u1', {
        'last_period_start': '2026-09-12',
        'health_condition': {'Endometriosis': true},
      });

      final read = await LocalPeriodStore.readSettings('u1');
      expect(read!['last_period_start'], '2026-09-12');
      expect(read['days_between_period'], 29,
          reason: 'setup answers must not be wiped by the short flow');
      expect(read['take_birth_control'], false);
    });

    test('Firestore sentinels are dropped, not crashed on', () async {
      // FieldValue.serverTimestamp() has no JSON form; it must be skipped
      // silently rather than breaking the whole save.
      await LocalPeriodStore.saveSettings('u1', {
        'days_between_period': 28,
        'updated_at': Object(),
      });
      final read = await LocalPeriodStore.readSettings('u1');
      expect(read!['days_between_period'], 28);
      expect(read.containsKey('updated_at'), isFalse);
    });

    test('another account on the same handset starts clean', () async {
      await LocalPeriodStore.saveSettings('u1', {'days_between_period': 29});
      await LocalPeriodStore.recordPeriod('u1', '2026-08-14', 5);

      // u1's cycle must not leak into u2's app.
      expect(await LocalPeriodStore.readSettings('u2'), isNull);
      await LocalPeriodStore.saveSettings('u2', {'days_between_period': 26});
      expect(await LocalPeriodStore.readHistory('u2'), isEmpty);
      expect((await LocalPeriodStore.readSettings('u2'))!['days_between_period'],
          26);
    });
  });

  group('history accumulates offline', () {
    test('several periods logged with no connection are all kept', () async {
      await LocalPeriodStore.recordPeriod('u1', '2026-06-17', 5);
      await LocalPeriodStore.recordPeriod('u1', '2026-07-16', 4);
      await LocalPeriodStore.recordPeriod('u1', '2026-08-14', 5);

      final h = await LocalPeriodStore.readHistory('u1');
      expect(h.length, 3);
      expect(h['2026-07-16'], 4);
    });

    test('logging the same date twice is idempotent', () async {
      await LocalPeriodStore.recordPeriod('u1', '2026-08-14', 5);
      await LocalPeriodStore.recordPeriod('u1', '2026-08-14', 6);

      final h = await LocalPeriodStore.readHistory('u1');
      expect(h.length, 1, reason: 'the date is the identity, as in Firestore');
      expect(h['2026-08-14'], 6, reason: 'the later value wins');
    });

    test('a sync brings in remote periods without dropping local ones', () async {
      // Logged on this phone while offline.
      await LocalPeriodStore.recordPeriod('u1', '2026-08-14', 5);
      // Arrives from the server, logged on another handset.
      await LocalPeriodStore.mergeHistory('u1', {
        '2026-07-16': 4,
        '2026-06-17': 5,
      });

      final h = await LocalPeriodStore.readHistory('u1');
      expect(h.length, 3);
      expect(h['2026-08-14'], 5, reason: 'the offline entry must survive');
      expect(h['2026-07-16'], 4);
    });

    test('an empty server response never empties the device', () async {
      await LocalPeriodStore.recordPeriod('u1', '2026-08-14', 5);
      await LocalPeriodStore.mergeHistory('u1', {});
      expect((await LocalPeriodStore.readHistory('u1')).length, 1);
    });
  });

  group('sync marker', () {
    test('defaults to nothing pending', () async {
      expect(await LocalPeriodStore.hasPending(), isFalse);
    });

    test('set and cleared', () async {
      await LocalPeriodStore.setPending(true);
      expect(await LocalPeriodStore.hasPending(), isTrue);
      await LocalPeriodStore.setPending(false);
      expect(await LocalPeriodStore.hasPending(), isFalse);
    });
  });

  group('corrupt storage degrades safely', () {
    test('unparseable settings read as null, not a crash', () async {
      SharedPreferences.setMockInitialValues({
        'local_period_uid': 'u1',
        'local_period_settings': 'not json{{',
        'local_period_history': 'also not json',
      });
      expect(await LocalPeriodStore.readSettings('u1'), isNull);
      expect(await LocalPeriodStore.readHistory('u1'), isEmpty);
    });
  });
}
