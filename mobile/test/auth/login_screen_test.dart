import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readlog/features/auth/presentation/screens/login_screen.dart';
import 'package:readlog/core/theme/app_theme.dart';

/// Helper: empacota o widget em um MaterialApp sem depender do GoRouter,
/// o que evita a inicialização do Supabase durante os testes.
Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  group('LoginScreen — estrutura visual', () {
    testWidgets('exibe o título "Readlog"', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.text('Readlog'), findsOneWidget);
    });

    testWidgets('exibe subtítulo "Bem-vindo de volta" no modo login', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.text('Bem-vindo de volta'), findsOneWidget);
    });

    testWidgets('exibe campo de e-mail', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
    });

    testWidgets('exibe campo de senha', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
    });

    testWidgets('exibe botão "Entrar"', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    });

    testWidgets('exibe botão "Entrar com Google"', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.widgetWithText(OutlinedButton, 'Entrar com Google'),
          findsOneWidget);
    });

    testWidgets('exibe link para cadastro', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(
        find.text('Nao tenho conta — cadastrar'),
        findsOneWidget,
      );
    });
  });

  group('LoginScreen — alternância login/cadastro', () {
    testWidgets('ao tocar em "cadastrar", muda subtítulo para "Crie sua conta"',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      await tester.tap(find.text('Nao tenho conta — cadastrar'));
      await tester.pump();

      expect(find.text('Crie sua conta'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);
    });

    testWidgets('ao tocar em "Ja tenho conta", volta para modo login',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      // Vai para cadastro
      await tester.tap(find.text('Nao tenho conta — cadastrar'));
      await tester.pump();

      // Volta para login
      await tester.tap(find.text('Ja tenho conta'));
      await tester.pump();

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    });
  });

  group('LoginScreen — validação de formulário', () {
    testWidgets('mostra erro se e-mail for inválido', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      // Preenche e-mail inválido
      await tester.enterText(
          find.widgetWithText(TextFormField, 'E-mail'), 'nao-e-um-email');
      // Preenche senha válida
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'), 'senha123');

      // Toca no botão Entrar
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.text('E-mail invalido'), findsOneWidget);
    });

    testWidgets('mostra erro se senha for muito curta', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'E-mail'), 'teste@teste.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'), '123'); // curta

      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.text('Minimo 6 caracteres'), findsOneWidget);
    });

    testWidgets(
        'não mostra erros quando e-mail e senha são preenchidos corretamente',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'E-mail'), 'teste@teste.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'), 'senha123');

      // Verifica que os erros de validação não aparecem antes de submeter
      expect(find.text('E-mail invalido'), findsNothing);
      expect(find.text('Minimo 6 caracteres'), findsNothing);
    });
  });
}
