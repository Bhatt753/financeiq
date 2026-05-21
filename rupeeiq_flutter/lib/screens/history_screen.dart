import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool  _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h = await ApiService.getHistory();
      setState(() { _history = h; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(num? v) =>
      v == null ? '—' : '₹${NumberFormat('#,##,##0', 'en_IN').format(v)}';

  Future<void> _confirmDelete(int id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Entry', style: TextStyle(color: AppColors.text)),
        content: Text('Delete $label? This cannot be undone.',
            style: const TextStyle(color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSub))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteEntry(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly History'),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _history.isEmpty
                  ? const EmptyView(
                      title: 'No history yet',
                      subtitle: 'Add your first month\'s data to start tracking',
                      icon: Icons.calendar_today_outlined,
                    )
                  : RefreshIndicator(
                      color: AppColors.green,
                      backgroundColor: AppColors.surface,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _history.length,
                        itemBuilder: (_, i) {
                          final e = _history[i] as Map;
                          return _HistoryCard(
                            entry: e,
                            onFmt: _fmt,
                            onDelete: () => _confirmDelete(
                                e['id'] as int, '${e['month']} ${e['year']}'),
                            onView: () => _showDetail(e),
                          );
                        },
                      ),
                    ),
    );
  }

  void _showDetail(Map entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DetailSheet(entry: entry, onFmt: _fmt),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map entry;
  final String Function(num?) onFmt;
  final VoidCallback onDelete;
  final VoidCallback onView;

  const _HistoryCard({
    required this.entry, required this.onFmt,
    required this.onDelete, required this.onView,
  });

  Color _scoreColor(num s) {
    if (s >= 80) return AppColors.green;
    if (s >= 60) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final score   = (entry['health_score'] as num?) ?? 0;
    final savings = (entry['savings']      as num?) ?? 0;
    final color   = _scoreColor(score);

    return GestureDetector(
      onTap: onView,
      child: Container(
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
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text('${score.toInt()}',
                        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry['month']} ${entry['year']}',
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Income ${onFmt(entry['income'] as num?)}',
                          style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(onFmt(savings),
                        style: TextStyle(
                            color: savings >= 0 ? AppColors.green : AppColors.red,
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const Text('savings', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('Expenses', onFmt(entry['total_expenses'] as num?), AppColors.red),
                const SizedBox(width: 12),
                _stat('EMI', onFmt(entry['total_emi'] as num?), AppColors.amber),
                const SizedBox(width: 12),
                _stat('Rate', '${(entry['savings_rate'] as num? ?? 0).toStringAsFixed(1)}%', AppColors.green),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ],
  );
}

class _DetailSheet extends StatefulWidget {
  final Map entry;
  final String Function(num?) onFmt;
  const _DetailSheet({required this.entry, required this.onFmt});
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  List<dynamic> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getHistoryEntry(widget.entry['id'] as int);
      setState(() { _expenses = d['expenses'] as List? ?? []; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${e['month']} ${e['year']}',
                    style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textSub), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          MetricCard(value: widget.onFmt(e['income'] as num?), label: 'Income', valueColor: AppColors.green),
                          MetricCard(value: widget.onFmt(e['savings'] as num?), label: 'Savings',
                              valueColor: (e['savings'] as num? ?? 0) >= 0 ? AppColors.green : AppColors.red),
                          MetricCard(value: widget.onFmt(e['total_expenses'] as num?), label: 'Expenses', valueColor: AppColors.red),
                          MetricCard(value: '${(e['savings_rate'] as num? ?? 0).toStringAsFixed(1)}%', label: 'Rate'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Expenses', style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (_expenses.isEmpty)
                        const Text('No expense data', style: TextStyle(color: AppColors.textSub, fontSize: 13))
                      else
                        ..._expenses.map((exp) => _expRow(exp as Map)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _expRow(Map exp) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exp['name'] ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${exp['category']} · ${exp['type']}',
                    style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
              ],
            )),
            Text(widget.onFmt(exp['amount'] as num?),
                style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );
}
