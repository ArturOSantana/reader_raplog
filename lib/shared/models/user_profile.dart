import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final int? yearlyGoal;
  final String? favoriteGenre;
  final String? favoriteAuthors;
  final String? favoriteBook;
  final bool onboardingCompleted;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.name,
    this.bio,
    this.avatarUrl,
    this.yearlyGoal,
    this.favoriteGenre,
    this.favoriteAuthors,
    this.favoriteBook,
    this.onboardingCompleted = false,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        name: map['name'] as String?,
        bio: map['bio'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        yearlyGoal: map['yearly_goal'] as int?,
        favoriteGenre: map['favorite_genre'] as String?,
        favoriteAuthors: map['favorite_authors'] as String?,
        favoriteBook: map['favorite_book'] as String?,
        onboardingCompleted: switch (map['onboarding_completed']) {
          bool b => b,
          int i => i != 0,
          _ => false,
        },
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'bio': bio,
        'avatar_url': avatarUrl,
        'yearly_goal': yearlyGoal,
        'favorite_genre': favoriteGenre,
        'favorite_authors': favoriteAuthors,
        'favorite_book': favoriteBook,
        'onboarding_completed': onboardingCompleted ? 1 : 0,
      };

  UserProfile copyWith({
    String? name,
    String? bio,
    String? avatarUrl,
    int? yearlyGoal,
    String? favoriteGenre,
    String? favoriteAuthors,
    String? favoriteBook,
    bool? onboardingCompleted,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        yearlyGoal: yearlyGoal ?? this.yearlyGoal,
        favoriteGenre: favoriteGenre ?? this.favoriteGenre,
        favoriteAuthors: favoriteAuthors ?? this.favoriteAuthors,
        favoriteBook: favoriteBook ?? this.favoriteBook,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [
        id,
        name,
        bio,
        yearlyGoal,
        favoriteGenre,
        favoriteAuthors,
        favoriteBook,
        onboardingCompleted,
      ];
}
