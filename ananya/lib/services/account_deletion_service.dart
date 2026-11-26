import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ananya/services/period_reminder_service.dart';

/// How a deletion attempt ended.
///
/// Returned rather than thrown so every outcome has to be handled explicitly:
/// a screen that erases someone's health records must never fail quietly.
enum DeletionOutcome {
  success,
  notSignedIn,
  wrongPassword,
  noConnection,
  tooManyAttempts,
  failed,
}

/// Permanently removes an account and everything stored under it.
///
/// The app had no working way to do this. The one feature built for it —
/// "Request Data Purge" on a screen nothing ever linked to — deleted rows from
/// the Django database, which is not where a Firebase user's data lives. She
/// would have been shown a success message while every period stayed in
/// Firestore.
class AccountDeletionService {
  /// Subcollections under users/{uid}. `periods` holds one document per logged
  /// period; `period` holds the single `latest` settings document.
  static const _subcollections = ['periods', 'period'];

  /// Batches are capped at 500 operations by Firestore; 400 leaves headroom.
  static const _pageSize = 400;

  /// Every step here is a network call. Firestore write Futures complete only
  /// on server acknowledgement, so with no connection they never return at all
  /// — the same trap that once made logging a period appear to require
  /// internet. A ceiling turns that into an honest "no connection".
  static const _netTimeout = Duration(seconds: 20);

  static Future<DeletionOutcome> deleteEverything({
    required String password,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return DeletionOutcome.notSignedIn;

    // 1. Prove it is her. Deleting health data is irreversible, and a phone
    //    left unlocked for a moment should not be enough to do it.
    final reauth = await _reauthenticate(user, password);
    if (reauth != DeletionOutcome.success) return reauth;

    final uid = user.uid;

    // 2. Firestore BEFORE the account. The security rules only allow a user to
    //    touch their own documents, so deleting the credential first would
    //    lock us out of her data and leave it orphaned on the server forever.
    try {
      await _deleteFirestoreData(uid);
    } on TimeoutException {
      return DeletionOutcome.noConnection;
    } catch (e) {
      debugPrint('AccountDeletion: Firestore delete failed: $e');
      return DeletionOutcome.failed;
    }

    // 3. The credential itself.
    try {
      await FirebaseAuth.instance.currentUser?.delete().timeout(_netTimeout);
    } on TimeoutException {
      // Her data is already gone; only the empty login remains. Say so rather
      // than reporting success.
      return DeletionOutcome.noConnection;
    } on FirebaseAuthException catch (e) {
      debugPrint('AccountDeletion: auth delete failed: ${e.code}');
      return e.code == 'network-request-failed'
          ? DeletionOutcome.noConnection
          : DeletionOutcome.failed;
    }

    // 4. Nothing may be left on the handset, including the offline mirror.
    await _wipeDevice();
    return DeletionOutcome.success;
  }

  static Future<DeletionOutcome> _reauthenticate(
      User user, String password) async {
    try {
      await user
          .reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: user.email!,
              password: password,
            ),
          )
          .timeout(_netTimeout);
      return DeletionOutcome.success;
    } on TimeoutException {
      return DeletionOutcome.noConnection;
    } on FirebaseAuthException catch (e) {
      debugPrint('AccountDeletion: reauth refused: ${e.code}');
      switch (e.code) {
        // Recent Firebase versions report a wrong password as the generic
        // invalid-credential, older ones as wrong-password. Both mean the same
        // thing to the person typing.
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-mismatch':
          return DeletionOutcome.wrongPassword;
        case 'network-request-failed':
          return DeletionOutcome.noConnection;
        case 'too-many-requests':
          return DeletionOutcome.tooManyAttempts;
        default:
          return DeletionOutcome.failed;
      }
    } catch (e) {
      debugPrint('AccountDeletion: reauth failed: $e');
      return DeletionOutcome.failed;
    }
  }

  /// Removes the user document and every subcollection beneath it.
  ///
  /// Deleting a document in Firestore does NOT delete its subcollections, and
  /// the client SDK has no recursive delete — so the children are listed and
  /// removed explicitly. Skipping this would leave every logged period on the
  /// server under an invisible parent.
  static Future<void> _deleteFirestoreData(String uid) async {
    final db = FirebaseFirestore.instance;
    final userDoc = db.collection('users').doc(uid);

    for (final name in _subcollections) {
      while (true) {
        final snap = await userDoc
            .collection(name)
            .limit(_pageSize)
            .get()
            .timeout(_netTimeout);
        if (snap.docs.isEmpty) break;

        final batch = db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit().timeout(_netTimeout);

        // A short page was the last one.
        if (snap.docs.length < _pageSize) break;
      }
    }

    await userDoc.delete().timeout(_netTimeout);
  }

  /// Clears the device so nothing survives locally either.
  ///
  /// Each step is guarded separately: having deleted the account on the server,
  /// failing to cancel a notification must not report the whole deletion as
  /// failed.
  static Future<void> _wipeDevice() async {
    try {
      await PeriodReminderService.cancelAll();
    } catch (e) {
      debugPrint('AccountDeletion: cancelling reminders failed: $e');
    }

    try {
      // Covers the LocalPeriodStore mirror, the auth-email cache and the
      // session flags — everything the app keeps in SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('AccountDeletion: clearing local storage failed: $e');
    }

    try {
      // Deleting the account already ends the session; this is belt and braces
      // so FirebaseAuth.currentUser cannot survive on the handset.
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('AccountDeletion: signOut failed: $e');
    }
  }
}
