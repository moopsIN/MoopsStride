import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthNotifier extends Notifier<User?> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Google Sign-In is temporarily stubbed to resolve analyzer issues
  // final g_sign_in.GoogleSignIn _googleSignIn = g_sign_in.GoogleSignIn(scopes: ['email']);

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
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Google Sign-In is temporarily disabled.');
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});
