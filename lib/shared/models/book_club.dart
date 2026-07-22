import 'package:equatable/equatable.dart';

// ── Clube do livro ────────────────────────────────────────────────────────────

class BookClub extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String adminId;
  final String? currentBookTitle;
  final String? currentBookAuthor;
  final String? currentBookId;
  final int memberCount;
  final DateTime createdAt;

  // Dados de membro (preenchido ao listar clubes do usuário)
  final String? memberRole; // 'admin' | 'moderator' | 'member'

  const BookClub({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.adminId,
    this.currentBookTitle,
    this.currentBookAuthor,
    this.currentBookId,
    required this.memberCount,
    required this.createdAt,
    this.memberRole,
  });

  bool get isAdmin => memberRole == 'admin';
  bool get isModerator => memberRole == 'admin' || memberRole == 'moderator';

  factory BookClub.fromMap(Map<String, dynamic> map) => BookClub(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        coverUrl: map['cover_url'] as String?,
        adminId: map['admin_id'] as String,
        currentBookTitle: map['current_book_title'] as String?,
        currentBookAuthor: map['current_book_author'] as String?,
        currentBookId: map['current_book_id'] as String?,
        memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        memberRole: map['member_role'] as String?,
      );

  @override
  List<Object?> get props => [id, name, currentBookId, memberCount];
}

// ── Membro do clube ───────────────────────────────────────────────────────────

class ClubMember extends Equatable {
  final String id;
  final String clubId;
  final String userId;
  final String role; // 'admin' | 'moderator' | 'member'
  final String? name;
  final String? avatarUrl;
  final DateTime joinedAt;

  const ClubMember({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.role,
    this.name,
    this.avatarUrl,
    required this.joinedAt,
  });

  factory ClubMember.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>? ?? {};
    return ClubMember(
      id: map['id'] as String,
      clubId: map['club_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'member',
      name: profile['name'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, userId, role];
}

// ── Encontro ──────────────────────────────────────────────────────────────────

enum MeetingRsvp { going, maybe, notGoing, noResponse }

extension MeetingRsvpX on MeetingRsvp {
  String get dbValue {
    switch (this) {
      case MeetingRsvp.going:
        return 'going';
      case MeetingRsvp.maybe:
        return 'maybe';
      case MeetingRsvp.notGoing:
        return 'not_going';
      case MeetingRsvp.noResponse:
        return 'no_response';
    }
  }

  String get label {
    switch (this) {
      case MeetingRsvp.going:
        return 'Vou';
      case MeetingRsvp.maybe:
        return 'Talvez';
      case MeetingRsvp.notGoing:
        return 'Não vou';
      case MeetingRsvp.noResponse:
        return 'Sem resposta';
    }
  }

  static MeetingRsvp fromDb(String? value) {
    switch (value) {
      case 'going':
        return MeetingRsvp.going;
      case 'maybe':
        return MeetingRsvp.maybe;
      case 'not_going':
        return MeetingRsvp.notGoing;
      default:
        return MeetingRsvp.noResponse;
    }
  }
}

class BookClubMeeting extends Equatable {
  final String id;
  final String clubId;
  final String clubName;
  final String title;
  final DateTime scheduledAt;
  final String? location;
  final String? onlineLink;
  final String? notes;
  final int goingCount;
  final int maybeCount;
  final MeetingRsvp myRsvp;

  const BookClubMeeting({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.title,
    required this.scheduledAt,
    this.location,
    this.onlineLink,
    this.notes,
    required this.goingCount,
    required this.maybeCount,
    required this.myRsvp,
  });

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());

  factory BookClubMeeting.fromMap(Map<String, dynamic> map) {
    final club = map['club'] as Map<String, dynamic>? ?? {};
    final rsvps = map['meeting_rsvps'] as List? ?? [];
    final myRsvpMap = rsvps.isNotEmpty ? rsvps.first : null;
    final going = (map['going_count'] as num?)?.toInt() ?? 0;
    final maybe = (map['maybe_count'] as num?)?.toInt() ?? 0;

    return BookClubMeeting(
      id: map['id'] as String,
      clubId: map['club_id'] as String,
      clubName: club['name'] as String? ?? '',
      title: map['title'] as String,
      scheduledAt: DateTime.parse(map['scheduled_at'] as String),
      location: map['location'] as String?,
      onlineLink: map['online_link'] as String?,
      notes: map['notes'] as String?,
      goingCount: going,
      maybeCount: maybe,
      myRsvp: MeetingRsvpX.fromDb(myRsvpMap?['rsvp'] as String?),
    );
  }

  @override
  List<Object?> get props => [id, clubId, scheduledAt, myRsvp];
}
