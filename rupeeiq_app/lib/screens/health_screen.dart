import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _ringAnim =
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getHealth();
      if (res['error'] != null) {
        setState(() { _error = res['error'] as String; _loading = false; });
        return;
      }
      setState(() { _data = res; _loading = false; });
      _ringCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = 'Failed to load health score.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Health'),
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
                : KeyedSubtree(
                    key: const ValueKey('content'),
                    child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final hasData = d['has_data'] as bool? ?? false;

    if (!hasData) {
      return const EmptyView(
          message:
              'No financial data yet.\nAdd a month to see your health score.',
          icon: Icons.favorite_border_outlined);
    }

    final score = d['score'] as Map<String, dynamic>? ?? {};
    final components = score['components'] as List? ?? [];
    final priorityActions = score['priority_actions'] as List? ?? [];
    final finalScore =
        (score['final_score'] as num? ?? 0).toDouble();
    final grade = score['grade'] as String? ?? 'C';
    final status = score['status'] as String? ?? '';
    final summary = score['summary'] as String? ?? '';
    final month = d['month'] as String? ?? '';
    final year = d['year'];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.green,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          Text('$month $year · Financial Health',
              style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 11,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _buildScoreHero(finalScore, grade, status, summary,
              components.length),
          if (components.isNotEmpty) ...[
            const SectionHeader(title: 'Score Breakdown'),
            ...List.generate(
                components.length,
                (i) => _ComponentCard(
                      component:
                          components[i] as Map<String, dynamic>,
                      emoji: _emojis[i % _emojis.length],
                    )),
          ],
          if (priorityActions.isNotEmpty) ...[
            const SectionHeader(title: 'Priority Actions'),
            _buildPriorityCard(priorityActions),
          ],
          if (components.isNotEmpty) ...[
            const SectionHeader(title: 'Industry Benchmarks'),
            _buildBenchmarksCard(components),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static const _emojis = ['💰', '📉', '🏦', '🛡️', '🎯'];

  Widget _buildScoreHero(double score, String grade, String status,
      String summary, int numMetrics) {
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0c1a10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (_, __) => SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: _ringAnim.value * (score / 100),
                  color: gradeColor,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${score.toInt()}',
                          style: TextStyle(
                              color: gradeColor,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2)),
                      const Text('/100',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(grade,
              style: TextStyle(
                  color: gradeColor,
                  fontSize: 48,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.14)),
            ),
            child: Text(status,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          const SizedBox(height: 10),
          Text(summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13, height: 1.6)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _statChip('${score.toInt()}', 'Score'),
                _statDiv(),
                _statChip(grade, 'Grade'),
                _statDiv(),
                _statChip('$numMetrics', 'Metrics'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String val, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(val,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _statDiv() =>
      Container(width: 1, height: 36, color: Colors.white10);

  Widget _buildPriorityCard(List actions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
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
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
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
                                letterSpacing: 0.4)),
                        const SizedBox(height: 3),
                        Text(a['action'] as String? ?? '',
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < actions.length - 1)
                const Divider(height: 20),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBenchmarksCard(List components) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(components.length, (i) {
          final c = components[i] as Map<String, dynamic>;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c['component'] as String? ?? '',
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 13)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(c['benchmark'] as String? ?? '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: AppColors.textSub,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
              if (i < components.length - 1)
                const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  final Map<String, dynamic> component;
  final String emoji;

  const _ComponentCard(
      {required this.component, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final raw = (component['raw_score'] as num? ?? 0).toDouble();
    final grade = component['grade'] as String? ?? 'C';
    final name = component['component'] as String? ?? '';
    final value = component['value'] as String? ?? '';
    final weight = (component['weight'] as num? ?? 0).toDouble();
    final explanation = component['explanation'] as String? ?? '';
    final action = component['action'] as String? ?? '';

    Color pc, gc;
    if (raw >= 70) {
      pc = gc = AppColors.green;
    } else if (raw >= 40) {
      pc = gc = AppColors.amber;
    } else {
      pc = gc = AppColors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(emoji,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(
                        '$value · Weight ${(weight * 100).toInt()}%',
                        style: const TextStyle(
                            color: AppColors.textSub, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(grade,
                    style: TextStyle(
                        color: gc,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text('${raw.toInt()}',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: raw / 100,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(pc),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 10),
          Text(explanation,
              style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 13,
                  height: 1.6)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceGreen,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGreen),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.chevron_right,
                    color: AppColors.green, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(action,
                      style: const TextStyle(
                          color: AppColors.greenDark,
                          fontSize: 12,
                          height: 1.5)),
                ),
              ],
            ),
          ),
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
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
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
