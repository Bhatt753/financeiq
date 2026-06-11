import 'dart:math' as Math;

// ─── METRICS ─────────────────────────────────────────────────────────────────
// Mirrors services/metrics.py

Map<String, dynamic> calculateMetrics(
    double income, List expenses, List loans) {
  if (income <= 0) return {'error': 'Income must be greater than zero'};

  double totalExpenses = expenses.fold<double>(
      0.0, (sum, e) => sum + ((e as Map)['amount'] as num).toDouble());
  double totalEmi = loans.fold<double>(
      0.0, (sum, l) => sum + ((l as Map)['emi'] as num).toDouble());
  double savings = income - totalExpenses - totalEmi;
  double totalOutflow = totalExpenses + totalEmi;
  double saveRate = (savings > 0 ? savings : 0) / income * 100;
  double expRatio = totalOutflow / income * 100;

  double fixedTotal = expenses
      .where((e) => (e as Map)['type'] == 'Fixed')
      .fold<double>(0.0, (sum, e) => sum + ((e as Map)['amount'] as num).toDouble());
  double variableTotal = expenses
      .where((e) => (e as Map)['type'] == 'Variable')
      .fold<double>(0.0, (sum, e) => sum + ((e as Map)['amount'] as num).toDouble());

  final Map<String, double> categoryTotals = {};
  for (final e in expenses) {
    final cat = (e as Map)['category'] as String;
    categoryTotals[cat] =
        (categoryTotals[cat] ?? 0) + (e['amount'] as num).toDouble();
  }
  final Map<String, double> categoryPercent = {};
  categoryTotals.forEach((cat, amt) {
    categoryPercent[cat] =
        double.parse((amt / income * 100).toStringAsFixed(2));
  });

  return {
    'income': income,
    'total_expenses': double.parse(totalExpenses.toStringAsFixed(2)),
    'total_emi': double.parse(totalEmi.toStringAsFixed(2)),
    'total_outflow': double.parse(totalOutflow.toStringAsFixed(2)),
    'savings': double.parse(savings.toStringAsFixed(2)),
    'savings_rate': double.parse(saveRate.toStringAsFixed(2)),
    'expense_ratio': double.parse(expRatio.toStringAsFixed(2)),
    'fixed_total': double.parse(fixedTotal.toStringAsFixed(2)),
    'variable_total': double.parse(variableTotal.toStringAsFixed(2)),
    'category_totals': categoryTotals,
    'category_percent': categoryPercent,
  };
}

// ─── HEALTH SCORE ─────────────────────────────────────────────────────────────
// Mirrors services/health_score.py

Map<String, dynamic> scoreSavingsRate(double savingsRate) {
  int score;
  String grade, explanation, action;

  if (savingsRate < 0) {
    score = 0; grade = 'F';
    explanation = 'You are overspending. Negative savings rate of ${savingsRate.toStringAsFixed(1)}%.';
    action = 'Immediately cut expenses. Start with largest variable expense.';
  } else if (savingsRate < 5) {
    score = 15; grade = 'F';
    explanation = 'Critical savings rate of ${savingsRate.toStringAsFixed(1)}%.';
    action = 'Set minimum ₹500/month auto-transfer to savings on salary day.';
  } else if (savingsRate < 10) {
    score = 30; grade = 'D';
    explanation = 'Poor savings rate of ${savingsRate.toStringAsFixed(1)}%.';
    action = 'Cut one major expense to reach 10% savings target.';
  } else if (savingsRate < 20) {
    score = 55; grade = 'C';
    explanation = 'Average savings rate of ${savingsRate.toStringAsFixed(1)}%.';
    action = 'Increase savings by reducing variable expenses.';
  } else if (savingsRate < 30) {
    score = 80; grade = 'B';
    explanation = 'Good savings rate of ${savingsRate.toStringAsFixed(1)}%.';
    action = 'Consider investing surplus in SIP or index funds.';
  } else {
    score = 100; grade = 'A';
    explanation = 'Excellent savings rate of ${savingsRate.toStringAsFixed(1)}%.';
    action = 'Diversify investments: SIP, PPF, NPS for tax efficiency.';
  }

  return {
    'component': 'Savings Rate',
    'weight': 0.25,
    'raw_score': score,
    'weighted': double.parse((score * 0.25).toStringAsFixed(2)),
    'grade': grade,
    'value': '${savingsRate.toStringAsFixed(1)}%',
    'explanation': explanation,
    'action': action,
    'benchmark': '20%+ is recommended',
  };
}

Map<String, dynamic> scoreExpenseRatio(double expenseRatio) {
  int score;
  String grade, explanation, action;

  if (expenseRatio > 100) {
    score = 0; grade = 'F';
    explanation = 'You spend ${expenseRatio.toStringAsFixed(1)}% of income — more than you earn.';
    action = 'Track every expense for 30 days. Eliminate all non-essential spending.';
  } else if (expenseRatio > 90) {
    score = 15; grade = 'F';
    explanation = 'Critical expense ratio of ${expenseRatio.toStringAsFixed(1)}%.';
    action = 'Identify top 3 expenses and cut each by 15%.';
  } else if (expenseRatio > 80) {
    score = 35; grade = 'D';
    explanation = 'High expense ratio of ${expenseRatio.toStringAsFixed(1)}%.';
    action = 'Reduce variable expenses by 20% this month.';
  } else if (expenseRatio > 70) {
    score = 55; grade = 'C';
    explanation = 'Moderate expense ratio of ${expenseRatio.toStringAsFixed(1)}%.';
    action = 'Try the 50-30-20 rule: 50% needs, 30% wants, 20% savings.';
  } else if (expenseRatio > 60) {
    score = 75; grade = 'B';
    explanation = 'Good expense ratio of ${expenseRatio.toStringAsFixed(1)}%.';
    action = 'Maintain discipline. Look for investment opportunities.';
  } else {
    score = 100; grade = 'A';
    explanation = 'Excellent expense ratio of ${expenseRatio.toStringAsFixed(1)}%.';
    action = 'Channel surplus into long-term wealth building investments.';
  }

  return {
    'component': 'Expense Ratio',
    'weight': 0.20,
    'raw_score': score,
    'weighted': double.parse((score * 0.20).toStringAsFixed(2)),
    'grade': grade,
    'value': '${expenseRatio.toStringAsFixed(1)}%',
    'explanation': explanation,
    'action': action,
    'benchmark': 'Below 70% is ideal',
  };
}

Map<String, dynamic> scoreDebtBurden(double income, List loans) {
  if (loans.isEmpty) {
    return {
      'component': 'Debt Burden',
      'weight': 0.25,
      'raw_score': 100,
      'weighted': 25.0,
      'grade': 'A',
      'value': 'No loans',
      'emi_ratio': 0.0,
      'total_emi': 0.0,
      'explanation': 'No loans detected. Debt-free status.',
      'action': 'Maintain debt-free status.',
      'benchmark': 'EMI/Income ratio below 30%',
    };
  }

  double totalEmi = loans.fold<double>(
      0.0, (sum, l) => sum + ((l as Map)['emi'] as num).toDouble());
  double emiRatio = income > 0
      ? double.parse((totalEmi / income * 100).toStringAsFixed(2))
      : 100.0;

  final highInterest = loans
      .where((l) => ((l as Map)['interest_rate'] as num).toDouble() > 18)
      .toList();
  int penalty = highInterest.length * 10;

  int baseScore;
  String grade, explanation, action;

  if (emiRatio == 0) {
    baseScore = 100; grade = 'A';
    explanation = 'No EMI obligations. Excellent debt management.';
    action = 'Maintain debt-free status.';
  } else if (emiRatio <= 10) {
    baseScore = 90; grade = 'A';
    explanation = 'Very low EMI ratio of ${emiRatio}%.';
    action = 'Well within safe limits.';
  } else if (emiRatio <= 20) {
    baseScore = 75; grade = 'B';
    explanation = 'Healthy EMI ratio of ${emiRatio}%.';
    action = 'Good debt management. Avoid additional loans.';
  } else if (emiRatio <= 30) {
    baseScore = 55; grade = 'C';
    explanation = 'Moderate EMI ratio of ${emiRatio}%.';
    action = 'Avoid new loans. Prepay highest-interest loan first.';
  } else if (emiRatio <= 40) {
    baseScore = 35; grade = 'D';
    explanation = 'High EMI ratio of ${emiRatio}%.';
    action = 'Prioritize debt repayment.';
  } else if (emiRatio <= 50) {
    baseScore = 15; grade = 'F';
    explanation = 'Very high EMI ratio of ${emiRatio}%.';
    action = 'Emergency debt reduction needed.';
  } else {
    baseScore = 0; grade = 'F';
    explanation = 'Critical EMI ratio of ${emiRatio}%.';
    action = 'Seek financial counseling immediately.';
  }

  int finalScore = (baseScore - penalty).clamp(0, 100);

  return {
    'component': 'Debt Burden',
    'weight': 0.25,
    'raw_score': finalScore,
    'weighted': double.parse((finalScore * 0.25).toStringAsFixed(2)),
    'grade': grade,
    'value': '$emiRatio% EMI ratio',
    'emi_ratio': emiRatio,
    'total_emi': totalEmi,
    'explanation': explanation,
    'action': action,
    'benchmark': 'EMI/Income ratio below 30% (FOIR)',
  };
}

Map<String, dynamic> scoreEmergencyFund(
    double monthlyExpenses, double currentSavings, double existingFund) {
  double totalFund = existingFund + (currentSavings > 0 ? currentSavings : 0);
  double months = monthlyExpenses > 0
      ? double.parse((totalFund / monthlyExpenses).toStringAsFixed(1))
      : 0.0;
  double targetAmount = monthlyExpenses * 6;

  int score;
  String grade, explanation, action;

  if (months <= 0) {
    score = 0; grade = 'F';
    explanation = 'No emergency fund. Financially vulnerable.';
    action = 'Start immediately. Target ₹${targetAmount.toStringAsFixed(0)} (6 months expenses).';
  } else if (months < 1) {
    score = 15; grade = 'F';
    explanation = 'Less than 1 month emergency coverage.';
    action = 'Build to 3 months as first milestone.';
  } else if (months < 3) {
    score = 35; grade = 'D';
    explanation = '$months months emergency coverage.';
    action = 'Add more to reach 3-month safety net.';
  } else if (months < 6) {
    score = 65; grade = 'C';
    explanation = '$months months emergency coverage.';
    action = 'Build to recommended 6-month fund.';
  } else if (months < 12) {
    score = 85; grade = 'B';
    explanation = '$months months emergency coverage.';
    action = 'Invest additional savings in liquid mutual funds.';
  } else {
    score = 100; grade = 'A';
    explanation = '$months months emergency coverage. Excellent!';
    action = 'Emergency fund complete. Focus on wealth creation.';
  }

  return {
    'component': 'Emergency Fund',
    'weight': 0.20,
    'raw_score': score,
    'weighted': double.parse((score * 0.20).toStringAsFixed(2)),
    'grade': grade,
    'value': '$months months coverage',
    'months_covered': months,
    'explanation': explanation,
    'action': action,
    'benchmark': '6 months minimum (RBI recommendation)',
  };
}

Map<String, dynamic> scoreSpendingDiscipline(
    Map<String, double> categoryPercent, double income) {
  const Map<String, double> healthyLimits = {
    'Rent/Housing': 30,
    'Food & Groceries': 20,
    'Transport': 15,
    'Utilities': 10,
    'Healthcare': 10,
    'Entertainment': 10,
    'Shopping': 10,
    'Education': 10,
    'Other': 5,
  };

  final List<Map<String, dynamic>> violations = [];
  healthyLimits.forEach((cat, limit) {
    double actual = categoryPercent[cat] ?? 0;
    if (actual > limit) {
      double overBy = double.parse((actual - limit).toStringAsFixed(1));
      violations.add({
        'category': cat,
        'actual': actual,
        'limit': limit,
        'over_by': overBy,
        'excess_amount': ((overBy / 100) * income).roundToDouble(),
      });
    }
  });

  int numViolations = violations.length;
  int score;
  String grade, explanation, action;

  if (numViolations == 0) {
    score = 100; grade = 'A';
    explanation = 'All spending categories within healthy limits.';
    action = 'Maintain current spending habits.';
  } else if (numViolations == 1) {
    score = 75; grade = 'B';
    explanation = '1 category over limit: ${violations[0]['category']}.';
    action = 'Reduce ${violations[0]['category']} spending.';
  } else if (numViolations == 2) {
    score = 50; grade = 'C';
    explanation = '2 categories over limit.';
    action = 'Focus on reducing these 2 categories first.';
  } else if (numViolations <= 4) {
    score = 25; grade = 'D';
    explanation = '$numViolations categories exceed healthy limits.';
    action = 'Apply envelope budgeting method.';
  } else {
    score = 5; grade = 'F';
    explanation = '$numViolations categories exceed limits.';
    action = 'Complete spending overhaul needed.';
  }

  return {
    'component': 'Spending Discipline',
    'weight': 0.10,
    'raw_score': score,
    'weighted': double.parse((score * 0.10).toStringAsFixed(2)),
    'grade': grade,
    'value': '$numViolations violations',
    'violations': violations,
    'explanation': explanation,
    'action': action,
    'benchmark': '0 category limit violations',
  };
}

Map<String, dynamic> calculateHealthScore(
    double income, List expenses, List loans, double emergencyFund) {
  if (income <= 0) {
    return {
      'final_score': 0,
      'grade': 'F',
      'status': 'Cannot Calculate',
      'components': <dynamic>[],
    };
  }

  double totalExpenses = expenses.fold<double>(
      0.0, (sum, e) => sum + ((e as Map)['amount'] as num).toDouble());
  double totalEmi = loans.fold<double>(
      0.0, (sum, l) => sum + ((l as Map)['emi'] as num).toDouble());
  double savings = income - totalExpenses - totalEmi;
  double totalOutflow = totalExpenses + totalEmi;
  double savingsRate = double.parse(
      ((savings > 0 ? savings : 0) / income * 100).toStringAsFixed(2));
  double expenseRatio =
      double.parse((totalOutflow / income * 100).toStringAsFixed(2));

  final Map<String, double> categoryTotals = {};
  for (final e in expenses) {
    final cat = (e as Map)['category'] as String;
    categoryTotals[cat] =
        (categoryTotals[cat] ?? 0) + (e['amount'] as num).toDouble();
  }
  final Map<String, double> categoryPercent = {};
  categoryTotals.forEach((cat, amt) {
    categoryPercent[cat] =
        double.parse((amt / income * 100).toStringAsFixed(2));
  });

  final c1 = scoreSavingsRate(savingsRate);
  final c2 = scoreExpenseRatio(expenseRatio);
  final c3 = scoreDebtBurden(income, loans);
  final c4 = scoreEmergencyFund(totalExpenses, savings, emergencyFund);
  final c5 = scoreSpendingDiscipline(categoryPercent, income);

  final List<Map<String, dynamic>> components = [c1, c2, c3, c4, c5];
  double finalScoreDouble = components.fold<double>(
      0.0, (sum, c) => sum + (c['weighted'] as num).toDouble());
  int finalScore = finalScoreDouble.round().clamp(0, 100);

  String grade, status, color, summary;

  if (finalScore >= 85) {
    grade = 'A'; status = 'Excellent'; color = '#4ade80';
    summary = 'Your finances are in excellent shape.';
  } else if (finalScore >= 70) {
    grade = 'B'; status = 'Good'; color = '#86efac';
    summary = 'Good financial health with room for improvement.';
  } else if (finalScore >= 55) {
    grade = 'C'; status = 'Average'; color = '#fbbf24';
    summary = 'Average financial health. Several areas need attention.';
  } else if (finalScore >= 40) {
    grade = 'D'; status = 'Poor'; color = '#fb923c';
    summary = 'Poor financial health. Immediate changes needed.';
  } else {
    grade = 'F'; status = 'Critical'; color = '#fca5a5';
    summary = 'Critical financial situation. Urgent action required.';
  }

  final sortedComponents = List<Map<String, dynamic>>.from(components)
    ..sort((a, b) =>
        (a['raw_score'] as int).compareTo(b['raw_score'] as int));

  final priorityActions = sortedComponents.take(3).map((c) => <String, dynamic>{
    'component': c['component'],
    'action': c['action'],
    'score': c['raw_score'],
  }).toList();

  return {
    'final_score': finalScore,
    'grade': grade,
    'status': status,
    'color': color,
    'summary': summary,
    'components': components,
    'priority_actions': priorityActions,
  };
}

// ─── LOAN ENGINE ──────────────────────────────────────────────────────────────
// Mirrors services/loan_engine.py

const _monthOrder = <String, int>{
  'January': 1, 'February': 2, 'March': 3, 'April': 4,
  'May': 5, 'June': 6, 'July': 7, 'August': 8,
  'September': 9, 'October': 10, 'November': 11, 'December': 12,
};

int _monthsPassed(String startMonth, int startYear) {
  final now = DateTime.now();
  int startM = _monthOrder[startMonth] ?? 1;
  int passed = (now.year - startYear) * 12 + (now.month - startM);
  return passed < 0 ? 0 : passed;
}

Map<String, dynamic> analyzeSingleLoan(Map<String, dynamic> loan) {
  double principal = (loan['principal'] as num).toDouble();
  double emi = (loan['emi'] as num).toDouble();
  double interestRate = (loan['interest_rate'] as num).toDouble();
  int tenure = (loan['tenure_months'] as num).toInt();
  String startMonth = loan['start_month'] as String? ?? 'January';
  int startYear = (loan['start_year'] as num).toInt();

  int monthsPaid = _monthsPassed(startMonth, startYear);
  if (monthsPaid > tenure) monthsPaid = tenure;
  int monthsRemaining = tenure - monthsPaid > 0 ? tenure - monthsPaid : 0;

  double monthlyRate = interestRate / (12 * 100);
  double outstanding;

  if (monthlyRate > 0 && tenure > 0) {
    double powTenure = Math.pow(1 + monthlyRate, tenure).toDouble();
    double powPaid = Math.pow(1 + monthlyRate, monthsPaid).toDouble();
    double denom = powTenure - 1;
    outstanding = denom > 0
        ? principal * (powTenure - powPaid) / denom
        : 0.0;
  } else {
    outstanding = principal - (emi * monthsPaid);
  }
  if (outstanding < 0) outstanding = 0;
  outstanding = double.parse(outstanding.toStringAsFixed(2));

  double principalPaid = double.parse(
      (principal - outstanding).toStringAsFixed(2));
  double progressPct = tenure > 0
      ? double.parse((monthsPaid / tenure * 100).toStringAsFixed(1))
      : 100.0;

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final now = DateTime.now();
  final payoffDate = DateTime(now.year, now.month + monthsRemaining);
  String payoffDateStr =
      '${monthNames[payoffDate.month - 1]} ${payoffDate.year}';

  final List<Map<String, dynamic>> monthlyBreakdown = [];
  double bal = principal;
  int chartMonths = tenure < 60 ? tenure : 60;
  for (int m = 0; m < chartMonths; m++) {
    double interestComp = monthlyRate > 0
        ? double.parse((bal * monthlyRate).toStringAsFixed(2))
        : 0.0;
    double principalComp =
        double.parse((emi - interestComp).toStringAsFixed(2));
    bal -= principalComp;
    if (bal < 0) bal = 0;
    monthlyBreakdown.add({
      'month': m + 1,
      'balance': double.parse(bal.toStringAsFixed(2)),
      'principal': principalComp,
      'interest': interestComp,
      'paid': m < monthsPaid,
    });
  }

  return {
    'loan_name': loan['loan_name'],
    'loan_type': loan['loan_type'],
    'principal': principal,
    'emi': emi,
    'interest_rate': interestRate,
    'tenure': tenure,
    'months_paid': monthsPaid,
    'months_remaining': monthsRemaining,
    'outstanding': outstanding,
    'principal_paid': principalPaid,
    'progress_pct': progressPct,
    'payoff_date': payoffDateStr,
    'monthly_breakdown': monthlyBreakdown,
    'is_completed': monthsRemaining == 0,
  };
}

// ─── GOAL ENGINE ──────────────────────────────────────────────────────────────
// Mirrors services/goal_engine.py

Map<String, dynamic> analyzeGoal({
  required String goalName,
  required double goalAmount,
  required int goalMonths,
  required double income,
  required double currentSavings,
}) {
  double requiredMonthly =
      double.parse((goalAmount / goalMonths).toStringAsFixed(2));
  double gap =
      double.parse((requiredMonthly - currentSavings).toStringAsFixed(2));

  String difficulty;
  if (gap <= 0) {
    difficulty = 'ACHIEVED';
  } else if (income > 0 && gap <= income * 0.05) {
    difficulty = 'EASY';
  } else if (income > 0 && gap <= income * 0.15) {
    difficulty = 'MEDIUM';
  } else {
    difficulty = 'HARD';
  }

  return {
    'goal_name': goalName,
    'goal_amount': goalAmount,
    'goal_months': goalMonths,
    'required_monthly': requiredMonthly,
    'current_savings': currentSavings,
    'gap': gap,
    'difficulty': difficulty,
    'extended_months': goalMonths + 6,
    'extended_amount': double.parse(
        (goalAmount / (goalMonths + 6)).toStringAsFixed(2)),
  };
}

// ─── TRENDS ──────────────────────────────────────────────────────────────────
// Mirrors services/trends.py

Map<String, dynamic>? analyzeTrends(List history) {
  if (history.length < 2) return null;

  final latest = history[0] as Map<String, dynamic>;
  final prev = history[1] as Map<String, dynamic>;

  double savingsChange = (latest['savings'] as num).toDouble() -
      (prev['savings'] as num).toDouble();
  double expenseChange = (latest['total_expenses'] as num).toDouble() -
      (prev['total_expenses'] as num).toDouble();
  int scoreChange = (latest['health_score'] as num).toInt() -
      (prev['health_score'] as num).toInt();

  return {
    'savings_change': double.parse(savingsChange.toStringAsFixed(2)),
    'savings_trend': savingsChange > 0 ? 'up' : 'down',
    'expense_change': double.parse(expenseChange.toStringAsFixed(2)),
    'expense_trend': expenseChange > 0 ? 'up' : 'down',
    'score_change': scoreChange,
    'score_trend': scoreChange > 0 ? 'up' : 'down',
  };
}

Map<String, dynamic>? calculateAnnualSummary(List history) {
  if (history.isEmpty) return null;

  double totalIncome = history.fold<double>(
      0.0, (sum, h) => sum + ((h as Map)['income'] as num).toDouble());
  double totalExpenses = history.fold<double>(
      0.0, (sum, h) => sum + ((h as Map)['total_expenses'] as num).toDouble());
  double totalSavings = history.fold<double>(
      0.0, (sum, h) => sum + ((h as Map)['savings'] as num).toDouble());
  double avgScore = history.fold<double>(
          0.0,
          (sum, h) => sum + ((h as Map)['health_score'] as num).toDouble()) /
      history.length;

  return {
    'total_income': double.parse(totalIncome.toStringAsFixed(2)),
    'total_expenses': double.parse(totalExpenses.toStringAsFixed(2)),
    'total_savings': double.parse(totalSavings.toStringAsFixed(2)),
    'avg_health_score': double.parse(avgScore.toStringAsFixed(1)),
    'months_tracked': history.length,
  };
}
