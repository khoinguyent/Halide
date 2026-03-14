import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Email & Password Sign Up
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // Email & Password Sign In
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Phone Authentication
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithPhoneNumber(String verificationId, String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Apple Sign In
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Logic to sync with backend
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  Future<void> syncWithBackend() async {
    final user = _auth.currentUser;
    if (user != null) {
      final uid = user.uid;
      final email = user.email;
      final displayName = user.displayName ?? '';
      final avatarUrl = user.photoURL;

      try {
        final response = await http.post(
          Uri.parse('${AppConfig.apiUrl}/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': uid,
            'email': email,
            'display_name': displayName,
            'avatar_url': avatarUrl,
          }),
        );

        if (response.statusCode == 200) {
          print('User synced successfully with backend');
        } else {
          print('Failed to sync user: ${response.body}');
        }
      } catch (e) {
        print('Error syncing with backend: $e');
      }
    }
  }
}
