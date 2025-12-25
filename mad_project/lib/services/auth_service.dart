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

    await _upsertUserDoc(
      uid: user.uid,
      name: name.trim(),
      email: email.trim(),
      avatarUrl: user.photoURL ?? '',
      role: role,
      setRole: true,
    );

    return cred;
  }

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

  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _db.collection('users').doc(user.uid).get();
    if (!snap.exists) return null;

    final data = snap.data();
    final role = (data?['role'] ?? '').toString().trim();
    if (role.isEmpty) return null;

    return role;
  }

  Future<void> ensureGoogleUserDocBasic() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _upsertUserDoc(
      uid: user.uid,
      name: (user.displayName ?? '').trim(),
      email: (user.email ?? '').trim(),
      avatarUrl: user.photoURL ?? '',
      role: '',
      setRole: false,
    );
  }

  Future<void> setRoleForCurrentUser(String role) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Not signed in',
      );
    }

    await _upsertUserDoc(
      uid: user.uid,
      name: (user.displayName ?? '').trim(),
      email: (user.email ?? '').trim(),
      avatarUrl: user.photoURL ?? '',
      role: role,
      setRole: true,
    );
  }

  Future<void> _upsertUserDoc({
    required String uid,
    required String name,
    required String email,
    required String avatarUrl,
    required String role,
    required bool setRole,
  }) async {
    final payload = <String, dynamic>{
      'id': uid,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (setRole) {
      payload['role'] = role;
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await _db
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }

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
