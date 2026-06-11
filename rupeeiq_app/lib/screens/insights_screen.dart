import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/transaction.dart';
import '../services/analytics_service.dart';
import '../services/behavioral_insights_service.dart';
import '../services/feedback_service.dart';
import '../services/learning_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const _storage = FlutterSecureStorage();
  static const _challengeKey = 'challenge_start_v1';

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  bool _loading = true;
  String? _error;

  List<Transaction>          _transactions   = [];
  List<BehavioralInsight>    _insights       = [];
  Map<String, dynamic>       _personality    = {};
  List<Map<String, dynamic>> _topMerchants   = [];
  Map<String, dynamic>       _learningStats  = {};

  late String _selectedMonth;
  late int    _selectedYear;

  DateTime? _challengeStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = _months[now.month - 1];
    _selectedYear  = now.year;
    _load();
    _loadChallengeState();
  }

  Future<void> _loadChallengeState() async {
    final val = await _storage.read(key: _challengeKey);
    if (val != null && mounted) {
      setState(() => _challengeStart = DateTime.tryParse(val));
    }
  }

  Future<void> _startChallenge() async {
    final now = DateTime.now();
    await _storage.write(key: _challengeKey, value: now.toIso8601String());
    if (mounted) setState(() => _challengeStart = now);
  }

  Future<void> _resetChallenge() async {
    await _storage.delete(key: _challengeKey);
    if (mounted) setState(() => _challengeStart = null);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final txns = await loadTransactions(_selectedMonth, _selectedYear);
      if (txns.length < kMinTransactionsForInsights) {
        setState(() {
          _transactions = txns;
          _loading      = false;
          _error        = txns.isEmpty
              ? 'No transactions found for $_selectedMonth $_selectedYear.\n'
                'Import SMS transactions from the Add tab first.'
              : 'Need at least $kMinTransactionsForInsights transactions for '
                'meaningful insights.\nOnly ${txns.length} found — import more SMS data.';
        });
        return;
      }
      final metrics      = getMonthlySummary(txns);
      final insights     = generateInsights(txns, metrics);
      final personality  = getSpendingPersonality(txns, metrics);
      final merchants    = getTopMerchants(txns, 8);
      final learnedCount = await getMerchantsLearnedCount();
      final lstats       = await getLearningStats(learnedCount);
      setState(() {
        _transactions  = txns;
        _insights      = insights;
        _personality   = personality;
        _topMerchants  = merchants;
        _learningStats = lstats;
        _loading       = false;
      });
    } catch (_) {
      setState(() { _error = 'Failed to load insights.'; _loading = false; });
    }
  }

  // ── Month selector helpers ────────────────────────────────────────────────

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final now   = DateTime.now();
        final items = <Map<String, dynamic>>[];
        for (var i = 0; i < 12; i++) {
          var y = now.year;
          var m = now.month - i;
          while (m < 1) { m += 12; y--; }
          items.add({'month': _months[m - 1], 'year': y});
        }
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select Month',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item      = items[i];
                    final m         = item['month'] as String;
                    final y         = item['year']  as int;
                    final isSelected = m == _selectedMonth && y == _selectedYear;
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      title: Text('$m $y',
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.green
                                  : AppColors.text,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14)),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.green, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedMonth = m;
                          _selectedYear  = y;
                        });
                        _load();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          GestureDetector(
            onTap: _showMonthPicker,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceGreen,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderGreen),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 11, color: AppColors.green),
                  const SizedBox(width: 5),
                  Text(
                    '${_selectedMonth.substring(0, 3)} $_selectedYear',
                    style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.expand_more_rounded,
                      size: 14, color: AppColors.green),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _loading
            ? const ShimmerLoadingView(key: ValueKey('shimmer'))
            : _error != null
                ? _buildEmpty()
                : _buildContent(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline_rounded,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSub, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final challenge = _insights
        .where((i) => i.type == 'challenge')
        .cast<BehavioralInsight?>()
        .firstOrNull;
    final nonChallenge =
        _insights.where((i) => i.type != 'challenge').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        // Personality card
        if (_personality.isNotEmpty) ...[
          _buildPersonalityCard(),
          const SizedBox(height: 16),
        ],

        // Insights list
        if (nonChallenge.isNotEmpty) ...[
          const SectionHeader(title: 'Behavioral Insights'),
          const SizedBox(height: 8),
          ...nonChallenge.map(_buildInsightCard),
          const SizedBox(height: 8),
        ],

        // Weekly challenge
        if (challenge != null) ...[
          const SectionHeader(title: 'Weekly Challenge'),
          const SizedBox(height: 8),
          _buildChallengeCard(challenge),
          const SizedBox(height: 16),
        ],

        // Top merchants
        if (_topMerchants.isNotEmpty) ...[
          const SectionHeader(title: 'Top Merchants'),
          const SizedBox(height: 8),
          _buildMerchantsRow(),
        ],

        // Summary stat row
        if (_transactions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSummaryRow(),
        ],

        // Learning progress
        if ((_learningStats['merchantsLearned'] as int? ?? 0) > 0 ||
            (_learningStats['correctionsThisMonth'] as int? ?? 0) > 0) ...[
          const SizedBox(height: 16),
          _buildLearningProgress(),
        ],
      ],
    );
  }

  // ── Personality card ──────────────────────────────────────────────────────

  Widget _buildPersonalityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _personality['emoji'] as String? ?? '⚖️',
                style: const TextStyle(fontSize: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('You are',
                        style: TextStyle(
                            color: AppColors.textSub, fontSize: 12)),
                    Text(
                      _personality['type'] as String? ?? '',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _personality['description'] as String? ?? '',
            style: const TextStyle(
                color: AppColors.textMid, fontSize: 13, height: 1.5),
          ),
          const Divider(height: 20),
          _personalityRow('💪', 'Strength',
              _personality['strength'] as String? ?? ''),
          const SizedBox(height: 6),
          _personalityRow('⚠️', 'Watch out',
              _personality['weakness'] as String? ?? ''),
          const SizedBox(height: 6),
          _personalityRow(
              '💡', 'Tip', _personality['tip'] as String? ?? ''),
        ],
      ),
    );
  }

  Widget _personalityRow(String icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSub,
                  height: 1.4),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMid)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Insight card ──────────────────────────────────────────────────────────

  Widget _buildInsightCard(BehavioralInsight insight) {
    final borderColor = _insightColor(insight.type);
    final bgColor     = _insightBg(insight.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(insight.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.title,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(insight.message,
                      style: const TextStyle(
                          color: AppColors.textSub,
                          fontSize: 12,
                          height: 1.4)),
                  if ((insight.savingsPotential ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Potential saving: ${_fmtRupees(insight.savingsPotential!)}/month',
                      style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_outlined,
                            size: 12, color: borderColor),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            insight.actionAdvice,
                            style: TextStyle(
                                color: borderColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Challenge card ────────────────────────────────────────────────────────

  Widget _buildChallengeCard(BehavioralInsight challenge) {
    final now          = DateTime.now();
    final daysElapsed  = _challengeStart != null
        ? now.difference(_challengeStart!).inDays.clamp(0, 7)
        : 0;
    final isActive     = _challengeStart != null && daysElapsed < 7;
    final isCompleted  = _challengeStart != null && daysElapsed >= 7;
    final progress     = daysElapsed / 7.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.indigoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.indigoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(challenge.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.title,
                        style: const TextStyle(
                            color: AppColors.indigo,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(
                      isCompleted
                          ? '✅ Completed!'
                          : isActive
                              ? 'Day $daysElapsed of 7'
                              : '7-day challenge',
                      style: TextStyle(
                          color: isCompleted
                              ? AppColors.green
                              : AppColors.textSub,
                          fontSize: 11,
                          fontWeight: isCompleted
                              ? FontWeight.w600
                              : FontWeight.w400),
                    ),
                  ],
                ),
              ),
              if (challenge.savingsPotential != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_fmtRupees(challenge.savingsPotential!)} saved',
                    style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(challenge.message,
              style: const TextStyle(
                  color: AppColors.textMid, fontSize: 13, height: 1.4)),
          const SizedBox(height: 4),
          Text(challenge.actionAdvice,
              style: const TextStyle(
                  color: AppColors.textSub, fontSize: 12, height: 1.4)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.indigoBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.indigo),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          if (!isActive && !isCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Start Challenge',
                    style: TextStyle(fontSize: 13)),
              ),
            )
          else if (isCompleted)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetChallenge,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.indigo,
                      side:
                          const BorderSide(color: AppColors.indigoBorder),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Start Again',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            )
          else
            Text(
              'Keep going! ${7 - daysElapsed} day${7 - daysElapsed == 1 ? '' : 's'} left.',
              style: const TextStyle(
                  color: AppColors.indigo,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  // ── Merchants row ─────────────────────────────────────────────────────────

  Widget _buildMerchantsRow() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 4),
        physics: const BouncingScrollPhysics(),
        itemCount: _topMerchants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final m = _topMerchants[i];
          return Container(
            width: 112,
            padding: const EdgeInsets.all(10),
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
                    Text(m['icon'] as String,
                        style: const TextStyle(fontSize: 18)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${m['count']}×',
                          style: const TextStyle(
                              color: AppColors.textSub,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  m['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  _fmtRupees((m['total'] as num).toDouble()),
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Summary stat strip ────────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    final metrics  = getMonthlySummary(_transactions);
    final income   = (metrics['totalIncome']   as num? ?? 0).toDouble();
    final expenses = (metrics['totalExpenses'] as num? ?? 0).toDouble();
    final savings  = (metrics['savings']       as num? ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Transactions',
              '${_transactions.length}', AppColors.indigo),
          _statItem('Total Spent',
              _fmtRupees(expenses), AppColors.red),
          _statItem('Savings',
              _fmtRupees(savings),
              savings >= 0 ? AppColors.green : AppColors.red),
        ],
      ),
    );
  }

  // ── Learning progress card ────────────────────────────────────────────────

  Widget _buildLearningProgress() {
    final learned     = _learningStats['merchantsLearned']    as int?    ?? 0;
    final corrections = _learningStats['correctionsThisMonth'] as int?   ?? 0;
    final accuracy    = (_learningStats['accuracyRate']        as double? ?? 0.0);
    final total       = _learningStats['totalCategorized']     as int?    ?? 0;
    final topMerchant = _learningStats['topCorrectedMerchant'] as String?;
    final correct     = total - corrections;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.indigoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.indigoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'RupeeIQ Learning Progress',
                  style: TextStyle(
                      color: AppColors.indigo,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _learnStat(
                    '$learned', 'Merchants learned', AppColors.indigo),
              ),
              Expanded(
                child: _learnStat(
                    '$corrections', 'Corrections made', AppColors.amber),
              ),
              Expanded(
                child: _learnStat(
                    '$correct', 'Auto-correct', AppColors.green),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Accuracy rate',
                    style: const TextStyle(
                        color: AppColors.textSub, fontSize: 11)),
                Text('${accuracy.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppColors.indigo,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (accuracy / 100).clamp(0.0, 1.0),
                backgroundColor: AppColors.indigoBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.indigo),
                minHeight: 6,
              ),
            ),
          ],
          if (topMerchant != null) ...[
            const SizedBox(height: 8),
            Text(
              'Most corrected: $topMerchant',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _learnStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 9)),
      ],
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Color _insightColor(String type) {
    switch (type) {
      case 'success':   return AppColors.green;
      case 'tip':       return AppColors.amber;
      case 'challenge': return AppColors.indigo;
      default:          return AppColors.red;
    }
  }

  static Color _insightBg(String type) {
    switch (type) {
      case 'success':   return AppColors.surfaceGreen;
      case 'tip':       return AppColors.amberBg;
      case 'challenge': return AppColors.indigoBg;
      default:          return AppColors.redBg;
    }
  }
}

String _fmtRupees(double amount) {
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000)   return '₹${(amount / 1000).toStringAsFixed(1)}K';
  return '₹${amount.toStringAsFixed(0)}';
}
