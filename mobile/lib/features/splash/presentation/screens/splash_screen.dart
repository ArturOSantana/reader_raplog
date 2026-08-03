import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../theme/lumen_theme.dart';
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
    // Agenda a verificação de sessão para após o primeiro frame, garantindo
    // que o widget esteja montado e o contexto disponível. Toda a lógica de
    // navegação passa por _navigate, que é protegida pelo flag _navigated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentSession = Supabase.instance.client.auth.currentSession;
      _navigate(currentSession);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuta mudanças futuras de auth (login após tela, logout, token refresh).
    // É o único ponto de disparo de navegação além do initState.
    ref.listen(authStateProvider, (_, next) {
      next.whenData((state) => _navigate(state.session));
    });
    // Observa authStateProvider para forçar rebuild quando o stream emitir,
    // garantindo que o listen acima seja registrado antes de qualquer emissão.
    ref.watch(authStateProvider);

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
