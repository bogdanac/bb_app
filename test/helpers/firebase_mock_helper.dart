import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock Firebase Platform for tests
class MockFirebasePlatform extends FirebasePlatform {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseAppPlatform();
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseAppPlatform();
  }

  @override
  List<FirebaseAppPlatform> get apps => [MockFirebaseAppPlatform()];
}

class MockFirebaseAppPlatform extends FirebaseAppPlatform {
  MockFirebaseAppPlatform()
      : super(
          defaultFirebaseAppName,
          const FirebaseOptions(
            apiKey: 'test-api-key',
            appId: 'test-app-id',
            messagingSenderId: 'test-sender-id',
            projectId: 'test-project-id',
          ),
        );
}

/// Mock Firebase Auth Platform for tests
class MockFirebaseAuthPlatform extends FirebaseAuthPlatform with MockPlatformInterfaceMixin {
  MockFirebaseAuthPlatform() : super();

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    return this;
  }

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(null);

  @override
  Future<void> sendPasswordResetEmail(
    String email, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {}

  @override
  Future<UserCredentialPlatform> signInAnonymously() async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) async => [];
}

/// Initialize Firebase mocks for testing.
/// Call this in setUpAll() or setUp() before running tests that use Firebase.
void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock Firebase Core
  FirebasePlatform.instance = MockFirebasePlatform();

  // Mock Firebase Auth
  FirebaseAuthPlatform.instance = MockFirebaseAuthPlatform();
}
