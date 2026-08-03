import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/shared/models/goal.dart';

void main() {
  // ── GoalPeriodX ───────────────────────────────────────────────────────────

  group('GoalPeriodX.dbValue', () {
    test('converte cada período para o valor de BD correto', () {
      expect(GoalPeriod.daily.dbValue, 'daily');
      expect(GoalPeriod.weekly.dbValue, 'weekly');
      expect(GoalPeriod.monthly.dbValue, 'monthly');
      expect(GoalPeriod.yearly.dbValue, 'yearly');
    });
  });

  group('GoalPeriodX.fromDb', () {
    test('converte strings do BD corretamente', () {
      expect(GoalPeriodX.fromDb('weekly'), GoalPeriod.weekly);
      expect(GoalPeriodX.fromDb('monthly'), GoalPeriod.monthly);
      expect(GoalPeriodX.fromDb('yearly'), GoalPeriod.yearly);
    });

    test('retorna daily para valor desconhecido', () {
      expect(GoalPeriodX.fromDb('unknown'), GoalPeriod.daily);
      expect(GoalPeriodX.fromDb('daily'), GoalPeriod.daily);
    });
  });

  // ── GoalTypeX ─────────────────────────────────────────────────────────────

  group('GoalTypeX.label', () {
    test('retorna os labels corretos', () {
      expect(GoalType.dailyPages.label, 'Páginas por dia');
      expect(GoalType.dailyMinutes.label, 'Minutos por dia');
      expect(GoalType.yearlyBooks.label, 'Livros por ano');
      expect(GoalType.monthlyPages.label, 'Páginas por mês');
    });
  });

  group('GoalTypeX.unit', () {
    test('retorna a unidade correta', () {
      expect(GoalType.dailyPages.unit, 'páginas');
      expect(GoalType.dailyMinutes.unit, 'minutos');
      expect(GoalType.yearlyBooks.unit, 'livros');
      expect(GoalType.monthlyPages.unit, 'páginas');
    });
  });

  group('GoalTypeX.dbValue', () {
    test('converte cada tipo para o valor de BD correto', () {
      expect(GoalType.dailyPages.dbValue, 'daily_pages');
      expect(GoalType.dailyMinutes.dbValue, 'daily_minutes');
      expect(GoalType.yearlyBooks.dbValue, 'yearly_books');
      expect(GoalType.monthlyPages.dbValue, 'monthly_pages');
    });
  });

  group('GoalTypeX.fromDb', () {
    test('converte strings do BD corretamente', () {
      expect(GoalTypeX.fromDb('daily_pages'), GoalType.dailyPages);
      expect(GoalTypeX.fromDb('daily_minutes'), GoalType.dailyMinutes);
      expect(GoalTypeX.fromDb('yearly_books'), GoalType.yearlyBooks);
      expect(GoalTypeX.fromDb('monthly_pages'), GoalType.monthlyPages);
    });

    test('retorna dailyMinutes para valor desconhecido', () {
      expect(GoalTypeX.fromDb('unknown'), GoalType.dailyMinutes);
    });
  });

  // ── Goal.fromMap ──────────────────────────────────────────────────────────

  group('Goal.fromMap', () {
    test('faz parse de todos os campos corretamente', () {
      final map = {
        'id': 'goal-1',
        'user_id': 'user-1',
        'type': 'daily_pages',
        'period': 'daily',
        'target_value': 30,
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      final goal = Goal.fromMap(map);
      expect(goal.id, 'goal-1');
      expect(goal.userId, 'user-1');
      expect(goal.type, GoalType.dailyPages);
      expect(goal.period, GoalPeriod.daily);
      expect(goal.targetValue, 30);
    });

    test('usa period=daily quando o campo está ausente', () {
      final map = {
        'id': 'g-2',
        'user_id': 'u-1',
        'type': 'yearly_books',
        'period': null,
        'target_value': 12,
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      final goal = Goal.fromMap(map);
      expect(goal.period, GoalPeriod.daily);
    });
  });
}
