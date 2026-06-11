import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl  = 'https://financeiq-kqi9.onrender.com/api';
const _tokenKey = 'jwt_token';
const _storage  = FlutterSecureStorage();

Future<void> _checkInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 5));
    if (result.isEmpty || result[0].rawAddress.isEmpty) {
      throw const SocketException('No internet');
    }
  } on SocketException {
    throw const SocketException('Please check your internet connection');
  } on TimeoutException {
    throw const SocketException('Please check your internet connection');
  }
}

class ApiService {
  static const String baseUrl = 'https://financeiq-kqi9.onrender.com';

  // ── Token storage ──────────────────────────────────────────────────────
  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  // ── HTTP helpers ───────────────────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _handleError(Object e) {
    if (e is SocketException) {
      return {'error': 'Please check your internet connection'};
    }
    if (e is TimeoutException) {
      return {'error': 'Server is starting up, please try again in 30 seconds'};
    }
    return {'error': 'Something went wrong, please try again'};
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      await _checkInternet();
      final headers = auth
          ? await _authHeaders()
          : {'Content-Type': 'application/json'};
      final res = await http
          .post(Uri.parse('$_baseUrl$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 500) {
        return decoded['error'] != null
            ? decoded
            : {'error': 'Something went wrong, please try again'};
      }
      return decoded;
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      await _checkInternet();
      final headers = await _authHeaders();
      final res = await http
          .get(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 60));
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 500) {
        return decoded['error'] != null
            ? decoded
            : {'error': 'Something went wrong, please try again'};
      }
      return decoded;
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    try {
      await _checkInternet();
      final headers = await _authHeaders();
      final res = await http
          .delete(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 60));
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 500) {
        return decoded['error'] != null
            ? decoded
            : {'error': 'Something went wrong, please try again'};
      }
      return decoded;
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      await _checkInternet();
      final headers = await _authHeaders();
      final res = await http
          .put(Uri.parse('$_baseUrl$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 500) {
        return decoded['error'] != null
            ? decoded
            : {'error': 'Something went wrong, please try again'};
      }
      return decoded;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ── Auth ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
          String username, String password) =>
      _post('/auth/login', {'username': username, 'password': password},
          auth: false);

  static Future<Map<String, dynamic>> googleLogin(
          Map<String, String> googleData) =>
      _post('/auth/google_login', googleData, auth: false);

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String name,
    required String profession,
    required String email,
  }) =>
      _post(
          '/auth/register',
          {
            'username': username,
            'password': password,
            'name': name,
            'profession': profession,
            'email': email,
          },
          auth: false);

  // ── Dashboard ─────────────────────────────────────────────────────────
  // Returns: {history: [...], trends: {...}, summary: {...}, goals: [...]}
  static Future<Map<String, dynamic>> getDashboard() => _get('/dashboard');

  // ── Finance ───────────────────────────────────────────────────────────
  // Returns: {loans: [...], categories: [...], months: [...]}
  static Future<Map<String, dynamic>> getFormData() =>
      _get('/finance/form_data');

  // expenses = [{name, category, type, amount}, ...]
  static Future<Map<String, dynamic>> addFinanceEntry({
    required String month,
    required int year,
    required double income,
    required List<Map<String, dynamic>> expenses,
    double emergencyFund = 0,
  }) =>
      _post('/finance/add', {
        'month': month,
        'year': year,
        'income': income,
        'expenses': expenses,
        'emergency_fund': emergencyFund,
      });

  // ── History ───────────────────────────────────────────────────────────
  // Returns: {history: [...]}
  static Future<Map<String, dynamic>> getHistory() => _get('/history');

  // Returns: {entry: {...}, expenses: [...]}
  static Future<Map<String, dynamic>> getHistoryEntry(int id) =>
      _get('/history/$id');

  static Future<Map<String, dynamic>> deleteHistoryEntry(int id) =>
      _delete('/history/$id');

  // expenses = [{name, category, type, amount}, ...]
  static Future<Map<String, dynamic>> updateHistoryEntry(
    int id, {
    required String month,
    required int year,
    required double income,
    required List<Map<String, dynamic>> expenses,
    double emergencyFund = 0,
  }) =>
      _put('/history/$id', {
        'month': month,
        'year': year,
        'income': income,
        'expenses': expenses,
        'emergency_fund': emergencyFund,
      });

  // ── Loans ─────────────────────────────────────────────────────────────
  // Returns: {loans: [...], analysis: {...}, advice: {...}, income: N}
  static Future<Map<String, dynamic>> getLoans() => _get('/loans');

  static Future<Map<String, dynamic>> addLoan({
    required String loanName,
    required String loanType,
    required double principal,
    required double emi,
    required double interestRate,
    required int tenureMonths,
    required String startMonth,
    required int startYear,
  }) =>
      _post('/loans/add', {
        'loan_name': loanName,
        'loan_type': loanType,
        'principal': principal,
        'emi': emi,
        'interest_rate': interestRate,
        'tenure_months': tenureMonths,
        'start_month': startMonth,
        'start_year': startYear,
      });

  static Future<Map<String, dynamic>> deleteLoan(int id) =>
      _delete('/loans/$id');

  // ── Goals ─────────────────────────────────────────────────────────────
  // Returns: {goals: [...], current_savings: N}
  // Goal fields: goal_name, goal_amount, goal_months, status, progress_pct
  static Future<Map<String, dynamic>> getGoals() => _get('/goals');

  static Future<Map<String, dynamic>> analyzeGoal({
    required String goalName,
    required double goalAmount,
    required int goalMonths,
  }) =>
      _post('/goals/analyze', {
        'goal_name': goalName,
        'goal_amount': goalAmount,
        'goal_months': goalMonths,
      });

  static Future<Map<String, dynamic>> completeGoal(int id) =>
      _post('/goals/$id/complete', {});

  static Future<Map<String, dynamic>> deleteGoal(int id) =>
      _delete('/goals/$id');

  // ── Health ────────────────────────────────────────────────────────────
  // Returns: {has_data: bool, score: {...}, month, year, income}
  static Future<Map<String, dynamic>> getHealth() => _get('/health');

  // ── Profile ───────────────────────────────────────────────────────────
  // Returns: {user: {id, name, username, email, profession, ...}}
  static Future<Map<String, dynamic>> getProfile() => _get('/profile');

  // Accepts: {name, profession}
  static Future<Map<String, dynamic>> updateProfile(
          String name, String profession) =>
      _put('/profile', {'name': name, 'profession': profession});
}
