import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuth() async {
    try {
      final token = await ApiService.getToken();
      _status =
          token != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.login(username, password);
      if (res['token'] != null) {
        await ApiService.saveToken(res['token'] as String);
        _status = AuthStatus.authenticated;
        _loading = false;
        notifyListeners();
        return true;
      }
      _error = res['error'] as String? ?? 'Login failed';
    } catch (_) {
      _error = 'Connection error. Check your internet.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String username,
    required String password,
    required String name,
    required String profession,
    required String email,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.register(
        username: username,
        password: password,
        name: name,
        profession: profession,
        email: email,
      );
      if (res['token'] != null) {
        await ApiService.saveToken(res['token'] as String);
        _status = AuthStatus.authenticated;
        _loading = false;
        notifyListeners();
        return true;
      }
      _error = res['error'] as String? ?? 'Registration failed';
    } catch (_) {
      _error = 'Connection error. Check your internet.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  /// Signs in with Google. Returns the full response map (includes `needs_setup`)
  /// or null on error. If `needs_setup` is false the status is set to authenticated
  /// immediately; otherwise the caller navigates to SetupProfileScreen and calls
  /// [setAuthenticated] after the user completes setup.
  Future<Map<String, dynamic>?> googleLogin(
      Map<String, String> googleData) async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      final res = await ApiService.googleLogin(googleData);
      if (res['token'] != null) {
        await ApiService.saveToken(res['token'] as String);
        if (res['needs_setup'] != true) {
          _status = AuthStatus.authenticated;
        }
        _loading = false;
        notifyListeners();
        return res;
      }
      _error = res['error'] as String? ?? 'Google sign-in failed';
    } catch (_) {
      _error = 'Connection error. Check your internet.';
    }
    _loading = false;
    notifyListeners();
    return null;
  }

  void setAuthenticated() {
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }
}
