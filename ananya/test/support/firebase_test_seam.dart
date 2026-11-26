// These are transitive packages, imported directly because that is where the
// plugins' test seams live. Declaring them in dev_dependencies would be the
// proper fix and is a pubspec change, deliberately not made during an audit —
// see the report.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// A signed-in user, for widget tests. TEST CODE ONLY.
///
/// The history widget calls `FirebaseAuth.instance.currentUser` directly, so
/// it could not be driven in a widget test at all: two previous audits could
/// only inspect its source. Rather than change production code to add a seam,
/// this registers mock platform implementations underneath the real Firebase
/// packages, which is the seam the plugins already provide.
///
/// Firestore is deliberately NOT mocked. The write paths are fire-and-forget
/// with their own catchError, and the device copy is written first and
/// awaited — so the local half of every flow runs for real here, which is the
/// half that decides what the user sees. What a Firestore fake would add is
/// stated in the audit rather than pretended at.
const testUid = 'audit-uid';

class _MockFirebaseApp extends FirebaseAppPlatform {
  _MockFirebaseApp()
      : super(
          defaultFirebaseAppName,
          const FirebaseOptions(
            apiKey: 'test',
            appId: 'test',
            messagingSenderId: 'test',
            projectId: 'test',
          ),
        );
}

class _MockFirebaseCore extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      _MockFirebaseApp();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async =>
      _MockFirebaseApp();

  @override
  List<FirebaseAppPlatform> get apps => [_MockFirebaseApp()];
}

class _MockMultiFactor extends MultiFactorPlatform {
  _MockMultiFactor(super.auth);
}

class _MockUser extends UserPlatform {
  _MockUser(FirebaseAuthPlatform auth)
      : super(
          auth,
          _MockMultiFactor(auth),
          PigeonUserDetails(
            userInfo: PigeonUserInfo(
              uid: testUid,
              isAnonymous: false,
              isEmailVerified: true,
            ),
            providerData: const [],
          ),
        );
}

class _MockFirebaseAuth extends FirebaseAuthPlatform {
  _MockFirebaseAuth(FirebaseApp app) : super(appInstance: app);

  @override
  UserPlatform? get currentUser => _MockUser(this);

  @override
  FirebaseAuthPlatform delegateFor({
    required FirebaseApp app,
    Persistence? persistence,
  }) =>
      this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;
}

/// Installs the mocks. Call once, before `Firebase.initializeApp()`.
Future<void> installFirebaseTestSeam() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = _MockFirebaseCore();
  final app = await Firebase.initializeApp();
  FirebaseAuthPlatform.instance = _MockFirebaseAuth(app);
}

