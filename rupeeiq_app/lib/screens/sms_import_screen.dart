import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction.dart';
import '../services/feedback_service.dart';
import '../services/learning_service.dart';
import '../services/merchant_database.dart';
import '../services/sms_service.dart';
import '../services/transaction_detector.dart';
import '../services/transaction_extractor.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

// ── Cache ──────────────────────────────────────────────────────────────────

const _storage       = FlutterSecureStorage();
const _kCacheKey     = 'sms_txn_cache_v1';
const _kCacheTimeKey = 'sms_txn_cache_time_v1';
const _kCacheTtlMins = 60;

// ── Empty-state reason ─────────────────────────────────────────────────────

enum _EmptyReason {
  permissionDenied,
  noSmsFound,
  noKeywordMatch,
  noAmountFound,
  none,
}

// ── Date filter ────────────────────────────────────────────────────────────

enum _DateFilter { thisMonth, last7Days, last30Days }

class SmsImportScreen extends StatefulWidget {
  const SmsImportScreen({super.key});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  bool _loading = true;
  String _loadingText = 'Checking permission';

  List<Transaction> _all = [];
  final Set<String> _selected = {};
  _DateFilter _filter = _DateFilter.thisMonth;
  bool _showUncategorized = false;
  bool _onboardingShown   = false;

  int          _diagTotal   = 0;
  int          _diagKeyword = 0;
  int          _diagAmount  = 0;
  _EmptyReason _emptyReason = _EmptyReason.none;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Filtered view ──────────────────────────────────────────────────────

  List<Transaction> get _filtered {
    final now = DateTime.now();
    final DateTime cutoff;
    switch (_filter) {
      case _DateFilter.thisMonth:
        cutoff = DateTime(now.year, now.month, 1);
      case _DateFilter.last7Days:
        cutoff = now.subtract(const Duration(days: 7));
      case _DateFilter.last30Days:
        cutoff = now.subtract(const Duration(days: 30));
    }
    var list = _all.where((t) => t.dateTime.isAfter(cutoff)).toList();
    if (_showUncategorized) {
      list = list.where((t) => t.category == 'Other').toList();
    }
    return list;
  }

  List<Transaction> get _selectedList =>
      _filtered.where((t) => _selected.contains(t.id)).toList();

  // ── Cache helpers ──────────────────────────────────────────────────────

  Future<List<Transaction>?> _loadCache() async {
    try {
      final timeStr = await _storage.read(key: _kCacheTimeKey);
      if (timeStr == null) return null;
      final cacheTime = DateTime.tryParse(timeStr);
      if (cacheTime == null) return null;
      if (DateTime.now().difference(cacheTime).inMinutes > _kCacheTtlMins) {
        return null;
      }
      final json = await _storage.read(key: _kCacheKey);
      if (json == null || json.isEmpty) return null;
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => _txnFromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(List<Transaction> txns) async {
    try {
      await _storage.write(
          key: _kCacheKey,
          value: jsonEncode(txns.map(_txnToMap).toList()));
      await _storage.write(
          key: _kCacheTimeKey, value: DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    try {
      await _storage.delete(key: _kCacheKey);
      await _storage.delete(key: _kCacheTimeKey);
    } catch (_) {}
  }

  static Map<String, dynamic> _txnToMap(Transaction t) => {
        'id': t.id,
        'amount': t.amount,
        'merchantName': t.merchantName,
        'dateTime': t.dateTime.toIso8601String(),
        'type': t.type,
        'availableBalance': t.availableBalance,
        'paymentMethod': t.paymentMethod,
        'rawSms': t.rawSms,
        'sender': t.sender,
        'category': t.category,
      };

  static Transaction _txnFromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as String,
        amount: (m['amount'] as num).toDouble(),
        merchantName: m['merchantName'] as String,
        dateTime: DateTime.parse(m['dateTime'] as String),
        type: m['type'] as String,
        availableBalance: m['availableBalance'] == null
            ? null
            : (m['availableBalance'] as num).toDouble(),
        paymentMethod: m['paymentMethod'] as String,
        rawSms: m['rawSms'] as String,
        sender: m['sender'] as String,
        category: m['category'] as String? ?? 'Other',
      );

  // ── Load pipeline ──────────────────────────────────────────────────────

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading     = true;
      _loadingText = 'Checking permission';
      _diagTotal   = 0;
      _diagKeyword = 0;
      _diagAmount  = 0;
      _emptyReason = _EmptyReason.none;
    });

    // ── 1. Request SMS permission ───────────────────────────────────────
    final status = await Permission.sms.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _loading     = false;
        _emptyReason = _EmptyReason.permissionDenied;
      });
      return;
    }

    // ── 2. Try cache ────────────────────────────────────────────────────
    if (!forceRefresh) {
      final cached = await _loadCache();
      if (cached != null && mounted) {
        final preSelected = cached
            .where((t) => t.type == 'debit')
            .map((t) => t.id)
            .toSet();
        setState(() {
          _all = cached;
          _selected
            ..clear()
            ..addAll(preSelected);
          _loading = false;
        });
        return;
      }
    }

    // ── 3. Read SMS from inbox with progress ────────────────────────────
    setState(() => _loadingText = 'Reading messages');
    final smsList = await getRecentBankSms(
      onProgress: (scanned, found) {
        if (mounted) {
          setState(() =>
              _loadingText = 'Reading messages ($scanned read, $found found)');
        }
      },
    );
    if (!mounted) return;

    _diagTotal = smsList.length;
    if (_diagTotal == 0) {
      setState(() {
        _loading     = false;
        _emptyReason = _EmptyReason.noSmsFound;
      });
      return;
    }

    // ── 4. Filter by content keywords ───────────────────────────────────
    final bankSms = filterTransactionSms(smsList);
    _diagKeyword  = bankSms.length;
    if (_diagKeyword == 0) {
      setState(() {
        _loading     = false;
        _emptyReason = _EmptyReason.noKeywordMatch;
      });
      return;
    }

    setState(() =>
        _loadingText = 'Finding transactions (${bankSms.length} found)');
    await Future.delayed(Duration.zero);

    // ── 5. Extract & categorise ─────────────────────────────────────────
    final results = <Transaction>[];
    for (var i = 0; i < bankSms.length; i++) {
      if (mounted) {
        final pct = ((i + 1) / bankSms.length * 100).round();
        setState(() => _loadingText = pct >= 90
            ? 'Categorizing... almost done!'
            : 'Categorizing... ($i of ${bankSms.length})');
      }
      final txn = await extractTransaction(bankSms[i]);
      if (txn != null) results.add(txn);
      if (i % 3 == 0) await Future.delayed(Duration.zero);
    }

    _diagAmount = results.length;
    if (_diagAmount == 0) {
      if (mounted) {
        setState(() {
          _loading     = false;
          _emptyReason = _EmptyReason.noAmountFound;
        });
      }
      return;
    }

    // ── 6. Cache & finish ───────────────────────────────────────────────
    unawaited(_saveCache(results));

    final preSelected = results
        .where((t) => t.type == 'debit')
        .map((t) => t.id)
        .toSet();

    if (!mounted) return;
    setState(() {
      _all         = results;
      _selected
        ..clear()
        ..addAll(preSelected);
      _loading     = false;
      _emptyReason = _EmptyReason.none;
    });

    // Show onboarding for first-time users with uncategorized merchants
    await _checkOnboarding();
  }

  // ── Category correction ────────────────────────────────────────────────

  void _showCategoryPicker(Transaction txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryPickerSheet(
        transactions: [txn],
        onSelected: (category) async {
          txn.category = category;
          await learnMerchantCategory(txn.merchantName, category);
          await learnFromCorrection(txn, category);
          await recordCorrection(txn, category);
          unawaited(_saveCache(_all));
          if (mounted) setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Got it! We\'ll remember this 🧠'),
              backgroundColor: AppColors.green,
            ));
          }
        },
      ),
    );
  }

  void _bulkCategorize() {
    final selected = _selectedList;
    if (selected.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryPickerSheet(
        transactions: selected,
        onSelected: (category) async {
          for (final txn in selected) {
            txn.category = category;
            await learnMerchantCategory(txn.merchantName, category);
            await learnFromCorrection(txn, category);
          }
          unawaited(_saveCache(_all));
          if (mounted) setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${selected.length} transactions categorized as $category 🧠'),
              backgroundColor: AppColors.green,
            ));
          }
        },
      ),
    );
  }

  // ── Onboarding ─────────────────────────────────────────────────────────

  Future<void> _checkOnboarding() async {
    if (_onboardingShown) return;
    final done = await _storage.read(key: 'onboarding_done_v1');
    if (done != null) { _onboardingShown = true; return; }

    // Find top-3 most frequent uncategorised merchants
    final counts = <String, int>{};
    for (final t in _all) {
      if (t.category == 'Other' && t.merchantName.isNotEmpty) {
        counts[t.merchantName] = (counts[t.merchantName] ?? 0) + 1;
      }
    }
    final top = (counts.keys.toList()
          ..sort((a, b) => counts[b]!.compareTo(counts[a]!)))
        .take(3)
        .toList();

    _onboardingShown = true;
    if (top.isEmpty) {
      await _storage.write(key: 'onboarding_done_v1', value: 'true');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _OnboardingSheet(
        merchants: top,
        onDone: () async {
          await _storage.write(key: 'onboarding_done_v1', value: 'true');
          if (mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _toggleAll() {
    final ids = _filtered.map((t) => t.id).toSet();
    setState(() {
      if (_selected.containsAll(ids)) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  void _confirmAdd() => Navigator.pop(context, _selectedList);

  // ── Helpers ────────────────────────────────────────────────────────────

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Import from SMS'),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSub, size: 22),
              onPressed: () async {
                await _clearCache();
                _load(forceRefresh: true);
              },
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _loading ? _buildLoading() : _buildBody(),
      bottomNavigationBar:
          (!_loading && _all.isNotEmpty) ? _buildBottomBar() : null,
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
                color: AppColors.green, strokeWidth: 3),
          ),
          const SizedBox(height: 28),
          _DotsText(text: _loadingText),
          const SizedBox(height: 6),
          const Text('This may take a moment',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Main body ──────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_emptyReason != _EmptyReason.none) return _buildDiagnosticEmpty();

    final list = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            'Found ${_all.length} transaction${_all.length == 1 ? '' : 's'} (last 90 days)',
            style: const TextStyle(
                color: AppColors.textSub, fontSize: 13),
          ),
        ),
        _buildFilterPills(),
        const SizedBox(height: 6),
        Expanded(
          child: list.isEmpty
              ? _buildFilterEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _buildCard(list[i]),
                ),
        ),
      ],
    );
  }

  // ── Diagnostic empty state ─────────────────────────────────────────────

  Widget _buildDiagnosticEmpty() {
    final String emoji;
    final String title;
    final String detail;
    final Color  titleColor;
    final bool   showOpenSettings;

    switch (_emptyReason) {
      case _EmptyReason.permissionDenied:
        emoji            = '🔒';
        title            = 'SMS Permission Required';
        detail           = 'RupeeIQ needs permission to read your SMS inbox.\n\n'
            'Tap "Open Settings", then allow the SMS permission for RupeeIQ.';
        titleColor       = AppColors.amber;
        showOpenSettings = true;
      case _EmptyReason.noSmsFound:
        emoji            = '📭';
        title            = 'No SMS Found';
        detail           = 'Your inbox appears to be empty or inaccessible.\n\n'
            'Note: This feature reads traditional bank SMS alerts. '
            'Without a SIM card, banks cannot send SMS alerts to this device. '
            'Messages received via Google Messages / RCS are not stored in the '
            'system SMS inbox that this app reads.';
        titleColor       = AppColors.text;
        showOpenSettings = false;
      case _EmptyReason.noKeywordMatch:
        emoji            = '🔍';
        title            = 'No Bank SMS Found';
        detail           = '$_diagTotal message${_diagTotal == 1 ? '' : 's'} were scanned '
            'but none contained financial keywords (₹, Rs., debited, UPI, etc.).\n\n'
            'Make sure your bank sends transaction alerts as SMS to this number.';
        titleColor       = AppColors.text;
        showOpenSettings = false;
      case _EmptyReason.noAmountFound:
        emoji            = '🧾';
        title            = 'SMS Found, No Amounts Detected';
        detail           = '$_diagKeyword financial SMS were found but no transaction '
            'amounts could be extracted.\n\n'
            'Pipeline: $_diagTotal total → $_diagKeyword keyword match → '
            '$_diagAmount with amount';
        titleColor       = AppColors.text;
        showOpenSettings = false;
      case _EmptyReason.none:
        return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSub,
                    fontSize: 13,
                    height: 1.6)),
            const SizedBox(height: 28),
            if (showOpenSettings) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _clearCache();
                  _load(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter-only empty ──────────────────────────────────────────────────

  Widget _buildFilterEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('📆', style: TextStyle(fontSize: 48)),
            SizedBox(height: 14),
            Text('No transactions in this period',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Try "Last 30 Days"',
                style: TextStyle(
                    color: AppColors.textSub, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Filter pills ────────────────────────────────────────────────────────

  Widget _buildFilterPills() {
    final uncatCount = _all.where((t) => t.category == 'Other').length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _pill('This Month',   _DateFilter.thisMonth),
          const SizedBox(width: 8),
          _pill('Last 7 Days',  _DateFilter.last7Days),
          const SizedBox(width: 8),
          _pill('Last 30 Days', _DateFilter.last30Days),
          if (uncatCount > 0) ...[
            const SizedBox(width: 8),
            _uncatPill(uncatCount),
          ],
        ],
      ),
    );
  }

  Widget _uncatPill(int count) {
    final active = _showUncategorized;
    return GestureDetector(
      onTap: () => setState(() => _showUncategorized = !_showUncategorized),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:  active ? AppColors.amberBg    : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.amber : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Uncategorized',
              style: TextStyle(
                color:      active ? AppColors.amber    : AppColors.textSub,
                fontSize:   12,
                fontWeight: active ? FontWeight.w600    : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:        AppColors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, _DateFilter value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceGreen : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.borderGreen : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.green : AppColors.textSub,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Transaction card ───────────────────────────────────────────────────

  Widget _buildCard(Transaction txn) {
    final isSelected = _selected.contains(txn.id);
    final isDebit    = txn.type == 'debit';
    final amtColor   = isDebit ? AppColors.red : AppColors.green;
    final prefix     = isDebit ? '−' : '+';
    final emoji      = categoryIcons[txn.category] ?? '💰';
    final catColor   = _hex(categoryColors[txn.category] ?? '#6B7280');

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${txn.dateTime.day.toString().padLeft(2, '0')} '
        '${months[txn.dateTime.month - 1]}';

    return GestureDetector(
      onTap: () => setState(() {
        isSelected ? _selected.remove(txn.id) : _selected.add(txn.id);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceGreen : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.borderGreen : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dateStr · ${txn.paymentMethod}',
                    style: const TextStyle(
                        color: AppColors.textSub, fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  // Category chip — tap to correct
                  GestureDetector(
                    onTap: () => _showCategoryPicker(txn),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: catColor.withOpacity(0.25), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            txn.category,
                            style: TextStyle(
                                color: catColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.edit_rounded,
                              size: 8,
                              color: catColor.withOpacity(0.65)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Amount
            Text(
              '$prefix${formatCurrency(txn.amount)}',
              style: TextStyle(
                  color: amtColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.green
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.green
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final list     = _filtered;
    final selCount = list.where((t) => _selected.contains(t.id)).length;
    final allSel   =
        list.isNotEmpty && list.every((t) => _selected.contains(t.id));

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _toggleAll,
                child: Text(
                  allSel ? 'Deselect All' : 'Select All',
                  style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$selCount of ${list.length} selected',
                style: const TextStyle(
                    color: AppColors.textSub, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bulk categorize — shown when Uncategorized filter is active
          if (_showUncategorized && selCount > 0) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _bulkCategorize,
                icon: const Icon(Icons.category_outlined, size: 15),
                label: Text('Categorize $selCount Selected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  side: const BorderSide(color: AppColors.amberBorder),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: selCount > 0 ? _confirmAdd : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selCount > 0
                    ? AppColors.green
                    : AppColors.green.withOpacity(0.3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                selCount > 0
                    ? 'Add $selCount Transaction${selCount == 1 ? '' : 's'}'
                    : 'Select Transactions',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category picker bottom sheet ──────────────────────────────────────────

class _CategoryPickerSheet extends StatefulWidget {
  final List<Transaction> transactions;
  final Future<void> Function(String category) onSelected;

  const _CategoryPickerSheet({
    required this.transactions,
    required this.onSelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  static const _cats = [
    ['Food & Groceries', '🍕'],
    ['Transport',        '🚗'],
    ['Shopping',         '🛍️'],
    ['Entertainment',    '🎬'],
    ['Healthcare',       '💊'],
    ['Education',        '📚'],
    ['Utilities',        '💡'],
    ['Travel',           '✈️'],
    ['Investment',       '📈'],
    ['Rent/Housing',     '🏠'],
    ['Other',            '💰'],
  ];

  late String _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.transactions.first.category;
  }

  String _label(String name) =>
      name == 'Food & Groceries' ? 'Food' : name;

  @override
  Widget build(BuildContext context) {
    final isBulk  = widget.transactions.length > 1;
    final title   = isBulk
        ? 'Categorize ${widget.transactions.length} Transactions'
        : 'What was this for?';
    final subtitle = isBulk
        ? null
        : widget.transactions.first.merchantName;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSub, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: _cats.map((cat) {
              final name     = cat[0];
              final emoji    = cat[1];
              final isActive = _selected == name;
              return GestureDetector(
                onTap: _saving
                    ? null
                    : () => setState(() => _selected = name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.surfaceGreen
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? AppColors.borderGreen
                          : AppColors.border,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        _label(name),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.green
                              : AppColors.textMid,
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await widget.onSelected(_selected);
                      if (mounted) Navigator.pop(context);
                    },
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onboarding bottom sheet ────────────────────────────────────────────────

class _OnboardingSheet extends StatefulWidget {
  final List<String> merchants;
  final VoidCallback onDone;

  const _OnboardingSheet({required this.merchants, required this.onDone});

  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  final _picks = <String, String>{}; // merchant → chosen category
  bool _saving = false;

  static const _quickCats = [
    ['Food & Groceries', '🍕'],
    ['Transport',        '🚗'],
    ['Shopping',         '🛍️'],
    ['Healthcare',       '💊'],
    ['Utilities',        '💡'],
    ['Other',            '💰'],
  ];

  @override
  Widget build(BuildContext context) {
    final allPicked = widget.merchants
        .every((m) => _picks.containsKey(m));

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('🧠', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text('Help RupeeIQ Learn Faster!',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Categorize these merchants once and we\'ll\n'
            'recognize them automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSub, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          ...widget.merchants.map((m) => _merchantRow(m)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (!allPicked || _saving)
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          for (final e in _picks.entries) {
                            await learnMerchantCategory(e.key, e.value);
                          }
                          widget.onDone();
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save & Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _merchantRow(String merchant) {
    final selected = _picks[merchant];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(merchant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickCats.map((cat) {
                final name   = cat[0];
                final emoji  = cat[1];
                final active = selected == name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _picks[merchant] = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:  active
                            ? AppColors.surfaceGreen
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active
                                ? AppColors.borderGreen
                                : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            name == 'Food & Groceries' ? 'Food' : name,
                            style: TextStyle(
                              color: active
                                  ? AppColors.green
                                  : AppColors.textSub,
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated "..." loading text ────────────────────────────────────────────

class _DotsText extends StatefulWidget {
  final String text;
  const _DotsText({required this.text});

  @override
  State<_DotsText> createState() => _DotsTextState();
}

class _DotsTextState extends State<_DotsText> {
  late Timer _timer;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = _dots % 3 + 1);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.text}${'.' * _dots}',
      style: const TextStyle(
          color: AppColors.textSub, fontSize: 14),
    );
  }
}
