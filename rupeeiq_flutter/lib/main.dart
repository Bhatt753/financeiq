import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const RupeeIQApp());
}

class RupeeIQApp extends StatelessWidget {
  const RupeeIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: MaterialApp(
        title: 'RupeeIQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('RupeeIQ',
                  style: TextStyle(
                      color: AppColors.green,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              SizedBox(height: 24),
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: AppColors.green, strokeWidth: 2),
              ),
            ],
          ),
        ),
      );
    }

    return auth.isLoggedIn ? const MainShell() : const LoginScreen();
  }
}
