import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

class ParsedTransaction {
  final double amount;
  final String type;   // 'debit' | 'credit'
  final String bank;
  final String rawText;
  final String suggestedCategory;

  const ParsedTransaction({
    required this.amount,
    required this.type,
    required this.bank,
    required this.rawText,
    required this.suggestedCategory,
  });
}

class SmsService {
  static final _tel = Telephony.instance;

  // Category keyword mapping
  static const _catKeywords = <String, List<String>>{
    'Rent/Housing'     : ['rent', 'housing', 'maintenance', 'society'],
    'Food & Groceries' : ['swiggy', 'zomato', 'bigbasket', 'grocer', 'supermarket', 'restaurant', 'cafe', 'food', 'milk', 'blinkit', 'zepto', 'dunzo'],
    'Transport'        : ['uber', 'ola', 'petrol', 'fuel', 'metro', 'rapido', 'irctc', 'train', 'bus', 'parking', 'fastag'],
    'Utilities'        : ['electricity', 'broadband', 'jio', 'airtel', 'vi ', 'bsnl', 'water', 'gas', 'recharge', 'dth', 'tata sky'],
    'Healthcare'       : ['hospital', 'clinic', 'pharmacy', 'medicine', 'apollo', 'netmeds', 'medplus', 'doctor'],
    'Entertainment'    : ['netflix', 'hotstar', 'prime', 'spotify', 'pvr', 'inox', 'movie', 'zee5', 'amazon prime'],
    'Shopping'         : ['amazon', 'flipkart', 'myntra', 'meesho', 'ajio', 'nykaa', 'reliance', 'mall'],
    'Education'        : ['school', 'college', 'fee', 'udemy', 'coursera', 'byjus', 'unacademy', 'tuition'],
  };

  static Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<List<ParsedTransaction>> readBankSms({int limit = 30}) async {
    final granted = await requestPermission();
    if (!granted) return [];

    final msgs = await _tel.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(SmsColumn.ADDRESS)
          .like('%BANK%')
          .or
          .where(SmsColumn.ADDRESS)
          .like('%PAY%'),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final results = <ParsedTransaction>[];

    for (final msg in msgs.take(limit)) {
      final parsed = _parse(msg.body ?? '', msg.address ?? '');
      if (parsed != null) results.add(parsed);
    }

    return results;
  }

  static ParsedTransaction? _parse(String body, String address) {
    final lower = body.toLowerCase();

    // Only process debit/transaction SMSes
    if (!_isTransactionSms(lower)) return null;

    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    final type = lower.contains('credit') ||
            lower.contains('credited') ||
            lower.contains('received')
        ? 'credit'
        : 'debit';

    final bank = _extractBank(address, lower);
    final category = _suggestCategory(lower);

    return ParsedTransaction(
      amount: amount,
      type: type,
      bank: bank,
      rawText: body,
      suggestedCategory: category,
    );
  }

  static bool _isTransactionSms(String lower) {
    final keywords = [
      'debited', 'credited', 'transaction', 'payment',
      'spent', 'used', 'transferred', 'withdrawn',
      'inr', 'rs.', '₹',
    ];
    return keywords.any((k) => lower.contains(k));
  }

  static double? _extractAmount(String body) {
    // Patterns: INR 1,234.56 | Rs.1234 | ₹ 1234 | Rs 1,234
    final patterns = [
      RegExp(r'(?:INR|Rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:INR|Rs)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        final raw = m.group(1)!.replaceAll(',', '');
        return double.tryParse(raw);
      }
    }
    return null;
  }

  static String _extractBank(String address, String lower) {
    final bankMap = {
      'HDFC'  : 'HDFC Bank',
      'ICICI' : 'ICICI Bank',
      'SBI'   : 'SBI',
      'AXIS'  : 'Axis Bank',
      'KOTAK' : 'Kotak Bank',
      'IDBI'  : 'IDBI Bank',
      'YES'   : 'Yes Bank',
      'PNB'   : 'PNB',
      'BOI'   : 'Bank of India',
      'PAYTM' : 'Paytm',
      'GPAY'  : 'Google Pay',
      'PHONEPE': 'PhonePe',
    };

    final upper = address.toUpperCase();
    for (final entry in bankMap.entries) {
      if (upper.contains(entry.key) || lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 'Bank';
  }

  static String _suggestCategory(String lower) {
    for (final entry in _catKeywords.entries) {
      if (entry.value.any((k) => lower.contains(k))) {
        return entry.key;
      }
    }
    return 'Other';
  }
}
