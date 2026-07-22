import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final int? yearlyGoal;
  final String? favoriteGenre;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.name,
    this.bio,
    this.avatarUrl,
    this.yearlyGoal,
    this.favoriteGenre,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        name: map['name'] as String?,
        bio: map['bio'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        yearlyGoal: map['yearly_goal'] as int?,
        favoriteGenre: map['favorite_genre'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'bio': bio,
        'avatar_url': avatarUrl,
        'yearly_goal': yearlyGoal,
        'favorite_genre': favoriteGenre,
      };

  UserProfile copyWith({
    String? name,
    String? bio,
    String? avatarUrl,
    int? yearlyGoal,
    String? favoriteGenre,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        yearlyGoal: yearlyGoal ?? this.yearlyGoal,
        favoriteGenre: favoriteGenre ?? this.favoriteGenre,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [id, name, bio, yearlyGoal, favoriteGenre];
}
