import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Ensure user document exists
      await _ensureUserDocument(cred.user);

      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  // EMAIL SIGNUP → SAVE TO pending_users ONLY
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'User creation failed',
        );
      }

      // Send email verification
      await user.sendEmailVerification();

      // Save to pending_users collection
      await _db.collection('pending_users').doc(user.uid).set({
        'id': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'role': role.isEmpty ? '' : role,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  // Helper to ensure user document exists
  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) return;

      // Check pending_users
      final pendingDoc = await _db
          .collection('pending_users')
          .doc(user.uid)
          .get();
      if (pendingDoc.exists) return; // Will be moved by finalizeVerifiedUser

      // Create basic user document
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

  // MOVE VERIFIED USER TO users COLLECTION
  Future<void> finalizeVerifiedUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await user.reload();
      final refreshedUser = _auth.currentUser;
      final verified = refreshedUser?.emailVerified ?? false;

      if (!verified) return;

      // Check if already in users collection
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) return;

      final pendingRef = _db.collection('pending_users').doc(user.uid);
      final pendingSnap = await pendingRef.get();

      if (!pendingSnap.exists) {
        // If no pending doc, create basic user doc
        await _db.collection('users').doc(user.uid).set({
          'id': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'role': '',
          'verifiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final data = pendingSnap.data() ?? {};

      // Move to users collection
      await _db.collection('users').doc(user.uid).set({
        ...data,
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Delete from pending_users
      await pendingRef.delete();
    } catch (e) {
      print('Error finalizing user: $e');
      // Don't throw - allow flow to continue
    }
  }

  // GOOGLE SIGN IN
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

  Future<void> resendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user logged in',
        );
      }
      await user.sendEmailVerification();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.reload();
      final refreshedUser = _auth.currentUser;
      return refreshedUser?.emailVerified ?? false;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  // FORGOT PASSWORD
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
}
