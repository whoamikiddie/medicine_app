import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isPatient => _currentUser?.role == 'patient';
  bool get isDoctor => _currentUser?.role == 'doctor';

  UserProvider() {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) async {
      if (user == null) {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      } else {
        await _loadUserData();
      }
    });
  }

  Future<void> _loadUserData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.getCurrentUserModel();
      debugPrint('User loaded: ${_currentUser?.name} (${_currentUser?.role})');
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final user = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        role: role,
      );
      _currentUser = user;
      debugPrint('User registered: ${user.name} (${user.role})');
      notifyListeners();
    } catch (e) {
      debugPrint('Sign-up error: $e');
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _currentUser = user;
      debugPrint('User signed in: ${user.name} (${user.role})');
      notifyListeners();
    } catch (e) {
      debugPrint('Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  Future<void> signOut() async {
    try {
      debugPrint('User signing out: ${_currentUser?.name}');
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign-out error: $e');
      rethrow;
    }
  }

  Future<void> refreshUser() async {
    await _loadUserData();
  }
}
