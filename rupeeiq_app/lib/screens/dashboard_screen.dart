import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/finance_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/home/financial_overview_card.dart';
import 'add_data_screen.dart';
import 'history_screen.dart';
import 'loans_screen.dart';
import 'goals_screen.dart';
import 'health_screen.dart';
import 'month_detail_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _history = [];
  Map<String, dynamic> _summary = {};
  List<dynamic> _goals = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _annualSummary;
  int _viewIdx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dash = await ApiService.getDashboard();
      if (dash['error'] != null) {
        setState(() {
          _error = dash['error'] as String;
          _loading = false;
        });
        return;
      }
      setState(() {
        _history = dash['history'] as List? ?? [];
        _summary = dash['summary'] as Map<String, dynamic>? ?? {};
        _goals = (dash['goals'] as List? ?? [])
            .where((g) =>
                (g as Map<dynamic, dynamic>)['status'] != 'completed')
            .toList();
        _annualSummary = calculateAnnualSummary(_history);
        _viewIdx = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
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

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.surfaceGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.currency_rupee_rounded,
                color: AppColors.green, size: 18),
          ),
          const SizedBox(width: 8),
          const Text(
            'RupeeIQ',
            style: TextStyle(
                color: AppColors.green,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        _buildCalendarButton(),
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.text, size: 24),
          onPressed: _showHamburgerMenu,
          tooltip: 'Menu',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildCalendarButton() {
    final now = DateTime.now();
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final monthStr = months[now.month - 1];
    final dayName = days[now.weekday - 1];
    final isViewing = _viewIdx != 0 && _history.isNotEmpty;
    final accentColor = isViewing ? AppColors.indigo : AppColors.green;
    final bgColor = isViewing ? AppColors.indigoBg : AppColors.surfaceGreen;

    String topText;
    String bottomText;
    if (isViewing) {
      final e = _history[_viewIdx] as Map<String, dynamic>;
      final rawMonth = e['month'] as String? ?? '';
      final shortMonth = rawMonth.length >= 3
          ? rawMonth.substring(0, 3).toUpperCase()
          : rawMonth.toUpperCase();
      topText = '$shortMonth ${e['year']}';
      bottomText = 'viewing';
    } else {
      topText = '${now.day} $monthStr';
      bottomText = dayName;
    }

    return GestureDetector(
      onTap: _history.length > 1 ? _showMonthPicker : null,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 11, color: accentColor),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  topText,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2),
                ),
                Text(
                  bottomText,
                  style: TextStyle(
                      color: accentColor.withOpacity(0.65),
                      fontSize: 9,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (_history.length > 1) ...[
              const SizedBox(width: 3),
              Icon(Icons.expand_more_rounded,
                  size: 14, color: accentColor.withOpacity(0.7)),
            ],
          ],
        ),
      ),
    );
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  const Text('Select Month',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_viewIdx != 0)
                    TextButton(
                      onPressed: () {
                        setState(() => _viewIdx = 0);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Show Latest',
                          style: TextStyle(
                              color: AppColors.green, fontSize: 13)),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _history.length,
                itemBuilder: (_, idx) {
                  final entry = _history[idx] as Map<String, dynamic>;
                  final isSelected = idx == _viewIdx;
                  final income = (entry['income'] as num? ?? 0).toDouble();
                  final score = entry['health_score'] ?? 0;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.surfaceGreen
                            : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_month_outlined,
                          color: isSelected
                              ? AppColors.green
                              : AppColors.textSub,
                          size: 20),
                    ),
                    title: Text(
                      '${entry['month']} ${entry['year']}',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    subtitle: Text(
                      '${formatCurrency(income)} · Score: $score',
                      style: const TextStyle(
                          color: AppColors.textSub, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 22)
                        : null,
                    onTap: () {
                      setState(() => _viewIdx = idx);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHamburgerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              _menuItem(ctx, Icons.person_outline_rounded, 'Profile',
                  AppColors.textSub, () {
                Navigator.push(context, fadeRoute(const ProfileScreen()));
              }),
              _menuItem(ctx, Icons.history_outlined, 'History',
                  AppColors.textSub, () {
                Navigator.push(context, fadeRoute(const HistoryScreen()));
              }),
              _menuItem(ctx, Icons.info_outline_rounded, 'About RupeeIQ',
                  AppColors.textSub, () {
                _showAboutDialog();
              }),
              _menuItem(ctx, Icons.lock_outline_rounded, 'Privacy Policy',
                  AppColors.textSub, () {}),
              _menuItem(ctx, Icons.description_outlined, 'Terms of Service',
                  AppColors.textSub, () {}),
              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 4),
              _menuItem(ctx, Icons.logout_rounded, 'Logout', AppColors.red,
                  () async {
                await context.read<AuthProvider>().logout();
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext ctx, IconData icon, String label, Color color,
      VoidCallback onTap) {
    final isDestructive = color == AppColors.red;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.redBg : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: isDestructive ? AppColors.red : AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surfaceGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.currency_rupee_rounded,
                  color: AppColors.green, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('RupeeIQ',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Your personal budget planner for smart financial decisions.\n\nTrack income, expenses, loans, and goals — all in one place.',
          style: TextStyle(
              color: AppColors.textSub, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final viewIdx =
        _viewIdx.clamp(0, _history.isNotEmpty ? _history.length - 1 : 0);
    final latest = _history.isNotEmpty
        ? _history[viewIdx] as Map<String, dynamic>
        : null;
    final viewTrends =
        _history.length >= 2 ? analyzeTrends(_history.sublist(viewIdx)) : null;

    return ListView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildActionCircles(),
        ),
        if (latest != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildMetricCards(latest),
          ),
          if (viewTrends != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTrendsRow(viewTrends),
            ),
          ],
        ],
        if (_history.length >= 2) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FinancialOverviewCard(
              history: _history,
              goals: _goals,
              onEntryTap: (entry, prev) {
                final firstGoal = _goals.isNotEmpty
                    ? _goals.first as Map<String, dynamic>
                    : null;
                Navigator.push(
                  context,
                  slideUpRoute(MonthDetailScreen(
                    entry: entry,
                    prevEntry: prev,
                    firstGoal: firstGoal,
                  )),
                );
              },
            ),
          ),
        ],
        if (_goals.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Active Goals'),
                _buildGoalsList(),
              ],
            ),
          ),
        ],
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: EmptyView(
              message: 'No data yet.\nTap Add to record your first month.',
              icon: Icons.bar_chart_outlined,
            ),
          ),
        if (_annualSummary != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAnnualCard(),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActionCircles() {
    final actions = [
      _ActionItem('Add', Icons.add_circle_outline, AppColors.green,
          AppColors.surfaceGreen, () => _goTo(1)),
      _ActionItem('Goals', Icons.flag_outlined, AppColors.indigo,
          AppColors.indigoBg, () => _goTo(4)),
      _ActionItem('Loans', Icons.credit_card_outlined, AppColors.amber,
          AppColors.amberBg, () => _goTo(3)),
      _ActionItem(
          'History',
          Icons.history_outlined,
          const Color(0xFF0891B2),
          const Color(0xFFECFEFF),
          () => Navigator.push(context, fadeRoute(const HistoryScreen()))),
      _ActionItem(
          'Health',
          Icons.favorite_outline,
          const Color(0xFFE11D48),
          const Color(0xFFFFF1F2),
          () => _goTo(2)),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) => _buildCircle(a)).toList(),
    );
  }

  void _goTo(int index) {
    switch (index) {
      case 1:
        Navigator.push(context, fadeRoute(const AddDataScreen()))
            .then((_) { if (mounted) _load(); });
        break;
      case 2:
        Navigator.push(context, fadeRoute(const HealthScreen()));
        break;
      case 3:
        Navigator.push(context, fadeRoute(const LoansScreen()));
        break;
      case 4:
        Navigator.push(context, fadeRoute(const GoalsScreen()));
        break;
    }
  }

  Widget _buildCircle(_ActionItem a) {
    return TapScaleWrapper(
      onTap: a.onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: a.bg,
              shape: BoxShape.circle,
              border: Border.all(color: a.color.withOpacity(0.2)),
            ),
            child: Icon(a.icon, color: a.color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(a.label,
              style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMetricCards(Map<String, dynamic> e) {
    final savings = (e['savings'] as num? ?? 0).toDouble();
    final savingsColor = savings >= 0 ? AppColors.green : AppColors.red;
    final rate = (e['savings_rate'] as num? ?? 0).toDouble();
    final expenses = ((e['total_expenses'] as num? ?? 0) +
        (e['total_emi'] as num? ?? 0));

    return Column(
      children: [
        Row(children: [
          Expanded(
            child: MetricCard(
              label: 'Income',
              value: formatCurrency(e['income']),
              valueColor: AppColors.indigo,
              icon: Icons.arrow_downward_rounded,
              iconColor: AppColors.indigo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MetricCard(
              label: 'Expenses',
              value: formatCurrency(expenses),
              valueColor: AppColors.red,
              icon: Icons.arrow_upward_rounded,
              iconColor: AppColors.red,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: MetricCard(
              label: 'Savings',
              value: formatCurrency(savings),
              valueColor: savingsColor,
              icon: Icons.savings_outlined,
              iconColor: savingsColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MetricCard(
              label: 'Savings Rate',
              value: '${rate.toStringAsFixed(1)}%',
              valueColor: savingsColor,
              icon: Icons.percent_rounded,
              iconColor: savingsColor,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildGoalsList() {
    return Column(
      children: _goals.take(3).map((g) {
        final goal = g as Map<String, dynamic>;
        final progress = (goal['progress_pct'] as num? ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal['goal_name'] as String? ?? '',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                  Text(formatCurrency(goal['goal_amount']),
                      style: const TextStyle(
                          color: AppColors.textSub, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (progress / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.green),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text('${progress.toStringAsFixed(0)}% complete',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrendsRow(Map<String, dynamic> t) {
    return Row(
      children: [
        _trendChip('Savings', (t['savings_change'] as num).toDouble(),
            t['savings_trend'] as String,
            isCurrency: true),
        const SizedBox(width: 8),
        _trendChip('Expenses', (t['expense_change'] as num).toDouble(),
            t['expense_trend'] as String,
            isCurrency: true, invertColor: true),
        const SizedBox(width: 8),
        _trendChip('Score', (t['score_change'] as num).toDouble(),
            t['score_trend'] as String),
      ],
    );
  }

  Widget _trendChip(String label, double change, String trend,
      {bool isCurrency = false, bool invertColor = false}) {
    final isUp = trend == 'up';
    final isGood = invertColor ? !isUp : isUp;
    final color = isGood ? AppColors.green : AppColors.red;
    final bg = isGood ? AppColors.surfaceGreen : AppColors.redBg;
    final icon =
        isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final display = isCurrency
        ? formatCurrency(change.abs())
        : '${change.abs().toInt()}pts';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 9)),
                  Text(display,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnualCard() {
    final s = _annualSummary!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${s['months_tracked']} Month${(s['months_tracked'] as int) > 1 ? 's' : ''} Summary',
              style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _annualStat('Total Income',
                  formatCurrency(s['total_income']), AppColors.indigo),
              _annualStat('Total Savings',
                  formatCurrency(s['total_savings']), AppColors.green),
              _annualStat(
                  'Avg Score', '${s['avg_health_score']}', AppColors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _annualStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
      ],
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionItem(this.label, this.icon, this.color, this.bg, this.onTap);
}
