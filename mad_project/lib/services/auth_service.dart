import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // EMAIL SIGNUP → SAVE TO pending_users ONLY
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
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

    await user.sendEmailVerification();

    await _db.collection('pending_users').doc(user.uid).set({
      'id': user.uid,
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  // MOVE VERIFIED USER TO users COLLECTION
  Future<void> finalizeVerifiedUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await user.reload();
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (!verified) return;

    final pendingRef = _db.collection('pending_users').doc(user.uid);
    final pendingSnap = await pendingRef.get();

    if (!pendingSnap.exists) return;

    final data = pendingSnap.data() ?? {};

    await _db.collection('users').doc(user.uid).set({
      ...data,
      'verifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await pendingRef.delete();
  }

  // GOOGLE SIGN IN
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      return _auth.signInWithPopup(provider);
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

    return _auth.signInWithCredential(credential);
  }

  Future<void> ensureGoogleUserDocBasic() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'id': user.uid,
      'name': (user.displayName ?? '').trim(),
      'email': (user.email ?? '').trim(),
      'avatarUrl': user.photoURL ?? '',
      'verifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _db.collection('users').doc(user.uid).get();
    if (!snap.exists) return null;

    final role = (snap.data()?['role'] ?? '').toString();
    return role.isEmpty ? null : role;
  }

  Future<void> setRoleForCurrentUser(String role) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // FORGOT PASSWORD
  Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }
}
