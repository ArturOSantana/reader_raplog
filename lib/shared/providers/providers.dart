import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/library/data/book_repository.dart';
import '../../features/session/data/session_repository.dart';
import '../../features/achievements/data/achievement_repository.dart';
import '../../features/notes/data/note_repository.dart';

// Supabase client
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// Auth state
final authStateProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);

final currentUserProvider = Provider<User?>(
  (ref) => Supabase.instance.client.auth.currentUser,
);

// Repositories
final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(ref.watch(supabaseClientProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(supabaseClientProvider)),
);

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(ref.watch(supabaseClientProvider)),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(supabaseClientProvider)),
);
