import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseSyncService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get uid => _auth.currentUser?.uid;

  /// Save basic user profile
  static Future<void> syncUserProfile(Map<String, dynamic> data) async {
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set(
      data,
      SetOptions(merge: true),
    );
  }

  /// Save period data
  static Future<void> syncPeriodData(Map<String, dynamic> data) async {
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('periods')
        .add(data);
  }
}
