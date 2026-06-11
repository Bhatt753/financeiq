import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/finance_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

const _kLoanTypes = [
  'Personal Loan', 'Home Loan', 'Car Loan', 'Education Loan',
  'Gold Loan', 'Business Loan', 'Other',
];

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  // loans: raw list, analysis: {loans: [analyzed], total_emi, total_outstanding, ...}
  List<dynamic> _rawLoans = [];
  List<dynamic> _analyzedLoans = [];
  Map<String, dynamic> _analysis = {};
  List<dynamic> _advice = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getLoans();
      if (res['error'] != null) {
        setState(() { _error = res['error'] as String; _loading = false; });
        return;
      }
      final rawList = res['loans'] as List? ?? [];

      // Compute loan analysis locally using reducing-balance method
      final analyzed = rawList.map((r) {
        final raw = r as Map<String, dynamic>;
        try {
          final a = analyzeSingleLoan(raw);
          a['loan_id'] =
              ((raw['id'] ?? raw['loan_id'] ?? 0) as num).toInt();
          return a;
        } catch (_) {
          // Fallback: keep raw data if local analysis fails
          return <String, dynamic>{
            ...raw,
            'loan_id': ((raw['id'] ?? raw['loan_id'] ?? 0) as num).toInt(),
            'outstanding': raw['outstanding'] ?? 0,
            'principal_paid': raw['principal_paid'] ?? 0,
            'progress_pct': raw['progress_pct'] ?? 0,
            'payoff_date': raw['payoff_date'] ?? '',
            'months_remaining': raw['months_remaining'] ?? 0,
            'monthly_breakdown': raw['monthly_breakdown'] ?? <dynamic>[],
            'is_completed': raw['is_completed'] ?? false,
          };
        }
      }).toList();

      final totalEmi = analyzed.fold<double>(
          0.0, (s, l) => s + ((l as Map)['emi'] as num).toDouble());
      final totalOutstanding = analyzed.fold<double>(
          0.0, (s, l) => s + ((l as Map)['outstanding'] as num).toDouble());

      setState(() {
        _rawLoans = rawList;
        _analyzedLoans = analyzed;
        _analysis = {
          'total_emi': totalEmi,
          'total_outstanding': totalOutstanding,
        };
        _advice = res['advice'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load loans.'; _loading = false; });
    }
  }

  Future<void> _delete(int id) async {
    try {
      await ApiService.deleteLoan(id);
      _load();
    } catch (_) {}
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddLoanSheet(onSave: (data) async {
        Navigator.pop(context);
        try {
          await ApiService.addLoan(
            loanName: data['loan_name'] as String,
            loanType: data['loan_type'] as String,
            principal: data['principal'] as double,
            emi: data['emi'] as double,
            interestRate: data['interest_rate'] as double,
            tenureMonths: data['tenure_months'] as int,
            startMonth: data['start_month'] as String,
            startYear: data['start_year'] as int,
          );
          _load();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to add loan.')),
            );
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Tracker'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        child: const Icon(Icons.add),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        child: _loading
            ? const ShimmerLoadingView(key: ValueKey('shimmer'))
            : _error != null
                ? ErrorView(
                    key: const ValueKey('error'),
                    message: _error!,
                    onRetry: _load)
                : RefreshIndicator(
                    key: const ValueKey('content'),
                    onRefresh: _load,
                    color: AppColors.green,
                    child: _buildContent(),
                  ),
      ),
    );
  }

  Widget _buildContent() {
    if (_rawLoans.isEmpty) {
      return const EmptyView(
          message: 'No loans tracked.\nTap + to add a loan.',
          icon: Icons.credit_card_outlined);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Your Loans'),
        ..._analyzedLoans.map((l) {
          final loan = l as Map<String, dynamic>;
          return _LoanCard(
            loan: loan,
            onDelete: () => _confirmDelete(loan['loan_id'] as int? ?? 0),
          );
        }),
        if (_advice.isNotEmpty) ...[
          const SectionHeader(title: 'Smart Advice'),
          ..._advice.map((a) =>
              AdviceCard(advice: a as Map<String, dynamic>)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final activeCount = _analyzedLoans
        .where((l) => !(l as Map)['is_completed'])
        .length;
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'Monthly EMI',
            value: formatCurrency(_analysis['total_emi']),
            valueColor: AppColors.amber,
            icon: Icons.calendar_month_outlined,
            iconColor: AppColors.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            label: 'Outstanding',
            value: formatCurrency(_analysis['total_outstanding']),
            valueColor: AppColors.red,
            icon: Icons.account_balance_outlined,
            iconColor: AppColors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            label: 'Active Loans',
            value: '$activeCount',
            valueColor: AppColors.indigo,
            icon: Icons.credit_card_outlined,
            iconColor: AppColors.indigo,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Loan'),
        content: const Text('Remove this loan from tracking?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _delete(id);
              },
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
  }
}

class _LoanCard extends StatefulWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onDelete;

  const _LoanCard({required this.loan, required this.onDelete});

  @override
  State<_LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<_LoanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final name = loan['loan_name'] as String? ?? 'Loan';
    final type = loan['loan_type'] as String? ?? '';
    final emi = (loan['emi'] as num? ?? 0).toDouble();
    final outstanding = (loan['outstanding'] as num? ?? 0).toDouble();
    final monthsRemaining = loan['months_remaining'] as int? ?? 0;
    final payoffDate = loan['payoff_date'] as String? ?? '';
    final progress = (loan['progress_pct'] as num? ?? 0).toDouble();
    final isCompleted = loan['is_completed'] as bool? ?? false;
    final principalPaid = (loan['principal_paid'] as num? ?? 0).toDouble();
    final breakdown = loan['monthly_breakdown'] as List? ?? [];

    Color progressColor;
    if (progress >= 75) progressColor = AppColors.green;
    else if (progress >= 50) progressColor = AppColors.amber;
    else progressColor = AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          if (type.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.indigoBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(type,
                                  style: const TextStyle(
                                      color: AppColors.indigo,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.greenBadgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PAID',
                            style: TextStyle(
                                color: AppColors.greenDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.redBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: AppColors.red, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _stat('EMI/Month',
                            formatCurrency(emi), AppColors.amber)),
                    Expanded(
                        child: _stat('Outstanding',
                            formatCurrency(outstanding), AppColors.red)),
                    Expanded(
                        child: _stat(
                            isCompleted ? 'Status' : 'Months Left',
                            isCompleted ? 'Paid' : '$monthsRemaining mo',
                            isCompleted
                                ? AppColors.green
                                : AppColors.textSub)),
                  ],
                ),
                if (!isCompleted && payoffDate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Pays off $payoffDate',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Progress bar with gradient
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${progress.toStringAsFixed(0)}% paid',
                            style: const TextStyle(
                                color: AppColors.textSub, fontSize: 11)),
                        Text(formatCurrency(principalPaid),
                            style: const TextStyle(
                                color: AppColors.textSub, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor),
                        minHeight: 7,
                      ),
                    ),
                  ],
                ),
                if (breakdown.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        const Text('Balance Timeline',
                            style: TextStyle(
                                color: AppColors.textSub, fontSize: 11)),
                        const SizedBox(width: 4),
                        Icon(
                            _expanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AppColors.textMuted,
                            size: 16),
                      ],
                    ),
                  ),
                  if (_expanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildMiniBarChart(breakdown),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildMiniBarChart(List breakdown) {
    final bars = breakdown.take(36).toList();
    return SizedBox(
      height: 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.map((b) {
          final isPaid = b['paid'] as bool? ?? false;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              height: 40,
              decoration: BoxDecoration(
                color: isPaid ? AppColors.green : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AddLoanSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddLoanSheet({required this.onSave});

  @override
  State<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<_AddLoanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _emiCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  String _selectedType = 'Personal Loan';
  String _selectedMonth = _kMonths[DateTime.now().month - 1];
  String _selectedYear = DateTime.now().year.toString();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _principalCtrl.dispose();
    _emiCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave({
      'loan_name': _nameCtrl.text.trim(),
      'loan_type': _selectedType,
      'principal': double.tryParse(_principalCtrl.text) ?? 0,
      'emi': double.tryParse(_emiCtrl.text) ?? 0,
      'interest_rate': double.tryParse(_rateCtrl.text) ?? 0,
      'tenure_months': int.tryParse(_tenureCtrl.text) ?? 12,
      'start_month': _selectedMonth,
      'start_year':
          int.tryParse(_selectedYear) ?? DateTime.now().year,
    });
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final years =
        List.generate(5, (i) => (DateTime.now().year - 2 + i).toString());

    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Add Loan',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textSub),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _tf(_nameCtrl, 'Loan Name',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedType,
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                    color: AppColors.text, fontSize: 14),
                decoration: const InputDecoration(labelText: 'Loan Type'),
                items: _kLoanTypes
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedType = v ?? _selectedType),
              ),
              const SizedBox(height: 10),
              _tf(_principalCtrl, 'Principal Amount (₹)',
                  type: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              _tf(_emiCtrl, 'EMI per Month (₹)',
                  type: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              _tf(_rateCtrl, 'Interest Rate (% p.a.)',
                  type: const TextInputType.numberWithOptions(
                      decimal: true)),
              const SizedBox(height: 10),
              _tf(_tenureCtrl, 'Tenure (months)',
                  type: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedMonth,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 14),
                      decoration: const InputDecoration(
                          labelText: 'Start Month'),
                      items: _kMonths
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _selectedMonth = v ?? _selectedMonth),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedYear,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 14),
                      decoration: const InputDecoration(
                          labelText: 'Start Year'),
                      items: years
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _selectedYear = v ?? _selectedYear),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add Loan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController ctrl, String label,
      {TextInputType? type, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}
