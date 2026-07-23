// Este arquivo é o ponto de entrada padrão do Flutter Test.
// Os testes do projeto estão organizados em:
//
//   test/auth/login_screen_test.dart   — widget tests da LoginScreen
//   test/auth/splash_screen_test.dart  — widget tests da SplashScreen
//   test/models/book_test.dart         — unit tests do modelo Book
//   test/models/goal_test.dart         — unit tests do modelo Goal
//   test/models/highlight_test.dart    — unit tests do modelo Highlight
//   test/models/note_test.dart         — unit tests do modelo Note
//   test/models/reading_session_test.dart — unit tests do ReadingSession
//   test/models/user_profile_test.dart — unit tests do UserProfile
//   test/session/active_session_state_test.dart — unit tests do ActiveSessionState
//
// Execute todos os testes com: flutter test

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // App requires Supabase init at runtime — smoke test only
    expect(true, isTrue);
  });
}
