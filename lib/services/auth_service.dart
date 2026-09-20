import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    UserCredential? cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (_) {
      return 'Could not create your account. Please check your internet connection and try again.';
    }

    // Account was created in Firebase Auth; now save the profile document.
    // If this fails (e.g. Firestore rules, network drop), roll back the
    // auth account so the user isn't left with an account that has no
    // profile and can simply try signing up again.
    try {
      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'approved': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return null; // success
    } catch (_) {
      try {
        await cred.user?.delete();
      } catch (_) {
        // Ignore: even if cleanup fails, we still report the real problem below.
      }
      return 'Your account could not be saved. Please try again.';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (_) {
      return 'Could not sign in. Please check your internet connection and try again.';
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Watches the current user's own approval status document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyApprovalStatus() {
    final uid = currentUser!.uid;
    return _db.collection('users').doc(uid).snapshots();
  }

  /// Maps Firebase Auth error codes to clear, user-facing English messages.
  /// Falls back to the SDK message (or the error code) for anything not
  /// explicitly handled, so unexpected errors are still readable instead of
  /// showing a bare/blank "Error".
  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email. Try signing in instead.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'user-disabled':
        return 'This account has been disabled. Contact an administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this app. Contact an administrator.';
      default:
        final detail = (e.message == null || e.message!.trim().isEmpty)
            ? e.code
            : e.message!;
        return 'Something went wrong ($detail). Please try again.';
    }
  }
}
