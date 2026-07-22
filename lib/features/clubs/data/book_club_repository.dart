import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/book_club.dart';
import '../../../shared/models/club_extras.dart';
import '../../../shared/models/social_feed.dart';

class BookClubRepository {
  final SupabaseClient _client;

  BookClubRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ── Listar clubes do usuário ─────────────────────────────────────────────

  Future<List<BookClub>> listMyClubs() async {
    final data = await _client
        .from('book_club_members')
        .select(
          'role, club:book_clubs(id, name, description, cover_url, '
          'current_book_id, current_book_title, current_book_author, '
          'current_book_status, reading_pace_pages_per_day, '
          'reading_target_end_date, reading_started_at, '
          'status, closed_at, visibility, invite_code, '
          'max_admins, admins_can_promote, created_at)',
        )
        .eq('user_id', _userId);

    final List<BookClub> clubs = [];
    for (final row in (data as List)) {
      final clubMap = row['club'] as Map<String, dynamic>?;
      if (clubMap == null) continue;

      final countData = await _client
          .from('book_club_members')
          .select('id')
          .eq('club_id', clubMap['id'] as String);

      clubs.add(BookClub.fromMap({
        ...clubMap,
        'member_count': (countData as List).length,
        'member_role': row['role'],
      }));
    }
    return clubs;
  }

  // ── Buscar clube por ID ──────────────────────────────────────────────────

  Future<BookClub?> fetchById(String clubId) async {
    final data = await _client
        .from('book_clubs')
        .select()
        .eq('id', clubId)
        .maybeSingle();
    if (data == null) return null;

    final countData = await _client
        .from('book_club_members')
        .select('id')
        .eq('club_id', clubId);

    final memberRow = await _client
        .from('book_club_members')
        .select('role')
        .eq('club_id', clubId)
        .eq('user_id', _userId)
        .maybeSingle();

    return BookClub.fromMap({
      ...data,
      'member_count': (countData as List).length,
      'member_role': memberRow?['role'],
    });
  }

  // ── Buscar clube por código de convite ───────────────────────────────────

  Future<BookClub?> fetchByInviteCode(String code) async {
    final data = await _client
        .from('book_clubs')
        .select()
        .eq('invite_code', code.toUpperCase())
        .neq('status', 'closed')
        .maybeSingle();
    if (data == null) return null;

    final countData = await _client
        .from('book_club_members')
        .select('id')
        .eq('club_id', data['id'] as String);

    return BookClub.fromMap({
      ...data,
      'member_count': (countData as List).length,
    });
  }

  // ── Criar clube ──────────────────────────────────────────────────────────

  Future<BookClub> createClub({
    required String name,
    String? description,
    String? coverUrl,
    ClubVisibility visibility = ClubVisibility.private,
  }) async {
    final clubData = await _client
        .from('book_clubs')
        .insert({
          'name': name,
          'description': description,
          'cover_url': coverUrl,
          'visibility': visibility.dbValue,
        })
        .select()
        .single();

    // Criador entra como owner
    await _client.from('book_club_members').insert({
      'club_id': clubData['id'],
      'user_id': _userId,
      'role': 'owner',
    });

    return BookClub.fromMap({
      ...clubData,
      'member_count': 1,
      'member_role': 'owner',
    });
  }

  // ── Editar clube ─────────────────────────────────────────────────────────

  Future<void> updateClub({
    required String clubId,
    String? name,
    String? description,
    String? coverUrl,
    ClubVisibility? visibility,
    bool? adminsCanPromote,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (coverUrl != null) updates['cover_url'] = coverUrl;
    if (visibility != null) updates['visibility'] = visibility.dbValue;
    if (adminsCanPromote != null) updates['admins_can_promote'] = adminsCanPromote;
    await _client.from('book_clubs').update(updates).eq('id', clubId);
  }

  // ── Status do clube ──────────────────────────────────────────────────────

  Future<void> setVacation(String clubId) async {
    await _client.from('book_clubs').update({
      'status': 'on_vacation',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clubId);
  }

  Future<void> reactivate(String clubId) async {
    await _client.from('book_clubs').update({
      'status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clubId);
  }

  Future<void> closeClub(String clubId) async {
    await _client.from('book_clubs').update({
      'status': 'closed',
      'closed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clubId);
  }

  /// Exclusão definitiva — só funciona após 30 dias de encerramento (RLS).
  Future<void> deleteClub(String clubId) async {
    await _client.from('book_clubs').delete().eq('id', clubId);
  }

  // ── Atualizar livro atual (com arquivamento opcional) ────────────────────

  Future<void> setCurrentBook({
    required String clubId,
    required String bookTitle,
    String? bookAuthor,
    String? bookId,
    bool archivePrevious = false,
  }) async {
    // Primeiro arquiva o livro anterior se solicitado
    if (archivePrevious) {
      final club = await fetchById(clubId);
      if (club?.currentBookTitle != null) {
        await _client.from('club_book_history').insert({
          'club_id': clubId,
          'book_id': club!.currentBookId,
          'book_title': club.currentBookTitle,
          'book_author': club.currentBookAuthor,
          'ended_at': DateTime.now().toIso8601String(),
        });
      }
    }

    await _client.from('book_clubs').update({
      'current_book_title': bookTitle,
      'current_book_author': bookAuthor,
      'current_book_id': bookId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clubId);

    // Cria entrada no histórico para o novo livro
    await _client.from('club_book_history').insert({
      'club_id': clubId,
      'book_id': bookId,
      'book_title': bookTitle,
      'book_author': bookAuthor,
    });
  }

  // ── Histórico de livros ──────────────────────────────────────────────────

  Future<List<ClubBookHistory>> listBookHistory(String clubId) async {
    final data = await _client
        .from('club_book_history')
        .select()
        .eq('club_id', clubId)
        .order('started_at', ascending: false);

    return (data as List)
        .map((m) => ClubBookHistory.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ── Membros ──────────────────────────────────────────────────────────────

  Future<List<ClubMember>> listMembers(String clubId) async {
    final data = await _client
        .from('book_club_members')
        .select('id, club_id, user_id, role, joined_at, '
            'profile:profiles!book_club_members_user_id_profiles_fkey(name, avatar_url)')
        .eq('club_id', clubId)
        .order('joined_at', ascending: true);

    return (data as List)
        .map((m) => ClubMember.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> joinClub(String clubId) async {
    await _client.from('book_club_members').insert({
      'club_id': clubId,
      'user_id': _userId,
      'role': 'member',
    });
  }

  /// Saída de membro ou admin (não-dono).
  Future<void> leaveClub(String clubId) async {
    await _client
        .from('book_club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', _userId);
  }

  /// Saída do dono com transferência automática.
  /// Retorna 'transferred' ou 'closed'.
  Future<String> leaveClubAsOwner(String clubId) async {
    final result = await _client
        .rpc('leave_club_as_owner', params: {'p_club_id': clubId});
    return result as String;
  }

  Future<void> removeMember(String clubId, String userId) async {
    await _client
        .from('book_club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);
  }

  // ── Promoção / rebaixamento ──────────────────────────────────────────────

  /// Promove um membro para admin.
  Future<void> promoteMember(String clubId, String userId) async {
    await _client
        .from('book_club_members')
        .update({'role': 'admin'})
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .eq('role', 'member');
  }

  /// Rebaixa um admin para membro.
  Future<void> demoteMember(String clubId, String userId) async {
    await _client
        .from('book_club_members')
        .update({'role': 'member'})
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .eq('role', 'admin');
  }

  // ── Encontros ────────────────────────────────────────────────────────────

  Future<List<BookClubMeeting>> listMeetings(String clubId) async {
    final data = await _client
        .from('book_club_meetings')
        .select(
          'id, club_id, title, scheduled_at, location, online_link, '
          'notes, going_count, maybe_count, '
          'club:book_clubs(name), '
          'meeting_rsvps(rsvp)',
        )
        .eq('club_id', clubId)
        .eq('meeting_rsvps.user_id', _userId)
        .order('scheduled_at', ascending: true);

    return (data as List)
        .map((m) => BookClubMeeting.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Retorna próximos encontros de TODOS os clubes do usuário (para o calendário).
  Future<List<BookClubMeeting>> listUpcomingMeetings() async {
    final now = DateTime.now().toIso8601String();

    final data = await _client
        .from('book_club_meetings')
        .select(
          'id, club_id, title, scheduled_at, location, online_link, '
          'notes, going_count, maybe_count, '
          'club:book_clubs(name), '
          'meeting_rsvps(rsvp)',
        )
        .gte('scheduled_at', now)
        .eq('meeting_rsvps.user_id', _userId)
        .order('scheduled_at', ascending: true)
        .limit(50);

    return (data as List)
        .map((m) => BookClubMeeting.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<BookClubMeeting> createMeeting({
    required String clubId,
    required String title,
    required DateTime scheduledAt,
    String? location,
    String? onlineLink,
    String? notes,
  }) async {
    final data = await _client
        .from('book_club_meetings')
        .insert({
          'club_id': clubId,
          'title': title,
          'scheduled_at': scheduledAt.toIso8601String(),
          'location': location,
          'online_link': onlineLink,
          'notes': notes,
        })
        .select(
          'id, club_id, title, scheduled_at, location, online_link, '
          'notes, going_count, maybe_count, '
          'club:book_clubs(name)',
        )
        .single();

    return BookClubMeeting.fromMap({...data, 'meeting_rsvps': []});
  }

  Future<void> deleteMeeting(String meetingId) async {
    await _client
        .from('book_club_meetings')
        .delete()
        .eq('id', meetingId);
  }

  // ── RSVP ────────────────────────────────────────────────────────────────

  Future<void> setRsvp({
    required String meetingId,
    required MeetingRsvp rsvp,
  }) async {
    await _client.from('meeting_rsvps').upsert({
      'meeting_id': meetingId,
      'user_id': _userId,
      'rsvp': rsvp.dbValue,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await _client.rpc(
      'refresh_meeting_rsvp_counts',
      params: {'p_meeting_id': meetingId},
    );
  }

  // ── Enquetes de livro ─────────────────────────────────────────────────────

  Future<List<ClubBookPoll>> listPolls(String clubId) async {
    final pollsData = await _client
        .from('club_book_polls')
        .select()
        .eq('club_id', clubId)
        .order('created_at', ascending: false);

    final polls = <ClubBookPoll>[];
    for (final p in pollsData as List) {
      final pollId = p['id'] as String;

      final optionsData = await _client
          .from('club_book_poll_options')
          .select()
          .eq('poll_id', pollId)
          .order('vote_count', ascending: false);

      final myVoteData = await _client
          .from('club_book_poll_votes')
          .select('option_id')
          .eq('poll_id', pollId)
          .eq('user_id', _userId)
          .maybeSingle();

      final options = (optionsData as List)
          .map((o) => ClubBookPollOption.fromMap(o as Map<String, dynamic>))
          .toList();

      polls.add(ClubBookPoll.fromMap(
        p as Map<String, dynamic>,
        options: options,
        myVoteOptionId: myVoteData?['option_id'] as String?,
      ));
    }
    return polls;
  }

  Future<ClubBookPoll> createPoll({
    required String clubId,
    required String title,
    String? description,
    DateTime? closesAt,
    required List<({String bookTitle, String? bookAuthor})> options,
  }) async {
    final pollData = await _client
        .from('club_book_polls')
        .insert({
          'club_id': clubId,
          'title': title,
          'description': description,
          'closes_at': closesAt?.toIso8601String(),
          'created_by': _userId,
        })
        .select()
        .single();

    final pollId = pollData['id'] as String;

    for (final opt in options) {
      await _client.from('club_book_poll_options').insert({
        'poll_id': pollId,
        'book_title': opt.bookTitle,
        'book_author': opt.bookAuthor,
      });
    }

    final optionsData = await _client
        .from('club_book_poll_options')
        .select()
        .eq('poll_id', pollId)
        .order('created_at', ascending: true);

    final parsedOptions = (optionsData as List)
        .map((o) => ClubBookPollOption.fromMap(o as Map<String, dynamic>))
        .toList();

    return ClubBookPoll.fromMap(
      pollData,
      options: parsedOptions,
    );
  }

  /// Vota em uma opção (toggle: votar na mesma opção remove o voto).
  Future<void> voteOnPoll({
    required String pollId,
    required String optionId,
  }) async {
    await _client.rpc('vote_on_book_poll', params: {
      'p_poll_id': pollId,
      'p_option_id': optionId,
    });
  }

  Future<void> closePoll(String pollId) async {
    await _client
        .from('club_book_polls')
        .update({'status': 'closed', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', pollId);
  }

  Future<void> deletePoll(String pollId) async {
    await _client.from('club_book_polls').delete().eq('id', pollId);
  }

  // ── Feed do clube ─────────────────────────────────────────────────────────

  Future<List<FeedItem>> fetchClubFeed(String clubId,
      {int limit = 40}) async {
    final data = await _client
        .from('social_feed')
        .select(
          'id, user_id, event_type, club_id, book_title, book_author, rating, review, '
          'reading_time_minutes, pages_read, current_page, session_minutes, '
          'streak_days, achievement_name, goal_description, '
          'likes_count, comments_count, reactions_summary, created_at, '
          'profile:profiles!social_feed_user_id_fkey(name, avatar_url)',
        )
        .eq('club_id', clubId)
        .order('created_at', ascending: false)
        .limit(limit);

    final rows = List<Map<String, dynamic>>.from(data as List);
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as String).toList();
    final likesData = await _client
        .from('feed_likes')
        .select('feed_id')
        .eq('user_id', _userId)
        .filter('feed_id', 'in', '(${ids.map((id) => '"$id"').join(',')})');
    final likedIds =
        Set<String>.from((likesData as List).map((e) => e['feed_id']));

    return rows
        .map((row) =>
            FeedItem.fromMap({...row, 'liked_by_me': likedIds.contains(row['id'])}))
        .toList();
  }

  // ── Pessoas lendo agora ───────────────────────────────────────────────────

  Future<List<ClubReadingNowEntry>> fetchReadingNow(String clubId) async {
    final data = await _client.rpc(
      'club_reading_now',
      params: {'p_club_id': clubId},
    );
    return List<Map<String, dynamic>>.from(data as List)
        .map(ClubReadingNowEntry.fromMap)
        .toList();
  }

  // ── Progresso coletivo ────────────────────────────────────────────────────

  Future<ClubReadingProgress?> fetchReadingProgress(String clubId) async {
    final data = await _client.rpc(
      'club_reading_progress',
      params: {'p_club_id': clubId},
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    if (rows.isEmpty) return null;
    return ClubReadingProgress.fromMap(rows.first);
  }

  // ── Ofensiva coletiva ─────────────────────────────────────────────────────

  Future<int> fetchClubStreak(String clubId) async {
    final result = await _client.rpc(
      'calculate_club_streak',
      params: {'p_club_id': clubId},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  // ── Estatísticas do clube ─────────────────────────────────────────────────

  Future<ClubStats?> fetchClubStats(String clubId) async {
    final data = await _client
        .from('club_stats')
        .select()
        .eq('club_id', clubId)
        .maybeSingle();
    if (data == null) return null;
    return ClubStats.fromMap(
      clubId,
      Map<String, dynamic>.from(data as Map),
    );
  }

  // ── Ranking do clube ──────────────────────────────────────────────────────

  /// [period]: 'current_book' | 'week' | 'month' | 'all'
  /// [criteria]: 'pages' | 'minutes' | 'sessions' | 'xp'
  Future<List<ClubRankingEntry>> fetchRanking(
    String clubId, {
    String period = 'all',
    String criteria = 'xp',
  }) async {
    final data = await _client.rpc(
      'club_ranking',
      params: {
        'p_club_id': clubId,
        'p_period': period,
        'p_criteria': criteria,
      },
    );
    return List<Map<String, dynamic>>.from(data as List)
        .map(ClubRankingEntry.fromMap)
        .toList();
  }

  // ── Hall da Fama ──────────────────────────────────────────────────────────

  Future<List<ClubHallOfFameEntry>> fetchHallOfFame(String clubId) async {
    final data = await _client
        .from('club_hall_of_fame')
        .select()
        .eq('club_id', clubId)
        .order('season_ended_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List)
        .map(ClubHallOfFameEntry.fromMap)
        .toList();
  }

  Future<String> closeReadingCycle(String clubId) async {
    final result = await _client.rpc(
      'close_reading_cycle',
      params: {'p_club_id': clubId},
    );
    return result as String;
  }
}
