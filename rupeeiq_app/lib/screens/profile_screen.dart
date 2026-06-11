import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _editing = false;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _professionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _professionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getProfile();
      if (res['error'] != null) {
        setState(() { _error = res['error'] as String; _loading = false; });
      } else {
        final p = res['user'] as Map<String, dynamic>? ?? {};
        _nameCtrl.text = p['name'] as String? ?? '';
        _professionCtrl.text = p['profession'] as String? ?? '';
        setState(() { _profile = p; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Failed to load profile.'; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(
        _nameCtrl.text.trim(),
        _professionCtrl.text.trim(),
      );
      setState(() { _editing = false; _saving = false; });
      _load();
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing && _profile != null)
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit',
                  style: TextStyle(color: AppColors.green)),
            ),
          if (_editing) ...[
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.green),
                    )
                  : const Text('Save',
                      style: TextStyle(color: AppColors.green)),
            ),
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSub)),
            ),
          ]
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
    final p = _profile ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildAvatar(p),
        const SizedBox(height: 24),
        if (_editing) _buildEditForm() else _buildProfileView(p),
        const SizedBox(height: 20),
        _buildStatsSection(p),
        const SizedBox(height: 20),
        _buildLogoutButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAvatar(Map<String, dynamic> p) {
    final name = p['name'] as String? ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Center(
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.green, AppColors.greenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          Text(p['name'] as String? ?? '',
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(p['email'] as String? ?? '',
              style: const TextStyle(
                  color: AppColors.textSub, fontSize: 13)),
          if (p['profession'] != null &&
              (p['profession'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.indigoBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(p['profession'] as String,
                  style: const TextStyle(
                      color: AppColors.indigo,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileView(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InfoRow(
              label: 'Full Name', value: p['name'] as String? ?? '—'),
          const Divider(height: 16),
          InfoRow(
              label: 'Username',
              value: p['username'] as String? ?? '—',
              valueColor: AppColors.textSub),
          const Divider(height: 16),
          InfoRow(
              label: 'Email', value: p['email'] as String? ?? '—'),
          if (p['profession'] != null &&
              (p['profession'] as String).isNotEmpty) ...[
            const Divider(height: 16),
            InfoRow(
                label: 'Profession',
                value: p['profession'] as String),
          ],
          if (p['member_since'] != null) ...[
            const Divider(height: 16),
            InfoRow(
                label: 'Member Since',
                value: p['member_since'] as String,
                valueColor: AppColors.textSub),
          ],
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        TextFormField(
          controller: _nameCtrl,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _professionCtrl,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            labelText: 'Profession',
            prefixIcon: Icon(Icons.work_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> p) {
    final totalMonths = p['total_months'] ?? 0;
    final totalLoans = p['total_loans'] ?? 0;
    final totalGoals = p['total_goals'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Activity',
              style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _actStat('$totalMonths', 'Months\nTracked',
                  AppColors.indigo),
              _actStat('$totalLoans', 'Loans\nTracked',
                  AppColors.amber),
              _actStat('$totalGoals', 'Goals\nSet', AppColors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actStat(String val, String label, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSub, fontSize: 11)),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?',
                  style: TextStyle(color: AppColors.textSub)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign Out',
                        style: TextStyle(color: AppColors.red))),
              ],
            ),
          );
          if (confirm == true && mounted) {
            context.read<AuthProvider>().logout();
          }
        },
        icon: const Icon(Icons.logout, color: AppColors.red),
        label: const Text('Sign Out',
            style: TextStyle(color: AppColors.red)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.redBorder),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          foregroundColor: AppColors.red,
        ),
      ),
    );
  }
}
