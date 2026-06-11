import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'edit_entry_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
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
      final res = await ApiService.getHistory();
      if (res['error'] != null) {
        setState(() { _error = res['error'] as String; _loading = false; });
        return;
      }
      setState(() {
        _history = res['history'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load history.'; _loading = false; });
    }
  }

  void _showDetail(Map<String, dynamic> entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetailSheet(
        entry: entry,
        onDelete: () async {
          Navigator.pop(context);
          await _delete(entry['id'] as int);
        },
        onEdit: () {
          Navigator.pop(context);
          _navigateToEdit(entry);
        },
      ),
    );
  }

  void _navigateToEdit(Map<String, dynamic> entry) {
    Navigator.push(
      context,
      fadeRoute(EditEntryScreen(
        entryId: entry['id'] as int,
        month: entry['month'] as String,
        year: entry['year'] as int,
      )),
    ).then((result) {
      if (result == true) _load();
    });
  }

  Future<void> _delete(int id) async {
    try {
      await ApiService.deleteHistoryEntry(id);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
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
                : _history.isEmpty
                    ? const EmptyView(
                        key: ValueKey('empty'),
                        message: 'No history yet.\nAdd your first month!',
                        icon: Icons.history_outlined)
                    : RefreshIndicator(
                        key: const ValueKey('content'),
                        onRefresh: _load,
                        color: AppColors.green,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _history.length,
                          itemBuilder: (context, i) {
                            final e = _history[i] as Map<String, dynamic>;
                            return _HistoryCard(
                              entry: e,
                              onTap: () => _showDetail(e),
                              onEdit: () => _navigateToEdit(e),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _HistoryCard({
    required this.entry,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final savings = (entry['savings'] as num? ?? 0).toDouble();
    final emi = (entry['total_emi'] as num? ?? 0).toDouble();
    final totalExp =
        (entry['total_expenses'] as num? ?? 0).toDouble() + emi;
    final color = savings >= 0 ? AppColors.green : AppColors.red;
    final rate = (entry['savings_rate'] as num? ?? 0).toDouble();
    final score = (entry['health_score'] as num? ?? 0).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 1))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${entry['month']} ${entry['year']}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text('Edit',
                            style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _scoreBadge(score),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textMuted, size: 18),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _stat('Income',
                        formatCurrency(entry['income']),
                        AppColors.indigo)),
                Expanded(
                    child: _stat('Expenses',
                        formatCurrency(totalExp), AppColors.red)),
                Expanded(
                    child: _stat(
                        'Savings', formatCurrency(savings), color)),
                Expanded(
                    child: _stat(
                        'Rate',
                        '${rate.toStringAsFixed(1)}%',
                        AppColors.textSub)),
              ],
            ),
          ],
        ),
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
                fontSize: 12)),
      ],
    );
  }

  Widget _scoreBadge(int score) {
    Color bg, textColor;
    if (score >= 80) {
      bg = AppColors.greenBadgeBg;
      textColor = AppColors.greenDark;
    } else if (score >= 60) {
      bg = AppColors.amberBadgeBg;
      textColor = AppColors.amberText;
    } else {
      bg = AppColors.redBg;
      textColor = AppColors.redText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$score/100',
          style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 11)),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _DetailSheet({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final savings = (entry['savings'] as num? ?? 0).toDouble();
    final emi = (entry['total_emi'] as num? ?? 0).toDouble();
    final totalExp =
        (entry['total_expenses'] as num? ?? 0).toDouble() + emi;
    final score = (entry['health_score'] as num? ?? 0).toInt();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('${entry['month']} ${entry['year']}',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF2563EB)),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.red),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Entry'),
                      content: const Text(
                          "Permanently delete this month's entry?",
                          style:
                              TextStyle(color: AppColors.textSub)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: onDelete,
                            child: const Text('Delete',
                                style: TextStyle(
                                    color: AppColors.red))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                _section('Summary', [
                  InfoRow(
                      label: 'Income',
                      value: formatCurrency(entry['income']),
                      valueColor: AppColors.indigo),
                  InfoRow(
                      label: 'Expenses (incl. EMI)',
                      value: formatCurrency(totalExp),
                      valueColor: AppColors.red),
                  if (emi > 0)
                    InfoRow(
                        label: 'EMI',
                        value: formatCurrency(emi),
                        valueColor: AppColors.amber),
                  InfoRow(
                      label: 'Savings',
                      value: formatCurrency(savings),
                      valueColor: savings >= 0
                          ? AppColors.green
                          : AppColors.red),
                  InfoRow(
                      label: 'Savings Rate',
                      value:
                          '${(entry['savings_rate'] as num? ?? 0).toStringAsFixed(1)}%'),
                  if (score > 0)
                    InfoRow(
                        label: 'Health Score',
                        value: '$score/100',
                        valueColor: score >= 70
                            ? AppColors.green
                            : score >= 50
                                ? AppColors.amber
                                : AppColors.red),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}
