import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's own on-device copy of everything the period tracker needs.
///
/// Ananya is used where a connection appears occasionally rather than
/// continuously, so nothing in the tracking flow may depend on reaching a
/// server. Firestore does keep an offline cache and does replay queued writes
/// when the network returns, but that cache is opaque to us, can be cold on a
/// fresh install, and gives no way to render a screen synchronously. This store
/// is written on every change and is what the UI reads first; Firestore is then
/// treated as the thing that carries the data to other devices, not as the
/// thing the user waits for.
class LocalPeriodStore {
  static const _settingsKey = 'local_period_settings';
  static const _historyKey = 'local_period_history';
  static const _uidKey = 'local_period_uid';
  static const _pendingKey = 'local_period_pending';
  static const _seededKey = 'local_period_seeded';

  /// Values Firestore understands but JSON does not — chiefly
  /// FieldValue.serverTimestamp(), which is a sentinel, not data.
  static Map<String, dynamic> _encodable(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((k, v) {
      if (v == null || v is String || v is num || v is bool) {
        out[k] = v;
      } else if (v is Map) {
        out[k] = v.map((mk, mv) => MapEntry('$mk', mv));
      } else if (v is List) {
        out[k] = v;
      }
      // Anything else (FieldValue, Timestamp, DocumentReference) is dropped:
      // it has no meaning outside Firestore.
    });
    return out;
  }

  /// Settings are per-account. A second user signing in on a shared handset
  /// must not inherit the first one's cycle, so switching uid clears the store.
  static Future<void> _claimFor(SharedPreferences prefs, String uid) async {
    final stored = prefs.getString(_uidKey);
    if (stored != null && stored != uid) {
      await prefs.remove(_settingsKey);
      await prefs.remove(_historyKey);
      await prefs.remove(_pendingKey);
      await prefs.remove(_seededKey);
      debugPrint('LocalPeriodStore: cleared store for new user');
    }
    await prefs.setString(_uidKey, uid);
  }

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------- settings

  /// Merges [data] over whatever is already stored, mirroring the merge
  /// semantics of the Firestore document it shadows.
  static Future<void> saveSettings(String uid, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _claimFor(prefs, uid);
      final existing = _decodeMap(prefs.getString(_settingsKey)) ?? {};
      final merged = <String, dynamic>{...existing, ..._encodable(data)};
      await prefs.setString(_settingsKey, jsonEncode(merged));
    } catch (e) {
      debugPrint('LocalPeriodStore: saveSettings failed: $e');
    }
  }

  /// Replaces the cached settings with the authoritative server document.
  ///
  /// [saveSettings] merges, which is right for the logging flow: that writes
  /// three fields and must not erase the rest. It is wrong for caching the
  /// server's answer. A field the server no longer holds survived in the
  /// device copy indefinitely, and the next load that could not reach
  /// Firestore would read it back and predict from it — a value the account
  /// had already discarded, resurfacing only on one handset.
  ///
  /// This is not a conflict-resolution policy. The server document is simply
  /// copied as it stands, which is what "cache" means.
  static Future<void> replaceSettings(
      String uid, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _claimFor(prefs, uid);
      await prefs.setString(_settingsKey, jsonEncode(_encodable(data)));
    } catch (e) {
      debugPrint('LocalPeriodStore: replaceSettings failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> readSettings(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_uidKey) != uid) return null;
      return _decodeMap(prefs.getString(_settingsKey));
    } catch (e) {
      debugPrint('LocalPeriodStore: readSettings failed: $e');
      return null;
    }
  }

  // --------------------------------------------------------------- history

  /// Stored as {'yyyy-MM-dd': bleedDays}, so logging the same date twice is
  /// idempotent exactly as it is in Firestore, where the date is the doc id.
  static Future<void> recordPeriod(
      String uid, String isoDate, int bleedDays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _claimFor(prefs, uid);
      final map = _decodeMap(prefs.getString(_historyKey)) ?? {};
      map[isoDate] = bleedDays;
      await prefs.setString(_historyKey, jsonEncode(map));
    } catch (e) {
      debugPrint('LocalPeriodStore: recordPeriod failed: $e');
    }
  }

  /// Removes one logged period. Safe to call for a date that is not stored.
  static Future<void> deletePeriod(String uid, String isoDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _claimFor(prefs, uid);
      final map = _decodeMap(prefs.getString(_historyKey)) ?? {};
      if (!map.containsKey(isoDate)) return;
      map.remove(isoDate);
      await prefs.setString(_historyKey, jsonEncode(map));
    } catch (e) {
      debugPrint('LocalPeriodStore: deletePeriod failed: $e');
    }
  }

  /// Whether the one-off bootstrap from period/latest has already happened.
  ///
  /// Without this flag a deletion could undo itself: seeding fires whenever the
  /// history is empty, so removing a lone logged period would simply see it
  /// written back on the next home-screen load.
  static Future<bool> hasSeeded(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_uidKey) != uid) return false;
      return prefs.getBool(_seededKey) ?? false;
    } catch (e) {
      debugPrint('LocalPeriodStore: hasSeeded failed: $e');
      return false;
    }
  }

  static Future<void> markSeeded(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _claimFor(prefs, uid);
      await prefs.setBool(_seededKey, true);
    } catch (e) {
      debugPrint('LocalPeriodStore: markSeeded failed: $e');
    }
  }

  /// Every locally known period, as {'yyyy-MM-dd': bleedDays}.
  static Future<Map<String, int>> readHistory(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_uidKey) != uid) return {};
      final map = _decodeMap(prefs.getString(_historyKey)) ?? {};
      final out = <String, int>{};
      map.forEach((k, v) {
        if (v is int) {
          out[k] = v;
        } else if (v is num) {
          out[k] = v.round();
        }
      });
      return out;
    } catch (e) {
      debugPrint('LocalPeriodStore: readHistory failed: $e');
      return {};
    }
  }

  /// Adds anything the server knows that this device does not. Used after a
  /// successful fetch so a period logged on another handset lands here too.
  static Future<void> mergeHistory(String uid, Map<String, int> remote) async {
    if (remote.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _claimFor(prefs, uid);
      final map = _decodeMap(prefs.getString(_historyKey)) ?? {};
      var changed = false;
      remote.forEach((k, v) {
        if (map[k] != v) {
          map[k] = v;
          changed = true;
        }
      });
      if (changed) await prefs.setString(_historyKey, jsonEncode(map));
    } catch (e) {
      debugPrint('LocalPeriodStore: mergeHistory failed: $e');
    }
  }

  // ---------------------------------------------------------- sync marker

  /// Whether at least one write has not yet been acknowledged by the server.
  /// Purely for telling the user; Firestore replays the queue on its own.
  static Future<void> setPending(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, value);
    } catch (_) {
      // Not worth failing a save over.
    }
  }

  static Future<bool> hasPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pendingKey) ?? false;
    } catch (_) {
      return false;
    }
  }
}
