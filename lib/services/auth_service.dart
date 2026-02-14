import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user from Firebase Auth
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get full UserModel from Firestore
  Future<UserModel?> getCurrentUserModel() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        debugPrint('No Firestore document for user: ${user.uid}');
        return null;
      }
      return UserModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching user model: $e');
      return null;
    }
  }

  // Sign up with email and password
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      debugPrint('Creating user with email: $email');
      
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw 'Account creation failed. Please try again.';

      debugPrint('User created in Firebase Auth: ${user.uid}');

      // Create user document in Firestore
      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: email,
        role: role,
        createdAt: DateTime.now(),
      );

      debugPrint('Saving user to Firestore...');
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toJson());

      debugPrint('User saved to Firestore successfully');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException in signUp: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      debugPrint('Sign-up error: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    UserCredential? credential;
    
    try {
      debugPrint('Signing in with email: $email');
      
      // Try sign-in without accessing credential.user immediately
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('signInWithEmailAndPassword completed');
      } catch (signInError) {
        debugPrint('Error in signInWithEmailAndPassword: $signInError');
        debugPrint('Error type: ${signInError.runtimeType}');
        rethrow;
      }

      // Now try to access the user property
      debugPrint('Attempting to access credential.user...');
      User? user;
      try {
        user = credential.user;
        debugPrint('credential.user accessed successfully');
      } catch (userAccessError) {
        debugPrint('Error accessing credential.user: $userAccessError');
        debugPrint('Error type: ${userAccessError.runtimeType}');
        
        // Fallback: try getting current user directly
        debugPrint('Trying fallback: _auth.currentUser');
        user = _auth.currentUser;
      }

      if (user == null) {
        debugPrint('User is null after all attempts');
        throw 'Authentication failed. Please try again.';
      }

      debugPrint('User UID: ${user.uid}');

      // Fetch user data from Firestore
      debugPrint('Fetching user from Firestore...');
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('No Firestore doc - creating one');
        final userModel = UserModel(
          uid: user.uid,
          name: email.split('@').first,
          email: email,
          role: 'patient',
          createdAt: DateTime.now(),
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toJson());
        return userModel;
      }

      debugPrint('Parsing UserModel from Firestore');
      final userModel = UserModel.fromJson(doc.data()!);
      debugPrint('Login successful: ${userModel.name}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      debugPrint('[CATCH-ALL] Sign-in error: $e');
      debugPrint('[CATCH-ALL] Error type: ${e.runtimeType}');
      debugPrint('[CATCH-ALL] Stack trace: ${StackTrace.current}');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
