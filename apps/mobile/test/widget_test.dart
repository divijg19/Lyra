// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lyra/core/auth/auth_notifier.dart';
import 'package:lyra/main.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async {
    return const AuthState.unauthenticated();
  }
}

void main() {
  testWidgets('redirects unauthenticated users to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authNotifierProvider.overrideWith(_TestAuthNotifier.new)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lyra Login'), findsOneWidget);
    expect(find.text('Continue with Spotify'), findsOneWidget);
  });
}
