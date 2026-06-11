import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class EditEntryScreen extends StatefulWidget {
  final int entryId;
  final String month;
  final int year;

  const EditEntryScreen({
    super.key,
    required this.entryId,
    required this.month,
    required this.year,
  });

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _incomeCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  List<_ExpenseData> _rows = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _emergencyCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getHistoryEntry(widget.entryId),
        ApiService.getFormData(),
      ]);
      final entryRes = results[0];
      final formRes = results[1];
      if (entryRes['error'] != null) {
        setState(() {
          _error = entryRes['error'] as String;
          _loading = false;
        });
        return;
      }
      final entry = entryRes['entry'] as Map<String, dynamic>? ?? {};
      final expenses = entryRes['expenses'] as List? ?? [];
      final cats = (formRes['categories'] as List? ?? []).cast<String>();

      _incomeCtrl.text = (entry['income'] as num? ?? 0).toString();
      _emergencyCtrl.text =
          (entry['emergency_fund'] as num? ?? 0).toString();

      final rows = <_ExpenseData>[];
      for (final e in expenses) {
        final exp = e as Map<String, dynamic>;
        final cat = exp['category'] as String? ?? '';
        rows.add(_ExpenseData(
          name: exp['name'] as String? ?? '',
          category: cats.contains(cat)
              ? cat
              : (cats.isNotEmpty ? cats[0] : ''),
          type: exp['type'] as String? ?? 'Fixed',
          amount: (exp['amount'] as num? ?? 0).toString(),
        ));
      }
      if (rows.isEmpty) {
        rows.add(_ExpenseData(category: cats.isNotEmpty ? cats[0] : ''));
      }

      setState(() {
        _categories = cats;
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load entry. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final income = double.tryParse(_incomeCtrl.text.trim());
    if (income == null || income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid income amount')),
      );
      return;
    }

    final expenses = _rows
        .where((r) =>
            r.nameCtrl.text.trim().isNotEmpty &&
            (double.tryParse(r.amountCtrl.text.trim()) ?? 0) > 0)
        .map((r) => {
              'name': r.nameCtrl.text.trim(),
              'category': r.category,
              'type': r.type,
              'amount': double.parse(r.amountCtrl.text.trim()),
            })
        .toList();

    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one valid expense with name and amount')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiService.updateHistoryEntry(
        widget.entryId,
        month: widget.month,
        year: widget.year,
        income: income,
        expenses: expenses,
        emergencyFund:
            double.tryParse(_emergencyCtrl.text.trim()) ?? 0,
      );
      if (res['error'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] as String)),
          );
        }
        setState(() => _saving = false);
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to save. Check your connection.')),
        );
      }
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Edit ${widget.month} ${widget.year}'),
      ),
      body: _loading
          ? const ShimmerLoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        _sectionCard(
          title: 'Income Details',
          icon: Icons.attach_money_rounded,
          child: Column(
            children: [
              _labeledField(
                'Monthly Income (₹)',
                _incomeCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _readonlyField('Month', widget.month)),
                const SizedBox(width: 10),
                Expanded(
                    child: _readonlyField('Year', '${widget.year}')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Expenses',
          icon: Icons.credit_card_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...List.generate(
                _rows.length,
                (i) => _ExpenseRowWidget(
                  key: ObjectKey(_rows[i]),
                  data: _rows[i],
                  categories: _categories,
                  onRemove: () {
                    if (_rows.length > 1) {
                      setState(() {
                        _rows[i].dispose();
                        _rows.removeAt(i);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _rows.add(_ExpenseData(
                      category: _categories.isNotEmpty
                          ? _categories[0]
                          : ''));
                }),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Another Expense'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.borderGreen),
                  backgroundColor: AppColors.surfaceGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Emergency Fund',
          icon: Icons.shield_outlined,
          optional: true,
          child: _labeledField(
            'Emergency Fund Amount (₹)',
            _emergencyCtrl,
            keyboardType: TextInputType.number,
            hint: 'e.g. 50000',
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? 'Saving…' : 'Save Changes'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool optional = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.surfaceGreen,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderGreen),
              ),
              child: Icon(icon, color: AppColors.green, size: 16),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textMid,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            if (optional) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGreen,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderGreen),
                ),
                child: const Text('Optional',
                    style: TextStyle(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMid,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.text, fontSize: 15),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _readonlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMid,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textSub, fontSize: 15)),
        ),
      ],
    );
  }
}

class _ExpenseData {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  String category;
  String type;

  _ExpenseData({
    String name = '',
    required String category,
    String type = 'Fixed',
    String amount = '',
  })  : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(text: amount),
        category = category,
        type = type;

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _ExpenseRowWidget extends StatefulWidget {
  final _ExpenseData data;
  final List<String> categories;
  final VoidCallback onRemove;

  const _ExpenseRowWidget({
    required super.key,
    required this.data,
    required this.categories,
    required this.onRemove,
  });

  @override
  State<_ExpenseRowWidget> createState() => _ExpenseRowWidgetState();
}

class _ExpenseRowWidgetState extends State<_ExpenseRowWidget> {
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final cats = widget.categories;
    final safeCategory =
        cats.contains(d.category) ? d.category : (cats.isNotEmpty ? cats[0] : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              flex: 5,
              child: TextField(
                controller: d.nameCtrl,
                style:
                    const TextStyle(color: AppColors.text, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Expense name',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 5,
              child: cats.isEmpty
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<String>(
                      value: safeCategory,
                      items: cats
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style:
                                      const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => d.category = v);
                      },
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        isDense: true,
                      ),
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 12),
                      dropdownColor: AppColors.surface,
                    ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<String>(
                value: d.type,
                items: ['Fixed', 'Variable']
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t,
                            style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => d.type = v);
                },
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                ),
                style: const TextStyle(
                    color: AppColors.text, fontSize: 12),
                dropdownColor: AppColors.surface,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: TextField(
                controller: d.amountCtrl,
                keyboardType: TextInputType.number,
                style:
                    const TextStyle(color: AppColors.text, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Amount ₹',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.redBorder),
                ),
                child: const Icon(Icons.close,
                    color: AppColors.red, size: 16),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
