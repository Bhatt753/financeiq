import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const _professions = [
  ('Student',        Icons.school_outlined),
  ('Salaried',       Icons.work_outline_rounded),
  ('Business Owner', Icons.store_outlined),
  ('Freelancer',     Icons.laptop_outlined),
  ('Doctor',         Icons.local_hospital_outlined),
  ('Engineer',       Icons.engineering_outlined),
  ('Other',          Icons.person_outline_rounded),
];

class SetupProfileScreen extends StatefulWidget {
  final String name;
  const SetupProfileScreen({super.key, required this.name});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  String? _selected;
  bool    _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ApiService.updateProfile(widget.name, _selected!);
      if (!mounted) return;
      if (res['ok'] == true || res['error'] == null) {
        context.read<AuthProvider>().setAuthenticated();
        Navigator.of(context).pop();
      } else {
        setState(() => _error = res['error'] as String? ?? 'Failed to save');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Connection error. Try again.');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _skipForNow() async {
    context.read<AuthProvider>().setAuthenticated();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              _buildHeader(),
              const SizedBox(height: 32),
              if (_error != null) ...[
                _buildErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              ..._professions.map(_buildOption),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _saving ? null : _skipForNow,
                child: const Text('Skip for now',
                    style: TextStyle(color: AppColors.textSub, fontSize: 14)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final firstName = widget.name.isNotEmpty
        ? widget.name.trim().split(' ').first
        : '';
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.waving_hand_rounded,
              color: AppColors.green, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          firstName.isNotEmpty ? 'Welcome, $firstName!' : 'Welcome!',
          style: const TextStyle(
              color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'What best describes you?\nThis helps personalise your financial insights.',
          style: TextStyle(color: AppColors.textSub, fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOption((String, IconData) item) {
    final (label, icon) = item;
    final selected = _selected == label;
    return GestureDetector(
      onTap: () => setState(() => _selected = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceGreen : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.green : AppColors.textSub,
                size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.green : AppColors.text,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.green : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.green : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: (_selected == null || _saving) ? null : _save,
        child: _saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('Save & Continue'),
      ),
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: AppColors.red, fontSize: 13))),
        ],
      ),
    );
  }
}
