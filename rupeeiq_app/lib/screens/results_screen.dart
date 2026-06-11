import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ResultsScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const ResultsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
    final advice = data['advice'] as List? ?? [];
    final month = data['month'] as String? ?? '';
    final year = data['year'];

    final income = (metrics['income'] as num? ?? 0).toDouble();
    final totalExpenses =
        (metrics['total_expenses'] as num? ?? 0).toDouble();
    final totalEmi = (metrics['total_emi'] as num? ?? 0).toDouble();
    final savings = (metrics['savings'] as num? ?? 0).toDouble();
    final savingsRate =
        (metrics['savings_rate'] as num? ?? 0).toDouble();
    final savingsColor = savings >= 0 ? AppColors.green : AppColors.red;

    final healthData =
        metrics['health_data'] as Map<String, dynamic>? ?? {};
    final finalScore =
        (healthData['final_score'] as num? ?? 0).toDouble();
    final grade = healthData['grade'] as String? ?? 'C';
    final status = healthData['status'] as String? ?? '';
    final summary = healthData['summary'] as String? ?? '';
    final components = healthData['components'] as List? ?? [];
    final priorityActions = healthData['priority_actions'] as List? ?? [];

    final categoryTotals =
        (metrics['category_totals'] as Map?)
                ?.map((k, v) => MapEntry(k as String, (v as num).toDouble()))
            ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text('$month $year · Results'),
        leading: IconButton(
          icon: const Icon(Icons.check_circle_outline,
              color: AppColors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGreen),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('$month $year data saved successfully!',
                      style: const TextStyle(
                          color: AppColors.greenDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4 metric cards
          Row(children: [
            Expanded(
              child: MetricCard(
                label: 'Income',
                value: formatCurrency(income),
                valueColor: AppColors.indigo,
                icon: Icons.arrow_downward_rounded,
                iconColor: AppColors.indigo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: 'Expenses',
                value: formatCurrency(totalExpenses + totalEmi),
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
                value: '${savingsRate.toStringAsFixed(1)}%',
                valueColor: savingsColor,
                icon: Icons.percent_rounded,
                iconColor: savingsColor,
              ),
            ),
          ]),

          // EMI breakdown (if applicable)
          if (totalEmi > 0) ...[
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
                      Icon(Icons.credit_card_outlined,
                          color: AppColors.amber, size: 16),
                      SizedBox(width: 6),
                      Text('EMI Deduction',
                          style: TextStyle(
                              color: AppColors.amberText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InfoRow(
                      label: 'Monthly EMI',
                      value: formatCurrency(totalEmi),
                      valueColor: AppColors.amber),
                  InfoRow(
                      label: 'Remaining for expenses',
                      value: formatCurrency(income - totalEmi),
                      valueColor: AppColors.textMid),
                ],
              ),
            ),
          ],

          // Health Score
          const SizedBox(height: 16),
          _buildHealthHero(finalScore, grade, status, summary),

          // Score components
          if (components.isNotEmpty) ...[
            const SectionHeader(title: 'Score Breakdown'),
            ...components.map((c) => _ComponentRow(
                component: c as Map<String, dynamic>)),
          ],

          // Priority actions
          if (priorityActions.isNotEmpty) ...[
            const SectionHeader(title: 'Priority Actions'),
            _buildPriorityCard(priorityActions),
          ],

          // Spending donut
          if (categoryTotals.isNotEmpty) ...[
            const SectionHeader(title: 'Spending Breakdown'),
            _buildSpendingDonut(categoryTotals),
          ],

          // Advice
          if (advice.isNotEmpty) ...[
            const SectionHeader(title: 'Smart Advice'),
            ...advice.map((a) =>
                AdviceCard(advice: a as Map<String, dynamic>)),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHealthHero(double score, String grade, String status,
      String summary) {
    Color gradeColor;
    switch (grade) {
      case 'A':
      case 'B':
        gradeColor = AppColors.green;
        break;
      case 'C':
        gradeColor = AppColors.amber;
        break;
      default:
        gradeColor = AppColors.red;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0c1a10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _RingPainter(
                  progress: score / 100, color: gradeColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${score.toInt()}',
                        style: TextStyle(
                            color: gradeColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const Text('/100',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(grade,
                        style: TextStyle(
                            color: gradeColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(summary,
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityCard(List actions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(actions.length, (i) {
          final a = actions[i] as Map<String, dynamic>;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            (a['component'] as String? ?? '')
                                .toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(a['action'] as String? ?? '',
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 12,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < actions.length - 1)
                const Divider(height: 18),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSpendingDonut(Map<String, double> catTotals) {
    final colors = [
      AppColors.red,
      AppColors.indigo,
      AppColors.amber,
      AppColors.green,
      const Color(0xFF0891B2),
      const Color(0xFFE11D48),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      AppColors.textSub,
    ];

    final entries = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = List.generate(entries.length, (i) {
      return PieChartSectionData(
        value: entries[i].value,
        color: colors[i % colors.length],
        title: '',
        radius: 30,
      );
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 32,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(entries.length, (i) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entries[i].key.split('/').first} ${formatCurrency(entries[i].value)}',
                      style: const TextStyle(
                          color: AppColors.textSub, fontSize: 10),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final Map<String, dynamic> component;
  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final raw = (component['raw_score'] as num? ?? 0).toDouble();
    final grade = component['grade'] as String? ?? 'C';
    final name = component['component'] as String? ?? '';
    final value = component['value'] as String? ?? '';
    final explanation = component['explanation'] as String? ?? '';

    Color color;
    if (raw >= 70) color = AppColors.green;
    else if (raw >= 40) color = AppColors.amber;
    else color = AppColors.red;

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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    if (value.isNotEmpty)
                      Text(value,
                          style: const TextStyle(
                              color: AppColors.textSub, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(grade,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text('${raw.toInt()}',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: raw / 100,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(explanation,
                style: const TextStyle(
                    color: AppColors.textSub,
                    fontSize: 11,
                    height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
