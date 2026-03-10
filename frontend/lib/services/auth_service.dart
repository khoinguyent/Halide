import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Logic to sync with backend can be added here
  Future<void> syncWithBackend() async {
    final user = _auth.currentUser;
    if (user != null) {
      final uid = user.uid;
      final email = user.email;
      // TODO: Call backend POST /users/sync { uid, email }
      print('Syncing user with backend: UID=$uid, Email=$email');
    }
  }
}
