import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/sms_service.dart';
import '../widgets/metric_card.dart';

class AddDataScreen extends StatefulWidget {
  const AddDataScreen({super.key});
  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  final _incCtrl = TextEditingController();
  final _efCtrl  = TextEditingController(text: '0');
  final _form    = GlobalKey<FormState>();

  String _month     = _currentMonth();
  int    _year      = DateTime.now().year;
  bool   _loading   = false;
  bool   _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _loans     = [];
  List<String>               _categories= [];
  List<String>               _months    = [];

  final List<_ExpenseRow> _expenses = [_ExpenseRow()];

  // SMS
  bool _smsLoading = false;
  List<ParsedTransaction> _smsTxns = [];
  bool _showSms = false;

  static String _currentMonth() {
    const names = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return names[DateTime.now().month - 1];
  }

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _incCtrl.dispose(); _efCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getFormData();
      setState(() {
        _loans      = List<Map<String, dynamic>>.from(d['loans'] ?? []);
        _categories = List<String>.from(d['categories'] ?? []);
        _months     = List<String>.from(d['months'] ?? []);
        if (_months.isNotEmpty && !_months.contains(_month)) _month = _months.first;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _readSms() async {
    setState(() { _smsLoading = true; _showSms = true; });
    final txns = await SmsService.readBankSms(limit: 20);
    setState(() { _smsTxns = txns; _smsLoading = false; });
  }

  void _applyTxn(ParsedTransaction txn) {
    if (txn.type == 'debit') {
      final row = _ExpenseRow();
      row.nameCtrl.text   = txn.bank;
      row.amountCtrl.text = txn.amount.toStringAsFixed(0);
      row.category        = _categories.contains(txn.suggestedCategory)
          ? txn.suggestedCategory
          : (_categories.isNotEmpty ? _categories.first : 'Other');
      setState(() { _expenses.add(row); _showSms = false; });
    } else if (txn.type == 'credit') {
      _incCtrl.text = txn.amount.toStringAsFixed(0);
      setState(() => _showSms = false);
    }
  }

  double get _activeEmi {
    double total = 0;
    final mo = _months.indexOf(_month) + 1;
    final yr = _year;
    const mOrd = {
      'January':1,'February':2,'March':3,'April':4,'May':5,'June':6,
      'July':7,'August':8,'September':9,'October':10,'November':11,'December':12
    };

    for (final loan in _loans) {
      final sm = loan['start_month'] as String?;
      final sy = loan['start_year'] as int?;
      final ten= loan['tenure_months'] as int?;
      if (sm == null || sy == null || ten == null) {
        total += (loan['emi'] as num? ?? 0).toDouble();
        continue;
      }
      final smN = mOrd[sm] ?? 1;
      final start = sy * 12 + smN - 1;
      final end   = start + ten - 1;
      final given = yr * 12 + mo - 1;
      if (start <= given && given <= end) {
        total += (loan['emi'] as num? ?? 0).toDouble();
      }
    }
    return total;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _submitting = true; _error = null; });

    final expenses = _expenses
        .where((r) => r.nameCtrl.text.trim().isNotEmpty && double.tryParse(r.amountCtrl.text) != null)
        .map((r) => {
              'name'    : r.nameCtrl.text.trim(),
              'category': r.category,
              'type'    : r.type,
              'amount'  : double.parse(r.amountCtrl.text),
            })
        .toList();

    try {
      final result = await ApiService.addData(
        income      : double.parse(_incCtrl.text),
        month       : _month,
        year        : _year,
        expenses    : expenses,
        emergencyFund: double.tryParse(_efCtrl.text) ?? 0,
      );
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => _ResultScreen(result: result)));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to submit. Check connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());

    final emi    = _activeEmi;
    final income = double.tryParse(_incCtrl.text) ?? 0;
    final expSum = _expenses.fold<double>(0,
        (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
    final savings = income - expSum - emi;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Monthly Data'),
        actions: [
          IconButton(
            tooltip: 'Read from SMS',
            icon: const Icon(Icons.sms_outlined),
            onPressed: _readSms,
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                _errorBanner(_error!),
                const SizedBox(height: 12),
              ],

              // SMS sheet
              if (_showSms) _buildSmsSheet(),

              // Income card
              _card(
                title: 'Income Details',
                icon: Icons.attach_money,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 2, child: _inputField(_incCtrl, 'Monthly Income ₹',
                            keyboard: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final d = double.tryParse(v);
                              if (d == null || d <= 0) return 'Invalid';
                              return null;
                            })),
                        const SizedBox(width: 10),
                        Expanded(child: _monthDropdown()),
                        const SizedBox(width: 10),
                        Expanded(child: _inputField(
                          TextEditingController(text: _year.toString()),
                          'Year',
                          keyboard: TextInputType.number,
                          onChanged: (v) { final y = int.tryParse(v); if (y != null) setState(() => _year = y); },
                        )),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Expenses card
              _card(
                title: 'Expenses',
                icon: Icons.receipt_long_outlined,
                child: Column(
                  children: [
                    // Headers
                    Row(
                      children: const [
                        Expanded(flex: 2, child: Text('Name', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        SizedBox(width: 6),
                        Expanded(flex: 2, child: Text('Category', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        SizedBox(width: 6),
                        Expanded(child: Text('Amount', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        SizedBox(width: 28),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._expenses.asMap().entries.map((e) => _expenseRow(e.key, e.value)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _expenses.add(_ExpenseRow())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.green.withOpacity(0.4), style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: AppColors.green, size: 18),
                            SizedBox(width: 6),
                            Text('Add Expense', style: TextStyle(color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // EMI preview
              if (_loans.isNotEmpty)
                _card(
                  title: 'Loans & EMI',
                  icon: Icons.credit_card_outlined,
                  child: Column(
                    children: [
                      ..._loans.map((l) => _loanRow(l)),
                      const Divider(color: AppColors.border, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Active EMI this month', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                          Text('−₹${NumberFormat('#,##,##0').format(emi)}',
                              style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Savings preview
              if (income > 0)
                _savingsPreview(income, expSum, emi, savings),

              const SizedBox(height: 12),

              // Emergency fund
              _card(
                title: 'Emergency Fund',
                icon: Icons.shield_outlined,
                child: _inputField(_efCtrl, 'Existing emergency fund ₹',
                    keyboard: TextInputType.number),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                      : const Icon(Icons.analytics_outlined, size: 20),
                  label: Text(_submitting ? 'Analyzing…' : 'Analyze My Finances'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmsSheet() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.indigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Bank Transactions',
                  style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
              GestureDetector(
                  onTap: () => setState(() => _showSms = false),
                  child: const Icon(Icons.close, color: AppColors.textSub, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          if (_smsLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2)),
            )
          else if (_smsTxns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No bank SMS found', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
            )
          else
            ..._smsTxns.take(6).map((t) => GestureDetector(
              onTap: () => _applyTxn(t),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      t.type == 'debit' ? Icons.arrow_upward : Icons.arrow_downward,
                      color: t.type == 'debit' ? AppColors.red : AppColors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${t.bank} — ${t.suggestedCategory}',
                              style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(t.rawText.length > 50 ? '${t.rawText.substring(0, 50)}…' : t.rawText,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text('₹${NumberFormat('#,##,##0').format(t.amount)}',
                        style: TextStyle(
                            color: t.type == 'debit' ? AppColors.red : AppColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.add_circle_outline, color: AppColors.green, size: 16),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _loanRow(Map loan) {
    final name = loan['loan_name'] ?? loan['loan_type'] ?? 'Loan';
    final emi  = loan['emi'] as num? ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
          Text('−₹${NumberFormat('#,##,##0').format(emi)}',
              style: const TextStyle(color: AppColors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _savingsPreview(double income, double expSum, double emi, double savings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          _previewRow('Monthly Income', '₹${NumberFormat('#,##,##0').format(income)}', AppColors.green),
          _previewRow('Expenses', '−₹${NumberFormat('#,##,##0').format(expSum)}', AppColors.red),
          if (emi > 0)
            _previewRow('Active EMI', '−₹${NumberFormat('#,##,##0').format(emi)}', AppColors.amber),
          const Divider(color: AppColors.green, height: 16),
          _previewRow('Estimated Savings', '₹${NumberFormat('#,##,##0').format(savings)}',
              savings >= 0 ? AppColors.green : AppColors.red, bold: true),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
              color: bold ? AppColors.text : AppColors.textSub, fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _expenseRow(int idx, _ExpenseRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: TextFormField(
            controller: row.nameCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(hintText: 'e.g. Rent', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: DropdownButtonFormField<String>(
            value: _categories.contains(row.category) ? row.category : (_categories.isNotEmpty ? _categories.first : 'Other'),
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            items: (_categories.isEmpty ? ['Other'] : _categories)
                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) => setState(() => row.category = v!),
          )),
          const SizedBox(width: 6),
          Expanded(child: TextFormField(
            controller: row.amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(hintText: '₹', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 4),
          if (_expenses.length > 1)
            GestureDetector(
              onTap: () => setState(() => _expenses.removeAt(idx)),
              child: const Icon(Icons.close, color: AppColors.red, size: 18),
            )
          else
            const SizedBox(width: 18),
        ],
      ),
    );
  }

  Widget _monthDropdown() {
    final list = _months.isEmpty
        ? ['January','February','March','April','May','June','July','August','September','October','November','December']
        : _months;
    return DropdownButtonFormField<String>(
      value: list.contains(_month) ? _month : list.first,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
      items: list.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (v) => setState(() => _month = v!),
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: AppColors.green, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          validator: validator,
          onChanged: onChanged ?? (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(color: AppColors.red, fontSize: 13))),
          ],
        ),
      );
}

class _ExpenseRow {
  final nameCtrl   = TextEditingController();
  final amountCtrl = TextEditingController();
  String category  = 'Other';
  String type      = 'Variable';
}

// ── Results Screen ─────────────────────────────────────────────────────────────

class _ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultScreen({required this.result});

  String _fmt(num? v) =>
      v == null ? '—' : '₹${NumberFormat('#,##,##0', 'en_IN').format(v)}';

  @override
  Widget build(BuildContext context) {
    final metrics = result['metrics'] as Map? ?? {};
    final advice  = result['advice']  as List? ?? [];
    final inactive= result['inactive_loans'] as List? ?? [];
    final month   = result['month'] ?? '';
    final year    = result['year']  ?? '';
    final hd      = metrics['health_data'] as Map? ?? {};
    final grade   = hd['grade'] ?? 'F';
    final score   = metrics['health_score'] ?? 0;
    final gradeColor = {'A': AppColors.green, 'B': AppColors.green,
        'C': AppColors.amber, 'D': AppColors.red, 'F': AppColors.red}[grade] ?? AppColors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text('Report — $month $year'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Metrics grid
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(value: _fmt(metrics['income'] as num?), label: 'Income', valueColor: AppColors.green),
                MetricCard(value: _fmt(metrics['total_expenses'] as num?), label: 'Expenses', valueColor: AppColors.red),
                MetricCard(
                  value: _fmt(metrics['savings'] as num?),
                  label: 'Savings',
                  valueColor: (metrics['savings'] as num? ?? 0) >= 0 ? AppColors.green : AppColors.red,
                ),
                MetricCard(
                  value: '${metrics['savings_rate'] ?? 0}%',
                  label: 'Savings Rate',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Health score hero
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF0C1A10)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text('$score', style: TextStyle(color: gradeColor, fontSize: 56, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(grade, style: TextStyle(color: gradeColor, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(hd['status'] ?? '', style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(hd['summary'] ?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // EMI section
            if ((metrics['total_emi'] as num? ?? 0) > 0 || inactive.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active EMI Deductions', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),
                    ...(metrics['loans'] as List? ?? []).map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l['loan_name'] ?? l['type'] ?? 'Loan',
                              style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
                          Text('−${_fmt(l['emi'] as num?)}',
                              style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    )),
                    if (inactive.isNotEmpty) ...[
                      const Divider(color: AppColors.border, height: 14),
                      const Text('Skipped (not active this month):', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ...inactive.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l['loan_name'] ?? l['type'] ?? '',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            Text(l['status_note'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Advice
            const Text('Financial Advice', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...advice.map((a) => _AdviceTile(a: a as Map)),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceTile extends StatelessWidget {
  final Map a;
  const _AdviceTile({required this.a});

  Color get _bg {
    switch (a['type']) {
      case 'success': return AppColors.green.withOpacity(0.08);
      case 'warning': return AppColors.amber.withOpacity(0.08);
      case 'danger' : return AppColors.red.withOpacity(0.08);
      default       : return AppColors.indigo.withOpacity(0.08);
    }
  }

  Color get _border {
    switch (a['type']) {
      case 'success': return AppColors.green.withOpacity(0.3);
      case 'warning': return AppColors.amber.withOpacity(0.3);
      case 'danger' : return AppColors.red.withOpacity(0.3);
      default       : return AppColors.indigo.withOpacity(0.3);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a['icon'] ?? '💡', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['title'] ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(a['message'] ?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}
