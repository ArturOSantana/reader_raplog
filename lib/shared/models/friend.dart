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

/// Campos de privacidade do perfil público.
class PublicProfilePrivacy extends Equatable {
  final bool currentBook;
  final bool calendar;
  final bool clubs;
  final bool wishlist;
  final bool library;
  final bool activity;
  final bool compatibility;

  const PublicProfilePrivacy({
    this.currentBook = true,
    this.calendar = true,
    this.clubs = true,
    this.wishlist = false,
    this.library = false,
    this.activity = true,
    this.compatibility = true,
  });

  factory PublicProfilePrivacy.fromMap(Map<String, dynamic> map) =>
      PublicProfilePrivacy(
        currentBook: map['privacy_current_book'] as bool? ?? true,
        calendar: map['privacy_calendar'] as bool? ?? true,
        clubs: map['privacy_clubs'] as bool? ?? true,
        wishlist: map['privacy_wishlist'] as bool? ?? false,
        library: map['privacy_library'] as bool? ?? false,
        activity: map['privacy_activity'] as bool? ?? true,
        compatibility: map['privacy_compatibility'] as bool? ?? true,
      );

  @override
  List<Object?> get props =>
      [currentBook, calendar, clubs, wishlist, library, activity, compatibility];
}

/// Estatísticas públicas de um amigo.
class FriendPublicStats extends Equatable {
  final int streak;
  final int booksCompleted;
  final int pagesRead;
  final int readingMinutes;
  final int achievements;
  final int bestStreak;
  final int bestSessionMinutes;
  final int avgSessionMinutes;
  final int avgPagesPerSession;
  final int booksThisYear;
  // Biblioteca
  final int libraryReading;
  final int libraryWishlist;
  final int libraryRead;
  final int libraryAbandoned;
  // Meta anual
  final int? yearlyGoal;
  final int yearlyProgress;

  const FriendPublicStats({
    this.streak = 0,
    this.booksCompleted = 0,
    this.pagesRead = 0,
    this.readingMinutes = 0,
    this.achievements = 0,
    this.bestStreak = 0,
    this.bestSessionMinutes = 0,
    this.avgSessionMinutes = 0,
    this.avgPagesPerSession = 0,
    this.booksThisYear = 0,
    this.libraryReading = 0,
    this.libraryWishlist = 0,
    this.libraryRead = 0,
    this.libraryAbandoned = 0,
    this.yearlyGoal,
    this.yearlyProgress = 0,
  });

  factory FriendPublicStats.fromMap(Map<String, dynamic> map) =>
      FriendPublicStats(
        streak: (map['streak'] as num?)?.toInt() ?? 0,
        booksCompleted: (map['books_completed'] as num?)?.toInt() ?? 0,
        pagesRead: (map['pages_read'] as num?)?.toInt() ?? 0,
        readingMinutes: (map['reading_minutes'] as num?)?.toInt() ?? 0,
        achievements: (map['achievements'] as num?)?.toInt() ?? 0,
        bestStreak: (map['best_streak'] as num?)?.toInt() ?? 0,
        bestSessionMinutes: (map['best_session_minutes'] as num?)?.toInt() ?? 0,
        avgSessionMinutes: (map['avg_session_minutes'] as num?)?.toInt() ?? 0,
        avgPagesPerSession: (map['avg_pages_per_session'] as num?)?.toInt() ?? 0,
        booksThisYear: (map['books_this_year'] as num?)?.toInt() ?? 0,
        libraryReading: (map['library_reading'] as num?)?.toInt() ?? 0,
        libraryWishlist: (map['library_wishlist'] as num?)?.toInt() ?? 0,
        libraryRead: (map['library_read'] as num?)?.toInt() ?? 0,
        libraryAbandoned: (map['library_abandoned'] as num?)?.toInt() ?? 0,
        yearlyGoal: (map['yearly_goal'] as num?)?.toInt(),
        yearlyProgress: (map['yearly_progress'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [streak, booksCompleted, pagesRead, readingMinutes];
}

/// Livro que o amigo está lendo atualmente (se público).
class FriendCurrentBook extends Equatable {
  final String title;
  final String? author;
  final String? coverUrl;
  final int currentPage;
  final int totalPages;
  final int daysReading;

  const FriendCurrentBook({
    required this.title,
    this.author,
    this.coverUrl,
    required this.currentPage,
    required this.totalPages,
    required this.daysReading,
  });

  double get progress =>
      totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;

  int get progressPercent => (progress * 100).round();

  factory FriendCurrentBook.fromMap(Map<String, dynamic> map) =>
      FriendCurrentBook(
        title: map['title'] as String? ?? '',
        author: map['author'] as String?,
        coverUrl: map['cover_url'] as String?,
        currentPage: (map['current_page'] as num?)?.toInt() ?? 0,
        totalPages: (map['total_pages'] as num?)?.toInt() ?? 0,
        daysReading: (map['days_reading'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [title, currentPage, totalPages];
}

/// Perfil público completo de um amigo.
class PublicProfile extends Equatable {
  final String id;
  final String? name;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? location;
  final DateTime? memberSince;
  final String? favoriteGenre;
  final String? favoriteAuthors;
  final String? favoriteBook;
  final String? preferredFormat;
  final PublicProfilePrivacy privacy;

  const PublicProfile({
    required this.id,
    this.name,
    this.username,
    this.bio,
    this.avatarUrl,
    this.location,
    this.memberSince,
    this.favoriteGenre,
    this.favoriteAuthors,
    this.favoriteBook,
    this.preferredFormat,
    this.privacy = const PublicProfilePrivacy(),
  });

  factory PublicProfile.fromMap(Map<String, dynamic> map) => PublicProfile(
        id: map['id'] as String,
        name: map['name'] as String?,
        username: map['username'] as String?,
        bio: map['bio'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        location: map['location'] as String?,
        memberSince: map['member_since'] != null
            ? DateTime.tryParse(map['member_since'] as String)
            : null,
        favoriteGenre: map['favorite_genre'] as String?,
        favoriteAuthors: map['favorite_authors'] as String?,
        favoriteBook: map['favorite_book'] as String?,
        preferredFormat: map['preferred_format'] as String?,
        privacy: PublicProfilePrivacy.fromMap(map),
      );

  @override
  List<Object?> get props => [id, name, bio];
}
