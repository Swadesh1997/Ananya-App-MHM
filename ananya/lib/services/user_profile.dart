import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Her name, wherever the app needs to say it.
///
/// Signup asks for a name and writes it to Firestore at `users/{uid}.name`,
/// but sign-in read Firebase Auth's `displayName` instead — a field signup
/// never sets. It was therefore always null, `userName` was saved as an empty
/// string, and the sidebar rendered a blank where the name should be. The name
/// was collected and stored correctly all along; nothing ever read it.
class UserProfile {
  static const _key = 'userName';

  /// Cached copy, read synchronously by callers that already have prefs open.
  static Future<String?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      return (name == null || name.trim().isEmpty) ? null : name.trim();
    } catch (e) {
      debugPrint('UserProfile: cache read failed: $e');
      return null;
    }
  }

  /// Her name, fetching it from Firestore once if this device has not stored
  /// it yet.
  ///
  /// The backfill matters as much as the login path: someone already signed in
  /// never passes through sign-in again, so without this their name would stay
  /// blank forever.
  ///
  /// Returns null rather than a placeholder when there is genuinely no name —
  /// every caller is expected to drop the greeting instead of showing
  /// "Hello, ".
  static Future<String?> resolve() async {
    final local = await cached();
    if (local != null) return local;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final name = doc.data()?['name'];
      if (name is! String || name.trim().isEmpty) return null;

      await save(name.trim());
      return name.trim();
    } catch (e) {
      // Offline, or the read timed out. Firestore serves this from its own
      // cache when it can, so this is only reached on a genuinely cold device.
      debugPrint('UserProfile: name lookup unavailable: $e');
      return null;
    }
  }

  static Future<void> save(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, name.trim());
    } catch (e) {
      debugPrint('UserProfile: save failed: $e');
    }
  }

  /// Just the part to greet her by.
  ///
  /// "Rumana Akter Bithi" in a greeting line pushes everything else off the
  /// row and reads like a form field being echoed back at her. The full name
  /// is still shown in the sidebar, where there is room for it.
  static String firstNameOf(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? full.trim() : parts.first;
  }
}
