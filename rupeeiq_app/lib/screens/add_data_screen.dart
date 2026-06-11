import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/finance_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'results_screen.dart';
import 'sms_import_screen.dart';

// Month order matching Python's MONTH_ORDER dict in loan_engine.py
const _kMonthOrder = {
  'January': 1,  'February': 2, 'March': 3,     'April': 4,
  'May': 5,      'June': 6,    'July': 7,        'August': 8,
  'September': 9,'October': 10,'November': 11,   'December': 12,
};

const _kCategories = [
  _Cat('Rent / Housing', 'Rent/Housing', Icons.home_outlined),
  _Cat('Food & Groceries', 'Food & Groceries', Icons.restaurant_outlined),
  _Cat('Transport', 'Transport', Icons.directions_car_outlined),
  _Cat('Utilities & Bills', 'Utilities', Icons.bolt_outlined),
  _Cat('Healthcare', 'Healthcare', Icons.local_hospital_outlined),
  _Cat('Entertainment', 'Entertainment', Icons.movie_outlined),
  _Cat('Shopping', 'Shopping', Icons.shopping_bag_outlined),
  _Cat('Education', 'Education', Icons.school_outlined),
  _Cat('Other', 'Other', Icons.category_outlined),
];

class _Cat {
  final String label;
  final String category;
  final IconData icon;
  const _Cat(this.label, this.category, this.icon);
}

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class AddDataScreen extends StatefulWidget {
  const AddDataScreen({super.key});

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _incomeCtrl = TextEditingController();
  final _efCtrl = TextEditingController();

  late final List<TextEditingController> _catCtrls;

  List<Map<String, dynamic>> _loans = [];
  bool _loadingFormData = true;
  bool _submitting = false;
  String? _error;

  late String _selectedMonth;
  late String _selectedYear;

  @override
  void initState() {
    super.initState();
    _catCtrls =
        List.generate(_kCategories.length, (_) => TextEditingController());
    final now = DateTime.now();
    _selectedMonth = _kMonths[now.month - 1];
    _selectedYear = now.year.toString();
    _loadFormData();
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _efCtrl.dispose();
    for (final c in _catCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _loadingFormData = true);
    try {
      final res = await ApiService.getFormData();
      setState(() {
        _loans =
            List<Map<String, dynamic>>.from(res['loans'] as List? ?? []);
        _loadingFormData = false;
      });
    } catch (_) {
      setState(() => _loadingFormData = false);
    }
  }

  double get _income => double.tryParse(_incomeCtrl.text) ?? 0;
  double get _totalCatExpenses =>
      _catCtrls.fold(0.0, (s, c) => s + (double.tryParse(c.text) ?? 0));

  // Mirrors Python's get_active_loans_for_month from loan_engine.py:
  // only include loans whose start–tenure window covers the selected month.
  List<Map<String, dynamic>> get _activeLoansForMonth {
    final targetYear = int.tryParse(_selectedYear) ?? DateTime.now().year;
    final targetMonthNum = _kMonthOrder[_selectedMonth] ?? DateTime.now().month;
    final targetNum = targetYear * 12 + targetMonthNum;
    return _loans.where((loan) {
      final sm = loan['start_month'] as String?;
      final sy = loan['start_year'];
      final tenure = loan['tenure_months'];
      // Graceful fallback: if loan lacks date fields, always include it.
      if (sm == null || sy == null || tenure == null) return true;
      final startNum =
          (sy as num).toInt() * 12 + (_kMonthOrder[sm] ?? 1);
      final endNum = startNum + (tenure as num).toInt() - 1;
      return startNum <= targetNum && targetNum <= endNum;
    }).toList();
  }

  double get _totalEMI => _activeLoansForMonth.fold(
      0.0, (s, l) => s + (l['emi'] as num? ?? 0).toDouble());
  double get _totalExpenses => _totalCatExpenses + _totalEMI;
  double get _savings => _income - _totalExpenses;

  List<Map<String, dynamic>> _buildExpensesList() {
    return [
      for (var i = 0; i < _kCategories.length; i++)
        if ((double.tryParse(_catCtrls[i].text) ?? 0) > 0)
          {
            'name': _kCategories[i].label,
            'category': _kCategories[i].category,
            'type': 'Variable',
            'amount': double.tryParse(_catCtrls[i].text) ?? 0,
          }
    ];
  }

  static const _categoryIndex = {
    'Rent/Housing': 0,
    'Food & Groceries': 1,
    'Transport': 2,
    'Utilities': 3,
    'Healthcare': 4,
    'Entertainment': 5,
    'Shopping': 6,
    'Education': 7,
  };

  Future<void> _openSmsImport() async {
    final result = await Navigator.push<List<Transaction>>(
      context,
      MaterialPageRoute(builder: (_) => const SmsImportScreen()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _applyTransactions(result);
    }
  }

  void _applyTransactions(List<Transaction> transactions) {
    int count = 0;
    for (final txn in transactions) {
      if (txn.type != 'debit') continue;
      final idx = _categoryIndex[txn.category] ?? 8;
      final existing = double.tryParse(_catCtrls[idx].text) ?? 0;
      _catCtrls[idx].text = (existing + txn.amount).toStringAsFixed(0);
      count++;
    }
    unawaited(saveTransactions(
        _selectedMonth, int.parse(_selectedYear), transactions));
    setState(() {});
    if (mounted && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$count expense${count == 1 ? '' : 's'} imported. Enter income and tap Save & Analyse.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final res = await ApiService.addFinanceEntry(
        month: _selectedMonth,
        year: int.parse(_selectedYear),
        income: _income,
        expenses: _buildExpensesList(),
        emergencyFund: double.tryParse(_efCtrl.text) ?? 0,
      );
      if (res['error'] != null) {
        setState(() { _error = res['error'] as String; _submitting = false; });
      } else {
        setState(() => _submitting = false);
        _clearForm();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ResultsScreen(data: res)),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Submission failed. Check your connection.';
        _submitting = false;
      });
    }
  }

  void _clearForm() {
    _incomeCtrl.clear();
    _efCtrl.clear();
    for (final c in _catCtrls) c.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFormData) {
      return const Scaffold(body: LoadingView());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Monthly Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sms_outlined),
            tooltip: 'Import from SMS',
            onPressed: _openSmsImport,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            if (_error != null)
              _banner(_error!, AppColors.red, AppColors.redBorder,
                  Icons.error_outline),
            _buildMonthYearPicker(),
            const SizedBox(height: 14),
            _buildIncomeField(),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _openSmsImport,
              icon: const Icon(Icons.sms_outlined, size: 16),
              label: const Text('Import from SMS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 14),
            _buildExpenseSection(),
            if (_activeLoansForMonth.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildLoansSection(),
            ],
            const SizedBox(height: 14),
            _buildEFField(),
            if (_income > 0) ...[
              const SizedBox(height: 14),
              _buildPreview(),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save & Analyse'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _banner(String msg, Color color, Color borderColor, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildMonthYearPicker() {
    final years =
        List.generate(5, (i) => (DateTime.now().year - 2 + i).toString());
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: _selectedMonth,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text, fontSize: 14),
            decoration: const InputDecoration(labelText: 'Month'),
            items: _kMonths
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) =>
                setState(() => _selectedMonth = v ?? _selectedMonth),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedYear,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text, fontSize: 14),
            decoration: const InputDecoration(labelText: 'Year'),
            items: years
                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                .toList(),
            onChanged: (v) =>
                setState(() => _selectedYear = v ?? _selectedYear),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeField() {
    return TextFormField(
      controller: _incomeCtrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.text),
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Monthly Income (₹)',
        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
      ),
      validator: (v) =>
          v == null || v.isEmpty ? 'Income is required' : null,
    );
  }

  Widget _buildExpenseSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expenses by Category',
              style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...List.generate(_kCategories.length, (i) {
            final cat = _kCategories[i];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: i < _kCategories.length - 1 ? 10 : 0),
              child: TextFormField(
                controller: _catCtrls[i],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.text),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: cat.label,
                  prefixIcon: Icon(cat.icon, size: 20),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLoansSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amberBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.credit_card_outlined,
                  color: AppColors.amber, size: 16),
              SizedBox(width: 6),
              Text('Active EMI Deductions',
                  style: TextStyle(
                      color: AppColors.amberText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ..._activeLoansForMonth.map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l['loan_name'] as String? ?? 'Loan',
                        style: const TextStyle(
                            color: AppColors.textMid, fontSize: 13)),
                    Text(formatCurrency(l['emi']),
                        style: const TextStyle(
                            color: AppColors.amber,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total EMI',
                  style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(formatCurrency(_totalEMI),
                  style: const TextStyle(
                      color: AppColors.amber,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEFField() {
    return TextFormField(
      controller: _efCtrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.text),
      decoration: const InputDecoration(
        labelText: 'Emergency Fund (₹)',
        prefixIcon: Icon(Icons.shield_outlined),
        helperText: 'Total emergency fund saved so far',
      ),
    );
  }

  Widget _buildPreview() {
    final metrics = calculateMetrics(
        _income, _buildExpensesList(), _activeLoansForMonth);
    final savings = (metrics['savings'] as num).toDouble();
    final rate = (metrics['savings_rate'] as num).toDouble();
    final expRatio = (metrics['expense_ratio'] as num).toDouble();
    final totalExp = (metrics['total_expenses'] as num).toDouble();
    final totalEmi = (metrics['total_emi'] as num).toDouble();
    final isPositive = savings >= 0;
    final color = isPositive ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPositive ? AppColors.surfaceGreen : AppColors.redBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPositive ? AppColors.borderGreen : AppColors.redBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_outlined, color: color, size: 14),
              const SizedBox(width: 6),
              Text('Live Preview',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(
              label: 'Income',
              value: formatCurrency(_income),
              valueColor: AppColors.indigo),
          InfoRow(
              label: 'Expenses',
              value: formatCurrency(totalExp),
              valueColor: AppColors.red),
          if (totalEmi > 0)
            InfoRow(
                label: 'EMI',
                value: formatCurrency(totalEmi),
                valueColor: AppColors.amber),
          const Divider(height: 12),
          InfoRow(
              label: 'Savings',
              value: formatCurrency(savings),
              valueColor: color),
          InfoRow(
              label: 'Savings Rate',
              value: '${rate.toStringAsFixed(1)}%',
              valueColor: color),
          InfoRow(
              label: 'Expense Ratio',
              value: '${expRatio.toStringAsFixed(1)}%',
              valueColor: AppColors.textSub),
        ],
      ),
    );
  }
}

