import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/metric_card.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  String _profession = 'Salaried';
  bool _saving = false;

  static const _professions = [
    'Salaried', 'Self-Employed', 'Business Owner',
    'Freelancer', 'Student', 'Retired', 'Other',
  ];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getProfile();
      final u = d['user'] as Map<String, dynamic>? ?? {};
      setState(() {
        _user       = u;
        _nameCtrl.text = u['name'] ?? '';
        _profession = (_professions.contains(u['profession'])) ? u['profession'] : 'Salaried';
        _loading    = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(name: _nameCtrl.text.trim(), profession: _profession);
      context.read<AuthProvider>().setUser({...?_user, 'name': _nameCtrl.text.trim(), 'profession': _profession});
      setState(() { _editing = false; });
      _load();
    } catch (_) {}
    setState(() => _saving = false);
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Logout', style: TextStyle(color: AppColors.text)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSub))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing && !_loading)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => setState(() => _editing = true)),
          if (_editing)
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _editing = false)),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar / header
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.green, Color(0xFF16A34A)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (_user?['name'] ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(_user?['name'] ?? '',
                            style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('@${_user?['username'] ?? ''}',
                            style: const TextStyle(color: AppColors.textSub, fontSize: 14)),
                        const SizedBox(height: 4),
                        InfoChip(label: _user?['profession'] ?? '', color: AppColors.indigo),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  if (_editing) _editForm() else _profileInfo(),

                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: AppColors.red, size: 18),
                      label: const Text('Logout', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.red),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _profileInfo() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        _infoRow('Full Name', _user?['name'] ?? '—', Icons.person_outline),
        const Divider(color: AppColors.border, height: 16),
        _infoRow('Username', '@${_user?['username'] ?? '—'}', Icons.alternate_email),
        const Divider(color: AppColors.border, height: 16),
        _infoRow('Email', _user?['email'] ?? '—', Icons.email_outlined),
        const Divider(color: AppColors.border, height: 16),
        _infoRow('Profession', _user?['profession'] ?? '—', Icons.work_outline),
      ],
    ),
  );

  Widget _infoRow(String label, String value, IconData icon) => Row(
    children: [
      Icon(icon, color: AppColors.textSub, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14)),
          ],
        ),
      ),
    ],
  );

  Widget _editForm() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Edit Profile', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 16),

        const Text('Full Name', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameCtrl,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline, color: AppColors.textSub, size: 18),
          ),
        ),
        const SizedBox(height: 14),

        const Text('Profession', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _profession,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.work_outline, color: AppColors.textSub, size: 18),
          ),
          items: _professions.map((p) =>
              DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _profession = v!),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textSub),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
