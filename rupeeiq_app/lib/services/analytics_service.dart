import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/transaction.dart';

// Mirrors Python metrics.py:
//   category_totals = {cat: sum(amounts)}
//   savings = income - total_expenses
// All pure functions — no UI dependency.

const _storage = FlutterSecureStorage();

// ── Storage key ────────────────────────────────────────────────────────────

String _txnKey(String month, int year) => 'transactions_${month}_$year';

// ── Serialization (private) ────────────────────────────────────────────────

Map<String, dynamic> _toMap(Transaction t) => {
      'id': t.id,
      'amount': t.amount,
      'merchantName': t.merchantName,
      'dateTime': t.dateTime.toIso8601String(),
      'type': t.type,
      'availableBalance': t.availableBalance,
      'paymentMethod': t.paymentMethod,
      'rawSms': t.rawSms,
      'sender': t.sender,
      'category': t.category,
    };

Transaction _fromMap(Map<String, dynamic> m) => Transaction(
      id: m['id'] as String,
      amount: (m['amount'] as num).toDouble(),
      merchantName: m['merchantName'] as String,
      dateTime: DateTime.parse(m['dateTime'] as String),
      type: m['type'] as String,
      availableBalance: m['availableBalance'] == null
          ? null
          : (m['availableBalance'] as num).toDouble(),
      paymentMethod: m['paymentMethod'] as String,
      rawSms: m['rawSms'] as String,
      sender: m['sender'] as String,
      category: m['category'] as String? ?? 'Other',
    );

// ── Persistent storage ─────────────────────────────────────────────────────

/// Saves [transactions] for the given month/year.
/// Merges with any previously saved transactions for that month (dedup by id).
Future<void> saveTransactions(
    String month, int year, List<Transaction> transactions) async {
  try {
    final existing = await loadTransactions(month, year);
    // Merge: existing first, then new ones overwrite by id
    final merged = <String, Transaction>{
      for (final t in existing) t.id: t,
      for (final t in transactions) t.id: t,
    };
    await _storage.write(
      key: _txnKey(month, year),
      value: jsonEncode(merged.values.map(_toMap).toList()),
    );
  } catch (_) {}
}

/// Loads saved transactions for the given month/year.
/// Returns an empty list if nothing was saved or on any error.
Future<List<Transaction>> loadTransactions(String month, int year) async {
  try {
    final json = await _storage.read(key: _txnKey(month, year));
    if (json == null || json.isEmpty) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

// ── Analytics functions ────────────────────────────────────────────────────

/// Groups debit transactions by category and sums the amounts.
/// Mirrors Python's category_totals dict in metrics.py.
Map<String, double> getCategoryTotals(List<Transaction> transactions) {
  final totals = <String, double>{};
  for (final t in transactions) {
    if (t.type != 'debit') continue;
    totals[t.category] = (totals[t.category] ?? 0) + t.amount;
  }
  return totals;
}

/// Returns a summary dict mirroring the shape of Python's calculate_metrics:
///   totalIncome, totalExpenses, savings, categoryBreakdown,
///   topSpendingCategory, transactionCount, uniqueMerchantCount.
Map<String, dynamic> getMonthlySummary(List<Transaction> transactions) {
  double totalIncome   = 0;
  double totalExpenses = 0;
  final  categoryTotals = <String, double>{};
  final  merchants      = <String>{};

  for (final t in transactions) {
    if (t.type == 'credit') {
      totalIncome += t.amount;
    } else {
      totalExpenses += t.amount;
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0) + t.amount;
      merchants.add(t.merchantName);
    }
  }

  String? topCategory;
  double  topAmount = 0;
  for (final e in categoryTotals.entries) {
    if (e.value > topAmount) {
      topAmount   = e.value;
      topCategory = e.key;
    }
  }

  return {
    'totalIncome':          totalIncome,
    'totalExpenses':        totalExpenses,
    'savings':              totalIncome - totalExpenses,
    'categoryBreakdown':    categoryTotals,
    'topSpendingCategory':  topCategory,
    'transactionCount':     transactions.length,
    'uniqueMerchantCount':  merchants.length,
  };
}

/// Filters [transactions] to those belonging to [month] and [year].
List<Transaction> getTransactionsByMonth(
    List<Transaction> transactions, String month, int year) {
  const monthOrder = {
    'January': 1, 'February': 2, 'March': 3,    'April': 4,
    'May': 5,     'June': 6,    'July': 7,       'August': 8,
    'September': 9,'October': 10,'November': 11, 'December': 12,
  };
  final monthNum = monthOrder[month];
  if (monthNum == null) return [];
  return transactions
      .where((t) =>
          t.dateTime.month == monthNum && t.dateTime.year == year)
      .toList();
}

/// Groups debit transactions by date (YYYY-MM-DD) and sums per day.
Map<String, double> getDailySpending(List<Transaction> transactions) {
  final daily = <String, double>{};
  for (final t in transactions) {
    if (t.type != 'debit') continue;
    final key =
        '${t.dateTime.year}-'
        '${t.dateTime.month.toString().padLeft(2, '0')}-'
        '${t.dateTime.day.toString().padLeft(2, '0')}';
    daily[key] = (daily[key] ?? 0) + t.amount;
  }
  return daily;
}

/// Returns the mean daily spend across all days that had at least one debit.
double getAverageDaily(List<Transaction> transactions) {
  final daily = getDailySpending(transactions);
  if (daily.isEmpty) return 0;
  final total = daily.values.fold(0.0, (s, v) => s + v);
  return total / daily.length;
}
