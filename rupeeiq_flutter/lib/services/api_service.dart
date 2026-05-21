import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const _base = 'https://financeiq-kqi9.onrender.com/api';
  static const _tokenKey = 'jwt_token';

  // ── Token storage ──────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> isLoggedIn() async => (await getToken()) != null;

  // ── HTTP helpers ───────────────────────────────────────

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Map<String, dynamic> _parse(http.Response r) {
    final body = jsonDecode(r.body);
    if (r.statusCode >= 400) {
      throw ApiException(body['error'] ?? 'Server error ${r.statusCode}');
    }
    return body as Map<String, dynamic>;
  }

  // ── Auth ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final r = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: await _headers(auth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = _parse(r);
    await saveToken(data['token']);
    return data;
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String name,
    required String profession,
    required String email,
  }) async {
    final r = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: await _headers(auth: false),
      body: jsonEncode({
        'username': username, 'password': password,
        'name': name, 'profession': profession, 'email': email,
      }),
    );
    final data = _parse(r);
    await saveToken(data['token']);
    return data;
  }

  // ── Dashboard ──────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard() async {
    final r = await http.get(
      Uri.parse('$_base/dashboard'),
      headers: await _headers(),
    );
    return _parse(r);
  }

  // ── History ────────────────────────────────────────────

  static Future<List<dynamic>> getHistory() async {
    final r = await http.get(
      Uri.parse('$_base/history'),
      headers: await _headers(),
    );
    return _parse(r)['history'] as List;
  }

  static Future<Map<String, dynamic>> getHistoryEntry(int id) async {
    final r = await http.get(
      Uri.parse('$_base/history/$id'),
      headers: await _headers(),
    );
    return _parse(r);
  }

  static Future<void> deleteEntry(int id) async {
    final r = await http.delete(
      Uri.parse('$_base/history/$id'),
      headers: await _headers(),
    );
    _parse(r);
  }

  // ── Finance ────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFormData() async {
    final r = await http.get(
      Uri.parse('$_base/finance/form_data'),
      headers: await _headers(),
    );
    return _parse(r);
  }

  static Future<Map<String, dynamic>> addData({
    required double income,
    required String month,
    required int year,
    required List<Map<String, dynamic>> expenses,
    double emergencyFund = 0,
    String profession = '',
  }) async {
    final r = await http.post(
      Uri.parse('$_base/finance/add'),
      headers: await _headers(),
      body: jsonEncode({
        'income': income, 'month': month, 'year': year,
        'expenses': expenses, 'emergency_fund': emergencyFund,
        'profession': profession,
      }),
    );
    return _parse(r);
  }

  // ── Loans ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getLoans() async {
    final r = await http.get(
      Uri.parse('$_base/loans'),
      headers: await _headers(),
    );
    return _parse(r);
  }

  static Future<void> addLoan(Map<String, dynamic> loan) async {
    final r = await http.post(
      Uri.parse('$_base/loans/add'),
      headers: await _headers(),
      body: jsonEncode(loan),
    );
    _parse(r);
  }

  static Future<void> deleteLoan(int id) async {
    final r = await http.delete(
      Uri.parse('$_base/loans/$id'),
      headers: await _headers(),
    );
    _parse(r);
  }

  // ── Goals ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getGoals() async {
    final r = await http.get(
      Uri.parse('$_base/goals'),
      headers: await _headers(),
    );
    return _parse(r);
  }

  static Future<Map<String, dynamic>> analyzeGoal({
    required String name,
    required double amount,
    required int months,
  }) async {
    final r = await http.post(
      Uri.parse('$_base/goals/analyze'),
      headers: await _headers(),
      body: jsonEncode({'goal_name': name, 'goal_amount': amount, 'goal_months': months}),
    );
    return _parse(r);
  }

  static Future<void> completeGoal(int id) async {
    final r = await http.post(
      Uri.parse('$_base/goals/$id/complete'),
      headers: await _headers(),
    );
    _parse(r);
  }

  static Future<void> deleteGoal(int id) async {
    final r = await http.delete(
      Uri.parse('$_base/goals/$id'),
      headers: await _headers(),
    );
    _parse(r);
  }

  // ── Health ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHealth() async {
    final r = await http.get(
      Uri.parse('$_base/health'),
      headers: await _headers(),
    );
    return _parse(r);
  }

  // ── Profile ────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    final r = await http.get(
      Uri.parse('$_base/profile'),
      headers: await _headers(),
    );
    return _parse(r);
  }

  static Future<void> updateProfile({required String name, required String profession}) async {
    final r = await http.put(
      Uri.parse('$_base/profile'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'profession': profession}),
    );
    _parse(r);
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
