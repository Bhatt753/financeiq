import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

// All Android SMS apps (Google Messages, Samsung Messages, Motorola, etc.)
// store messages in the same content://sms/inbox URI, so no sender filtering
// is needed. Content-based detection is handled by transaction_detector.dart.

const int _kMaxScan    = 500; // max messages fetched from inbox
const int _kDays       = 90;  // lookback window in days
const int _kTimeoutSec = 30;  // abort if inbox query hangs

/// Returns up to [_kMaxScan] inbox messages from the last [_kDays] days.
/// No sender filter — works with every SMS app on every Android device.
/// [onProgress] receives (messagesScanned, totalKept) after each batch of 25.
/// Yields to the UI thread every 25 messages so the screen stays responsive.
Future<List<SmsMessage>> getRecentBankSms({
  void Function(int scanned, int found)? onProgress,
}) async {
  List<SmsMessage> all;
  try {
    all = await SmsQuery()
        .querySms(kinds: [SmsQueryKind.inbox], count: _kMaxScan)
        .timeout(const Duration(seconds: _kTimeoutSec), onTimeout: () => []);
  } catch (_) {
    all = [];
  }

  final cutoff  = DateTime.now().subtract(const Duration(days: _kDays));
  final results = <SmsMessage>[];
  final total   = all.length;

  for (var i = 0; i < total; i++) {
    final m = all[i];
    // Keep messages within the 90-day window; undated messages are included
    // and will be dropped later if no amount is found.
    if (m.date == null || m.date!.isAfter(cutoff)) {
      results.add(m);
    }
    if (i % 25 == 0 || i == total - 1) {
      onProgress?.call(i + 1, results.length);
      await Future.delayed(Duration.zero); // yield to UI thread
    }
  }

  return results;
}

/// Simple single-call read — no sender filter, no date filter.
/// Used when the caller just needs the raw inbox list quickly.
Future<List<SmsMessage>> readAllSms() async {
  try {
    return await SmsQuery()
        .querySms(kinds: [SmsQueryKind.inbox], count: _kMaxScan)
        .timeout(const Duration(seconds: _kTimeoutSec), onTimeout: () => []);
  } catch (_) {
    return [];
  }
}
