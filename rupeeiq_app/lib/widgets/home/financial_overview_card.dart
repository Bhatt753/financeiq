import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../common_widgets.dart';

// ── Enums & constants ────────────────────────────────────────────────────────

enum OverviewView { monthly, yearly, spending }

const _kIncome = 'income';
const _kExpenses = 'expenses';
const _kEmi = 'emi';
const _kSavings = 'savings';

const _spendCats = [
  'Rent/Housing',
  'Food & Groceries',
  'Transport',
  'Shopping',
  'Healthcare',
  'Entertainment',
  'Other',
];

const _spendColors = [
  Color(0xFF6366F1), // indigo   – Rent
  Color(0xFF22C55E), // green    – Food
  Color(0xFF06B6D4), // cyan     – Transport
  Color(0xFFEF4444), // red      – Shopping
  Color(0xFFA855F7), // purple   – Healthcare
  Color(0xFFF59E0B), // amber    – Entertainment
  Color(0xFFFB923C), // orange   – Other
];

// Lighter shade for gradient end
const _spendGradEnd = [
  Color(0xFF818CF8),
  Color(0xFF4ADE80),
  Color(0xFF22D3EE),
  Color(0xFFF87171),
  Color(0xFFC084FC),
  Color(0xFFFBBF24),
  Color(0xFFFDBA74),
];

const _spendIcons = [
  Icons.home_outlined,
  Icons.shopping_cart_outlined,
  Icons.directions_car_outlined,
  Icons.shopping_bag_outlined,
  Icons.medical_services_outlined,
  Icons.movie_outlined,
  Icons.more_horiz,
];

// ── Insight builder ──────────────────────────────────────────────────────────

class SpendingInsightBuilder {
  static String build(
    String category,
    double currAmt,
    int txnCount,
    double? prevAmt,
  ) {
    if (prevAmt != null && prevAmt > 0) {
      final pct = ((currAmt - prevAmt) / prevAmt * 100).round();
      if (pct > 30) return 'Up $pct% on $category vs last month.';
      if (pct < -20) return 'Down ${(-pct)}% on $category — good discipline!';
      if (pct.abs() <= 5) {
        if (category == 'Rent/Housing') return 'Rent is steady at ${_fK(currAmt)}/month.';
        return '$category is consistent — ${_fK(currAmt)} this month vs ${_fK(prevAmt)} last.';
      }
    }
    switch (category) {
      case 'Rent/Housing':
        return 'Housing at ${_fK(currAmt)} — your biggest fixed cost.';
      case 'Food & Groceries':
        return '$txnCount grocery trips totalling ${_fK(currAmt)} this month.';
      case 'Transport':
        return '$txnCount transport expenses — ${_fK(currAmt)} total.';
      case 'Shopping':
        return '${_fK(currAmt)} across $txnCount purchases this month.';
      case 'Healthcare':
        return 'Health spending: ${_fK(currAmt)} across $txnCount transactions.';
      case 'Entertainment':
        return 'Entertainment: ${_fK(currAmt)} over $txnCount items this month.';
      default:
        return 'Miscellaneous: ${_fK(currAmt)} across $txnCount transactions.';
    }
  }

  static String _fK(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}K';
    return '₹${v.toInt()}';
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _CatRow {
  final String name;
  final double amount;
  final int count;
  const _CatRow(this.name, this.amount, this.count);
}

// ── Widget ───────────────────────────────────────────────────────────────────

class FinancialOverviewCard extends StatefulWidget {
  final List<dynamic> history;
  final List<dynamic> goals;
  final void Function(Map<String, dynamic> entry, Map<String, dynamic>? prev)?
      onEntryTap;

  const FinancialOverviewCard({
    super.key,
    required this.history,
    this.goals = const [],
    this.onEntryTap,
  });

  @override
  State<FinancialOverviewCard> createState() => _FinancialOverviewCardState();
}

class _FinancialOverviewCardState extends State<FinancialOverviewCard> {
  OverviewView _view = OverviewView.monthly;
  final Set<String> _hiddenMonthly = {};
  final Set<String> _hiddenYearly = {};
  final Set<String> _hiddenSpend = {};

  final _pageCtrl = PageController();
  int _page = 0;

  List<_CatRow> _catData = [];
  List<_CatRow> _prevCatData = [];
  bool _loadingSpend = false;
  int? _touchedSeg;
  int _selectedMonthIdx = 0;
  final Map<int, List<_CatRow>> _catCache = {};
  final Map<int, List<_CatRow>> _prevCatCache = {};

  @override
  void initState() {
    super.initState();
    _loadSpendDataForMonth(0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadSpendDataForMonth(int idx) async {
    if (widget.history.isEmpty || idx >= widget.history.length) return;

    // Serve from cache immediately, no spinner
    if (_catCache.containsKey(idx)) {
      if (mounted) {
        setState(() {
          _catData = _catCache[idx]!;
          _prevCatData = _prevCatCache[idx] ?? [];
        });
      }
      return;
    }

    if (mounted) setState(() => _loadingSpend = true);
    try {
      final entry = widget.history[idx] as Map<String, dynamic>;
      final res = await ApiService.getHistoryEntry(entry['id'] as int);
      final exps =
          (res['expenses'] as List? ?? []).cast<Map<String, dynamic>>();
      final rows = _toCatRows(exps);
      _catCache[idx] = rows;

      List<_CatRow> prevRows = [];
      if (idx + 1 < widget.history.length) {
        final prev = widget.history[idx + 1] as Map<String, dynamic>;
        final prevRes = await ApiService.getHistoryEntry(prev['id'] as int);
        final prevExps =
            (prevRes['expenses'] as List? ?? []).cast<Map<String, dynamic>>();
        prevRows = _toCatRows(prevExps);
        _prevCatCache[idx] = prevRows;
      }

      if (mounted) {
        setState(() {
          _catData = rows;
          _prevCatData = prevRows;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSpend = false);
  }

  List<_CatRow> _toCatRows(List<Map<String, dynamic>> exps) {
    final amts = <String, double>{};
    final cnts = <String, int>{};
    for (final e in exps) {
      final cat = _normCat(e['category'] as String? ?? '');
      amts[cat] = (amts[cat] ?? 0) + (e['amount'] as num? ?? 0).toDouble();
      cnts[cat] = (cnts[cat] ?? 0) + 1;
    }
    return _spendCats
        .where((c) => amts.containsKey(c))
        .map((c) => _CatRow(c, amts[c]!, cnts[c]!))
        .toList();
  }

  String _normCat(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('rent') || l.contains('hous')) return 'Rent/Housing';
    if (l.contains('food') || l.contains('grocer') || l.contains('eat'))
      return 'Food & Groceries';
    if (l.contains('transport') ||
        l.contains('travel') ||
        l.contains('fuel') ||
        l.contains('uber') ||
        l.contains('ola')) return 'Transport';
    if (l.contains('shop') || l.contains('cloth') || l.contains('fashion'))
      return 'Shopping';
    if (l.contains('health') ||
        l.contains('medic') ||
        l.contains('doctor') ||
        l.contains('pharma')) return 'Healthcare';
    if (l.contains('entertain') ||
        l.contains('movie') ||
        l.contains('stream') ||
        l.contains('ott') ||
        l.contains('netflix') ||
        l.contains('spotify')) return 'Entertainment';
    return 'Other';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<dynamic> get _display {
    final all = widget.history;
    return (all.length > 6 ? all.sublist(0, 6) : all).reversed.toList();
  }

  Set<String> get _hidden {
    switch (_view) {
      case OverviewView.monthly:
        return _hiddenMonthly;
      case OverviewView.yearly:
        return _hiddenYearly;
      case OverviewView.spending:
        return _hiddenSpend;
    }
  }

  void _toggleSeries(String key) =>
      setState(() {
        _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
        _touchedSeg = null;
      });

  void _switchView(OverviewView v) {
    setState(() {
      _view = v;
      _page = v.index;
      _touchedSeg = null;
    });
    _pageCtrl.animateToPage(v.index,
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

  String _fmtAxis(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}K';
    return '₹${v.toInt()}';
  }

  _CatRow? _prevFor(String name) {
    for (final r in _prevCatData) {
      if (r.name == name) return r;
    }
    return null;
  }

  void _showMonthSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Select Month',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.history.length,
              itemBuilder: (ctx, i) {
                final entry =
                    widget.history[i] as Map<String, dynamic>;
                final label = '${entry['month']} ${entry['year']}';
                final totalExp =
                    ((entry['total_expenses'] as num? ?? 0) +
                            (entry['total_emi'] as num? ?? 0))
                        .toDouble();
                final isSelected = i == _selectedMonthIdx;
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.green.withOpacity(0.12)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_month_outlined,
                        size: 18,
                        color: isSelected
                            ? AppColors.green
                            : AppColors.textSub),
                  ),
                  title: Text(label,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500)),
                  subtitle: Text(
                      'Expenses: ${formatCurrency(totalExp)}',
                      style: const TextStyle(
                          color: AppColors.textSub, fontSize: 11)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.green, size: 18)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (i == _selectedMonthIdx) return;
                    setState(() {
                      _selectedMonthIdx = i;
                      _touchedSeg = null;
                      _hiddenSpend.clear();
                    });
                    _loadSpendDataForMonth(i);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _touchedSeg = null),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial Overview',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('Tap any bar or point for details',
                style: TextStyle(color: AppColors.textSub, fontSize: 12)),
            const SizedBox(height: 14),
            _buildTabs(),
            const SizedBox(height: 14),
            SizedBox(
              height: 305,
              child: PageView(
                controller: _pageCtrl,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) => setState(() {
                  _page = i;
                  _view = OverviewView.values[i];
                  _touchedSeg = null;
                }),
                children: [
                  _buildMonthlyPage(),
                  _buildYearlyPage(),
                  _buildSpendingPage(),
                ],
              ),
            ),
            // Insight card for tapped spending segment
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: (_view == OverviewView.spending && _touchedSeg != null)
                  ? _buildInsightCard(_touchedSeg!)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            _buildPageDots(),
            const SizedBox(height: 4),
            const Center(
              child: Text('Swipe to switch →',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab control ───────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    const labels = ['Monthly', 'Yearly', 'Spending'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final active = i == _view.index;
          return GestureDetector(
            onTap: () => _switchView(OverviewView.values[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textSub,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Page dots ─────────────────────────────────────────────────────────────────

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.green : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── Legend helper ─────────────────────────────────────────────────────────────

  Widget _buildLegend({
    required List<String> keys,
    required List<Color> colors,
    required List<String> labels,
    required Set<String> hidden,
    bool hollow = false,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: List.generate(keys.length, (i) {
        final isHidden = hidden.contains(keys[i]);
        return GestureDetector(
          onTap: () => _toggleSeries(keys[i]),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHidden
                      ? Colors.transparent
                      : (hollow ? Colors.white : colors[i]),
                  border: Border.all(
                    color: isHidden
                        ? colors[i].withOpacity(0.35)
                        : colors[i],
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                labels[i],
                style: TextStyle(
                  color: isHidden
                      ? AppColors.textMuted
                      : AppColors.textSub,
                  fontSize: 11,
                  decoration: isHidden
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Monthly page ──────────────────────────────────────────────────────────────

  Widget _buildMonthlyPage() {
    final display = _display;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(
          keys: [_kIncome, _kExpenses, _kEmi, _kSavings],
          colors: [
            AppColors.indigo,
            AppColors.red,
            AppColors.amber,
            AppColors.green
          ],
          labels: ['Income', 'Expenses', 'EMI', 'Savings'],
          hidden: _hiddenMonthly,
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBarChart(display)),
      ],
    );
  }

  Widget _buildBarChart(List<dynamic> display) {
    double maxY = 0;
    for (final m in display) {
      final e = m as Map<String, dynamic>;
      final inc = _hiddenMonthly.contains(_kIncome)
          ? 0.0
          : (e['income'] as num? ?? 0).toDouble();
      final exp = _hiddenMonthly.contains(_kExpenses)
          ? 0.0
          : (e['total_expenses'] as num? ?? 0).toDouble();
      final emi = _hiddenMonthly.contains(_kEmi)
          ? 0.0
          : (e['total_emi'] as num? ?? 0).toDouble();
      final sav = _hiddenMonthly.contains(_kSavings)
          ? 0.0
          : math.max(0.0, (e['savings'] as num? ?? 0).toDouble());
      maxY = math.max(maxY, math.max(inc, exp + emi + sav));
    }

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, gi, rod, ri) {
              if (gi >= display.length) return null;
              final e = display[gi] as Map<String, dynamic>;
              final month = e['month'] as String? ?? '';
              final label = ri == 0 ? 'Income' : 'Total';
              return BarTooltipItem(
                '$month\n$label: ${formatCurrency(rod.toY)}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              );
            },
          ),
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions) return;
            final gi = response?.spot?.touchedBarGroupIndex;
            if (gi == null || gi >= display.length) return;
            final d = _display;
            final entry = d[gi] as Map<String, dynamic>;
            final prev = gi > 0 ? d[gi - 1] as Map<String, dynamic> : null;
            widget.onEntryTap?.call(entry, prev);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, _) => Text(_fmtAxis(val),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 9)),
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= display.length) return const SizedBox();
                final m =
                    (display[idx] as Map)['month'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(m.length > 3 ? m.substring(0, 3) : m,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 9)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(display.length, (i) {
          final e = display[i] as Map<String, dynamic>;
          final inc =
              (e['income'] as num? ?? 0).toDouble();
          final exp =
              (e['total_expenses'] as num? ?? 0).toDouble();
          final emi =
              (e['total_emi'] as num? ?? 0).toDouble();
          final sav =
              math.max(0.0, (e['savings'] as num? ?? 0).toDouble());

          final incY = _hiddenMonthly.contains(_kIncome) ? 0.001 : inc;
          final expV =
              _hiddenMonthly.contains(_kExpenses) ? 0.0 : exp;
          final emiV =
              _hiddenMonthly.contains(_kEmi) ? 0.0 : emi;
          final savV =
              _hiddenMonthly.contains(_kSavings) ? 0.0 : sav;

          double cursor = 0;
          final stackItems = <BarChartRodStackItem>[];
          if (expV > 0) {
            stackItems.add(
                BarChartRodStackItem(cursor, cursor + expV, AppColors.red));
            cursor += expV;
          }
          if (emiV > 0) {
            stackItems.add(BarChartRodStackItem(
                cursor, cursor + emiV, AppColors.amber));
            cursor += emiV;
          }
          if (savV > 0) {
            stackItems.add(BarChartRodStackItem(
                cursor, cursor + savV, AppColors.green));
            cursor += savV;
          }

          return BarChartGroupData(
            x: i,
            barsSpace: 3,
            barRods: [
              BarChartRodData(
                toY: incY,
                color: _hiddenMonthly.contains(_kIncome)
                    ? Colors.transparent
                    : AppColors.indigo,
                width: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              BarChartRodData(
                toY: cursor == 0 ? 0.001 : cursor,
                width: 12,
                borderRadius: BorderRadius.circular(6),
                rodStackItems: stackItems.isEmpty
                    ? [BarChartRodStackItem(0, 0.001, Colors.transparent)]
                    : stackItems,
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Yearly page ───────────────────────────────────────────────────────────────

  Widget _buildYearlyPage() {
    final display = _display;
    return Column(
      children: [
        _buildLegend(
          keys: [_kIncome, _kExpenses, _kEmi, _kSavings],
          colors: [
            AppColors.indigo,
            AppColors.red,
            AppColors.amber,
            AppColors.green
          ],
          labels: ['Income', 'Expenses', 'EMI', 'Savings'],
          hidden: _hiddenYearly,
          hollow: true,
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildLineChart(display)),
      ],
    );
  }

  Widget _buildLineChart(List<dynamic> display) {
    FlSpot _spot(int i, dynamic val) =>
        FlSpot(i.toDouble(), (val as num? ?? 0).toDouble());

    double maxY = 0;
    for (final m in display) {
      final e = m as Map<String, dynamic>;
      if (!_hiddenYearly.contains(_kIncome)) {
        maxY = math.max(maxY, (e['income'] as num? ?? 0).toDouble());
      }
      if (!_hiddenYearly.contains(_kExpenses)) {
        maxY = math.max(
            maxY,
            ((e['total_expenses'] as num? ?? 0) +
                    (e['total_emi'] as num? ?? 0))
                .toDouble());
      }
    }

    FlDotCirclePainter _hollow(Color c) => FlDotCirclePainter(
        radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: c);

    final bars = <LineChartBarData>[];

    if (!_hiddenYearly.contains(_kIncome)) {
      bars.add(LineChartBarData(
        spots: List.generate(
            display.length, (i) => _spot(i, (display[i] as Map)['income'])),
        isCurved: true,
        color: AppColors.indigo,
        barWidth: 2,
        dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) => _hollow(AppColors.indigo)),
        belowBarData:
            BarAreaData(show: true, color: AppColors.indigo.withOpacity(0.07)),
      ));
    }
    if (!_hiddenYearly.contains(_kExpenses)) {
      bars.add(LineChartBarData(
        spots: List.generate(display.length, (i) {
          final e = display[i] as Map<String, dynamic>;
          return FlSpot(
              i.toDouble(),
              ((e['total_expenses'] as num? ?? 0) +
                      (e['total_emi'] as num? ?? 0))
                  .toDouble());
        }),
        isCurved: true,
        color: AppColors.red,
        barWidth: 2,
        dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) => _hollow(AppColors.red)),
        belowBarData:
            BarAreaData(show: true, color: AppColors.red.withOpacity(0.07)),
      ));
    }
    if (!_hiddenYearly.contains(_kEmi)) {
      bars.add(LineChartBarData(
        spots: List.generate(display.length,
            (i) => _spot(i, (display[i] as Map)['total_emi'])),
        isCurved: true,
        color: AppColors.amber,
        barWidth: 2,
        dashArray: [6, 4],
        dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) => _hollow(AppColors.amber)),
      ));
    }
    if (!_hiddenYearly.contains(_kSavings)) {
      bars.add(LineChartBarData(
        spots: List.generate(display.length, (i) {
          final s = ((display[i] as Map)['savings'] as num? ?? 0).toDouble();
          return FlSpot(i.toDouble(), s < 0 ? 0.0 : s);
        }),
        isCurved: true,
        color: AppColors.green,
        barWidth: 2,
        dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) => _hollow(AppColors.green)),
        belowBarData:
            BarAreaData(show: true, color: AppColors.green.withOpacity(0.07)),
      ));
    }

    return LineChart(
      LineChartData(
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, _) => Text(_fmtAxis(val),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 9)),
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= display.length) return const SizedBox();
                final m = (display[idx] as Map)['month'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(m.length > 3 ? m.substring(0, 3) : m,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 9)),
                );
              },
            ),
          ),
        ),
        lineBarsData: bars.isEmpty
            ? [
                LineChartBarData(
                    spots: const [FlSpot(0, 0)],
                    color: Colors.transparent)
              ]
            : bars,
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions) return;
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) return;
            final idx = spots.first.x.toInt();
            final d = _display;
            if (idx < 0 || idx >= d.length) return;
            final entry = d[idx] as Map<String, dynamic>;
            final prev = idx > 0 ? d[idx - 1] as Map<String, dynamic> : null;
            widget.onEntryTap?.call(entry, prev);
          },
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      formatCurrency(s.y),
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  // ── Spending page ─────────────────────────────────────────────────────────────

  Widget _buildSpendingPage() {
    if (_loadingSpend) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.green, strokeWidth: 2));
    }

    final visible =
        _catData.where((c) => !_hiddenSpend.contains(c.name)).toList();
    final total = visible.fold<double>(0, (s, c) => s + c.amount);

    final selectedEntry = widget.history.isNotEmpty &&
            _selectedMonthIdx < widget.history.length
        ? widget.history[_selectedMonthIdx] as Map<String, dynamic>
        : null;
    final monthLabel = selectedEntry != null
        ? '${selectedEntry['month']} ${selectedEntry['year']}'
        : 'This Month';

    return Column(
      children: [
        // Legend with rounded-square swatches
        _buildSpendLegend(),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty || total == 0
              ? const Center(
                  child: Text('No spending data.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 13)))
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 58,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions) return;
                            final idx = response
                                ?.touchedSection?.touchedSectionIndex;
                            setState(() {
                              _touchedSeg =
                                  (idx == _touchedSeg) ? null : idx;
                            });
                          },
                        ),
                        sections: List.generate(visible.length, (i) {
                          final cat = visible[i];
                          final ci = _spendCats.indexOf(cat.name);
                          final baseColor = ci >= 0
                              ? _spendColors[ci]
                              : _spendColors.last;
                          final gradEnd = ci >= 0
                              ? _spendGradEnd[ci]
                              : _spendGradEnd.last;
                          final isTouched = _touchedSeg == i;
                          final radius = isTouched ? 64.0 : 54.0;

                          return PieChartSectionData(
                            value: cat.amount,
                            radius: radius,
                            color: baseColor,
                            gradient: LinearGradient(
                              colors: [baseColor, gradEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            title: '',
                            badgeWidget: _buildCallout(
                              cat.name,
                              cat.amount / total * 100,
                              ci >= 0 ? _spendIcons[ci] : Icons.more_horiz,
                              baseColor,
                              isTouched,
                            ),
                            badgePositionPercentageOffset: 1.28,
                          );
                        }),
                      ),
                    ),
                    // Center disc — tap to select month
                    GestureDetector(
                      onTap: () => _showMonthSelector(context),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x18000000),
                                blurRadius: 10,
                                spreadRadius: 1)
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Spending',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(monthLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSub, fontSize: 9)),
                            const SizedBox(height: 1),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCallout(
      String name, double pct, IconData icon, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: active ? color : const Color(0xFFE5E7EB), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 3, offset: Offset(0, 1))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: active ? color : AppColors.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 5,
      children: _catData.map((cat) {
        final ci = _spendCats.indexOf(cat.name);
        final color = ci >= 0 ? _spendColors[ci] : _spendColors.last;
        final hidden = _hiddenSpend.contains(cat.name);
        return GestureDetector(
          onTap: () => _toggleSeries(cat.name),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: hidden ? Colors.transparent : color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: hidden ? color.withOpacity(0.4) : color,
                      width: 1.5),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                cat.name,
                style: TextStyle(
                  color:
                      hidden ? AppColors.textMuted : AppColors.textSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  decoration: hidden
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Insight card ──────────────────────────────────────────────────────────────

  Widget _buildInsightCard(int segIdx) {
    final visible =
        _catData.where((c) => !_hiddenSpend.contains(c.name)).toList();
    if (segIdx >= visible.length) return const SizedBox.shrink();
    final cat = visible[segIdx];
    final ci = _spendCats.indexOf(cat.name);
    final color = ci >= 0 ? _spendColors[ci] : _spendColors.last;
    final icon =
        ci >= 0 ? _spendIcons[ci] : Icons.more_horiz;
    final total = visible.fold<double>(0, (s, c) => s + c.amount);
    final pct = total > 0 ? (cat.amount / total * 100) : 0.0;
    final prev = _prevFor(cat.name);
    final insight = SpendingInsightBuilder.build(
        cat.name, cat.amount, cat.count, prev?.amount);

    return Container(
      key: ValueKey(segIdx),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text(
                        '${pct.toStringAsFixed(1)}% · ${cat.count} txn',
                        style: const TextStyle(
                            color: AppColors.textSub, fontSize: 10)),
                  ],
                ),
              ),
              Text(formatCurrency(cat.amount),
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(insight,
                    style: const TextStyle(
                        color: AppColors.textSub,
                        fontSize: 11,
                        height: 1.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
