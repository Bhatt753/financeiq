import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool loading = true;
  bool isLoggedIn = false;
  Map<String, dynamic>? user;

  Future<void> init() async {
    isLoggedIn = await ApiService.isLoggedIn();
    loading    = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final data = await ApiService.login(username, password);
    user       = data['user'];
    isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String username, required String password,
    required String name,     required String profession,
    required String email,
  }) async {
    final data = await ApiService.register(
      username: username, password: password,
      name: name, profession: profession, email: email,
    );
    user       = data['user'];
    isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    isLoggedIn = false;
    user       = null;
    notifyListeners();
  }

  void setUser(Map<String, dynamic> u) {
    user = u;
    notifyListeners();
  }
}
