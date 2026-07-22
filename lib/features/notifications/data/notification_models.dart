import 'package:equatable/equatable.dart';

// ── Categorias ────────────────────────────────────────────────────────────────

enum NotificationCategory {
  reading,
  streak,
  goals,
  clubs,
  friends,
  calendar,
  achievements,
  system,
}

extension NotificationCategoryX on NotificationCategory {
  String get label {
    switch (this) {
      case NotificationCategory.reading:      return 'Leitura';
      case NotificationCategory.streak:       return 'Ofensiva';
      case NotificationCategory.goals:        return 'Metas';
      case NotificationCategory.clubs:        return 'Clubes';
      case NotificationCategory.friends:      return 'Amigos';
      case NotificationCategory.calendar:     return 'Calendário';
      case NotificationCategory.achievements: return 'Conquistas';
      case NotificationCategory.system:       return 'Sistema';
    }
  }

  String get emoji {
    switch (this) {
      case NotificationCategory.reading:      return '📖';
      case NotificationCategory.streak:       return '🔥';
      case NotificationCategory.goals:        return '🎯';
      case NotificationCategory.clubs:        return '📚';
      case NotificationCategory.friends:      return '👥';
      case NotificationCategory.calendar:     return '📅';
      case NotificationCategory.achievements: return '🏆';
      case NotificationCategory.system:       return '📢';
    }
  }

  String get key => name;
}

// ── Preferências de notificação ───────────────────────────────────────────────

class NotificationPrefs extends Equatable {
  final Map<NotificationCategory, bool> categories;
  final List<ReadingSchedule> schedules;

  const NotificationPrefs({
    required this.categories,
    required this.schedules,
  });

  factory NotificationPrefs.defaults() => NotificationPrefs(
        categories: {for (final c in NotificationCategory.values) c: true},
        schedules: const [],
      );

  bool isEnabled(NotificationCategory cat) => categories[cat] ?? true;

  NotificationPrefs copyWithCategory(NotificationCategory cat, bool value) {
    final updated = Map<NotificationCategory, bool>.from(categories);
    updated[cat] = value;
    return NotificationPrefs(categories: updated, schedules: schedules);
  }

  NotificationPrefs copyWithSchedules(List<ReadingSchedule> s) =>
      NotificationPrefs(categories: categories, schedules: s);

  @override
  List<Object?> get props => [categories, schedules];
}

// ── Horários de leitura ───────────────────────────────────────────────────────

class ReadingSchedule extends Equatable {
  final String id;
  final int hour;
  final int minute;
  final Set<int> weekdays; // 1=segunda … 7=domingo (ISO 8601)

  const ReadingSchedule({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekdays,
  });

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays.toList()..sort(),
      };

  factory ReadingSchedule.fromJson(Map<String, dynamic> j) => ReadingSchedule(
        id: j['id'] as String,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
        weekdays: Set<int>.from(j['weekdays'] as List),
      );

  @override
  List<Object?> get props => [id, hour, minute, weekdays];
}

// ── Item da central de notificações ──────────────────────────────────────────

class NotificationItem extends Equatable {
  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> m) => NotificationItem(
        id: m['id'] as String,
        category: NotificationCategory.values.firstWhere(
          (c) => c.name == (m['category'] as String),
          orElse: () => NotificationCategory.system,
        ),
        title: m['title'] as String,
        body: m['body'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        isRead: m['is_read'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category.name,
        'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        category: category,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  @override
  List<Object?> get props => [id, isRead];
}
