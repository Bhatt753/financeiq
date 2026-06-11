import '../models/transaction.dart';

// Pure-Dart notification computation — no external package needed.
// Add flutter_local_notifications to pubspec.yaml and call the native
// trigger when you want real system push notifications.

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'budget' | 'weekend' | 'impulse' | 'tip'
  final DateTime timestamp;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
  });
}

/// Returns in-app notifications that should be shown based on today's data.
/// [dailyFoodBudget] and [weekendBudget] are optional user-configured limits.
List<AppNotification> computeNotifications(
  List<Transaction> transactions, {
  double? dailyFoodBudget,
  double? weekendBudget,
}) {
  final now        = DateTime.now();
  final todayDebits = transactions.where((t) =>
      t.type == 'debit' &&
      t.dateTime.year  == now.year  &&
      t.dateTime.month == now.month &&
      t.dateTime.day   == now.day).toList();

  final notifications = <AppNotification>[];

  // Food budget alert
  final todayFoodTotal = todayDebits
      .where((t) => t.category == 'Food & Groceries')
      .fold(0.0, (s, t) => s + t.amount);
  if (todayFoodTotal > 0 && dailyFoodBudget != null && dailyFoodBudget > 0) {
    final remaining = dailyFoodBudget - todayFoodTotal;
    notifications.add(AppNotification(
      id:        'food_today',
      title:     'Food Budget Update',
      body:      'You spent ₹${todayFoodTotal.toStringAsFixed(0)} on food today. '
                 '${remaining > 0
                     ? 'Daily budget: ₹${remaining.toStringAsFixed(0)} remaining.'
                     : 'Daily food budget exceeded!'}',
      type:      'budget',
      timestamp: now,
    ));
  }

  // Weekend spending alert
  final isWeekend = now.weekday == 6 || now.weekday == 7;
  if (isWeekend && weekendBudget != null && weekendBudget > 0) {
    final todayTotal = todayDebits.fold(0.0, (s, t) => s + t.amount);
    if (todayTotal > 0) {
      notifications.add(AppNotification(
        id:        'weekend_alert',
        title:     'Weekend Spending Alert',
        body:      'You\'ve spent ₹${todayTotal.toStringAsFixed(0)} today. '
                   'Stay within your ₹${weekendBudget.toStringAsFixed(0)} weekend budget.',
        type:      'weekend',
        timestamp: now,
      ));
    }
  }

  // Impulse alert: ≥3 late-night purchases this week
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final lateNightThisWeek = transactions.where((t) {
    final h = t.dateTime.hour;
    return t.type == 'debit' &&
        t.dateTime.isAfter(weekStart) &&
        (h >= 22 || h < 2);
  }).toList();
  if (lateNightThisWeek.length >= 3) {
    final impulseTotal =
        lateNightThisWeek.fold(0.0, (s, t) => s + t.amount);
    notifications.add(AppNotification(
      id:        'impulse_alert',
      title:     'Impulse Buying Alert',
      body:      '${lateNightThisWeek.length} purchases after 10pm this week. '
                 'Total: ₹${impulseTotal.toStringAsFixed(0)}.',
      type:      'impulse',
      timestamp: now,
    ));
  }

  // Saving tip: food delivery today
  final fdToday = todayDebits.where((t) {
    final lower = t.merchantName.toLowerCase();
    return lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('uber eats');
  }).toList();
  if (fdToday.isNotEmpty) {
    final fdAmount = fdToday.fold(0.0, (s, t) => s + t.amount);
    notifications.add(AppNotification(
      id:        'fd_tip',
      title:     'Monthly Saving Tip',
      body:      'Skip one food delivery = ₹${fdAmount.toStringAsFixed(0)} saved. '
                 'Cook a simple meal instead!',
      type:      'tip',
      timestamp: now,
    ));
  }

  return notifications;
}
