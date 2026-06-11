import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'add_data_screen.dart';
import 'edit_entry_screen.dart';
import 'health_screen.dart';
import 'goals_screen.dart';

class MonthDetailScreen extends StatefulWidget {
  final Map<String, dynamic> entry;
  final Map<String, dynamic>? prevEntry;
  final Map<String, dynamic>? firstGoal;

  const MonthDetailScreen({
    super.key,
    required this.entry,
    this.prevEntry,
    this.firstGoal,
  });

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCats = true;

  double get emiV =>
      (widget.entry['total_emi'] as num?)?.toDouble() ?? 0.0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final id = widget.entry['id'];
      if (id == null) { setState(() => _loadingCats = false); return; }
      final res = await ApiService.getHistoryEntry(id as int);
      final expenses = (res['expenses'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final Map<String, double> catMap = {};
      for (final e in expenses) {
        final cat = e['category'] as String? ?? 'Other';
        final amt = (e['amount'] as num? ?? 0).toDouble();
        catMap[cat] = (catMap[cat] ?? 0) + amt;
      }
      final sorted = catMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      setState(() {
        _categories =
            sorted.map((e) => {'name': e.key, 'amount': e.value}).toList();
        _loadingCats = false;
      });
    } catch (_) {
      setState(() => _loadingCats = false);
    }
  }

  int? _pctChange(double current, double? prev) {
    if (prev == null || prev == 0) return null;
    return ((current - prev) / prev.abs() * 100).round();
  }

  String _sign(int n) => n > 0 ? '+' : '';

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final prev = widget.prevEntry;

    final income = (e['income'] as num? ?? 0).toDouble();
    final expenses = (e['total_expenses'] as num? ?? 0).toDouble();
    final savings = (e['savings'] as num? ?? 0).toDouble();
    final sr = (e['savings_rate'] as num? ?? 0).toDouble();

    final prevIncome =
        prev != null ? (prev['income'] as num? ?? 0).toDouble() : null;
    final prevExp = prev != null
        ? (prev['total_expenses'] as num? ?? 0).toDouble()
        : null;
    final prevSav =
        prev != null ? (prev['savings'] as num? ?? 0).toDouble() : null;

    final savTrend = _pctChange(savings, prevSav);
    final expTrend = _pctChange(expenses, prevExp);
    final incTrend = _pctChange(income, prevIncome);
    final emiLoad = income > 0 ? (emiV / income * 100).round() : 0;
    final expRatio = income > 0 ? (expenses / income * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('${e['month']} ${e['year']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        physics: const BouncingScrollPhysics(),
        children: [
          // 4 Trend cards
          _buildTrendGrid(savTrend, expTrend, incTrend, emiLoad, income,
              expenses, savings, sr),
          const SizedBox(height: 14),
          // Insight + Advice
          _buildInsightCard(savTrend, expTrend, incTrend, emiLoad, expRatio,
              savings, sr),
          // Goal progress
          if (widget.firstGoal != null) ...[
            const SizedBox(height: 14),
            _buildGoalProgress(savings),
          ],
          const SizedBox(height: 16),
          _sectionLabel('This Month'),
          const SizedBox(height: 10),
          _buildMetrics(income, expenses, emiV, savings, sr, emiLoad,
              expRatio),
          const SizedBox(height: 16),
          _sectionLabel('Category Breakdown'),
          const SizedBox(height: 10),
          _buildCategoryBreakdown(),
          const SizedBox(height: 16),
          _sectionLabel('Quick Actions'),
          const SizedBox(height: 10),
          _buildActions(),
        ],
      ),
    );
  }

  // ── Trend Cards ───────────────────────────────────────────────────────────

  Widget _buildTrendGrid(int? savTrend, int? expTrend, int? incTrend,
      int emiLoad, double income, double expenses, double savings, double sr) {
    final e = widget.entry;

    final cards = [
      _trendCardData(
        title: 'Savings Trend',
        icon: Icons.trending_up_rounded,
        iconBg: AppColors.greenBadgeBg,
        iconColor: AppColors.green,
        value: savTrend != null
            ? '${_sign(savTrend)}$savTrend%'
            : '${sr.toStringAsFixed(1)}%',
        valueColor: savTrend == null
            ? AppColors.green
            : (savTrend >= 0 ? AppColors.green : AppColors.red),
        sub: savTrend != null ? 'vs last month' : 'savings rate',
        badge: savTrend == null
            ? 'This month'
            : (savTrend >= 10
                ? 'Healthy growth'
                : savTrend >= 0
                    ? 'On track'
                    : 'Needs attention'),
        badgeBg: savTrend == null
            ? AppColors.surfaceAlt
            : (savTrend >= 0 ? AppColors.greenBadgeBg : AppColors.redBg),
        badgeText: savTrend == null
            ? AppColors.textSub
            : (savTrend >= 0 ? AppColors.greenDark : AppColors.redText),
      ),
      _trendCardData(
        title: 'Expenses Trend',
        icon: Icons.north_east_rounded,
        iconBg:
            expTrend != null && expTrend > 5 ? AppColors.redBg : AppColors.greenBadgeBg,
        iconColor:
            expTrend != null && expTrend > 5 ? AppColors.red : AppColors.green,
        value: expTrend != null
            ? '${_sign(expTrend)}$expTrend%'
            : '$expRatio% of income',
        valueColor: expTrend == null
            ? AppColors.red
            : (expTrend > 5 ? AppColors.red : AppColors.green),
        sub: expTrend != null ? 'vs last month' : 'of income',
        badge: expTrend == null
            ? 'This month'
            : (expTrend > 10
                ? 'Needs attention'
                : expTrend > 0
                    ? 'Monitor'
                    : 'Well controlled'),
        badgeBg: expTrend == null
            ? AppColors.surfaceAlt
            : (expTrend > 5 ? AppColors.redBg : AppColors.greenBadgeBg),
        badgeText: expTrend == null
            ? AppColors.textSub
            : (expTrend > 5 ? AppColors.redText : AppColors.greenDark),
      ),
      _trendCardData(
        title: 'EMI Load',
        icon: Icons.credit_card_outlined,
        iconBg: AppColors.indigoBg,
        iconColor: AppColors.indigo,
        value: '$emiLoad%',
        valueColor: AppColors.indigo,
        sub: 'of income',
        badge: emiV == 0
            ? 'No loans'
            : (emiLoad <= 30
                ? 'Healthy range'
                : emiLoad <= 40
                    ? 'Moderate'
                    : 'High load'),
        badgeBg: emiV == 0
            ? AppColors.surfaceAlt
            : (emiLoad <= 30
                ? AppColors.indigoBg
                : emiLoad <= 40
                    ? AppColors.amberBadgeBg
                    : AppColors.redBg),
        badgeText: emiV == 0
            ? AppColors.textSub
            : (emiLoad <= 30
                ? AppColors.indigoDark
                : emiLoad <= 40
                    ? AppColors.amberText
                    : AppColors.redText),
      ),
      _trendCardData(
        title: 'Income Trend',
        icon: Icons.show_chart_rounded,
        iconBg:
            incTrend != null && incTrend < 0 ? AppColors.redBg : AppColors.indigoBg,
        iconColor:
            incTrend != null && incTrend < 0 ? AppColors.red : AppColors.indigo,
        value: incTrend != null
            ? '${_sign(incTrend)}$incTrend%'
            : formatCurrency(income),
        valueColor: incTrend == null
            ? AppColors.indigo
            : (incTrend >= 0 ? AppColors.indigo : AppColors.red),
        sub: incTrend != null ? 'vs last month' : 'this month',
        badge: incTrend == null
            ? 'This month'
            : (incTrend > 5
                ? 'Growing'
                : incTrend >= 0
                    ? 'On track'
                    : 'Declined'),
        badgeBg: incTrend == null
            ? AppColors.surfaceAlt
            : (incTrend >= 0 ? AppColors.indigoBg : AppColors.redBg),
        badgeText: incTrend == null
            ? AppColors.textSub
            : (incTrend >= 0 ? AppColors.indigoDark : AppColors.redText),
      ),
    ];

    return Column(
      children: [
        Row(children: [
          Expanded(child: _trendCard(cards[0])),
          const SizedBox(width: 10),
          Expanded(child: _trendCard(cards[1])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _trendCard(cards[2])),
          const SizedBox(width: 10),
          Expanded(child: _trendCard(cards[3])),
        ]),
      ],
    );
  }

  Map<String, dynamic> _trendCardData({
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required Color valueColor,
    required String sub,
    required String badge,
    required Color badgeBg,
    required Color badgeText,
  }) => {
        'title': title,
        'icon': icon,
        'iconBg': iconBg,
        'iconColor': iconColor,
        'value': value,
        'valueColor': valueColor,
        'sub': sub,
        'badge': badge,
        'badgeBg': badgeBg,
        'badgeText': badgeText,
      };

  Widget _trendCard(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d['title'] as String,
              style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: d['iconBg'] as Color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(d['icon'] as IconData,
                color: d['iconColor'] as Color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(d['value'] as String,
              style: TextStyle(
                  color: d['valueColor'] as Color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -0.5)),
          const SizedBox(height: 3),
          Text(d['sub'] as String,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: d['badgeBg'] as Color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(d['badge'] as String,
                style: TextStyle(
                    color: d['badgeText'] as Color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Insight + Advice Card ─────────────────────────────────────────────────

  int get expRatio {
    final income = (widget.entry['income'] as num? ?? 0).toDouble();
    final expenses = (widget.entry['total_expenses'] as num? ?? 0).toDouble();
    return income > 0 ? (expenses / income * 100).round() : 0;
  }

  Widget _buildInsightCard(int? savTrend, int? expTrend, int? incTrend,
      int emiLoad, int expRatio, double savings, double sr) {
    final spans = <InlineSpan>[];

    if (widget.prevEntry != null) {
      if (savTrend != null) {
        spans.add(const TextSpan(text: 'Your savings '));
        spans.add(TextSpan(
          text: savTrend >= 0
              ? 'increased by ${savTrend.abs()}%'
              : 'decreased by ${savTrend.abs()}%',
          style: TextStyle(
              color: savTrend >= 0 ? AppColors.green : AppColors.red,
              fontWeight: FontWeight.w600),
        ));
      }
      if (expTrend != null) {
        spans.add(TextSpan(
            text: savTrend != null ? ' while expenses ' : 'Expenses '));
        spans.add(TextSpan(
          text: expTrend >= 0
              ? 'rose by ${expTrend.abs()}%'
              : 'fell by ${expTrend.abs()}%',
          style: TextStyle(
              color: expTrend > 0 ? AppColors.red : AppColors.green,
              fontWeight: FontWeight.w600),
        ));
      }
      if (emiLoad > 0) {
        spans.add(const TextSpan(text: '. EMI load is at '));
        spans.add(TextSpan(
          text: '$emiLoad% of income',
          style: const TextStyle(
              color: AppColors.indigo, fontWeight: FontWeight.w600),
        ));
        spans.add(TextSpan(
            text: emiLoad <= 30
                ? ' — healthy range'
                : emiLoad <= 40
                    ? ' — moderate'
                    : ' — review needed'));
      }
      if (incTrend != null && incTrend > 0) {
        spans.add(const TextSpan(
            text: ', and your income is growing consistently.'));
      } else if (incTrend != null && incTrend < 0) {
        spans.add(
            const TextSpan(text: ', though income declined this month.'));
      } else {
        spans.add(const TextSpan(text: '.'));
      }
    } else {
      spans.add(const TextSpan(text: 'Your savings rate is '));
      spans.add(TextSpan(
        text: '${sr.toStringAsFixed(1)}%',
        style: const TextStyle(
            color: AppColors.green, fontWeight: FontWeight.w600),
      ));
      spans.add(const TextSpan(text: ' of income.'));
      if (emiLoad > 0) {
        spans.add(const TextSpan(text: ' EMI load is '));
        spans.add(TextSpan(
          text: '$emiLoad%',
          style: const TextStyle(
              color: AppColors.indigo, fontWeight: FontWeight.w600),
        ));
        spans.add(const TextSpan(text: ' of income.'));
      }
      spans.add(const TextSpan(text: ' Expenses are '));
      spans.add(TextSpan(
        text: '$expRatio%',
        style: TextStyle(
            color: expRatio > 70 ? AppColors.red : AppColors.green,
            fontWeight: FontWeight.w600),
      ));
      spans.add(const TextSpan(text: ' of your income.'));
    }

    final advice = <Map<String, dynamic>>[];
    if (sr >= 20) {
      advice.add({
        'icon': Icons.savings_outlined,
        'bg': AppColors.greenBadgeBg,
        'color': AppColors.green,
        'text':
            'Great job! You\'re saving ${sr.toStringAsFixed(0)}% of income — keep building this habit.',
      });
    } else {
      advice.add({
        'icon': Icons.savings_outlined,
        'bg': AppColors.amberBadgeBg,
        'color': AppColors.amber,
        'text':
            'Try to save at least 20% of income. Currently at ${sr.toStringAsFixed(0)}%.',
      });
    }
    if (expRatio < 70) {
      advice.add({
        'icon': Icons.account_balance_wallet_outlined,
        'bg': AppColors.greenBadgeBg,
        'color': AppColors.green,
        'text':
            'Expenses are $expRatio% of income — well within the 70% guideline.',
      });
    } else {
      advice.add({
        'icon': Icons.account_balance_wallet_outlined,
        'bg': AppColors.amberBadgeBg,
        'color': AppColors.amber,
        'text':
            'Try to keep expenses below 70% of income. Currently at $expRatio%.',
      });
    }
    if (savings > 500) {
      advice.add({
        'icon': Icons.trending_up_rounded,
        'bg': AppColors.indigoBg,
        'color': AppColors.indigo,
        'text':
            'Consider investing ${formatCurrency(savings / 2)}/month in SIP for long-term wealth.',
      });
    } else {
      advice.add({
        'icon': Icons.trending_up_rounded,
        'bg': AppColors.indigoBg,
        'color': AppColors.indigo,
        'text':
            'Build an emergency fund first, then explore SIP investments.',
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insight section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.amberBadgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb_outline_rounded,
                        color: AppColors.amber, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text('Financial Insight',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 13,
                        height: 1.7),
                    children: spans,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Advice section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Practical Advice',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ...advice.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: a['bg'] as Color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(a['icon'] as IconData,
                                color: a['color'] as Color, size: 15),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(a['text'] as String,
                                style: const TextStyle(
                                    color: AppColors.textMid,
                                    fontSize: 13,
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Goal Progress ─────────────────────────────────────────────────────────

  Widget _buildGoalProgress(double monthlySavings) {
    final g = widget.firstGoal!;
    final amount = (g['goal_amount'] as num? ?? 0).toDouble();
    final pct = (g['progress_pct'] as num? ?? 0).toDouble();
    final savedSoFar = amount * pct / 100;
    final remaining = (amount - savedSoFar).clamp(0.0, double.infinity);
    final monthsLeft = monthlySavings > 0 && remaining > 0
        ? (remaining / monthlySavings).ceil()
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceGreen,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderGreen),
              ),
              child: const Icon(Icons.flag_outlined,
                  color: AppColors.green, size: 15),
            ),
            const SizedBox(width: 8),
            const Text('Goal Progress',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceGreen,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderGreen),
                ),
                child: const Icon(Icons.track_changes_outlined,
                    color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 13,
                        height: 1.6),
                    children: [
                      const TextSpan(
                          text: 'You\'re on track to reach your '),
                      TextSpan(
                        text: formatCurrency(amount),
                        style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' goal'),
                      if (monthsLeft != null) ...[
                        const TextSpan(text: ' in '),
                        TextSpan(
                          text: '~$monthsLeft months',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Goal Progress',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 3),
                  Text('${pct.toInt()}%',
                      style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: const Cubic(0.16, 1, 0.3, 1),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.green),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Key Metrics ───────────────────────────────────────────────────────────

  Widget _buildMetrics(double income, double expenses, double emiV,
      double savings, double sr, int emiLoad, int expRatio) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _metricTile('Income', formatCurrency(income), 'Monthly income',
            AppColors.indigo),
        _metricTile('Expenses', formatCurrency(expenses),
            '$expRatio% of income', AppColors.red),
        _metricTile(
          'Loan EMI',
          formatCurrency(emiV),
          emiV > 0 ? '$emiLoad% of income' : 'No active loans',
          AppColors.amber,
          dimmed: emiV == 0,
        ),
        _metricTile(
            'Savings',
            formatCurrency(savings < 0 ? 0 : savings),
            '${sr.toStringAsFixed(1)}% savings rate',
            AppColors.green),
      ],
    );
  }

  Widget _metricTile(
      String label, String value, String sub, Color color,
      {bool dimmed = false}) {
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000),
                blurRadius: 3,
                offset: Offset(0, 1))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.2),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(sub,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Category Breakdown ────────────────────────────────────────────────────

  Widget _buildCategoryBreakdown() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: _loadingCats
          ? Column(
              children: List.generate(
                  4,
                  (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ShimmerBox(
                            height: 36,
                            borderRadius: BorderRadius.circular(8)),
                      )))
          : _categories.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No expense data',
                        style:
                            TextStyle(color: AppColors.textSub, fontSize: 13)),
                  ),
                )
              : Column(
                  children: List.generate(_categories.length, (i) {
                    final cat = _categories[i];
                    final name = cat['name'] as String;
                    final amt = cat['amount'] as double;
                    final maxAmt =
                        (_categories[0]['amount'] as double);
                    final pct = maxAmt > 0 ? (amt / maxAmt) : 0.0;
                    final color = _catColor(i);
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: i < _categories.length - 1 ? 12 : 0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              Text(formatCurrency(amt),
                                  style: const TextStyle(
                                      color: AppColors.textSub,
                                      fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: pct.toDouble()),
                              duration: Duration(
                                  milliseconds: 550 + i * 60),
                              curve: const Cubic(0.16, 1, 0.3, 1),
                              builder: (_, v, __) =>
                                  LinearProgressIndicator(
                                value: v.clamp(0.0, 1.0),
                                backgroundColor:
                                    const Color(0xFFF3F4F6),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                                minHeight: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
    );
  }

  Color _catColor(int idx) {
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF22C55E),
      Color(0xFF06B6D4),
      Color(0xFFEF4444),
      Color(0xFFA855F7),
      Color(0xFFF59E0B),
      Color(0xFFFB923C),
      Color(0xFF0EA5E9),
    ];
    return palette[idx % palette.length];
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildActions() {
    final e = widget.entry;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: [
        _actionBtn(
          label: 'Add Data',
          icon: Icons.add_circle_outline_rounded,
          bg: AppColors.green,
          fg: Colors.white,
          border: Colors.transparent,
          onTap: () => Navigator.push(
              context, fadeRoute(const AddDataScreen())),
        ),
        _actionBtn(
          label: 'Edit Entry',
          icon: Icons.edit_outlined,
          bg: AppColors.indigoBg,
          fg: AppColors.indigo,
          border: AppColors.indigoBorder,
          onTap: () => Navigator.push(
              context,
              fadeRoute(EditEntryScreen(
                entryId: e['id'] as int,
                month: e['month'] as String,
                year: e['year'] as int,
              ))),
        ),
        _actionBtn(
          label: 'Health Score',
          icon: Icons.favorite_outline_rounded,
          bg: AppColors.surface,
          fg: AppColors.textMid,
          border: AppColors.border,
          onTap: () =>
              Navigator.push(context, fadeRoute(const HealthScreen())),
        ),
        _actionBtn(
          label: 'My Goals',
          icon: Icons.track_changes_rounded,
          bg: AppColors.surface,
          fg: AppColors.textMid,
          border: AppColors.border,
          onTap: () =>
              Navigator.push(context, fadeRoute(const GoalsScreen())),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return TapScaleWrapper(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000),
                blurRadius: 3,
                offset: Offset(0, 1))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6));
  }
}
