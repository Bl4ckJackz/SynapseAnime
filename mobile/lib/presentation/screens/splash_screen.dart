import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../domain/providers/auth_provider.dart';
import '../widgets/loading_spinner.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Artificial delay for splash animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if there's a valid stored token
    final authService = ref.read(authServiceProvider.notifier);
    final isAuthenticated = await authService.checkStoredToken();

    if (!mounted) return;

    if (isAuthenticated) {
      context.goNamed('home');
    } else {
      // Check onboarding status
      // For now, let's just go to 'intro' which we will define,
      // or we can use 'login' but we want to start at page 0 if not onboarded.
      // Let's assume we want to force onboarding for now or check prefs.
      // Since I don't want to add another file read here if I can avoid it,
      // but I should checking persistent storage.

      // I will update this file to read shared_prefs.
      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      if (onboardingComplete) {
        context.goNamed('login');
      } else {
        context.goNamed('intro');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo_full.png',
              width: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            const LoadingSpinner(size: 80),
          ],
        ),
      ),
    );
  }
}
