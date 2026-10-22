import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthNotifier extends Notifier<User?> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: '19953138860-tfvj001dlpve2birqlpfu1fs7n6g8dv9.apps.googleusercontent.com',
      );
      _initialized = true;
    }
  }

  @override
  User? build() {
    // Listen to auth state changes and update the provider state
    _auth.authStateChanges().listen((user) {
      state = user;
    });
    return _auth.currentUser;
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // Best effort: confirms the address is real without blocking first use.
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {}
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Returns false if the user dismissed the Google account picker.
  Future<bool> signInWithGoogle() async {
    await _ensureInitialized();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw Exception('Google sign in failed: ${e.description ?? e.code.name}');
    }

    // Firebase only needs the ID token; requesting extra scopes here just
    // added a second consent prompt.
    final credential = GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
    );
    await _auth.signInWithCredential(credential);
    return true;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // Clear the cached Google account so the next sign-in can pick another.
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});
