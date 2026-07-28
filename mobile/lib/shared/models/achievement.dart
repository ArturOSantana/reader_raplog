import 'package:equatable/equatable.dart';

class Achievement extends Equatable {
  final String id;
  final String key;
  final String name;
  final String description;
  final String? icon;
  final int xpReward;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    this.icon,
    required this.xpReward,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  factory Achievement.fromMap(Map<String, dynamic> map) => Achievement(
        id: map['id'] as String,
        key: map['key'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        icon: map['icon'] as String?,
        xpReward: map['xp_reward'] as int,
        unlockedAt: map['unlocked_at'] != null
            ? DateTime.parse(map['unlocked_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, key, unlockedAt];
}
