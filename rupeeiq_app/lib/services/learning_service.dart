import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/transaction.dart';

const _storage = FlutterSecureStorage();

// Storage keys
// _kMerchantKey MUST match the key in merchant_classifier.dart so that
// learnMerchantCategory() corrections are immediately visible to classifyMerchant().
const _kMerchantKey = 'learned_merchants'; // same key as merchant_classifier.dart
const _kUpiKey      = 'upi_learning';
const _kPatternKey  = 'pattern_learning';

// ── Part 1: Merchant correction learning ─────────────────────────────────────

/// Saves merchant → category (and optionally UPI ID → category).
/// Writing to 'merchant_learning' is read by classifyMerchant() in
/// merchant_classifier.dart, completing the learning loop.
Future<void> learnMerchantCategory(
    String merchantName, String correctCategory, [String? upiId]) async {
  final key = merchantName.trim().toLowerCase();
  if (key.isEmpty) return;

  await _writeToMap(_kMerchantKey, key, correctCategory);

  if (upiId != null && upiId.isNotEmpty) {
    await _writeToMap(_kUpiKey, upiId.toLowerCase().trim(), correctCategory);
  }
}

/// Returns the user-learned category for [merchantName], or null.
Future<String?> getLearnedMerchant(String merchantName) async {
  final map = await _readMap(_kMerchantKey);
  return map[merchantName.trim().toLowerCase()];
}

/// Returns the user-learned category for a UPI ID, or null.
Future<String?> getLearnedUpi(String upiId) async {
  final map = await _readMap(_kUpiKey);
  return map[upiId.toLowerCase().trim()];
}

/// How many distinct merchants the user has corrected.
Future<int> getMerchantsLearnedCount() async {
  final map = await _readMap(_kMerchantKey);
  return map.length;
}

// ── Part 2: Pattern learning ──────────────────────────────────────────────────

/// Records a correction so the app can learn patterns over time.
/// Once the same pattern+category has been corrected ≥3 times it is returned
/// by [getLearnedPattern] for future transactions.
Future<void> learnFromCorrection(
    Transaction transaction, String correctCategory) async {
  final pk      = _patternKey(transaction);
  final patterns = await _readPatterns();
  final countKey = '$pk:$correctCategory';
  patterns[countKey] = (patterns[countKey] ?? 0) + 1;
  await _writePatterns(patterns);
}

/// Returns the most likely category learned from past corrections for this
/// transaction's pattern, if ≥3 corrections confirm it.
Future<String?> getLearnedPattern(Transaction transaction) async {
  final patterns = await _readPatterns();
  final pk       = _patternKey(transaction);

  String? best;
  int bestCount = 0;
  for (final e in patterns.entries) {
    if (e.key.startsWith('$pk:') && e.value >= 3 && e.value > bestCount) {
      bestCount = e.value;
      best      = e.key.substring(pk.length + 1);
    }
  }
  return best;
}

// ── Part 3: Smart category suggestions ───────────────────────────────────────

/// Returns all categories ordered by how likely they are for [transaction],
/// using time-of-day, amount, day-of-week, and learned patterns.
/// The first item is the most likely suggestion to pre-select in the UI.
Future<List<String>> getSmartSuggestions(Transaction transaction) async {
  const all = [
    'Food & Groceries', 'Transport', 'Shopping', 'Entertainment',
    'Healthcare', 'Education', 'Utilities', 'Travel', 'Investment',
    'Rent/Housing', 'Other',
  ];

  final scores = <String, double>{for (final c in all) c: 0.0};

  // Time-of-day priors
  final h = transaction.dateTime.hour;
  if (h >= 7 && h < 10) {
    scores['Food & Groceries'] = scores['Food & Groceries']! + 2.0;
    scores['Transport']        = scores['Transport']!        + 1.5;
  } else if (h >= 12 && h < 14) {
    scores['Food & Groceries'] = scores['Food & Groceries']! + 2.0;
  } else if (h >= 18 && h < 21) {
    scores['Food & Groceries'] = scores['Food & Groceries']! + 1.5;
    scores['Entertainment']    = scores['Entertainment']!    + 1.0;
  } else if (h >= 22 || h < 2) {
    scores['Food & Groceries'] = scores['Food & Groceries']! + 1.0;
    scores['Entertainment']    = scores['Entertainment']!    + 1.0;
    scores['Shopping']         = scores['Shopping']!         + 0.5;
  }

  // Amount range priors
  final amt = transaction.amount;
  if (amt < 100) {
    scores['Food & Groceries'] = scores['Food & Groceries']! + 1.5;
    scores['Transport']        = scores['Transport']!        + 1.0;
  } else if (amt >= 500 && amt < 2000) {
    scores['Shopping']         = scores['Shopping']!         + 1.0;
    scores['Entertainment']    = scores['Entertainment']!    + 0.5;
  } else if (amt >= 2000) {
    scores['Rent/Housing']     = scores['Rent/Housing']!     + 1.0;
    scores['Shopping']         = scores['Shopping']!         + 0.5;
    scores['Travel']           = scores['Travel']!           + 0.5;
  }

  // Day-of-week priors (weekend)
  if (transaction.dateTime.weekday >= 6) {
    scores['Entertainment'] = scores['Entertainment']! + 1.0;
    scores['Shopping']      = scores['Shopping']!      + 0.5;
  }

  // Learned-pattern boost (strongest signal)
  final patternCat = await getLearnedPattern(transaction);
  if (patternCat != null && scores.containsKey(patternCat)) {
    scores[patternCat] = scores[patternCat]! + 5.0;
  }

  final sorted = all.toList()
    ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
  return sorted;
}

// ── Private helpers ───────────────────────────────────────────────────────────

/// Pattern key: paymentMethod tier + time-of-day + amount tier.
String _patternKey(Transaction t) {
  final h  = t.dateTime.hour;
  final tod = h >= 6 && h < 12  ? 'morning'
            : h >= 12 && h < 18 ? 'afternoon'
            : h >= 18 && h < 23 ? 'evening'
            : 'night';
  final tier = t.amount < 100   ? 'small'
             : t.amount < 500   ? 'medium'
             : t.amount < 2000  ? 'large'
             : 'xlarge';
  final pm = t.paymentMethod.toLowerCase().contains('upi') ? 'upi' : 'other';
  return '${pm}_${tod}_$tier';
}

Future<void> _writeToMap(String key, String field, String value) async {
  try {
    final map = await _readMap(key);
    map[field] = value;
    await _storage.write(key: key, value: jsonEncode(map));
  } catch (_) {}
}

Future<Map<String, String>> _readMap(String key) async {
  try {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  } catch (_) {
    return {};
  }
}

Future<Map<String, int>> _readPatterns() async {
  try {
    final raw = await _storage.read(key: _kPatternKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return {};
  }
}

Future<void> _writePatterns(Map<String, int> patterns) async {
  try {
    await _storage.write(key: _kPatternKey, value: jsonEncode(patterns));
  } catch (_) {}
}
