class Transaction {
  final String id;
  final double amount;
  final String merchantName;
  final DateTime dateTime;
  final String type; // 'debit' or 'credit'
  final double? availableBalance;
  final String paymentMethod;
  final String rawSms;
  final String sender;
  String category; // mutable — assigned in Step 5

  Transaction({
    required this.id,
    required this.amount,
    required this.merchantName,
    required this.dateTime,
    required this.type,
    this.availableBalance,
    required this.paymentMethod,
    required this.rawSms,
    required this.sender,
    this.category = 'Other',
  });
}
