import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});
  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      setState(() { _data = null; _loading = true; });
      final d = await ApiService.getLoans();
      setState(() { _data = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(num? v) =>
      v == null ? '—' : '₹${NumberFormat('#,##,##0', 'en_IN').format(v)}';

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Close Loan', style: TextStyle(color: AppColors.text)),
        content: Text('Mark "$name" as closed?', style: const TextStyle(color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSub))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Close', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) { await ApiService.deleteLoan(id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Tracker'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddLoanSheet(),
          ),
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLoanSheet(),
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add),
        label: const Text('Add Loan', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody() {
    final loans    = (_data?['loans']    as List?) ?? [];
    final analysis = (_data?['analysis'] as Map?)  ?? {};
    final advice   = (_data?['advice']   as List?) ?? [];

    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            if (analysis['has_loans'] == true) ...[
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MetricCard(value: _fmt(analysis['total_outstanding'] as num?), label: 'Total Outstanding', valueColor: AppColors.red),
                  MetricCard(value: _fmt(analysis['total_emi'] as num?), label: 'Monthly EMI', valueColor: AppColors.amber),
                  MetricCard(value: '${(analysis['debt_burden_ratio'] as num? ?? 0).toStringAsFixed(1)}%', label: 'Debt Burden'),
                  MetricCard(value: '${loans.length}', label: 'Active Loans', valueColor: AppColors.green),
                ],
              ),
              const SizedBox(height: 20),
            ],

            const SectionHeader(title: 'Your Loans'),

            if (loans.isEmpty)
              const EmptyView(
                title: 'No active loans',
                subtitle: 'Add your first loan to track EMI and get payoff advice',
                icon: Icons.credit_card_outlined,
              )
            else
              ...loans.map((l) => _LoanCard(loan: l as Map, onFmt: _fmt,
                  onDelete: () => _delete(l['id'] as int, l['loan_name'] ?? ''))),

            if (advice.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: 'Loan Advice'),
              ...advice.map((a) => _AdviceTile(a: a as Map)),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddLoanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddLoanSheet(onAdded: _load),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Map loan;
  final String Function(num?) onFmt;
  final VoidCallback onDelete;
  const _LoanCard({required this.loan, required this.onFmt, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final pct = (loan['tenure_months'] as num? ?? 1) > 0
        ? ((loan['tenure_months'] as num? ?? 0) / (loan['tenure_months'] as num? ?? 1) * 100).clamp(0, 100).toDouble()
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.credit_card_outlined, color: AppColors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan['loan_name'] ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${loan['loan_type']} · ${loan['interest_rate']}% p.a.',
                        style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_outlined, color: AppColors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('Principal', onFmt(loan['principal'] as num?), AppColors.red),
              _stat('Monthly EMI', onFmt(loan['emi'] as num?), AppColors.amber),
              _stat('Tenure', '${loan['tenure_months']} mo', AppColors.textSub),
            ],
          ),
          const SizedBox(height: 10),
          Text('${loan['start_month']} ${loan['start_year']}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
    children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ],
  );
}

class _AdviceTile extends StatelessWidget {
  final Map a;
  const _AdviceTile({required this.a});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.indigo.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.indigo.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a['icon'] ?? '💡', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['title'] ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(a['message'] ?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Add Loan Bottom Sheet ─────────────────────────────────────────────────────

class _AddLoanSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddLoanSheet({required this.onAdded});
  @override
  State<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<_AddLoanSheet> {
  final _form         = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _principalCtrl= TextEditingController();
  final _emiCtrl      = TextEditingController();
  final _rateCtrl     = TextEditingController();
  final _tenureCtrl   = TextEditingController();

  String _type       = 'Personal Loan';
  String _startMonth = 'January';
  int    _startYear  = DateTime.now().year;
  bool   _loading    = false;
  String? _error;

  static const _types = ['Home Loan','Personal Loan','Car Loan','Education Loan','Credit Card','Business Loan','Other'];
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _principalCtrl.dispose();
    _emiCtrl.dispose(); _rateCtrl.dispose(); _tenureCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.addLoan({
        'loan_name'    : _nameCtrl.text.trim(),
        'loan_type'    : _type,
        'principal'    : double.parse(_principalCtrl.text),
        'emi'          : double.parse(_emiCtrl.text),
        'interest_rate': double.tryParse(_rateCtrl.text) ?? 0,
        'tenure_months': int.parse(_tenureCtrl.text),
        'start_month'  : _startMonth,
        'start_year'   : _startYear,
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed. Try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add New Loan', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.red.withOpacity(0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],

              _tf(_nameCtrl, 'Loan Name', hint: 'e.g. Home Loan SBI'),
              const SizedBox(height: 10),

              _dropdown('Loan Type', _type, _types, (v) => setState(() => _type = v!)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: _tf(_principalCtrl, 'Principal ₹', keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _tf(_emiCtrl, 'Monthly EMI ₹', keyboard: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: _tf(_rateCtrl, 'Interest % p.a.', keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _tf(_tenureCtrl, 'Tenure (months)', keyboard: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: _dropdown('Start Month', _startMonth, _months, (v) => setState(() => _startMonth = v!))),
                  const SizedBox(width: 10),
                  Expanded(child: _tf(TextEditingController(text: _startYear.toString()),
                      'Start Year', keyboard: TextInputType.number,
                      onChanged: (v) { final y = int.tryParse(v); if (y != null) setState(() => _startYear = y); })),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _add,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                      : const Text('Add Loan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController ctrl, String label, {
    TextInputType keyboard = TextInputType.text,
    String hint = '',
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
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> options, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
