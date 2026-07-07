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
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _ensureInitialized();
    
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      
      final googleAuth = googleUser.authentication;
      final authz = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);
      
      final credential = GoogleAuthProvider.credential(
        accessToken: authz.accessToken,
        idToken: googleAuth.idToken,
      );
      
      await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});
