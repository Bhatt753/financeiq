import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';
import 'history_screen.dart';
import 'loans_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
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
      final d = await ApiService.getDashboard();
      setState(() { _data = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(num? v) =>
      v == null ? '—' : '₹${NumberFormat('#,##,##0', 'en_IN').format(v)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet, color: AppColors.green, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('RupeeIQ'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final history  = (_data?['history'] as List?) ?? [];
    final trends   = (_data?['trends']  as Map?)   ?? {};
    final goals    = (_data?['goals']   as List?)   ?? [];
    final summary  = (_data?['summary'] as Map?)    ?? {};

    final latest   = history.isNotEmpty ? history.first as Map : null;
    final inc      = (latest?['income']         as num?) ?? 0;
    final exp      = (latest?['total_expenses'] as num?) ?? 0;
    final sav      = (latest?['savings']        as num?) ?? 0;
    final rate     = (latest?['savings_rate']   as num?) ?? 0;
    final hs       = (latest?['health_score']   as num?) ?? 0;
    final month    = latest?['month'] ?? '';
    final year     = latest?['year']  ?? '';

    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Month banner
            if (latest != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF4ADE80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('$month $year — Latest Report',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _ScoreChip(hs.toInt()),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            const SectionHeader(title: 'This Month'),

            // Metrics grid
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(value: _fmt(inc), label: 'Income',   valueColor: AppColors.green, icon: Icons.arrow_downward, iconColor: AppColors.green),
                MetricCard(value: _fmt(exp), label: 'Expenses', valueColor: AppColors.red,   icon: Icons.arrow_upward,   iconColor: AppColors.red),
                MetricCard(value: _fmt(sav), label: 'Savings',  valueColor: sav >= 0 ? AppColors.green : AppColors.red),
                MetricCard(value: '${rate.toStringAsFixed(1)}%', label: 'Savings Rate', valueColor: rate >= 20 ? AppColors.green : AppColors.amber),
              ],
            ),

            const SizedBox(height: 24),

            // Quick actions
            const SectionHeader(title: 'Quick Actions'),
            Row(
              children: [
                _QuickAction(icon: Icons.history, label: 'History', color: AppColors.cyan,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
                const SizedBox(width: 10),
                _QuickAction(icon: Icons.credit_card_outlined, label: 'Loans', color: AppColors.amber,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansScreen()))),
              ],
            ),

            const SizedBox(height: 24),

            // Goals
            if (goals.isNotEmpty) ...[
              SectionHeader(
                title: 'Active Goals',
                trailing: Text('${goals.length}', style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
              ),
              ...goals.take(3).map((g) => _GoalTile(goal: g as Map)),
              const SizedBox(height: 24),
            ],

            // History trend
            if (history.length > 1) ...[
              SectionHeader(
                title: 'Recent Months',
                trailing: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  child: const Text('See all', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              ...history.take(4).map((h) => _HistoryTile(entry: h as Map, onFmt: _fmt)),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final int score;
  const _ScoreChip(this.score);

  Color get _color {
    if (score >= 80) return AppColors.green;
    if (score >= 60) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$score/100',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}

class _GoalTile extends StatelessWidget {
  final Map goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final pct = (goal['progress_pct'] as num? ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(goal['goal_name'] ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
              Text('${goal['goal_months'] ?? 0} months',
                  style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.green),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${NumberFormat('#,##,##0').format(goal['goal_amount'] ?? 0)} target',
                  style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
              Text('${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map entry;
  final String Function(num?) onFmt;
  const _HistoryTile({required this.entry, required this.onFmt});

  @override
  Widget build(BuildContext context) {
    final sav   = (entry['savings'] as num?) ?? 0;
    final score = (entry['health_score'] as num?) ?? 0;
    final color = score >= 80 ? AppColors.green : score >= 60 ? AppColors.amber : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('${score.toInt()}',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry['month']} ${entry['year']}',
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Income ${onFmt(entry['income'] as num?)}',
                    style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
              ],
            ),
          ),
          Text(onFmt(sav),
              style: TextStyle(
                  color: sav >= 0 ? AppColors.green : AppColors.red,
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
