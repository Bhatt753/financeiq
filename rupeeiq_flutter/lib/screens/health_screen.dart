import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiService.getHealth();
      setState(() { _data = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Health'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
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
    if (_data?['has_data'] != true) {
      return const EmptyView(
        title: 'No data yet',
        subtitle: 'Add your first month\'s financial data to see your health score',
        icon: Icons.favorite_outline,
      );
    }

    final score  = _data!['score'] as Map? ?? {};
    final month  = _data!['month'] ?? '';
    final year   = _data!['year']  ?? '';
    final grade  = score['grade'] ?? 'F';
    final fs     = (score['final_score'] as num? ?? 0).toInt();
    final status = score['status']  ?? '';
    final summary= score['summary'] ?? '';
    final comps  = score['components'] as List? ?? [];
    final actions= score['priority_actions'] as List? ?? [];

    final gradeColor = {
      'A': AppColors.green, 'B': AppColors.green,
      'C': AppColors.amber, 'D': AppColors.red, 'F': AppColors.red,
    }[grade] ?? AppColors.red;

    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month label
            Text('$month $year', style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
            const SizedBox(height: 12),

            // Score hero
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF111827), Color(0xFF0C1A10)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Score ring
                      _ScoreRing(score: fs, color: gradeColor),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(grade, style: TextStyle(color: gradeColor, fontSize: 28, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(status, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(summary, style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ScoreStat('$fs', 'Score'),
                      _ScoreStat(grade, 'Grade'),
                      _ScoreStat('${comps.length}', 'Metrics'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Score Breakdown'),

            ...comps.map((c) => _ComponentCard(comp: c as Map)),

            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: 'Priority Actions'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.red.withOpacity(0.25)),
                ),
                child: Column(
                  children: actions.asMap().entries.map((e) =>
                    _ActionItem(index: e.key + 1, action: e.value as Map)).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 7,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text('$score', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ScoreStat extends StatelessWidget {
  final String value;
  final String label;
  const _ScoreStat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
    ],
  );
}

class _ComponentCard extends StatelessWidget {
  final Map comp;
  const _ComponentCard({required this.comp});

  Color _gradeColor(String g) {
    switch (g) {
      case 'A': case 'B': return AppColors.green;
      case 'C': return AppColors.amber;
      default: return AppColors.red;
    }
  }

  Color _progressColor(num s) {
    if (s >= 80) return AppColors.green;
    if (s >= 60) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final grade  = comp['grade'] ?? 'F';
    final raw    = (comp['raw_score'] as num? ?? 0).toDouble();
    final weight = ((comp['weight'] as num? ?? 0) * 100).toInt();
    final gc     = _gradeColor(grade);

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comp['component'] ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Weight: $weight%', style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(comp['value'] ?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: gc.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$grade (${raw.toInt()}/100)',
                        style: TextStyle(color: gc, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: raw / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(_progressColor(raw)),
            borderRadius: BorderRadius.circular(4),
            minHeight: 5,
          ),
          const SizedBox(height: 8),
          Text(comp['explanation'] ?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4)),
          const SizedBox(height: 4),
          Text(comp['action'] ?? '', style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final int index;
  final Map action;
  const _ActionItem({required this.index, required this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
          child: Center(
            child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action['component'] ?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
              Text(action['action'] ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ),
  );
}
