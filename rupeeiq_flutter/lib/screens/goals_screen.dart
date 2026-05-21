import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _showForm = false;

  final _form      = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _amtCtrl   = TextEditingController();
  final _moCtrl    = TextEditingController(text: '12');
  bool _analyzing  = false;
  String? _formErr;
  Map<String, dynamic>? _result;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _amtCtrl.dispose(); _moCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiService.getGoals();
      setState(() { _data = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _analyze() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _analyzing = true; _formErr = null; _result = null; });
    try {
      final r = await ApiService.analyzeGoal(
        name: _nameCtrl.text.trim(),
        amount: double.parse(_amtCtrl.text),
        months: int.parse(_moCtrl.text),
      );
      setState(() { _result = r; _analyzing = false; _showForm = false; });
      _load();
    } on ApiException catch (e) {
      setState(() { _formErr = e.message; _analyzing = false; });
    } catch (_) {
      setState(() { _formErr = 'Failed. Try again.'; _analyzing = false; });
    }
  }

  Future<void> _delete(int id) async {
    await ApiService.deleteGoal(id);
    _load();
  }

  Future<void> _complete(int id) async {
    await ApiService.completeGoal(id);
    _load();
  }

  String _fmt(num? v) =>
      v == null ? '—' : '₹${NumberFormat('#,##,##0', 'en_IN').format(v)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Planner'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Analyze result
                      if (_result != null) _ResultCard(result: _result!, onFmt: _fmt),

                      // Form
                      if (_showForm) _buildForm(),

                      if (!_showForm && _result == null)
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _showForm = true),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Set New Goal'),
                        ),

                      const SizedBox(height: 20),

                      // Active goals
                      SectionHeader(
                        title: 'Active Goals',
                        trailing: InfoChip(label: '${(_data?['goals'] as List? ?? []).length}'),
                      ),

                      if ((_data?['goals'] as List? ?? []).isEmpty)
                        const EmptyView(
                          title: 'No goals yet',
                          subtitle: 'Set a financial goal and get a detailed savings plan',
                          icon: Icons.track_changes_outlined,
                        )
                      else
                        ...((_data?['goals'] as List?) ?? []).map((g) =>
                            _GoalCard(goal: g as Map, onFmt: _fmt,
                                onDelete: () => _delete(g['id'] as int),
                                onComplete: () => _complete(g['id'] as int))),
                    ],
                  ),
                ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New Goal', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16)),
                GestureDetector(
                  onTap: () => setState(() => _showForm = false),
                  child: const Icon(Icons.close, color: AppColors.textSub, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_formErr != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.red.withOpacity(0.3)),
                ),
                child: Text(_formErr!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
              ),

            _tf(_nameCtrl, 'Goal Name', hint: 'e.g. Emergency Fund'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _tf(_amtCtrl, 'Target Amount ₹', keyboard: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _tf(_moCtrl, 'Months to Achieve', keyboard: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showForm = false),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSub),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _analyzing ? null : _analyze,
                    child: _analyzing
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                        : const Text('Analyze'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tf(TextEditingController ctrl, String label, {
    TextInputType keyboard = TextInputType.text, String hint = '',
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
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Map goal;
  final String Function(num?) onFmt;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  const _GoalCard({required this.goal, required this.onFmt, required this.onDelete, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final pct = (goal['progress_pct'] as num? ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                  color: AppColors.indigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.track_changes, color: AppColors.indigo, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal['goal_name'] ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${goal['goal_months']} months · ${onFmt(goal['goal_amount'] as num?)}',
                        style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface,
                onSelected: (v) {
                  if (v == 'complete') onComplete();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'complete', child: Text('Mark Complete', style: TextStyle(color: AppColors.green))),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.red))),
                ],
                icon: const Icon(Icons.more_vert, color: AppColors.textSub, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
              Text('${pct.toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.green),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String Function(num?) onFmt;
  const _ResultCard({required this.result, required this.onFmt});

  @override
  Widget build(BuildContext context) {
    final r  = result['result'] as Map? ?? {};
    final sav= result['savings'] as num? ?? 0;
    final feasible = r['feasible'] ?? false;
    final months   = r['months_needed'] as num? ?? r['goal_months'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: feasible
            ? AppColors.green.withOpacity(0.08)
            : AppColors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: feasible
                ? AppColors.green.withOpacity(0.3)
                : AppColors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                feasible ? Icons.check_circle_outline : Icons.info_outline,
                color: feasible ? AppColors.green : AppColors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r['goal_name'] ?? 'Goal Analysis',
                  style: TextStyle(
                    color: feasible ? AppColors.green : AppColors.amber,
                    fontWeight: FontWeight.w700, fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row('Target', onFmt(r['goal_amount'] as num?)),
          _row('Monthly Savings', onFmt(sav)),
          _row('Months Needed', '${months ?? '—'}'),
          _row('Difficulty', r['difficulty'] ?? ''),
          if (r['recommendation'] != null) ...[
            const SizedBox(height: 10),
            Text(r['recommendation'],
                style: const TextStyle(color: AppColors.textSub, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );
}
