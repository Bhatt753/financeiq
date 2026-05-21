import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form     = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl= TextEditingController();
  final _passCtrl = TextEditingController();
  bool  _loading  = false;
  bool  _obscure  = true;
  String? _error;
  String _profession = 'Salaried';

  static const _professions = [
    'Salaried', 'Self-Employed', 'Business Owner',
    'Freelancer', 'Student', 'Retired', 'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _userCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().register(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        profession: _profession,
        email: _emailCtrl.text.trim(),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Network error. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Join RupeeIQ',
                    style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Start your smart financial journey',
                    style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                const SizedBox(height: 28),

                if (_error != null) ...[
                  _errorBanner(_error!),
                  const SizedBox(height: 16),
                ],

                _field(_nameCtrl,  'Full Name',  Icons.person_outline,  hint: 'Your full name'),
                const SizedBox(height: 14),
                _field(_userCtrl,  'Username',   Icons.alternate_email,  hint: 'Choose a username'),
                const SizedBox(height: 14),
                _field(_emailCtrl, 'Email',      Icons.email_outlined,   hint: 'your@email.com',
                    keyboard: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    }),
                const SizedBox(height: 14),

                const Text('Profession',
                    style: TextStyle(color: AppColors.textSub, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _profession,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.work_outline, color: AppColors.textSub, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  items: _professions.map((p) =>
                    DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _profession = v!),
                ),
                const SizedBox(height: 14),

                const Text('Password',
                    style: TextStyle(color: AppColors.textSub, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Min 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSub, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textSub, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? ",
                        style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('Sign In',
                          style: TextStyle(color: AppColors.green, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl, String label, IconData icon, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSub, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textSub, size: 20),
          ),
          validator: validator ?? (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(color: AppColors.red, fontSize: 13))),
          ],
        ),
      );
}
