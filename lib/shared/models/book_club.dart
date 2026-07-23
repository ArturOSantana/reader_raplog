import 'package:equatable/equatable.dart';

// ── Status do clube ───────────────────────────────────────────────────────────

enum ClubStatus { active, onVacation, closed, archived }

extension ClubStatusX on ClubStatus {
  String get dbValue {
    switch (this) {
      case ClubStatus.active:     return 'active';
      case ClubStatus.onVacation: return 'on_vacation';
      case ClubStatus.closed:     return 'closed';
      case ClubStatus.archived:   return 'archived';
    }
  }

  String get label {
    switch (this) {
      case ClubStatus.active:     return 'Ativo';
      case ClubStatus.onVacation: return 'Em férias';
      case ClubStatus.closed:     return 'Encerrado';
      case ClubStatus.archived:   return 'Arquivado';
    }
  }

  static ClubStatus fromDb(String? value) {
    switch (value) {
      case 'on_vacation': return ClubStatus.onVacation;
      case 'closed':      return ClubStatus.closed;
      case 'archived':    return ClubStatus.archived;
      default:            return ClubStatus.active;
    }
  }
}

// ── Visibilidade ──────────────────────────────────────────────────────────────

// ── Categoria ─────────────────────────────────────────────────────────────────

enum ClubCategory {
  general,
  fiction,
  nonfiction,
  fantasy,
  scifi,
  romance,
  mystery,
  biography,
  history,
  selfhelp,
  children,
  classics,
}

extension ClubCategoryX on ClubCategory {
  String get dbValue => name;

  String get label {
    switch (this) {
      case ClubCategory.general:    return 'Geral';
      case ClubCategory.fiction:    return 'Ficção';
      case ClubCategory.nonfiction: return 'Não-ficção';
      case ClubCategory.fantasy:    return 'Fantasia';
      case ClubCategory.scifi:      return 'Ficção Científica';
      case ClubCategory.romance:    return 'Romance';
      case ClubCategory.mystery:    return 'Mistério';
      case ClubCategory.biography:  return 'Biografias';
      case ClubCategory.history:    return 'História';
      case ClubCategory.selfhelp:   return 'Autoajuda';
      case ClubCategory.children:   return 'Infantojuvenil';
      case ClubCategory.classics:   return 'Clássicos';
    }
  }

  static ClubCategory fromDb(String? value) {
    return ClubCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ClubCategory.general,
    );
  }
}

// ── Visibilidade ──────────────────────────────────────────────────────────────

enum ClubVisibility { public, private }

extension ClubVisibilityX on ClubVisibility {
  String get dbValue => this == ClubVisibility.public ? 'public' : 'private';

  String get label => this == ClubVisibility.public ? 'Público' : 'Privado';

  static ClubVisibility fromDb(String? value) =>
      value == 'public' ? ClubVisibility.public : ClubVisibility.private;
}

// ── Clube do livro ────────────────────────────────────────────────────────────

class BookClub extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? currentBookTitle;
  final String? currentBookAuthor;
  final String? currentBookId;
  // Ciclo de leitura
  final String currentBookStatus; // none|voting|chosen|reading|finished
  final int? readingPacePerDay;
  final DateTime? readingTargetEndDate;
  final DateTime? readingStartedAt;
  final int memberCount;
  final DateTime createdAt;
  final ClubStatus status;
  final DateTime? closedAt;
  final ClubVisibility visibility;
  final ClubCategory category;
  final String? inviteCode;
  final int maxAdmins;
  final bool adminsCanPromote;

  // Dados de membro (preenchido ao listar clubes do usuário)
  final String? memberRole; // 'owner' | 'admin' | 'member'

  const BookClub({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.currentBookTitle,
    this.currentBookAuthor,
    this.currentBookId,
    this.currentBookStatus = 'none',
    this.readingPacePerDay,
    this.readingTargetEndDate,
    this.readingStartedAt,
    required this.memberCount,
    required this.createdAt,
    this.status = ClubStatus.active,
    this.closedAt,
    this.visibility = ClubVisibility.private,
    this.category = ClubCategory.general,
    this.inviteCode,
    this.maxAdmins = 5,
    this.adminsCanPromote = false,
    this.memberRole,
  });

  // ── Helpers de papel ───────────────────────────────────────────────────────

  bool get isOwner => memberRole == 'owner';
  bool get isAdmin => memberRole == 'admin';

  /// Pode gerenciar o clube (dono ou admin).
  bool get canManage => memberRole == 'owner' || memberRole == 'admin';

  /// Compatível com código legado que usava isModerator.
  bool get isModerator => canManage;

  // ── Helpers de status ──────────────────────────────────────────────────────

  bool get isActive => status == ClubStatus.active;
  bool get isOnVacation => status == ClubStatus.onVacation;
  bool get isClosed => status == ClubStatus.closed;

  /// Verifica se já passou o período de carência de 30 dias após encerramento.
  bool get canBeDeleted =>
      isClosed &&
      closedAt != null &&
      DateTime.now().difference(closedAt!).inDays >= 30;

  // ── Factory ────────────────────────────────────────────────────────────────

  factory BookClub.fromMap(Map<String, dynamic> map) => BookClub(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        coverUrl: map['cover_url'] as String?,
        currentBookTitle: map['current_book_title'] as String?,
        currentBookAuthor: map['current_book_author'] as String?,
        currentBookId: map['current_book_id'] as String?,
        currentBookStatus: map['current_book_status'] as String? ?? 'none',
        readingPacePerDay: (map['reading_pace_pages_per_day'] as num?)?.toInt(),
        readingTargetEndDate: map['reading_target_end_date'] != null
            ? DateTime.parse(map['reading_target_end_date'] as String)
            : null,
        readingStartedAt: map['reading_started_at'] != null
            ? DateTime.parse(map['reading_started_at'] as String)
            : null,
        memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        status: ClubStatusX.fromDb(map['status'] as String?),
        closedAt: map['closed_at'] != null
            ? DateTime.parse(map['closed_at'] as String)
            : null,
        visibility:
            ClubVisibilityX.fromDb(map['visibility'] as String?),
        category:
            ClubCategoryX.fromDb(map['category'] as String?),
        inviteCode: map['invite_code'] as String?,
        maxAdmins: (map['max_admins'] as num?)?.toInt() ?? 5,
        adminsCanPromote: map['admins_can_promote'] as bool? ?? false,
        memberRole: map['member_role'] as String?,
      );

  @override
  List<Object?> get props => [id, name, currentBookId, memberCount, status];
}

// ── Membro do clube ───────────────────────────────────────────────────────────

class ClubMember extends Equatable {
  final String id;
  final String clubId;
  final String userId;
  final String role; // 'owner' | 'admin' | 'member'
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

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get canManage => role == 'owner' || role == 'admin';

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Dono';
      case 'admin':
        return 'Admin';
      default:
        return 'Membro';
    }
  }

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

// ── Histórico de livros do clube ──────────────────────────────────────────────

class ClubBookHistory extends Equatable {
  final String id;
  final String clubId;
  final String? bookId;
  final String bookTitle;
  final String? bookAuthor;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int meetingCount;

  const ClubBookHistory({
    required this.id,
    required this.clubId,
    this.bookId,
    required this.bookTitle,
    this.bookAuthor,
    required this.startedAt,
    this.endedAt,
    required this.meetingCount,
  });

  bool get isFinished => endedAt != null;

  factory ClubBookHistory.fromMap(Map<String, dynamic> map) => ClubBookHistory(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        bookId: map['book_id'] as String?,
        bookTitle: map['book_title'] as String,
        bookAuthor: map['book_author'] as String?,
        startedAt: DateTime.parse(map['started_at'] as String),
        endedAt: map['ended_at'] != null
            ? DateTime.parse(map['ended_at'] as String)
            : null,
        meetingCount: (map['meeting_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, clubId, bookTitle, startedAt];
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

// ── Enquete de livro ──────────────────────────────────────────────────────────

enum ClubPollStatus { open, closed }

extension ClubPollStatusX on ClubPollStatus {
  String get dbValue => this == ClubPollStatus.open ? 'open' : 'closed';
  String get label => this == ClubPollStatus.open ? 'Aberta' : 'Encerrada';
  static ClubPollStatus fromDb(String? v) =>
      v == 'closed' ? ClubPollStatus.closed : ClubPollStatus.open;
}

class ClubBookPollOption extends Equatable {
  final String id;
  final String pollId;
  final String bookTitle;
  final String? bookAuthor;
  final String? bookId;
  final int voteCount;

  const ClubBookPollOption({
    required this.id,
    required this.pollId,
    required this.bookTitle,
    this.bookAuthor,
    this.bookId,
    required this.voteCount,
  });

  factory ClubBookPollOption.fromMap(Map<String, dynamic> m) =>
      ClubBookPollOption(
        id: m['id'] as String,
        pollId: m['poll_id'] as String,
        bookTitle: m['book_title'] as String,
        bookAuthor: m['book_author'] as String?,
        bookId: m['book_id'] as String?,
        voteCount: (m['vote_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, pollId, voteCount];
}

class ClubBookPoll extends Equatable {
  final String id;
  final String clubId;
  final String title;
  final String? description;
  final ClubPollStatus status;
  final DateTime? closesAt;
  final String createdBy;
  final DateTime createdAt;
  final List<ClubBookPollOption> options;

  /// ID da opção votada pelo usuário atual (null = não votou).
  final String? myVoteOptionId;

  const ClubBookPoll({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.status,
    this.closesAt,
    required this.createdBy,
    required this.createdAt,
    required this.options,
    this.myVoteOptionId,
  });

  bool get isOpen => status == ClubPollStatus.open;

  int get totalVotes => options.fold(0, (s, o) => s + o.voteCount);

  ClubBookPollOption? get leadingOption => options.isEmpty
      ? null
      : options.reduce((a, b) => a.voteCount >= b.voteCount ? a : b);

  factory ClubBookPoll.fromMap(
    Map<String, dynamic> m, {
    List<ClubBookPollOption> options = const [],
    String? myVoteOptionId,
  }) =>
      ClubBookPoll(
        id: m['id'] as String,
        clubId: m['club_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        status: ClubPollStatusX.fromDb(m['status'] as String?),
        closesAt: m['closes_at'] != null
            ? DateTime.parse(m['closes_at'] as String)
            : null,
        createdBy: m['created_by'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        options: options,
        myVoteOptionId: myVoteOptionId,
      );

  @override
  List<Object?> get props => [id, clubId, status, totalVotes];
}
