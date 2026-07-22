enum GoalType { dailyPages, dailyMinutes, yearlyBooks, monthlyPages }

enum GoalPeriod { daily, weekly, monthly, yearly }

extension GoalPeriodX on GoalPeriod {
  String get dbValue {
    switch (this) {
      case GoalPeriod.daily:
        return 'daily';
      case GoalPeriod.weekly:
        return 'weekly';
      case GoalPeriod.monthly:
        return 'monthly';
      case GoalPeriod.yearly:
        return 'yearly';
    }
  }

  static GoalPeriod fromDb(String value) {
    switch (value) {
      case 'weekly':
        return GoalPeriod.weekly;
      case 'monthly':
        return GoalPeriod.monthly;
      case 'yearly':
        return GoalPeriod.yearly;
      default:
        return GoalPeriod.daily;
    }
  }
}

extension GoalTypeX on GoalType {
  String get label {
    switch (this) {
      case GoalType.dailyPages:
        return 'Páginas por dia';
      case GoalType.dailyMinutes:
        return 'Minutos por dia';
      case GoalType.yearlyBooks:
        return 'Livros por ano';
      case GoalType.monthlyPages:
        return 'Páginas por mês';
    }
  }

  String get unit {
    switch (this) {
      case GoalType.dailyPages:
        return 'páginas';
      case GoalType.dailyMinutes:
        return 'minutos';
      case GoalType.yearlyBooks:
        return 'livros';
      case GoalType.monthlyPages:
        return 'páginas';
    }
  }

  String get dbValue {
    switch (this) {
      case GoalType.dailyPages:
        return 'daily_pages';
      case GoalType.dailyMinutes:
        return 'daily_minutes';
      case GoalType.yearlyBooks:
        return 'yearly_books';
      case GoalType.monthlyPages:
        return 'monthly_pages';
    }
  }

  static GoalType fromDb(String value) {
    switch (value) {
      case 'daily_pages':
        return GoalType.dailyPages;
      case 'daily_minutes':
        return GoalType.dailyMinutes;
      case 'yearly_books':
        return GoalType.yearlyBooks;
      case 'monthly_pages':
        return GoalType.monthlyPages;
      default:
        return GoalType.dailyMinutes;
    }
  }
}

class Goal {
  final String id;
  final String userId;
  final GoalType type;
  final GoalPeriod period;
  final int targetValue;
  final DateTime createdAt;

  const Goal({
    required this.id,
    required this.userId,
    required this.type,
    required this.period,
    required this.targetValue,
    required this.createdAt,
  });

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        type: GoalTypeX.fromDb(map['type'] as String),
        period: GoalPeriodX.fromDb((map['period'] as String?) ?? 'daily'),
        targetValue: map['target_value'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
