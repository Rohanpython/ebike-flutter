// lib/core/auth_helper.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthHelper {
  AuthHelper._();
  static final instance = AuthHelper._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state (null if signed out, User if signed in)
  Stream<User?> get authState => _auth.authStateChanges();

  /// Current signed-in user, or null
  User? get currentUser => _auth.currentUser;

  /// Sign in with email/password
  Future<UserCredential> signInWithEmailPassword(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Register with email/password
  Future<UserCredential> registerWithEmailPassword(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  /// Sign out
  Future<void> signOut() => _auth.signOut();

  /// Get the current Firebase ID token (JWT)
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // -------------------------------------------------------------------
  // Backward-compatibility shims for old code references
  // -------------------------------------------------------------------

  /// Old check for JWT validity → now just “is there a Firebase user?”
  static Future<bool> isTokenValid() async {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Old token clearing → no-op now
  static Future<void> clearToken() async {
    // nothing to clear, Firebase manages tokens
  }

  /// Old backend session setup → no-op now
  Future<void> ensureBackendSession() async {
    // not needed, API uses Firebase ID tokens directly
  }
}
