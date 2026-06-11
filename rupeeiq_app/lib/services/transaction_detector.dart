import '../models/sms_message.dart';

// Content-based detection only — no sender checks.
// Works regardless of which SMS app the user has installed.

const List<String> _contentKeywords = [
  // Currency symbols / codes
  '₹',
  'rs.',
  'inr',
  // Transaction verbs
  'debited',
  'credited',
  'transferred',
  'sent to',
  'received from',
  'withdrawn',
  'deposited',
  'paid',
  'payment',
  'purchase',
  'spent',
  'deducted',
  'charged',
  'refund',
  'cashback',
  // Payment rails
  'upi',
  'neft',
  'imps',
  'rtgs',
  // Account / balance markers
  'transaction',
  'a/c',
  'account',
  'balance',
];

const List<String> _debitKeywords = [
  'debited',
  'deducted',
  'spent',
  'paid',
  'sent to',
  'withdrawn',
  'purchase',
  'charged',
  'transferred to',
];

const List<String> _creditKeywords = [
  'credited',
  'received from',
  'deposited',
  'refund',
  'cashback',
  'reversed',
];

/// Returns true if [smsBody] looks like a financial SMS based on content alone.
/// Final validation (amount extraction) happens in extractTransaction().
bool isTransactionSms(String smsBody) {
  final lower = smsBody.toLowerCase();
  return _contentKeywords.any((kw) => lower.contains(kw));
}

/// Returns 'credit' if credit keywords appear first/at all, otherwise 'debit'.
String detectTransactionType(String smsBody) {
  final lower = smsBody.toLowerCase();
  if (_creditKeywords.any((kw) => lower.contains(kw))) return 'credit';
  if (_debitKeywords.any((kw) => lower.contains(kw))) return 'debit';
  return 'debit'; // safe default
}

/// Filters [allSms] to messages that look like financial transactions,
/// deduplicating by body + timestamp to avoid counting the same SMS twice.
List<SmsMessage> filterTransactionSms(List<SmsMessage> allSms) {
  final seen   = <String>{};
  final result = <SmsMessage>[];

  for (final m in allSms) {
    if (!isTransactionSms(m.body ?? '')) continue;

    final key =
        '${(m.body ?? '').trim()}|${m.date?.millisecondsSinceEpoch ?? 0}';
    if (seen.contains(key)) continue;

    seen.add(key);
    result.add(m);
  }

  return result;
}
