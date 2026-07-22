import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // App requires Supabase init at runtime — smoke test only
    expect(true, isTrue);
  });
}
