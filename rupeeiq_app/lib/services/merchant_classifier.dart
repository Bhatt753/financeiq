import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/transaction.dart';
import 'learning_service.dart' as ls;
import 'merchant_database.dart';

const _storage = FlutterSecureStorage();
const _kLearnedKey = 'learned_merchants';

// ── Keyword → category map for merchants not in the curated database ────────

const Map<String, List<String>> _keywordCategories = {
  'Food & Groceries': [
    'restaurant', 'cafe', 'kitchen', 'food', 'biryani',
    'dhaba', 'hotel', 'bakery', 'sweets', 'mithai',
    'juice', 'pizza', 'burger', 'chicken', 'dosa',
    'idli', 'chai', 'tea', 'coffee', 'canteen', 'mess',
  ],
  'Transport': [
    'travels', 'transport', 'cab', 'taxi', 'auto',
    'bus', 'train', 'railway', 'airlines', 'airport',
    'parking', 'fuel', 'petrol', 'diesel', 'garage',
  ],
  'Shopping': [
    'store', 'shop', 'mart', 'mall', 'bazaar', 'market',
    'emporium', 'boutique', 'fashion', 'clothing',
    'electronics', 'mobile', 'computer', 'hardware',
  ],
  'Healthcare': [
    'hospital', 'clinic', 'pharmacy', 'medical',
    'health', 'dental', 'doctor', 'lab', 'diagnostic',
    'nursing', 'optical', 'ayurveda', 'chemist',
  ],
  'Entertainment': [
    'cinema', 'theatre', 'club', 'bar', 'pub', 'resort',
    'spa', 'salon', 'beauty', 'gym', 'fitness', 'sports',
    'games', 'arcade', 'bowling', 'amusement',
  ],
  'Education': [
    'school', 'college', 'university', 'institute',
    'academy', 'coaching', 'tuition', 'library',
    'course', 'classes', 'training', 'workshop',
  ],
  'Utilities': [
    'electricity', 'water', 'gas', 'internet', 'wifi',
    'broadband', 'cable', 'telephone', 'mobile', 'recharge',
  ],
};

// ── Local storage: learned merchants ──────────────────────────────────────

Future<Map<String, String>> getLearnedMerchants() async {
  try {
    final json = await _storage.read(key: _kLearnedKey);
    if (json == null || json.isEmpty) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  } catch (_) {
    return {};
  }
}

Future<void> saveMerchantCategory(
    String merchant, String category) async {
  try {
    final existing = await getLearnedMerchants();
    existing[merchant.toLowerCase().trim()] = category;
    await _storage.write(
        key: _kLearnedKey, value: jsonEncode(existing));
  } catch (_) {
    // Silently fail — classification still works via other methods
  }
}

Future<String?> getLearnedCategory(String merchant) async {
  final learned = await getLearnedMerchants();
  return learned[merchant.toLowerCase().trim()];
}

// ── Keyword-based classification ───────────────────────────────────────────

String? classifyByKeywords(String merchantName) {
  final lower = merchantName.toLowerCase();
  for (final entry in _keywordCategories.entries) {
    for (final kw in entry.value) {
      if (lower.contains(kw)) return entry.key;
    }
  }
  return null;
}

// ── Main classification function ───────────────────────────────────────────

Future<String> classifyMerchant(String merchantName) async {
  final normalized = merchantName.trim();
  if (normalized.isEmpty) return 'Other';

  // 1. User-corrected / previously learned merchants take priority
  final learned = await getLearnedCategory(normalized);
  if (learned != null) return learned;

  // 2. Curated merchant database (150+ known merchants)
  final dbCategory = getMerchantCategory(normalized);
  if (dbCategory != null) return dbCategory;

  // 3. Generic keyword matching for unknown merchants
  final kwCategory = classifyByKeywords(normalized);
  if (kwCategory != null) return kwCategory;

  return 'Other';
}

// ── User correction ───────────────────────────────────────────────────────────

Future<void> correctMerchantCategory(
    String merchantName, String correctCategory) async {
  await saveMerchantCategory(merchantName, correctCategory);
}

// ── Smart classify (full learning stack) ──────────────────────────────────────

/// Full classification using all learned data, patterns, database, keywords,
/// and contextual signals. Use instead of [classifyMerchant] when a
/// [Transaction] object is available.
///
/// Priority:
///   1. User merchant corrections (learned_merchants / merchant_learning)
///   2. Learned UPI-ID corrections
///   3. Learned behavioural patterns (≥3 same-pattern corrections)
///   4. Curated merchant database
///   5. Keyword classification
///   6. 'Other'
Future<String> smartClassify(Transaction transaction) async {
  final merchant = transaction.merchantName.trim();

  // 1. User corrections — reads 'learned_merchants' (same key as learning_service)
  if (merchant.isNotEmpty) {
    final learned = await getLearnedCategory(merchant);
    if (learned != null) return learned;
  }

  // 2. UPI-ID learning (learning_service reads 'upi_learning')
  final pm = transaction.paymentMethod.toLowerCase();
  if (pm.contains('upi') || pm.contains('upi id')) {
    final upiMatch = RegExp(r'[\w.\-+]+@[\w]+')
        .firstMatch(transaction.rawSms);
    if (upiMatch != null) {
      final upiId = upiMatch.group(0)!.toLowerCase();
      final upiCat = await ls.getLearnedUpi(upiId);
      if (upiCat != null) return upiCat;
    }
  }

  // 3. Learned patterns
  final patternCat = await ls.getLearnedPattern(transaction);
  if (patternCat != null) return patternCat;

  // 4. Curated merchant database
  if (merchant.isNotEmpty) {
    final dbCat = getMerchantCategory(merchant);
    if (dbCat != null) return dbCat;
  }

  // 5. Keyword classification
  if (merchant.isNotEmpty) {
    final kwCat = classifyByKeywords(merchant);
    if (kwCat != null) return kwCat;
  }

  return 'Other';
}
