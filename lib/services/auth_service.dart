// ============================================================
// auth_service.dart
// ------------------------------------------------------------
// Wraps all Firebase Authentication calls (signup/login/logout)
// in one simple class so screens don't talk to FirebaseAuth
// directly. This keeps the UI code clean and easy to test.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns the currently logged-in user (or null if signed out).
  User? get currentUser => _auth.currentUser;

  // Stream that notifies listeners whenever login state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --------------------------------------------------------
  // SIGN UP: creates a new account with email + password.
  // Returns the new User on success, throws an Exception on error.
  // --------------------------------------------------------
  Future<User?> signUp({required String email, required String password}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Sign up failed');
    }
  }

  // --------------------------------------------------------
  // LOGIN: signs an existing user in with email + password.
  // --------------------------------------------------------
  Future<User?> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  // --------------------------------------------------------
  // LOGOUT
  // --------------------------------------------------------
  Future<void> logout() async {
    await _auth.signOut();
  }
}
