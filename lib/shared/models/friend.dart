import 'package:equatable/equatable.dart';

class FriendRequest extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime createdAt;

  // Dados denormalizados do outro usuário (join com profiles)
  final String? otherName;
  final String? otherAvatarUrl;
  final String? otherUsername;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.otherName,
    this.otherAvatarUrl,
    this.otherUsername,
  });

  factory FriendRequest.fromMap(Map<String, dynamic> map, String currentUserId) {
    final isSender = map['sender_id'] == currentUserId;
    final other = isSender
        ? map['receiver_profile'] as Map<String, dynamic>?
        : map['sender_profile'] as Map<String, dynamic>?;

    return FriendRequest(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      otherName: other?['name'] as String?,
      otherAvatarUrl: other?['avatar_url'] as String?,
      otherUsername: other?['name'] as String?,
    );
  }

  bool get isSentBy => true; // resolvido no repositório

  @override
  List<Object?> get props => [id, senderId, receiverId, status];
}

class Friend extends Equatable {
  final String id;
  final String friendId;
  final String? name;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;

  const Friend({
    required this.id,
    required this.friendId,
    this.name,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
  });

  factory Friend.fromMap(Map<String, dynamic> map) {
    final profile = map['friend_profile'] as Map<String, dynamic>? ?? {};
    return Friend(
      id: map['id'] as String,
      friendId: map['friend_id'] as String,
      name: profile['name'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      bio: profile['bio'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, friendId];
}

class PublicProfile extends Equatable {
  final String id;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final String? favoriteGenre;

  const PublicProfile({
    required this.id,
    this.name,
    this.bio,
    this.avatarUrl,
    this.favoriteGenre,
  });

  factory PublicProfile.fromMap(Map<String, dynamic> map) => PublicProfile(
        id: map['id'] as String,
        name: map['name'] as String?,
        bio: map['bio'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        favoriteGenre: map['favorite_genre'] as String?,
      );

  @override
  List<Object?> get props => [id, name, bio];
}
