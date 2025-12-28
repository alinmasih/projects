import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/user_model.dart';

/// Handles authentication and user metadata synchronisation with Firestore.
class AuthService extends ChangeNotifier {
  AuthService() {
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChange);
    _setInitializing(true);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  AppUser? _currentUser;
  bool _initializing = true;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isInitializing => _initializing;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Stream<List<AppUser>> get usersStream {
    return _firestore
        .collection(FirestoreCollections.users)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppUser.fromDocument).toList());
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _setPresence(true);
  }

  Future<void> signOut() async {
    await _setPresence(false);
    await _auth.signOut();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final newUser = AppUser(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      role: UserRole.user,
      isOnline: true,
    );

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(newUser.uid)
        .set(newUser.toMap());
    _currentUser = newUser;
    notifyListeners();
  }

  Future<void> createUserAsAdmin({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final secondaryAuth = await _ensureSecondaryAuth();
    final credential = await secondaryAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(credential.user!.uid)
        .set(
          AppUser(
            uid: credential.user!.uid,
            email: email,
            displayName: displayName,
            role: role,
            isOnline: false,
          ).toMap(),
        );

    await secondaryAuth.signOut();
  }

  Future<void> updateUserMetadata(AppUser user) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .update(user.toMap());
  }

  Future<void> deleteUserAsAdmin({
    required String email,
    required String password,
    required String uid,
  }) async {
    final secondaryAuth = await _ensureSecondaryAuth();
    final credential = await secondaryAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.delete();
    await secondaryAuth.signOut();

    await _firestore.collection(FirestoreCollections.users).doc(uid).delete();
  }

  Future<void> _handleAuthChange(User? firebaseUser) async {
    await _userSubscription?.cancel();
    if (firebaseUser == null) {
      _currentUser = null;
      _setInitializing(false);
      notifyListeners();
      return;
    }

    _userSubscription = _firestore
        .collection(FirestoreCollections.users)
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) {
          _currentUser = AppUser.fromDocument(snapshot);
          _setInitializing(false);
          notifyListeners();
        });
  }

  Future<void> updateFcmToken(String? token) async {
    if (_currentUser == null || token == null) return;
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(_currentUser!.uid)
        .update({'fcmToken': token});
    _currentUser = _currentUser!.copyWith(fcmToken: token);
    notifyListeners();
  }

  Future<void> _setPresence(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .update({
          'isOnline': isOnline,
          'lastSeen': Timestamp.fromDate(DateTime.now()),
        });
  }

  void _setInitializing(bool value) {
    _initializing = value;
    notifyListeners();
  }

  FirebaseApp? _secondaryApp;

  Future<FirebaseAuth> _ensureSecondaryAuth() async {
    _secondaryApp ??= await Firebase.initializeApp(
      name: 'admin-helper',
      options: AppConfig.firebaseOptions,
    );
    return FirebaseAuth.instanceFor(app: _secondaryApp!);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }
}
