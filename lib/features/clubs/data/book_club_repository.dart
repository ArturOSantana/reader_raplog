import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/book_club.dart';

class BookClubRepository {
  final SupabaseClient _client;

  BookClubRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ── Listar clubes do usuário ─────────────────────────────────────────────

  Future<List<BookClub>> listMyClubs() async {
    final data = await _client
        .from('book_club_members')
        .select(
          'role, club:book_clubs(id, name, description, cover_url, admin_id, '
          'current_book_id, current_book_title, current_book_author, created_at)',
        )
        .eq('user_id', _userId);

    final List<BookClub> clubs = [];
    for (final row in (data as List)) {
      final clubMap = row['club'] as Map<String, dynamic>?;
      if (clubMap == null) continue;

      // Busca contagem de membros
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

  // ── Criar clube ──────────────────────────────────────────────────────────

  Future<BookClub> createClub({
    required String name,
    String? description,
    String? coverUrl,
  }) async {
    final clubData = await _client
        .from('book_clubs')
        .insert({
          'admin_id': _userId,
          'name': name,
          'description': description,
          'cover_url': coverUrl,
        })
        .select()
        .single();

    // Insere o criador como admin
    await _client.from('book_club_members').insert({
      'club_id': clubData['id'],
      'user_id': _userId,
      'role': 'admin',
    });

    return BookClub.fromMap({
      ...clubData,
      'member_count': 1,
      'member_role': 'admin',
    });
  }

  // ── Atualizar livro atual ────────────────────────────────────────────────

  Future<void> setCurrentBook({
    required String clubId,
    required String bookTitle,
    String? bookAuthor,
    String? bookId,
  }) async {
    await _client.from('book_clubs').update({
      'current_book_title': bookTitle,
      'current_book_author': bookAuthor,
      'current_book_id': bookId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clubId);
  }

  // ── Membros ──────────────────────────────────────────────────────────────

  Future<List<ClubMember>> listMembers(String clubId) async {
    final data = await _client
        .from('book_club_members')
        .select('id, club_id, user_id, role, joined_at, '
            'profile:profiles(name, avatar_url)')
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

  Future<void> leaveClub(String clubId) async {
    await _client
        .from('book_club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', _userId);
  }

  Future<void> removeMember(String clubId, String userId) async {
    await _client
        .from('book_club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);
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
}
