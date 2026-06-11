import '../models/sms_message.dart';
import '../models/transaction.dart';
import 'merchant_classifier.dart';
import 'transaction_detector.dart';

// ── Amount patterns ────────────────────────────────────────────────────────
// Exact match to sms_parser.py BANK_PATTERNS — ordered most-specific first.

final List<RegExp> _amountPatterns = [
  // currency + amount + debit verb
  RegExp(
    r'(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:debited|deducted|spent|paid)',
    caseSensitive: false,
  ),
  // debit verb + currency + amount
  RegExp(
    r'(?:debited|deducted|spent|paid)\s*(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)',
    caseSensitive: false,
  ),
  // currency + amount + credit verb
  RegExp(
    r'(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*credited',
    caseSensitive: false,
  ),
  // credit verb + currency + amount
  RegExp(
    r'(?:credited|received)\s*(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)',
    caseSensitive: false,
  ),
  // Fallback: any amount after a currency symbol
  RegExp(
    r'(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)',
    caseSensitive: false,
  ),
];

// ── Merchant patterns ──────────────────────────────────────────────────────
// "trf to" checked before bare "to" to avoid over-matching.

final List<RegExp> _merchantPatterns = [
  RegExp(
    r'\btrf\s+to\s+([A-Za-z0-9][A-Za-z0-9 &./\-]{2,28}?)(?=\s+on|\s+via|\s+Ref|[.,;\n]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'\bat\s+([A-Za-z0-9][A-Za-z0-9 &./\-]{2,28}?)(?=\s+on|\s+via|\s+Ref|\s+for|[.,;\n]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'\bto\s+([A-Za-z0-9][A-Za-z0-9 &./\-]{2,28}?)(?=\s+on|\s+via|\s+Ref|\s+for|[.,;\n]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'@\s*([A-Za-z0-9][A-Za-z0-9 &./\-]{2,28}?)(?=\s+on|\s+via|\s+Ref|[.,;\n]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'Info:\s*([A-Za-z0-9][A-Za-z0-9 &./\-]{2,28}?)(?=\s+on|\s+via|\s+Ref|[.,;\n]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'UPI[-/]([A-Za-z0-9][A-Za-z0-9 &./\-]{2,28}?)(?=[.,;\s\n]|$)',
    caseSensitive: false,
  ),
];

// ── Date patterns ──────────────────────────────────────────────────────────

final RegExp _dateLong  = RegExp(r'(\d{2})[/\-](\d{2})[/\-](\d{4})');
final RegExp _dateShort = RegExp(r'(\d{2})[/\-](\d{2})[/\-](\d{2})(?!\d)');

// ── Balance patterns ───────────────────────────────────────────────────────

final RegExp _balancePattern = RegExp(
  r'(?:Avl\.?\s*Bal\.?|Available\s+[Bb]al(?:ance)?|Bal\.?)\s*:?\s*(?:Rs\.?|INR|₹)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
  caseSensitive: false,
);

// ── Public functions ───────────────────────────────────────────────────────

double? extractAmount(String smsBody) {
  for (final pattern in _amountPatterns) {
    final match = pattern.firstMatch(smsBody);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '');
      final value = double.tryParse(raw);
      if (value != null && value > 0) return value;
    }
  }
  return null;
}

String? extractMerchant(String smsBody) {
  for (final pattern in _merchantPatterns) {
    final match = pattern.firstMatch(smsBody);
    if (match != null) {
      final name = match.group(1)!.trim();
      if (name.length < 2) continue;
      return name.length > 30 ? name.substring(0, 30).trim() : name;
    }
  }
  return null;
}

DateTime extractDate(String smsBody, DateTime fallback) {
  // Try DD-MM-YYYY first (4-digit year, unambiguous)
  final long = _dateLong.firstMatch(smsBody);
  if (long != null) {
    final day   = int.tryParse(long.group(1)!) ?? 0;
    final month = int.tryParse(long.group(2)!) ?? 0;
    final year  = int.tryParse(long.group(3)!) ?? 0;
    if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year > 2000) {
      return DateTime(year, month, day);
    }
  }
  // Try DD-MM-YY (2-digit year → add 2000)
  final short = _dateShort.firstMatch(smsBody);
  if (short != null) {
    final day   = int.tryParse(short.group(1)!) ?? 0;
    final month = int.tryParse(short.group(2)!) ?? 0;
    final yy    = int.tryParse(short.group(3)!) ?? 0;
    if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
      return DateTime(2000 + yy, month, day);
    }
  }
  return fallback;
}

double? extractBalance(String smsBody) {
  final match = _balancePattern.firstMatch(smsBody);
  if (match != null) {
    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }
  return null;
}

String extractPaymentMethod(String smsBody) {
  final lower = smsBody.toLowerCase();
  if (lower.contains('upi'))         return 'UPI';
  if (lower.contains('neft'))        return 'NEFT';
  if (lower.contains('imps'))        return 'IMPS';
  if (lower.contains('atm'))         return 'ATM';
  if (lower.contains('card'))        return 'Card';
  if (lower.contains('net banking')) return 'Net Banking';
  return 'Bank Transfer';
}

Future<Transaction?> extractTransaction(SmsMessage sms) async {
  final body   = sms.body    ?? '';
  final sender = sms.address ?? '';

  if (!isTransactionSms(body)) return null;

  final amount = extractAmount(body);
  if (amount == null) return null;

  final merchant  = extractMerchant(body) ?? sender;
  final date      = extractDate(body, sms.date ?? DateTime.now());
  final balance   = extractBalance(body);
  final method    = extractPaymentMethod(body);
  final type      = detectTransactionType(body);
  final category  = await classifyMerchant(merchant);

  // ID: sender + timestamp + amount — unique without external packages
  final id = '${sender.replaceAll(RegExp(r'\W'), '')}_'
      '${date.millisecondsSinceEpoch}_'
      '${amount.toStringAsFixed(0)}';

  return Transaction(
    id:               id,
    amount:           amount,
    merchantName:     merchant,
    dateTime:         date,
    type:             type,
    availableBalance: balance,
    paymentMethod:    method,
    rawSms:           body,
    sender:           sender,
    category:         category,
  );
}
