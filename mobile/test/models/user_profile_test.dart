import 'package:flutter_test/flutter_test.dart';
import 'package:readlog/shared/models/user_profile.dart';

void main() {
  // ── UserProfile.fromMap ───────────────────────────────────────────────────

  group('UserProfile.fromMap', () {
    test('faz parse de todos os campos corretamente', () {
      final map = {
        'id': 'user-1',
        'name': 'Ana Lima',
        'bio': 'Leitora ávida',
        'avatar_url': 'https://example.com/avatar.jpg',
        'yearly_goal': 24,
        'favorite_genre': 'Ficção Científica',
        'favorite_authors': 'Asimov, Dick',
        'favorite_book': 'Fundação',
        'onboarding_completed': true,
        'updated_at': '2024-06-01T00:00:00.000Z',
      };
      final profile = UserProfile.fromMap(map);
      expect(profile.id, 'user-1');
      expect(profile.name, 'Ana Lima');
      expect(profile.bio, 'Leitora ávida');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.yearlyGoal, 24);
      expect(profile.favoriteGenre, 'Ficção Científica');
      expect(profile.favoriteAuthors, 'Asimov, Dick');
      expect(profile.favoriteBook, 'Fundação');
      expect(profile.onboardingCompleted, isTrue);
    });

    test('onboarding_completed aceita valor int 1 como true', () {
      final map = {
        'id': 'u-2',
        'name': null,
        'bio': null,
        'avatar_url': null,
        'yearly_goal': null,
        'favorite_genre': null,
        'favorite_authors': null,
        'favorite_book': null,
        'onboarding_completed': 1,
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      expect(UserProfile.fromMap(map).onboardingCompleted, isTrue);
    });

    test('onboarding_completed aceita valor int 0 como false', () {
      final map = {
        'id': 'u-3',
        'name': null,
        'bio': null,
        'avatar_url': null,
        'yearly_goal': null,
        'favorite_genre': null,
        'favorite_authors': null,
        'favorite_book': null,
        'onboarding_completed': 0,
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      expect(UserProfile.fromMap(map).onboardingCompleted, isFalse);
    });

    test('onboarding_completed trata null como false', () {
      final map = {
        'id': 'u-4',
        'name': null,
        'bio': null,
        'avatar_url': null,
        'yearly_goal': null,
        'favorite_genre': null,
        'favorite_authors': null,
        'favorite_book': null,
        'onboarding_completed': null,
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      expect(UserProfile.fromMap(map).onboardingCompleted, isFalse);
    });
  });

  // ── UserProfile.toMap ─────────────────────────────────────────────────────

  group('UserProfile.toMap', () {
    test('serializa onboardingCompleted como 1 quando true', () {
      final profile = UserProfile(
        id: 'u-1',
        onboardingCompleted: true,
        updatedAt: DateTime(2024),
      );
      expect(profile.toMap()['onboarding_completed'], 1);
    });

    test('serializa onboardingCompleted como 0 quando false', () {
      final profile = UserProfile(
        id: 'u-1',
        onboardingCompleted: false,
        updatedAt: DateTime(2024),
      );
      expect(profile.toMap()['onboarding_completed'], 0);
    });
  });

  // ── UserProfile.copyWith ──────────────────────────────────────────────────

  group('UserProfile.copyWith', () {
    test('somente os campos passados são alterados', () {
      final original = UserProfile(
        id: 'u-1',
        name: 'Ana',
        bio: 'Bio original',
        yearlyGoal: 10,
        onboardingCompleted: false,
        updatedAt: DateTime(2024),
      );
      final updated = original.copyWith(name: 'Carlos', yearlyGoal: 20);
      expect(updated.name, 'Carlos');
      expect(updated.yearlyGoal, 20);
      expect(updated.bio, 'Bio original');
      expect(updated.id, 'u-1');
    });
  });

  // ── UserProfile equality ──────────────────────────────────────────────────

  group('UserProfile equality', () {
    test('dois perfis com os mesmos campos relevantes são iguais', () {
      final a = UserProfile(
        id: 'u-1',
        name: 'Ana',
        onboardingCompleted: true,
        updatedAt: DateTime(2024),
      );
      final b = UserProfile(
        id: 'u-1',
        name: 'Ana',
        onboardingCompleted: true,
        updatedAt: DateTime(2025), // updatedAt não está em props
      );
      expect(a, equals(b));
    });
  });
}
