import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/book_club.dart';
import '../../../shared/models/club_bets_and_polls.dart';
import '../../../shared/models/club_extras.dart';
import '../../../shared/models/club_presence_stats.dart';
import '../../../shared/models/club_reviews.dart';
import '../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../shared/models/club_seals.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/social_feed.dart';

class BookClubRepository {
  final SupabaseClient _client;

  BookClubRepository(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  // ── Listar clubes do usuário ─────────────────────────────────────────────

  Future<List<BookClub>> listMyClubs() async {
    final data = await _client
        .from('book_club_members')
        .select(
          'role, club:book_clubs(id, name, description, cover_url, '
            'current_book_id, current_book_title, current_book_author, current_book_cover_url, '
            'current_book_status, reading_pace_pages_per_day, '
            'reading_target_end_date, reading_started_at, '
            'status, closed_at, visibility, category, invite_code, '
            'max_admins, admins_can_promote, created_at)',
        )
        .eq('user_id', _userId);

    final rows = (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final clubIds = rows
        .map((row) => (row['club'] as Map<String, dynamic>?)?['id'] as String?)
        .whereType<String>()
        .toList();

    Map<String, int> memberCounts = {};
    if (clubIds.isNotEmpty) {
      final countRows = await _client
          .from('book_club_members')
          .select('club_id')
          .inFilter('club_id', clubIds);
      for (final row in (countRows as List)) {
        final clubId = row['club_id'] as String?;
        if (clubId == null) continue;
        memberCounts[clubId] = (memberCounts[clubId] ?? 0) + 1;
      }
    }

    return rows.map((row) {
      final clubMap = row['club'] as Map<String, dynamic>?;
      if (clubMap == null) {
        throw StateError('Clube inválido retornado para o usuário.');
      }

      final clubId = clubMap['id'] as String;
      return BookClub.fromMap({
        ...clubMap,
        'member_count': memberCounts[clubId] ?? 0,
        'member_role': row['role'],
      });
    }).toList();
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
          'admin_id': _userId,
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

  /// Faz upload da capa do clube para o bucket `club-covers` e retorna a URL pública.
  Future<String> uploadClubCover(String clubId, File imageFile) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final path = '$clubId/cover.$ext';
    await _client.storage
        .from('club-covers')
        .upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
    return _client.storage.from('club-covers').getPublicUrl(path);
  }

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

  Future<void> archiveClub(String clubId) async {
    await _client.from('book_clubs').update({
      'status': 'archived',
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
    String? bookCoverUrl,
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

    final now = DateTime.now().toIso8601String();
    await _client.from('book_clubs').update({
      'current_book_title': bookTitle,
      'current_book_author': bookAuthor,
      'current_book_id': bookId,
      'current_book_cover_url': bookCoverUrl,
      'current_book_status': 'reading',
      'reading_started_at': now,
      'updated_at': now,
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

  // ── Solicitações de entrada (clube privado) ──────────────────────────────

  /// Envia solicitação para entrar num clube privado.
  Future<void> requestToJoin(String clubId, {String? message}) async {
    await _client.from('club_join_requests').insert({
      'club_id': clubId,
      'user_id': _userId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
  }

  /// Lista solicitações pendentes do clube (visível para managers).
  Future<List<Map<String, dynamic>>> listJoinRequests(String clubId) async {
    final data = await _client
        .from('club_join_requests')
        .select(
          'id, club_id, user_id, status, message, created_at, '
          'profile:profiles!club_join_requests_user_id_fkey(name, avatar_url)',
        )
        .eq('club_id', clubId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Aprova uma solicitação de entrada (manager).
  Future<void> approveJoinRequest(String requestId) async {
    await _client.rpc('approve_join_request', params: {'p_request_id': requestId});
  }

  /// Rejeita uma solicitação de entrada (manager).
  Future<void> rejectJoinRequest(String requestId) async {
    await _client.rpc('reject_join_request', params: {'p_request_id': requestId});
  }

  /// Cancela a própria solicitação pendente.
  Future<void> cancelJoinRequest(String requestId) async {
    await _client
        .from('club_join_requests')
        .delete()
        .eq('id', requestId)
        .eq('user_id', _userId);
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
    // Os contadores going_count/maybe_count são atualizados automaticamente
    // pelo trigger trg_rsvp_counts após o upsert.
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

  // ── Cronograma de Leitura ────────────────────────────────────────────────

  Future<List<ClubReadingScheduleEntry>> listReadingSchedule(String clubId) async {
    final data = await _client
        .from('club_reading_schedule')
        .select()
        .eq('club_id', clubId)
        .order('week_number');
    return (data as List)
        .map((e) => ClubReadingScheduleEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClubReadingScheduleEntry> addScheduleEntry(
      ClubReadingScheduleEntry entry) async {
    final data = await _client
        .from('club_reading_schedule')
        .insert(entry.toInsertMap())
        .select()
        .single();
    return ClubReadingScheduleEntry.fromMap(data);
  }

  Future<void> deleteScheduleEntry(String entryId) async {
    await _client.from('club_reading_schedule').delete().eq('id', entryId);
  }

  // ── Marcos de Progresso ──────────────────────────────────────────────────

  Future<List<ClubMilestone>> listMilestones(String clubId) async {
    final data = await _client
        .from('club_milestones')
        .select()
        .eq('club_id', clubId)
        .order('milestone_pct');
    return (data as List)
        .map((e) => ClubMilestone.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createMilestonesForCycle(String clubId) async {
    await _client.rpc(
      'create_milestones_for_cycle',
      params: {'p_club_id': clubId},
    );
  }

  Future<List<ClubMilestoneTopic>> listMilestoneTopics(
      String milestoneId) async {
    final data = await _client
        .from('club_milestone_topics')
        .select('*, profile:profiles(name, avatar_url)')
        .eq('milestone_id', milestoneId)
        .order('created_at');
    return (data as List)
        .map((e) => ClubMilestoneTopic.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClubMilestoneTopic> addMilestoneTopic({
    required String milestoneId,
    required String clubId,
    required String content,
    String spoilerLevel = 'none',
    String? parentId,
  }) async {
    final data = await _client
        .from('club_milestone_topics')
        .insert({
          'milestone_id': milestoneId,
          'club_id': clubId,
          'user_id': _userId,
          'content': content,
          'spoiler_level': spoilerLevel,
          'parent_id': parentId,
        })
        .select('*, profile:profiles(name, avatar_url)')
        .single();
    return ClubMilestoneTopic.fromMap(data);
  }

  // ── Desafios ─────────────────────────────────────────────────────────────

  Future<List<ClubChallenge>> listChallenges(String clubId,
      {bool activeOnly = false}) async {
    var q = _client
        .from('club_challenges')
        .select()
        .eq('club_id', clubId);
    if (activeOnly) q = q.eq('status', 'active');
    final data = await q.order('ends_at', ascending: false);
    return (data as List)
        .map((e) => ClubChallenge.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClubChallenge> createChallenge({
    required String clubId,
    required String title,
    String? description,
    required ChallengeGoalType goalType,
    required int goalValue,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final data = await _client
        .from('club_challenges')
        .insert({
          'club_id': clubId,
          'created_by': _userId,
          'title': title,
          'description': description,
          'goal_type': goalType.dbValue,
          'goal_value': goalValue,
          'starts_at': startsAt.toIso8601String(),
          'ends_at': endsAt.toIso8601String(),
        })
        .select()
        .single();
    return ClubChallenge.fromMap(data);
  }

  Future<List<ChallengeProgressEntry>> fetchChallengeProgress(
      String challengeId) async {
    final data = await _client.rpc(
      'club_challenge_progress',
      params: {'p_challenge_id': challengeId},
    );
    return (data as List)
        .map((e) => ChallengeProgressEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ── Votações Livres (Open Polls) ─────────────────────────────────────────

  Future<List<ClubOpenPoll>> listOpenPolls(String clubId) async {
    final data = await _client
        .from('club_open_polls')
        .select()
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ClubOpenPoll.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClubOpenPoll> createOpenPoll({
    required String clubId,
    required String question,
    required List<OpenPollOption> options,
    bool multiSelect = false,
    DateTime? closesAt,
  }) async {
    final data = await _client
        .from('club_open_polls')
        .insert({
          'club_id': clubId,
          'created_by': _userId,
          'question': question,
          'options': options.map((o) => o.toMap()).toList(),
          'multi_select': multiSelect,
          'closes_at': closesAt?.toIso8601String(),
        })
        .select()
        .single();
    return ClubOpenPoll.fromMap(data);
  }

  Future<void> voteOnOpenPoll(String pollId, List<String> optionIds) async {
    // Usa RPC SECURITY DEFINER para evitar rejeição silenciosa do upsert direto
    // quando a policy UPDATE não tem WITH CHECK.
    await _client.rpc('vote_on_open_poll', params: {
      'p_poll_id': pollId,
      'p_option_ids': optionIds,
    });
  }

  Future<List<OpenPollOptionResult>> fetchOpenPollResults(
      String pollId) async {
    final data = await _client.rpc(
      'open_poll_results',
      params: {'p_poll_id': pollId},
    );
    return (data as List)
        .map((e) =>
            OpenPollOptionResult.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> closeOpenPoll(String pollId) async {
    await _client
        .from('club_open_polls')
        .update({'status': 'closed'}).eq('id', pollId);
  }

  // ── F-01 Rest Days ───────────────────────────────────────────────────────

  /// Retorna quantos rest days o usuário ainda tem disponíveis no desafio.
  Future<int> fetchRestDaysLeft(String challengeId) async {
    // Lê allowed_rest_days do próprio desafio
    final challengeData = await _client
        .from('club_challenges')
        .select('allowed_rest_days')
        .eq('id', challengeId)
        .maybeSingle();
    if (challengeData == null) return 0;
    final allowed =
        (challengeData['allowed_rest_days'] as num?)?.toInt() ?? 0;
    if (allowed == 0) return 0;
    final usedData = await _client
        .from('challenge_rest_day_usage')
        .select('rest_date')
        .eq('challenge_id', challengeId)
        .eq('user_id', _userId);
    final used = (usedData as List).length;
    return (allowed - used).clamp(0, allowed);
  }

  /// Marca hoje como dia de descanso via RPC do banco.
  /// Retorna false se já não há saldo ou a RPC lançar exceção.
  Future<bool> useRestDay(String challengeId) async {
    try {
      await _client.rpc('use_challenge_rest_day', params: {
        'p_challenge_id': challengeId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── F-02/F-03 Heatmap de check-ins do desafio ────────────────────────────

  /// Retorna mapa dia→valor (pages_read + is_rest_day) para o heatmap.
  Future<Map<String, int>> fetchChallengeHeatmap(String challengeId) async {
    final data = await _client.rpc('challenge_heatmap', params: {
      'p_challenge_id': challengeId,
    });
    final result = <String, int>{};
    for (final row in (data as List)) {
      final day = row['day'] as String;
      // Usa pages_read como intensidade principal; fallback para sessions_count
      final pages = (row['pages_read'] as num?)?.toInt() ?? 0;
      final sessions = (row['sessions_count'] as num?)?.toInt() ?? 0;
      result[day] = pages > 0 ? pages : sessions;
    }
    return result;
  }

  // ── F-04 Tela de encerramento ────────────────────────────────────────────

  /// Retorna o snapshot de resultado gravado pela RPC finalize_challenge.
  Future<Map<String, dynamic>?> fetchChallengeResult(
      String challengeId) async {
    final data = await _client
        .from('challenge_results')
        .select()
        .eq('challenge_id', challengeId)
        .maybeSingle();
    return data != null ? Map<String, dynamic>.from(data as Map) : null;
  }

  // ── F-06 Cheer ───────────────────────────────────────────────────────────

  /// Toggle de cheer em um post do feed. Retorna true se foi adicionado.
  Future<bool> toggleCheer(String feedId) async {
    final result = await _client.rpc('toggle_cheer', params: {
      'p_feed_id': feedId,
    });
    return result as bool? ?? false;
  }

  // ── Progresso coletivo do desafio ────────────────────────────────────────

  /// Retorna o progresso agregado do clube no desafio via RPC.
  /// Usado pelo bloco coletivo na tela de detalhe e no nudge semanal.
  Future<ChallengeCollectiveProgress?> fetchCollectiveProgress(
      String challengeId) async {
    final data = await _client.rpc(
      'club_challenge_collective_progress',
      params: {'p_challenge_id': challengeId},
    );
    final rows = data as List?;
    if (rows == null || rows.isEmpty) return null;
    return ChallengeCollectiveProgress.fromMap(
        rows.first as Map<String, dynamic>);
  }

  // ── Membros que já contribuíram hoje no desafio ──────────────────────────

  /// Retorna lista de membros que registraram pelo menos uma sessão de leitura
  /// hoje (UTC) dentro do período do desafio.
  /// Usado pela fileira de avatares "Já leram hoje" na tela de detalhe.
  Future<List<Map<String, String?>>> fetchTodayContributors(
      String challengeId) async {
    final today = DateTime.now().toUtc();
    final dayStart = DateTime.utc(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Busca sessões associadas ao desafio hoje, join com perfil para foto
    final data = await _client
        .from('club_challenge_contributions')
        .select('user_id, profile:profiles!club_challenge_contributions_user_id_fkey(name, avatar_url)')
        .eq('challenge_id', challengeId)
        .gte('contributed_at', dayStart.toIso8601String())
        .lt('contributed_at', dayEnd.toIso8601String());

    final rows = (data as List).cast<Map<String, dynamic>>();
    // Deduplica por user_id (pode ter múltiplas contribuições no dia)
    final seen = <String>{};
    final result = <Map<String, String?>>[];
    for (final row in rows) {
      final uid = row['user_id'] as String? ?? '';
      if (seen.contains(uid)) continue;
      seen.add(uid);
      final profile = row['profile'] as Map<String, dynamic>? ?? {};
      result.add({
        'user_id': uid,
        'name': profile['name'] as String?,
        'avatar_url': profile['avatar_url'] as String?,
      });
    }
    return result;
  }

  // ── Contribuição pessoal do usuário corrente no desafio ─────────────────

  /// Retorna o percentual de contribuição do usuário no total coletivo.
  /// Ex: 8.0 = "você contribuiu com 8% do progresso do clube".
  /// Retorna null se não houver progresso coletivo ainda.
  Future<double?> fetchMyContributionPct(String challengeId) async {
    final data = await _client.rpc(
      'challenge_my_contribution_pct',
      params: {'p_challenge_id': challengeId},
    );
    final rows = data as List?;
    if (rows == null || rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return (row['contribution_pct'] as num?)?.toDouble();
  }

  // ── F-09 Perfil histórico (all-time) ─────────────────────────────────────

  /// Retorna stats all-time + desafios do membro no clube via RPC.
  Future<Map<String, dynamic>?> fetchMemberAllTimeStats(
      String clubId, String userId) async {
    final data = await _client.rpc('member_club_profile', params: {
      'p_club_id': clubId,
      'p_user_id': userId,
    });
    final rows = data as List?;
    if (rows == null || rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  // ── Selos (V2) ────────────────────────────────────────────────────────────────

  /// Retorna todos os selos de um clube, ordenados do mais recente.
  Future<List<ClubSeal>> listSeals(String clubId) async {
    final data = await _client
        .from('club_seals_view')
        .select()
        .eq('club_id', clubId)
        .order('awarded_at', ascending: false);
    return (data as List)
        .map((e) => ClubSeal.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Retorna selos de um membro específico no clube.
  Future<List<ClubSeal>> listSealsByMember(
      String clubId, String userId) async {
    final data = await _client
        .from('club_seals_view')
        .select()
        .eq('club_id', clubId)
        .eq('awarded_to', userId)
        .order('awarded_at', ascending: false);
    return (data as List)
        .map((e) => ClubSeal.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Atribui um selo a um membro. Apenas managers.
  Future<ClubSeal> awardSeal({
    required String clubId,
    required String awardedTo,
    required SealType sealType,
    String? description,
    String? bookHistoryId,
    String? challengeId,
  }) async {
    final inserted = await _client
        .from('club_seals')
        .insert({
          'club_id': clubId,
          'awarded_to': awardedTo,
          'awarded_by': _userId,
          'seal_type': sealType.dbValue,
          if (description?.isNotEmpty == true) 'description': description,
          if (bookHistoryId != null) 'book_history_id': bookHistoryId,
          if (challengeId != null) 'challenge_id': challengeId,
        })
        .select('id')
        .single();
    // Busca o registro completo via view (inclui nomes e avatares)
    final data = await _client
        .from('club_seals_view')
        .select()
        .eq('id', inserted['id'] as String)
        .single();
    return ClubSeal.fromMap(data);
  }

  /// Remove um selo. Apenas managers.
  Future<void> revokeSeal(String sealId) async {
    await _client.from('club_seals').delete().eq('id', sealId);
  }

  // ── Diário do Livro (V3) ──────────────────────────────────────────────────────

  /// Retorna sessões com mini_review ou mood preenchidos para um livro específico.
  /// Ordenadas cronologicamente — base para o Diário do Livro.
  Future<List<ReadingSession>> fetchBookDiary(String bookId) async {
    final data = await _client
        .from('reading_sessions')
        .select()
        .eq('book_id', bookId)
        .eq('status', 'finished')
        .or('mini_review.not.is.null,mood.not.is.null')
        .order('started_at', ascending: true);
    return (data as List)
        .map((e) => ReadingSession.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ── Momento do Clube (V2) ─────────────────────────────────────────────────────

  /// Confirma a presença do usuário no Momento de hoje.
  Future<void> confirmReadingMoment(String clubId) async {
    await _client
        .rpc('confirm_reading_moment', params: {'p_club_id': clubId});
  }

  /// Retorna o número de confirmações do Momento para hoje.
  Future<int> getMomentConfirmationsToday(String clubId) async {
    final result = await _client.rpc(
        'moment_confirmations_today', params: {'p_club_id': clubId});
    return (result as num?)?.toInt() ?? 0;
  }

  /// Verifica se o usuário atual já confirmou o Momento hoje.
  Future<bool> userConfirmedMomentToday(String clubId) async {
    final result = await _client.rpc(
        'user_confirmed_moment_today', params: {'p_club_id': clubId});
    return result as bool? ?? false;
  }

  // ── Estatísticas Avançadas (V3) ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMostReadBooks(
      String clubId) async {
    final data = await _client
        .rpc('club_most_read_book', params: {'p_club_id': clubId});
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMostConsistentMembers(
      String clubId) async {
    final data = await _client
        .rpc('club_most_consistent_member', params: {'p_club_id': clubId});
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMostProductiveMonths(
      String clubId) async {
    final data = await _client
        .rpc('club_most_productive_months', params: {'p_club_id': clubId});
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMostControversialBooks(
      String clubId) async {
    final data = await _client
        .rpc('club_most_controversial_book', params: {'p_club_id': clubId});
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── Resenhas Construtivas (Seção 8) ──────────────────────────────────────────

  /// Insere ou atualiza a resenha do usuário para um ciclo de livro.
  /// Retorna a resenha persistida.
  Future<ClubReview> submitReview({
    required String clubId,
    required String bookHistoryId,
    required int rating,
    String? whatWorked,
    String? whatDidnt,
    WouldRecommend wouldRecommend = WouldRecommend.yes,
    ReviewSpoilerLevel spoilerLevel = ReviewSpoilerLevel.none,
  }) async {
    final data = await _client.rpc('submit_club_review', params: {
      'p_club_id':          clubId,
      'p_book_history_id':  bookHistoryId,
      'p_rating':           rating,
      'p_what_worked':      whatWorked,
      'p_what_didnt':       whatDidnt,
      'p_would_recommend':  wouldRecommend.dbValue,
      'p_spoiler_level':    spoilerLevel.dbValue,
    });
    return ClubReview.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  /// Lista todas as resenhas de um ciclo de leitura + média do rating.
  Future<List<ClubReview>> fetchBookReviews(String bookHistoryId) async {
    final data = await _client.rpc(
      'fetch_book_reviews',
      params: {'p_book_history_id': bookHistoryId},
    );
    return (data as List)
        .map((e) => ClubReview.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Retorna estatísticas de resenhas do clube (média, variância por livro).
  /// Alimenta "livro mais controverso" com dado real de rating.
  Future<List<ClubReviewStats>> fetchClubReviewStats(String clubId) async {
    final data = await _client.rpc(
      'fetch_club_review_stats',
      params: {'p_club_id': clubId},
    );
    return (data as List)
        .map((e) => ClubReviewStats.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Retorna a resenha do usuário atual para um ciclo específico, se existir.
  Future<ClubReview?> fetchMyReview(String bookHistoryId) async {
    final data = await _client
        .from('club_reviews')
        .select()
        .eq('book_history_id', bookHistoryId)
        .eq('user_id', _userId)
        .maybeSingle();
    if (data == null) return null;
    return ClubReview.fromMap(Map<String, dynamic>.from(data as Map));
  }

  // ── Presença em tempo real ───────────────────────────────────────────────

  /// Atualiza o last_seen_at do usuário atual.
  Future<void> updateMyPresence() async {
    await _client.rpc('update_my_presence');
  }

  /// Retorna membros do clube que estiveram ativos nos últimos [windowMinutes].
  Future<List<ClubPresenceMember>> fetchPresence(
    String clubId, {
    int windowMinutes = 30,
  }) async {
    final data = await _client.rpc('club_presence', params: {
      'p_club_id': clubId,
      'p_window_minutes': windowMinutes,
    });
    return (data as List)
        .map((e) => ClubPresenceMember.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ── Estatísticas coletivas ───────────────────────────────────────────────

  /// Retorna totais históricos do clube + contribuição % do usuário atual.
  Future<ClubCollectiveStats?> fetchCollectiveStats(String clubId) async {
    final data = await _client.rpc(
      'club_collective_stats',
      params: {'p_club_id': clubId},
    );
    final list = data as List;
    if (list.isEmpty) return null;
    return ClubCollectiveStats.fromMap(list.first as Map<String, dynamic>);
  }

  // ── Heatmap social ───────────────────────────────────────────────────────

  /// Retorna atividade coletiva do clube por dia nos últimos [days] dias.
  Future<List<ClubHeatmapDay>> fetchSocialHeatmap(
    String clubId, {
    int days = 30,
  }) async {
    final data = await _client.rpc('club_social_heatmap', params: {
      'p_club_id': clubId,
      'p_days': days,
    });
    return (data as List)
        .map((e) => ClubHeatmapDay.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ── Mentor ───────────────────────────────────────────────────────────────

  /// Promove ou rebaixa um membro para o papel de mentor.
  Future<void> setMentor({
    required String clubId,
    required String userId,
    required bool promote,
  }) async {
    await _client.rpc('set_club_mentor', params: {
      'p_club_id': clubId,
      'p_user_id': userId,
      'p_promote': promote,
    });
  }

  /// Mentor dá boas-vindas a um novo membro (publica no feed do clube).
  Future<void> mentorWelcomeMember({
    required String clubId,
    required String newMemberId,
    String? message,
  }) async {
    await _client.rpc('mentor_welcome_member', params: {
      'p_club_id': clubId,
      'p_new_member_id': newMemberId,
      if (message != null) 'p_message': message,
    });
  }

  // ── Tópicos de Discussão Geral ───────────────────────────────────────────

  /// Lista todos os tópicos de discussão geral do clube.
  Future<List<ClubDiscussionTopic>> listDiscussionTopics(String clubId) async {
    final data = await _client
        .from('club_milestone_topics')
        .select('*, profile:profiles!created_by(name, avatar_url)')
        .eq('club_id', clubId)
        .order('created_at', ascending: true);
    return (data as List)
        .map((e) => ClubDiscussionTopic.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Adiciona um tópico ou resposta de discussão geral.
  Future<ClubDiscussionTopic> addDiscussionTopic({
    required String clubId,
    required String content,
    String? parentId,
  }) async {
    final inserted = await _client
        .from('club_milestone_topics')
        .insert({
          'club_id': clubId,
          'created_by': _userId,
          'content': content,
          if (parentId != null) 'parent_id': parentId,
        })
        .select('*, profile:profiles!created_by(name, avatar_url)')
        .single();
    return ClubDiscussionTopic.fromMap(
        Map<String, dynamic>.from(inserted as Map));
  }

  // ── Teorias do Clube ──────────────────────────────────────────────────────

  /// Lista todas as teorias de um clube, ordenadas do mais votado para o menos.
  Future<List<ClubTheory>> listTheories(String clubId) async {
    final data = await _client.rpc('list_club_theories', params: {
      'p_club_id': clubId,
      'p_user_id': _userId,
    });
    return (data as List)
        .map((e) => ClubTheory.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria uma nova teoria.
  Future<ClubTheory> addTheory({
    required String clubId,
    required String content,
    String? milestoneId,
  }) async {
    final inserted = await _client
        .from('club_theories')
        .insert({
          'club_id': clubId,
          'created_by': _userId,
          'content': content,
          'status': 'open',
          if (milestoneId != null) 'milestone_id': milestoneId,
        })
        .select('id')
        .single();
    final rows = await _client.rpc('list_club_theories', params: {
      'p_club_id': clubId,
      'p_user_id': _userId,
    });
    final id = inserted['id'] as String;
    final row = (rows as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['id'] == id);
    return ClubTheory.fromMap(row);
  }

  /// Alterna o voto do usuário em uma teoria (toggle).
  Future<void> toggleTheoryVote(String theoryId) async {
    await _client.rpc('toggle_theory_vote', params: {
      'p_theory_id': theoryId,
      'p_user_id': _userId,
    });
  }

  /// Atualiza o status de uma teoria. Apenas managers.
  Future<void> setTheoryStatus({
    required String theoryId,
    required String status, // 'open' | 'confirmed' | 'wrong'
  }) async {
    await _client
        .from('club_theories')
        .update({'status': status})
        .eq('id', theoryId);
  }

  // ── Ranking por dias com check-in ────────────────────────────────────────
  // [scope]: 'all' (histórico completo) | 'current_book' (ciclo atual)
  // Critério aprovado: dias distintos com pelo menos um check-in — não por
  // páginas, minutos ou sessões. Ver lumen-clube-pontuacao-logica.md.
  Future<List<ClubCheckinRankingEntry>> fetchCheckinRanking(
    String clubId, {
    String scope = 'all',
    DateTime? bookStartedAt,
  }) async {
    final String? startedAtIso = (scope == 'current_book' && bookStartedAt != null)
        ? bookStartedAt.toIso8601String()
        : null;

    // Consulta check-ins de clube (tabela: club_reading_checkins)
    // Agrupa por user_id, conta dias distintos dentro da janela.
    final data = await _client.rpc(
      'club_checkin_ranking',
      params: {
        'p_club_id': clubId,
        if (startedAtIso != null) 'p_started_at': startedAtIso,
      },
    );

    final rows = List<Map<String, dynamic>>.from(data as List);
    int rank = 0;
    int? prev;
    final result = <ClubCheckinRankingEntry>[];
    for (final row in rows) {
      final days = (row['checkin_days'] as num).toInt();
      if (days != prev) {
        rank++;
        prev = days;
      }
      result.add(ClubCheckinRankingEntry(
        position: rank,
        userId: row['user_id'] as String,
        userName: row['user_name'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        checkinDays: days,
      ));
    }
    return result;
  }
}
