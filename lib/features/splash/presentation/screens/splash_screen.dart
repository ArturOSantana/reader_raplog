import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    auth.whenData((state) async {
      if (!context.mounted) return;
      if (state.session == null) {
        context.go('/auth/login');
        return;
      }

      // Usuário logado: verifica se o onboarding foi completado
      final completed = await ref.read(onboardingCompletedProvider.future);
      if (!context.mounted) return;
      context.go(completed ? '/home' : '/onboarding');
    });

    return Scaffold(
      backgroundColor: AppColors.forestGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ReadLog',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seu diário de leitura',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white.withValues(alpha: 0.6),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
