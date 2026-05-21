import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form     = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading   = false;
  bool _obscure   = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().login(
        _userCtrl.text.trim(), _passCtrl.text.trim(),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),

                // Logo
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.green.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: AppColors.green, size: 26),
                ),
                const SizedBox(height: 24),

                const Text('Welcome back',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Sign in to your RupeeIQ account',
                    style: TextStyle(color: AppColors.textSub, fontSize: 15)),

                const SizedBox(height: 36),

                if (_error != null) ...[
                  _ErrorBanner(_error!),
                  const SizedBox(height: 16),
                ],

                _Label('Username'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _userCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(
                    hintText: 'Your username',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.textSub, size: 20),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                _Label('Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSub, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textSub, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                        : const Text('Sign In'),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              color: AppColors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
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
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.textSub, fontSize: 13, fontWeight: FontWeight.w600));
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
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
            Expanded(child: Text(message,
                style: const TextStyle(color: AppColors.red, fontSize: 13))),
          ],
        ),
      );
}
