import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  Future<void> _navigate(Session? session) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (session == null) {
      // Reseta o status de onboarding ao fazer logout
      ref.read(onboardingStatusProvider.notifier).state = null;
      context.go('/auth/login');
      return;
    }

    // Usuário logado: força nova leitura do repositório
    ref.invalidate(onboardingCompletedProvider);
    final completed = await ref.read(onboardingCompletedProvider.future);
    if (!mounted) return;

    // Escreve o resultado síncrono para que o redirect do router funcione
    ref.read(onboardingStatusProvider.notifier).state = completed;
    context.go(completed ? '/home' : '/onboarding');
  }

  @override
  void initState() {
    super.initState();
    // Verifica sessão imediatamente (sem esperar o stream emitir)
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      // Já tem sessão ativa — navega assim que o frame estiver pronto
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(currentSession));
    }
    // Se não tiver sessão, aguarda o stream (listener abaixo no build)
  }

  @override
  Widget build(BuildContext context) {
    // Escuta mudanças de auth (login, logout, token refresh)
    ref.listen(authStateProvider, (_, next) {
      next.whenData((state) => _navigate(state.session));
    });

    // Se ainda não temos sessão e o stream está loading, redireciona para login
    final auth = ref.watch(authStateProvider);
    if (auth is AsyncData && !_navigated) {
      final session = auth.valueOrNull?.session;
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(session));
    }

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
              'Lumen',
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
              'Seu companheiro de leitura',
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
