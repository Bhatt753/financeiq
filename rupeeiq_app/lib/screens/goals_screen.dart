import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<dynamic> _goals = [];
  double _currentSavings = 0;
  double _latestIncome = 0;
  bool _loadingGoals = true;
  String? _goalsError;

  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  Map<String, dynamic>? _analysisResult;
  double _analysisIncome = 0;
  bool _analyzing = false;
  String? _analyzeError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadGoals();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() { _loadingGoals = true; _goalsError = null; });
    try {
      final results = await Future.wait([
        ApiService.getGoals(),
        ApiService.getDashboard(),
      ]);
      final goalsRes = results[0];
      if (goalsRes['error'] != null) {
        setState(() {
          _goalsError = goalsRes['error'] as String;
          _loadingGoals = false;
        });
        return;
      }
      final dashRes = results[1];
      final histList = dashRes['history'] as List? ?? [];
      final latestIncome = histList.isNotEmpty
          ? ((histList[0] as Map)['income'] as num? ?? 0).toDouble()
          : 0.0;
      setState(() {
        _goals = goalsRes['goals'] as List? ?? [];
        _currentSavings =
            (goalsRes['current_savings'] as num? ?? 0).toDouble();
        _latestIncome = latestIncome;
        _loadingGoals = false;
      });
    } catch (e) {
      setState(() {
        _goalsError = 'Failed to load goals.';
        _loadingGoals = false;
      });
    }
  }

  Future<void> _analyze() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text);
    final months = int.tryParse(_monthsCtrl.text);
    if (name.isEmpty || amount == null || amount <= 0) {
      setState(() =>
          _analyzeError = 'Enter a goal name and valid target amount.');
      return;
    }
    setState(() {
      _analyzing = true;
      _analyzeError = null;
      _analysisResult = null;
    });
    try {
      final res = await ApiService.analyzeGoal(
        goalName: name,
        goalAmount: amount,
        goalMonths: months ?? 12,
      );
      if (res['error'] != null) {
        setState(() {
          _analyzeError = res['error'] as String;
          _analyzing = false;
        });
        return;
      }
      setState(() {
        _analysisResult = res['result'] as Map<String, dynamic>?;
        _analysisIncome = (res['income'] as num? ?? 0).toDouble();
        _analyzing = false;
      });
      _loadGoals();
    } catch (e) {
      setState(() {
        _analyzeError = 'Analysis failed. Check your connection.';
        _analyzing = false;
      });
    }
  }

  Future<void> _complete(int id) async {
    try {
      await ApiService.completeGoal(id);
      _loadGoals();
    } catch (_) {}
  }

  Future<void> _delete(int id) async {
    try {
      await ApiService.deleteGoal(id);
      _loadGoals();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Planner'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Plan Goal'), Tab(text: 'My Goals')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildPlanTab(), _buildMyGoalsTab()],
      ),
    );
  }

  Widget _buildPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_analyzeError != null) _errorBanner(_analyzeError!),
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Goal Name (e.g. Emergency Fund)',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Target Amount (₹)',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _monthsCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Target Timeline (months)',
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _analyzing ? null : _analyze,
              child: _analyzing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Analyse & Save Goal'),
            ),
          ),
          if (_analysisResult != null) ...[
            const SizedBox(height: 20),
            _buildAnalysisCard(_analysisResult!),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> r) {
    final difficulty = r['difficulty'] as String? ?? 'HARD';
    final gap = (r['gap'] as num? ?? 0).toDouble();
    final requiredMonthly =
        (r['required_monthly'] as num? ?? 0).toDouble();
    final currentSavings =
        (r['current_savings'] as num? ?? 0).toDouble();
    final realisticMonths = r['realistic_months'] as int?;
    final actionPlan = r['action_plan'] as List? ?? [];
    final goldenRules = r['golden_rules'] as List? ?? [];
    final loanImpact = r['loan_impact'] as Map<String, dynamic>?;

    final isAchieved = difficulty == 'ACHIEVED' || gap <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main result card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAchieved ? AppColors.surfaceGreen : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isAchieved
                    ? AppColors.borderGreen
                    : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                      isAchieved
                          ? Icons.check_circle_outline
                          : Icons.analytics_outlined,
                      color:
                          isAchieved ? AppColors.green : AppColors.indigo,
                      size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAchieved ? 'Goal is Achievable!' : 'Goal Analysis',
                      style: TextStyle(
                          color: isAchieved
                              ? AppColors.greenDark
                              : AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                  DifficultyBadge(difficulty: difficulty),
                ],
              ),
              const SizedBox(height: 14),
              InfoRow(
                  label: 'Monthly Savings Needed',
                  value: formatCurrency(requiredMonthly),
                  valueColor: AppColors.indigo),
              InfoRow(
                  label: 'Your Current Savings',
                  value: formatCurrency(currentSavings),
                  valueColor: AppColors.green),
              if (gap > 0)
                InfoRow(
                    label: 'Monthly Gap',
                    value: formatCurrency(gap),
                    valueColor: AppColors.red),
              if (realisticMonths != null)
                InfoRow(
                    label: 'Realistic Timeline',
                    value: '$realisticMonths months',
                    valueColor: AppColors.textSub),
            ],
          ),
        ),

        // Loan impact card
        if (loanImpact != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.indigoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.indigoBorder),
            ),
            child: Row(
              children: [
                const Text('🔮', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      loanImpact['boost_message'] as String? ?? '',
                      style: const TextStyle(
                          color: AppColors.indigoDark,
                          fontSize: 12,
                          height: 1.5)),
                ),
              ],
            ),
          ),
        ],

        // Action Plan
        if (actionPlan.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Action Plan',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...actionPlan.map((step) {
            final s = step as Map<String, dynamic>;
            final savings = (s['savings'] as num? ?? 0).toDouble();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                        color: AppColors.surfaceGreen,
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${s['step']}',
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['title'] as String? ?? '',
                            style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 3),
                        Text(s['detail'] as String? ?? '',
                            style: const TextStyle(
                                color: AppColors.textSub,
                                fontSize: 12,
                                height: 1.5)),
                        if (savings > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                              'Saves ${formatCurrency(savings)}/month',
                              style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // Golden Rules
        if (goldenRules.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amberBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('⭐', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('Golden Rules',
                        style: TextStyle(
                            color: AppColors.amberText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                ...goldenRules.map((rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•',
                              style: TextStyle(
                                  color: AppColors.amber,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(rule as String,
                                style: const TextStyle(
                                    color: AppColors.textMid,
                                    fontSize: 12,
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMyGoalsTab() {
    if (_loadingGoals) return const ShimmerLoadingView();
    if (_goalsError != null) {
      return ErrorView(message: _goalsError!, onRetry: _loadGoals);
    }
    if (_goals.isEmpty) {
      return const EmptyView(
          message: 'No goals yet.\nPlan your first goal!',
          icon: Icons.flag_outlined);
    }

    return RefreshIndicator(
      onRefresh: _loadGoals,
      color: AppColors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        itemCount: _goals.length,
        itemBuilder: (_, i) {
          final g = _goals[i] as Map<String, dynamic>;
          return _GoalCard(
            goal: g,
            currentSavings: _currentSavings,
            income: _latestIncome,
            onComplete: () => _confirmAction(
              'Mark Complete',
              'Mark this goal as completed?',
              AppColors.green,
              'Complete',
              () => _complete(g['id'] as int? ?? 0),
            ),
            onDelete: () => _confirmAction(
              'Delete Goal',
              'Remove this goal?',
              AppColors.red,
              'Delete',
              () => _delete(g['id'] as int? ?? 0),
            ),
          );
        },
      ),
    );
  }

  void _confirmAction(String title, String content, Color actionColor,
      String actionLabel, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content,
            style: const TextStyle(color: AppColors.textSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(actionLabel,
                  style: TextStyle(color: actionColor))),
        ],
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.redBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.redBorder),
      ),
      child: Text(msg,
          style: const TextStyle(color: AppColors.redText, fontSize: 13)),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final double currentSavings;
  final double income;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.currentSavings,
    required this.income,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = goal['goal_name'] as String? ?? '';
    final amount = (goal['goal_amount'] as num? ?? 0).toDouble();
    final months = (goal['goal_months'] as num? ?? 12).toInt();
    final status = goal['status'] as String? ?? 'active';
    final progress = (goal['progress_pct'] as num? ?? 0).toDouble();
    final isCompleted = status == 'completed';

    final savedSoFar = amount * progress / 100;
    final remaining = (amount - savedSoFar).clamp(0.0, double.infinity);
    final monthsToGoal = currentSavings > 0 && remaining > 0
        ? (remaining / currentSavings).ceil()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isCompleted
                ? AppColors.borderGreen
                : AppColors.border),
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
          // Header: name + actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 17),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                        '${formatCurrency(amount)}  ·  $months months',
                        style: const TextStyle(
                            color: AppColors.textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (!isCompleted) ...[
                GestureDetector(
                  onTap: onComplete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.redBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.redBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check,
                            color: AppColors.redText, size: 13),
                        SizedBox(width: 4),
                        Text('Done',
                            style: TextStyle(
                                color: AppColors.redText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.textSub, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Body: ring + metrics side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular progress ring
              Column(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                      painter: _GoalRingPainter(progress / 100),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '${progress.toInt()}%',
                                style: const TextStyle(
                                    color: AppColors.green,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5)),
                            const Text('done',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Progress',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(width: 14),
              // Metrics + progress bar
              Expanded(
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: _miniMetric(
                              formatCurrency(currentSavings),
                              'Monthly\nSavings')),
                      const SizedBox(width: 6),
                      Expanded(
                          child: _miniMetric(
                              monthsToGoal != null
                                  ? '$monthsToGoal mo'
                                  : '—',
                              'Months to\nGoal')),
                      const SizedBox(width: 6),
                      Expanded(
                          child: _miniMetric(
                              formatCurrency(remaining),
                              'Remaining')),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.border,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                AppColors.green),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${formatCurrency(savedSoFar)} saved',
                            style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                        Text(
                            '${formatCurrency(remaining)} to go',
                            style: const TextStyle(
                                color: AppColors.textSub,
                                fontSize: 10,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Mini projection chart
          if (currentSavings > 0 && months > 0) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text('Projected Savings Path',
                style: TextStyle(
                    color: AppColors.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildMiniChart(amount, months),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle,
                    color: AppColors.green, size: 16),
                SizedBox(width: 6),
                Text('COMPLETED',
                    style: TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniMetric(String value, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildMiniChart(double targetAmount, int numMonths) {
    final displayMonths = numMonths.clamp(1, 48);
    final savingsSpots = <FlSpot>[];
    final targetSpots = <FlSpot>[];
    double acc = 0;
    for (int i = 1; i <= displayMonths; i++) {
      acc += currentSavings;
      savingsSpots.add(
          FlSpot(i.toDouble(), acc.clamp(0, targetAmount)));
      targetSpots.add(FlSpot(i.toDouble(), targetAmount));
    }
    return SizedBox(
      height: 72,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: savingsSpots,
              isCurved: true,
              color: AppColors.green,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.green.withOpacity(0.07),
              ),
            ),
            LineChartBarData(
              spots: targetSpots,
              color: AppColors.red.withOpacity(0.4),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              dashArray: [5, 5],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  final double progress;
  const _GoalRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 8.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = AppColors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) =>
      old.progress != progress;
}
