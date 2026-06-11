import '../models/transaction.dart';
import 'merchant_database.dart';

class BehavioralInsight {
  final String type; // 'warning' | 'success' | 'tip' | 'challenge'
  final String emoji;
  final String title;
  final String message;
  final String actionAdvice;
  final double? savingsPotential;
  final String priority; // 'high' | 'medium' | 'low'

  const BehavioralInsight({
    required this.type,
    required this.emoji,
    required this.title,
    required this.message,
    required this.actionAdvice,
    this.savingsPotential,
    required this.priority,
  });
}

const int kMinTransactionsForInsights = 10;

const _foodDeliveryKeys = [
  'swiggy', 'zomato', 'uber eats', 'foodpanda', 'eatsure',
  'freshmenu', 'box8', 'faasos', 'rebel foods',
];

bool _isFoodDelivery(String merchantName) {
  final lower = merchantName.toLowerCase();
  return _foodDeliveryKeys.any((k) => lower.contains(k));
}

String _fmt(double amount) {
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000)   return '₹${(amount / 1000).toStringAsFixed(1)}K';
  return '₹${amount.toStringAsFixed(0)}';
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ── Part 1: Spending behaviour analysis ──────────────────────────────────────

/// Analyses HOW and WHEN the user spends, not just amounts.
/// Returns a flat map of derived metrics used by [generateInsights].
Map<String, dynamic> analyzeSpendingPatterns(List<Transaction> transactions) {
  final debits = transactions.where((t) => t.type == 'debit').toList();
  if (debits.isEmpty) return {};

  final totalDebit = debits.fold(0.0, (s, t) => s + t.amount);

  // A) Day-of-week (1 = Mon, 7 = Sun)
  final daySpending = <int, double>{for (var i = 1; i <= 7; i++) i: 0.0};
  for (final t in debits) {
    daySpending[t.dateTime.weekday] =
        daySpending[t.dateTime.weekday]! + t.amount;
  }
  final weekendTotal   = daySpending[6]! + daySpending[7]!;
  final weekendPercent = totalDebit > 0 ? (weekendTotal / totalDebit) * 100 : 0.0;

  // B) Time-of-day buckets
  final timeSpending = {
    'morning': 0.0, 'afternoon': 0.0, 'evening': 0.0, 'night': 0.0,
  };
  final timeCount = {
    'morning': 0, 'afternoon': 0, 'evening': 0, 'night': 0,
  };
  for (final t in debits) {
    final h    = t.dateTime.hour;
    final slot = h >= 6 && h < 12  ? 'morning'
               : h >= 12 && h < 18 ? 'afternoon'
               : h >= 18 && h < 23 ? 'evening'
               : 'night';
    timeSpending[slot] = timeSpending[slot]! + t.amount;
    timeCount[slot]    = timeCount[slot]! + 1;
  }

  // C) Week-of-month (week 1 = days 1-7, salary week)
  final weekSpending = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
  for (final t in debits) {
    final d = t.dateTime.day;
    final w = d <= 7 ? 1 : d <= 14 ? 2 : d <= 21 ? 3 : 4;
    weekSpending[w] = weekSpending[w]! + t.amount;
  }
  final salaryWeekPercent =
      totalDebit > 0 ? (weekSpending[1]! / totalDebit) * 100 : 0.0;

  // D) Impulse detection
  //    Triggers: 10pm-2am, same category twice on same day, weekend evenings
  final dayCatMap = <String, int>{};
  for (final t in debits) {
    final k =
        '${t.dateTime.year}-${t.dateTime.month}-${t.dateTime.day}:${t.category}';
    dayCatMap[k] = (dayCatMap[k] ?? 0) + 1;
  }
  int    impulseCount  = 0;
  double impulseAmount = 0;
  int    lateNightCount  = 0;
  double lateNightAmount = 0;
  for (final t in debits) {
    final h           = t.dateTime.hour;
    final isLateNight = h >= 22 || h < 2;
    final isWeekendEve = t.dateTime.weekday >= 6 && h >= 18;
    final k = '${t.dateTime.year}-${t.dateTime.month}-${t.dateTime.day}:${t.category}';
    final isSameCatRepeat = (dayCatMap[k] ?? 0) > 1;
    if (isLateNight) {
      lateNightCount++;
      lateNightAmount += t.amount;
    }
    if (isLateNight || isWeekendEve || isSameCatRepeat) {
      impulseCount++;
      impulseAmount += t.amount;
    }
  }
  final impulsePercent =
      totalDebit > 0 ? (impulseAmount / totalDebit) * 100 : 0.0;

  // E) Food delivery breakdown
  double foodDeliveryTotal = 0;
  int    foodDeliveryCount = 0;
  final  foodAppsUsed      = <String>{};
  for (final t in debits) {
    if (!_isFoodDelivery(t.merchantName)) continue;
    foodDeliveryTotal += t.amount;
    foodDeliveryCount++;
    final lower = t.merchantName.toLowerCase();
    for (final k in _foodDeliveryKeys) {
      if (lower.contains(k)) foodAppsUsed.add(_capitalize(k));
    }
  }

  // F) Category transaction frequency (per month)
  final catFrequency = <String, int>{};
  for (final t in debits) {
    catFrequency[t.category] = (catFrequency[t.category] ?? 0) + 1;
  }

  // G) Merchant aggregates
  final merchantTotals = <String, double>{};
  final merchantCounts = <String, int>{};
  for (final t in debits) {
    if (t.merchantName.isEmpty) continue;
    merchantTotals[t.merchantName] =
        (merchantTotals[t.merchantName] ?? 0) + t.amount;
    merchantCounts[t.merchantName] =
        (merchantCounts[t.merchantName] ?? 0) + 1;
  }

  return {
    'totalDebit':         totalDebit,
    'daySpending':        daySpending,
    'weekendTotal':       weekendTotal,
    'weekendPercent':     weekendPercent,
    'timeSpending':       timeSpending,
    'timeCount':          timeCount,
    'weekSpending':       weekSpending,
    'salaryWeekPercent':  salaryWeekPercent,
    'impulseCount':       impulseCount,
    'impulseAmount':      impulseAmount,
    'impulsePercent':     impulsePercent,
    'lateNightCount':     lateNightCount,
    'lateNightAmount':    lateNightAmount,
    'foodDeliveryTotal':  foodDeliveryTotal,
    'foodDeliveryCount':  foodDeliveryCount,
    'foodAppsUsed':       foodAppsUsed.toList(),
    'catFrequency':       catFrequency,
    'merchantTotals':     merchantTotals,
    'merchantCounts':     merchantCounts,
    'debitCount':         debits.length,
  };
}

// ── Part 2: Smart behavioural insights ───────────────────────────────────────

/// Generates personalised insights from [transactions] and a
/// [metrics] map (as returned by getMonthlySummary in analytics_service.dart).
/// Returns an empty list if fewer than [kMinTransactionsForInsights] are given.
List<BehavioralInsight> generateInsights(
    List<Transaction> transactions, Map<String, dynamic> metrics) {
  if (transactions.length < kMinTransactionsForInsights) return [];

  final patterns = analyzeSpendingPatterns(transactions);
  if (patterns.isEmpty) return [];

  final insights = <BehavioralInsight>[];

  final totalIncome   = (metrics['totalIncome']   as num? ?? 0).toDouble();
  final savings       = (metrics['savings']       as num? ?? 0).toDouble();
  final savingsRate   = totalIncome > 0 ? (savings / totalIncome) * 100 : 0.0;
  final categoryBreakdown = <String, double>{
    for (final e in ((metrics['categoryBreakdown'] as Map?) ?? {}).entries)
      e.key as String: (e.value as num).toDouble(),
  };

  final foodDeliveryTotal  = patterns['foodDeliveryTotal']  as double;
  final foodDeliveryCount  = patterns['foodDeliveryCount']  as int;
  final weekendPercent     = patterns['weekendPercent']     as double;
  final lateNightCount     = patterns['lateNightCount']     as int;
  final lateNightAmount    = patterns['lateNightAmount']    as double;
  final salaryWeekPercent  = patterns['salaryWeekPercent']  as double;
  final impulsePercent     = patterns['impulsePercent']     as double;
  final impulseAmount      = patterns['impulseAmount']      as double;
  final foodAppsUsed       = (patterns['foodAppsUsed'] as List).cast<String>();
  final catFrequency       = Map<String, int>.from(
      patterns['catFrequency'] as Map);

  // ── Warnings ─────────────────────────────────────────────────────────────

  if (foodDeliveryTotal > 2000) {
    final avgOrder      = foodDeliveryCount > 0
        ? foodDeliveryTotal / foodDeliveryCount : 0.0;
    final monthlySaving = foodDeliveryTotal * 0.5;
    insights.add(BehavioralInsight(
      type:             'warning',
      emoji:            '🍕',
      title:            'Food Delivery Addiction',
      message:          'You spent ${_fmt(foodDeliveryTotal)} on food delivery this '
                        'month. That\'s $foodDeliveryCount orders averaging '
                        '${_fmt(avgOrder)} each.',
      actionAdvice:     'Cook at home 3 days a week. You could save '
                        '${_fmt(monthlySaving)}/month = ${_fmt(monthlySaving * 12)}/year.',
      savingsPotential: monthlySaving,
      priority:         foodDeliveryTotal > 5000 ? 'high' : 'medium',
    ));
  }

  if (weekendPercent > 40) {
    final weekendBudget =
        totalIncome > 0 ? totalIncome * 0.15 : (patterns['totalDebit'] as double) * 0.15;
    insights.add(BehavioralInsight(
      type:         'warning',
      emoji:        '📅',
      title:        'Weekend Overspender',
      message:      'You spend ${weekendPercent.toStringAsFixed(0)}% of your monthly '
                    'budget in just 2 days (weekends).',
      actionAdvice: 'Set a weekend budget of ${_fmt(weekendBudget)}. '
                    'Use cash on weekends to control spending.',
      priority:     weekendPercent > 55 ? 'high' : 'medium',
    ));
  }

  if (lateNightCount > 5) {
    insights.add(BehavioralInsight(
      type:             'warning',
      emoji:            '🌙',
      title:            'Late Night Impulse Buyer',
      message:          '$lateNightCount of your purchases happen after 10pm. '
                        'Impulse buying costs you ${_fmt(lateNightAmount)}/month.',
      actionAdvice:     'Add items to cart but wait until morning to buy. '
                        'You\'ll skip 60% of them.',
      savingsPotential: lateNightAmount * 0.6,
      priority:         lateNightCount > 10 ? 'high' : 'medium',
    ));
  }

  final entertainmentAmt = categoryBreakdown['Entertainment'] ?? 0.0;
  if (totalIncome > 0 && entertainmentAmt / totalIncome > 0.15) {
    final entPct = (entertainmentAmt / totalIncome * 100).toStringAsFixed(0);
    insights.add(BehavioralInsight(
      type:             'warning',
      emoji:            '🎬',
      title:            'Entertainment Overspend',
      message:          'Entertainment takes $entPct% of your income '
                        '(${_fmt(entertainmentAmt)}/month).',
      actionAdvice:     'Audit your subscriptions. Cancel any you haven\'t '
                        'used in the last 30 days.',
      savingsPotential: entertainmentAmt * 0.3,
      priority:         'medium',
    ));
  }

  if (impulsePercent > 30 && impulseAmount > 1000) {
    insights.add(BehavioralInsight(
      type:             'warning',
      emoji:            '🛒',
      title:            'High Impulse Spending',
      message:          '${impulsePercent.toStringAsFixed(0)}% of your spending '
                        '(${_fmt(impulseAmount)}) comes from impulse purchases.',
      actionAdvice:     'Use the 24-hour rule: wait a day before buying '
                        'anything over ₹500.',
      savingsPotential: impulseAmount * 0.4,
      priority:         impulsePercent > 50 ? 'high' : 'medium',
    ));
  }

  // Category addiction: same category > 3× per week (≥12/month)
  catFrequency.forEach((cat, count) {
    if (count >= 12 && cat != 'Other') {
      final catTotal = categoryBreakdown[cat] ?? 0.0;
      if (catTotal > 500) {
        insights.add(BehavioralInsight(
          type:             'warning',
          emoji:            categoryIcons[cat] ?? '⚠️',
          title:            '$cat Habit',
          message:          'You made $count $cat transactions this month — '
                            'over 3 times a week.',
          actionAdvice:     'Set a weekly $cat budget of ${_fmt(catTotal / 4)} '
                            'and track it strictly.',
          savingsPotential: catTotal * 0.2,
          priority:         'medium',
        ));
      }
    }
  });

  // ── Tips ─────────────────────────────────────────────────────────────────

  if (salaryWeekPercent > 40) {
    final transferAmt = totalIncome * 0.20;
    insights.add(BehavioralInsight(
      type:         'tip',
      emoji:        '💰',
      title:        'Salary Day Splurge Alert',
      message:      'You spend ${salaryWeekPercent.toStringAsFixed(0)}% of your '
                    'income in the first week after salary.',
      actionAdvice: 'On salary day immediately transfer ${_fmt(transferAmt)} '
                    'to savings. Spend only what remains.',
      priority:     'medium',
    ));
  }

  if (foodAppsUsed.length >= 2) {
    final apps = foodAppsUsed.take(2).join(' and ');
    insights.add(BehavioralInsight(
      type:             'tip',
      emoji:            '💡',
      title:            'Food App Hack',
      message:          'You use $apps. Pick one and subscribe.',
      actionAdvice:     'A subscription (e.g. Swiggy One ₹299/month) saves '
                        '₹200–400 in delivery fees every month.',
      savingsPotential: 350,
      priority:         'low',
    ));
  }

  // ── Successes ────────────────────────────────────────────────────────────

  if (savingsRate >= 20) {
    insights.add(BehavioralInsight(
      type:         'success',
      emoji:        '📈',
      title:        'Great Savings Discipline!',
      message:      'You\'re saving ${savingsRate.toStringAsFixed(1)}% of your '
                    'income this month!',
      actionAdvice: 'Invest ${_fmt(savings)}/month in SIP for wealth building. '
                    'That\'s ${_fmt(savings * 12)}/year.',
      priority:     'low',
    ));
  }

  if (lateNightCount == 0 && impulsePercent < 5) {
    insights.add(BehavioralInsight(
      type:         'success',
      emoji:        '🏆',
      title:        'Discipline Champion!',
      message:      'Zero late-night impulse purchases this month!',
      actionAdvice: 'Transfer the money you saved to your goal account '
                    'right now.',
      priority:     'low',
    ));
  }

  // ── Challenge ────────────────────────────────────────────────────────────

  if (foodDeliveryTotal > 0) {
    final weeklyFD = foodDeliveryTotal / 4;
    insights.add(BehavioralInsight(
      type:             'challenge',
      emoji:            '🎯',
      title:            'No Food Delivery Challenge',
      message:          'Skip food delivery for 7 days.',
      actionAdvice:     'You could save ${_fmt(weeklyFD)} this week. '
                        'Cook simple meals or eat at the office canteen.',
      savingsPotential: weeklyFD,
      priority:         'low',
    ));
  }

  // Sort: high → medium → low
  const order = {'high': 0, 'medium': 1, 'low': 2};
  insights.sort(
      (a, b) => (order[a.priority] ?? 2).compareTo(order[b.priority] ?? 2));

  return insights;
}

// ── Part 3: Top merchants ─────────────────────────────────────────────────────

/// Returns up to [limit] merchants sorted by total spend.
List<Map<String, dynamic>> getTopMerchants(
    List<Transaction> transactions, int limit) {
  final debits     = transactions.where((t) => t.type == 'debit').toList();
  final totals     = <String, double>{};
  final counts     = <String, int>{};
  final categories = <String, String>{};

  for (final t in debits) {
    if (t.merchantName.isEmpty) continue;
    totals[t.merchantName]     = (totals[t.merchantName] ?? 0) + t.amount;
    counts[t.merchantName]     = (counts[t.merchantName] ?? 0) + 1;
    categories[t.merchantName] = t.category;
  }

  final sorted = totals.keys.toList()
    ..sort((a, b) => totals[b]!.compareTo(totals[a]!));

  return sorted.take(limit).map((name) {
    final cnt = counts[name]!;
    final tot = totals[name]!;
    final cat = categories[name] ?? 'Other';
    return <String, dynamic>{
      'name':     name,
      'total':    tot,
      'count':    cnt,
      'average':  tot / cnt,
      'category': cat,
      'icon':     categoryIcons[cat] ?? '💰',
    };
  }).toList();
}

// ── Part 4: Spending personality ─────────────────────────────────────────────

/// Classifies the user into a spending personality type.
/// Pass [metrics] (from getMonthlySummary) to enable The Saver classification.
Map<String, dynamic> getSpendingPersonality(
    List<Transaction> transactions, [Map<String, dynamic>? metrics]) {
  final debits = transactions.where((t) => t.type == 'debit').toList();
  if (debits.isEmpty) return _personality('The Balanced');

  final total = debits.fold(0.0, (s, t) => s + t.amount);
  if (total == 0) return _personality('The Balanced');

  final catTotals = <String, double>{};
  for (final t in debits) {
    catTotals[t.category] = (catTotals[t.category] ?? 0) + t.amount;
  }

  final foodPct          = ((catTotals['Food & Groceries'] ?? 0) / total) * 100;
  final shoppingPct      = ((catTotals['Shopping']         ?? 0) / total) * 100;
  final travelPct        = ((catTotals['Travel']           ?? 0) / total) * 100;
  final entertainmentPct = ((catTotals['Entertainment']    ?? 0) / total) * 100;

  if (metrics != null) {
    final income  = (metrics['totalIncome'] as num? ?? 0).toDouble();
    final savings = (metrics['savings']     as num? ?? 0).toDouble();
    if (income > 0 && savings / income > 0.30) return _personality('The Saver');
  }

  if (foodPct          > 30) return _personality('The Foodie');
  if (shoppingPct      > 25) return _personality('The Shopaholic');
  if (travelPct        > 20) return _personality('The Traveller');
  if (entertainmentPct > 20) return _personality('The Entertainer');
  return _personality('The Balanced');
}

Map<String, dynamic> _personality(String type) {
  const data = <String, Map<String, String>>{
    'The Foodie': {
      'emoji':       '🍕',
      'description': 'Food is your love language. You spend generously on '
                     'restaurants, delivery, and groceries.',
      'strength':    'You enjoy life and know how to treat yourself',
      'weakness':    'Food expenses quietly drain your budget',
      'tip':         'Try meal prepping on Sundays to cut food delivery by 40%',
    },
    'The Shopaholic': {
      'emoji':       '🛍️',
      'description': 'Retail therapy is your default stress relief. Shopping '
                     'makes you happy — but at a cost.',
      'strength':    'Great taste and eye for quality products',
      'weakness':    'Impulse purchases add up to thousands per month',
      'tip':         'Use the 30-day rule: wait before buying non-essentials',
    },
    'The Traveller': {
      'emoji':       '✈️',
      'description': 'You invest in experiences over things. Travel and '
                     'exploration define your spending.',
      'strength':    'Rich in experiences and memories',
      'weakness':    'Travel costs spike unpredictably',
      'tip':         'Book flights 6–8 weeks early to save 30–40%',
    },
    'The Entertainer': {
      'emoji':       '🎬',
      'description': 'Life is a movie and you\'re living it. Subscriptions '
                     'and events fill your wallet.',
      'strength':    'You know how to enjoy yourself',
      'weakness':    'Subscription creep — paying for things you forgot',
      'tip':         'Audit all subscriptions monthly, cancel unused ones',
    },
    'The Saver': {
      'emoji':       '💰',
      'description': 'You\'re financially disciplined and future-focused. '
                     'Saving is your superpower.',
      'strength':    'High savings rate and solid financial foundation',
      'weakness':    'May miss out on rewarding experiences',
      'tip':         'Invest savings in diversified SIP funds for better returns',
    },
    'The Balanced': {
      'emoji':       '⚖️',
      'description': 'You\'re a well-rounded spender. No single category '
                     'dominates your budget.',
      'strength':    'Balanced lifestyle with no extreme habits',
      'weakness':    'Hard to find one clear area to improve',
      'tip':         'You\'re doing great! Focus on increasing savings by 5%',
    },
  };
  final d = data[type] ?? data['The Balanced']!;
  return <String, dynamic>{'type': type, ...d};
}
