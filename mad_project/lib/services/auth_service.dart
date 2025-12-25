import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'unknown', message: 'Login failed');
      }

      await user.reload();
      final refreshed = _auth.currentUser;

      if (refreshed != null && !refreshed.emailVerified) {
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email before logging in.',
        );
      }

      await _ensureUserDocument(refreshed);
      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final emailLower = email.trim().toLowerCase();

      final cred = await _auth.createUserWithEmailAndPassword(
        email: emailLower,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'Account creation failed',
        );
      }

      await _db.collection('users').doc(user.uid).set({
        'id': user.uid,
        'name': name.trim(),
        'email': emailLower,
        'role': role.isEmpty ? '' : role,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.sendEmailVerification();

      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  Future<void> resendEmailVerificationLink() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No user found. Please sign up again.',
        );
      }

      await user.reload();
      final refreshed = _auth.currentUser;

      if (refreshed == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No user found. Please sign up again.',
        );
      }

      if (refreshed.emailVerified) {
        return;
      }

      await refreshed.sendEmailVerification();
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.reload();
      final refreshed = _auth.currentUser;
      return refreshed?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) return;

      await _db.collection('users').doc(user.uid).set({
        'id': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'role': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error ensuring user document: $e');
    }
  }

  Future<void> finalizeVerifiedUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null) return;

      if (!refreshed.emailVerified) {
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Email is not verified yet.',
        );
      }

      await _db.collection('users').doc(refreshed.uid).set({
        'id': refreshed.uid,
        'name': refreshed.displayName ?? '',
        'email': refreshed.email ?? '',
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('Error finalizing user: $e');
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        final cred = await _auth.signInWithPopup(provider);
        await ensureGoogleUserDocBasic();
        return cred;
      }

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'popup-closed-by-user',
          message: 'Popup closed',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      await ensureGoogleUserDocBasic();
      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  Future<void> ensureGoogleUserDocBasic() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) return;

      await _db.collection('users').doc(user.uid).set({
        'id': user.uid,
        'name': (user.displayName ?? '').trim(),
        'email': (user.email ?? '').trim(),
        'avatarUrl': user.photoURL ?? '',
        'role': '',
        'createdAt': FieldValue.serverTimestamp(),
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error ensuring Google user doc: $e');
    }
  }

  Future<String?> getCurrentUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snap = await _db.collection('users').doc(user.uid).get();
      if (!snap.exists) return null;

      final role = (snap.data()?['role'] ?? '').toString();
      return role.isEmpty ? null : role;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  Future<void> setRoleForCurrentUser(String role) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.collection('users').doc(user.uid).set({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting user role: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (!kIsWeb) {
        try {
          await GoogleSignIn().signOut();
        } catch (e) {
          print('Google sign out error: $e');
        }
      }
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  Future<dynamic> verifyEmailAndCreateAccount(String s) async {
    throw UnimplementedError('Not used in free plan email link flow');
  }

  Future<bool> hasPendingVerification(String email) async {
    return false;
  }

  Future<void> resendVerificationCode(String email) async {
    throw UnimplementedError('Not used in free plan email link flow');
  }

  Future<UserCredential> verifyWithCode({
    required String email,
    required String code,
  }) async {
    throw UnimplementedError('Not used in free plan email link flow');
  }

  Future<void> cleanupOldPendingUsers() async {
    return;
  }
}
