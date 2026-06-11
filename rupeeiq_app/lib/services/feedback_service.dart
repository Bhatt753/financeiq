import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/transaction.dart';

const _storage = FlutterSecureStorage();
const _kStatsKey = 'feedback_stats';

// Stored JSON shape:
// {
//   "total_shown": 100,
//   "corrections": 15,
//   "merchants_corrected": {"swiggy": 2, "local shop": 1}
// }

// ── Write ─────────────────────────────────────────────────────────────────────

/// Call when a transaction was categorised and the user CHANGED the category.
Future<void> recordCorrection(
    Transaction transaction, String correctCategory) async {
  try {
    final stats     = await _load();
    stats['corrections'] = (stats['corrections'] as int? ?? 0) + 1;
    stats['total_shown'] = (stats['total_shown'] as int? ?? 0) + 1;

    final merchants = Map<String, dynamic>.from(
        stats['merchants_corrected'] as Map? ?? {});
    final key = transaction.merchantName.toLowerCase().trim();
    merchants[key] = (merchants[key] as int? ?? 0) + 1;
    stats['merchants_corrected'] = merchants;

    await _save(stats);
  } catch (_) {}
}

/// Call when a transaction was categorised and the user DID NOT change it.
Future<void> recordCorrectCategorization() async {
  try {
    final stats     = await _load();
    stats['total_shown'] = (stats['total_shown'] as int? ?? 0) + 1;
    await _save(stats);
  } catch (_) {}
}

// ── Read ──────────────────────────────────────────────────────────────────────

/// Returns aggregated learning statistics.
/// [merchantsLearned] should be passed from learning_service.getMerchantsLearnedCount().
Future<Map<String, dynamic>> getLearningStats(int merchantsLearned) async {
  try {
    final stats     = await _load();
    final total     = stats['total_shown']  as int? ?? 0;
    final corrected = stats['corrections']  as int? ?? 0;
    final correct   = total - corrected;
    final accuracy  = total > 0 ? (correct / total) * 100.0 : 0.0;

    final merchants = Map<String, dynamic>.from(
        stats['merchants_corrected'] as Map? ?? {});
    String? topCorrected;
    int     topCount = 0;
    for (final e in merchants.entries) {
      if ((e.value as int) > topCount) {
        topCount     = e.value as int;
        topCorrected = e.key;
      }
    }

    return {
      'correctionsThisMonth': corrected,
      'merchantsLearned':     merchantsLearned,
      'accuracyRate':         accuracy,
      'totalCategorized':     total,
      'topCorrectedMerchant': topCorrected,
    };
  } catch (_) {
    return {
      'correctionsThisMonth': 0,
      'merchantsLearned':     merchantsLearned,
      'accuracyRate':         0.0,
      'totalCategorized':     0,
      'topCorrectedMerchant': null,
    };
  }
}

// ── Private ───────────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> _load() async {
  try {
    final raw = await _storage.read(key: _kStatsKey);
    if (raw == null || raw.isEmpty) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return {};
  }
}

Future<void> _save(Map<String, dynamic> stats) async {
  try {
    await _storage.write(key: _kStatsKey, value: jsonEncode(stats));
  } catch (_) {}
}
