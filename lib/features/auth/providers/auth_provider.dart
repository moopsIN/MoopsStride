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

  /// Whether the signed-in user authenticates with Google (vs. a password).
  bool get usesGoogle =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  /// Deleting an account requires a recent sign-in, so confirm identity
  /// before any data is destroyed. Returns false if the user cancelled.
  Future<bool> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (usesGoogle) {
      await _ensureInitialized();
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return false;
        rethrow;
      }
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: googleUser.authentication.idToken),
      );
    } else {
      if (password == null) return false;
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    }
    return true;
  }

  /// Deletes the Firebase user. Call after [reauthenticate] and after the
  /// user's cloud data is removed (security rules deny access afterwards).
  Future<void> deleteAccount() async {
    final wasGoogle = usesGoogle;
    await _auth.currentUser?.delete();
    if (wasGoogle) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}
    }
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
