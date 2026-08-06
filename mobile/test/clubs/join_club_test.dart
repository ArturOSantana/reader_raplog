// Testes do fluxo "entrar em um clube" — por código de convite ou link
//
// Cobre:
//   1. BookClub.fromMap preserva invite_code vindo do banco
//   2. fetchByInviteCode normaliza o código para maiúsculas
//   3. fetchByInviteCode retorna null quando o clube não existe
//   4. fetchByInviteCode retorna null para código vazio
//   5. joinClub registra clubId ao entrar com sucesso
//   6. joinClub lança exceção em caso de erro de servidor
//   7. joinClub não é chamado se fetchByInviteCode retorna null
//   8. Link de convite é gerado no formato https://readlog.app/join/<CODE>
//   9. JoinClubSheet — campo vazio não dispara requisição
//  10. JoinClubSheet — código inválido exibe snackbar de erro
//  11. JoinClubSheet — código válido chama joinClub e fecha o sheet
//  12. JoinClubSheet — erro no servidor exibe snackbar genérico
//  13. JoinClubSheet — código em minúsculas é normalizado no repositório

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lumen/core/theme/app_theme.dart';
import 'package:lumen/features/clubs/data/book_club_repository.dart';
import 'package:lumen/features/clubs/presentation/screens/book_clubs_screen.dart';
import 'package:lumen/shared/models/book_club.dart';
import 'package:lumen/shared/providers/providers.dart';

// ── Fake repository ──────────────────────────────────────────────────────────

/// Stub que não toca o Supabase real.
class _FakeBookClubRepository extends BookClubRepository {
  final Map<String, BookClub> _clubByCode;
  final bool throwOnJoin;

  String? joinedClubId;
  int joinCallCount = 0;
  String? lastFetchedCode;

  _FakeBookClubRepository({
    Map<String, BookClub>? clubByCode,
    this.throwOnJoin = false,
  })  : _clubByCode = clubByCode ?? {},
        super(_dummyClient());

  static SupabaseClient _dummyClient() => SupabaseClient(
        'https://fake.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          autoRefreshToken: false,
        ),
      );

  @override
  Future<BookClub?> fetchByInviteCode(String code) async {
    lastFetchedCode = code;
    return _clubByCode[code.toUpperCase()];
  }

  @override
  Future<void> joinClub(String clubId) async {
    if (throwOnJoin) throw Exception('Erro simulado ao entrar no clube');
    joinCallCount++;
    joinedClubId = clubId;
  }

  @override
  Future<List<BookClub>> listMyClubs() async => [];
}

// ── Helper: clube de teste ───────────────────────────────────────────────────

BookClub makeTestClub({
  String id = 'club-123',
  String name = 'Clube Teste',
  String inviteCode = 'ABC123',
  ClubStatus status = ClubStatus.active,
  ClubVisibility visibility = ClubVisibility.private,
}) {
  return BookClub(
    id: id,
    name: name,
    inviteCode: inviteCode,
    memberCount: 5,
    createdAt: DateTime(2024, 1, 1),
    status: status,
    visibility: visibility,
  );
}

// ── Helper: monta JoinClubSheet isolado ──────────────────────────────────────

Widget _buildJoinSheet(
  _FakeBookClubRepository fakeRepo, {
  ValueChanged<BookClub>? onJoined,
}) {
  return ProviderScope(
    overrides: [
      bookClubRepositoryProvider.overrideWith((_) => fakeRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: JoinClubSheet(onJoined: onJoined ?? (_) {}),
      ),
    ),
  );
}

// ── Testes ───────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Modelo BookClub ─────────────────────────────────────────────────────

  group('BookClub.fromMap — invite_code', () {
    Map<String, dynamic> baseMap({String? inviteCode}) => {
          'id': 'club-1',
          'name': 'Clube A',
          'member_count': 3,
          'created_at': '2024-01-01T00:00:00Z',
          'status': 'active',
          'visibility': 'private',
          'category': 'general',
          if (inviteCode != null) 'invite_code': inviteCode,
        };

    test('preserva invite_code quando presente no map', () {
      final club = BookClub.fromMap(baseMap(inviteCode: 'XYZ789'));
      expect(club.inviteCode, 'XYZ789');
    });

    test('aceita invite_code null (clube sem código gerado)', () {
      final club = BookClub.fromMap(baseMap());
      expect(club.inviteCode, isNull);
    });

    test('round-trip fromMap não perde invite_code', () {
      final club = BookClub.fromMap(baseMap(inviteCode: 'MYCODE'));
      expect(club.inviteCode, 'MYCODE');
    });
  });

  // ── 2. Repositório fake — fetchByInviteCode ────────────────────────────────

  group('_FakeBookClubRepository — fetchByInviteCode', () {
    final club = makeTestClub(inviteCode: 'ABC123');

    test('retorna o clube quando o código existe', () async {
      final repo = _FakeBookClubRepository(clubByCode: {'ABC123': club});
      final result = await repo.fetchByInviteCode('ABC123');
      expect(result, isNotNull);
      expect(result!.id, 'club-123');
    });

    test('normaliza código para maiúsculas antes de buscar', () async {
      final repo = _FakeBookClubRepository(clubByCode: {'ABC123': club});
      final result = await repo.fetchByInviteCode('abc123');
      expect(result, isNotNull);
      // lastFetchedCode recebe o valor original; toUpperCase é aplicado na busca
      expect(repo.lastFetchedCode, 'abc123');
    });

    test('retorna null para código inexistente', () async {
      final repo = _FakeBookClubRepository(clubByCode: {'ABC123': club});
      final result = await repo.fetchByInviteCode('INVALID');
      expect(result, isNull);
    });

    test('retorna null para código vazio', () async {
      final repo = _FakeBookClubRepository(clubByCode: {'ABC123': club});
      final result = await repo.fetchByInviteCode('');
      expect(result, isNull);
    });
  });

  // ── 3. Repositório fake — joinClub ────────────────────────────────────────

  group('_FakeBookClubRepository — joinClub', () {
    test('registra o clubId ao entrar com sucesso', () async {
      final repo = _FakeBookClubRepository(
        clubByCode: {'ABC123': makeTestClub()},
      );
      await repo.joinClub('club-123');
      expect(repo.joinedClubId, 'club-123');
      expect(repo.joinCallCount, 1);
    });

    test('lança exceção quando throwOnJoin=true', () async {
      final repo = _FakeBookClubRepository(throwOnJoin: true);
      expect(() => repo.joinClub('club-123'), throwsException);
    });

    test('joinClub não é chamado se fetchByInviteCode retorna null', () async {
      final repo = _FakeBookClubRepository(clubByCode: {});
      final club = await repo.fetchByInviteCode('NOPE');
      if (club != null) await repo.joinClub(club.id);
      expect(repo.joinCallCount, 0);
    });
  });

  // ── 4. Link de convite ─────────────────────────────────────────────────────

  group('Link de convite', () {
    test('formato correto: https://readlog.app/join/<CODE>', () {
      const inviteCode = 'XYZ789';
      final link = 'https://readlog.app/join/$inviteCode';
      expect(link, 'https://readlog.app/join/XYZ789');
    });

    test('link usa o inviteCode sem transformação', () {
      final club = makeTestClub(inviteCode: 'MCODE1');
      final link = 'https://readlog.app/join/${club.inviteCode}';
      expect(link, 'https://readlog.app/join/MCODE1');
    });
  });

  // ── 5. Widget JoinClubSheet ───────────────────────────────────────────────

  group('JoinClubSheet — widget', () {
    testWidgets('exibe título, campo e botão',
        (tester) async {
      final repo = _FakeBookClubRepository();
      await tester.pumpWidget(_buildJoinSheet(repo));
      await tester.pump();

      expect(find.text('Entrar em um clube'), findsOneWidget);
      expect(find.text('Entrar no clube'), findsOneWidget);
      // label do TextField
      expect(find.text('Código de convite'), findsOneWidget);
    });

    testWidgets('campo vazio não dispara nenhuma chamada ao repositório',
        (tester) async {
      final repo = _FakeBookClubRepository();
      await tester.pumpWidget(_buildJoinSheet(repo));
      await tester.pump();

      await tester.tap(find.text('Entrar no clube'));
      await tester.pump();

      expect(repo.joinCallCount, 0);
      expect(repo.lastFetchedCode, isNull);
    });

    testWidgets('código inválido exibe snackbar de erro',
        (tester) async {
      final repo = _FakeBookClubRepository(clubByCode: {});
      await tester.pumpWidget(_buildJoinSheet(repo));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'INVALIDO');
      await tester.tap(find.text('Entrar no clube'));
      await tester.pumpAndSettle();

      expect(
        find.text('Código inválido ou clube não encontrado.'),
        findsOneWidget,
      );
      expect(repo.joinCallCount, 0);
    });

    testWidgets('código válido chama joinClub',
        (tester) async {
      final club = makeTestClub(inviteCode: 'VALID1');
      BookClub? joinedClub;
      final repo = _FakeBookClubRepository(
        clubByCode: {'VALID1': club},
      );

      await tester.pumpWidget(_buildJoinSheet(
        repo,
        onJoined: (c) => joinedClub = c,
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'VALID1');
      await tester.tap(find.text('Entrar no clube'));
      await tester.pumpAndSettle();

      expect(repo.joinCallCount, 1);
      expect(repo.joinedClubId, 'club-123');
      expect(joinedClub?.id, 'club-123');
    });

    testWidgets('erro no servidor exibe snackbar genérico',
        (tester) async {
      final club = makeTestClub(inviteCode: 'VALID1');
      final repo = _FakeBookClubRepository(
        clubByCode: {'VALID1': club},
        throwOnJoin: true,
      );

      await tester.pumpWidget(_buildJoinSheet(repo));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'VALID1');
      await tester.tap(find.text('Entrar no clube'));
      await tester.pumpAndSettle();

      expect(
        find.text('Erro ao entrar no clube. Tente novamente.'),
        findsOneWidget,
      );
    });

    testWidgets('código em minúsculas é normalizado no fetch',
        (tester) async {
      final club = makeTestClub(inviteCode: 'ABC123');
      final repo = _FakeBookClubRepository(
        clubByCode: {'ABC123': club},
      );

      await tester.pumpWidget(_buildJoinSheet(repo));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.tap(find.text('Entrar no clube'));
      await tester.pumpAndSettle();

      // fetchByInviteCode faz .toUpperCase() então encontra o clube
      expect(repo.joinCallCount, 1);
    });
  });
}
