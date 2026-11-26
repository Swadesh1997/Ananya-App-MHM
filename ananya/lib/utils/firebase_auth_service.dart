import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> signInWithEmailOrPhone({
    required String identifier,
    required String password,
  }) async {
    try {
      // If user enters phone, convert to fake email (legacy trick)
      final email = identifier.contains('@')
          ? identifier
          : '${identifier.trim()}@ananya.app';

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return cred.user;
    } catch (_) {
      return null;
    }
  }
}
